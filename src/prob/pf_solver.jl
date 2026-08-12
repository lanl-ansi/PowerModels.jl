"""
    PowerFlowSystem(f!, j!, x0, p0, jac_prototype)

Contains a reduced statement of the power flow problem. Should contain everything a
Newton-type solver requires to solve the system.

* `f!` -- `(res, x, p) -> nothing`, the in-place residual function
* `j!` -- `(J, x, p) -> nothing`, the in-place analytic Jacobian function
* `x0` -- the initial starting point
* `p0` -- parameter vector containing the operating point (e.g. power injections)
* `jac_prototype` -- sparse matrix containing the Jacobian sparsity pattern

Everything that is specific to the network (bus types, admittance values,
index maps) can be compiled into `f!` and `j!` at construction time. The
solver only ends up seeing the sparse nonlinear system. See
`build_pf_system` for building this data structure from network data.
"""
struct PowerFlowSystem{F,J}
    f!::F
    j!::J
    x0::Vector{Float64}
    p0::Vector{Float64}
    jac_prototype::SparseArrays.SparseMatrixCSC{Float64,Int}
end


"""
    PowerFlowSolution(x, converged, iterations, residual_norm)

Holds the power flow result. Should be solver-agnostic. 

* `x` -- the solution vector
* `converged` -- `true` if the solver reached its convergence tolerance
* `iterations` -- the number of solver iterations taken
* `residual_norm` -- the infinity norm of the residual at `x` |f(x)|_∞
"""
struct PowerFlowSolution
    x::Vector{Float64}
    converged::Bool
    iterations::Int
    residual_norm::Float64
end


"""
    NativeNewton(; maxiters = 50, abstol = 1e-8, linesearch = true, maxstep = 10.0)

Built-in power flow solver that ships with PowerModels. It is a damped Newton method
using the analytic sparse Jacobian and a sparse LU factorization in each iteration.

* `maxiters` -- maximum number of Newton iterations
* `abstol` -- convergence tolerance on the residual's infinity norm
* `linesearch` -- when `true`, a backtracking line search is applied to each step
* `maxstep` -- a limit on the infinity norm of each Newton step, which keeps
  iterates from blowing up. Set to `Inf` to disable the limit.
"""
Base.@kwdef struct NativeNewton
    maxiters::Int = 50
    abstol::Float64 = 1e-8
    linesearch::Bool = true
    maxstep::Float64 = 10.0
end


"
The entry point for power flow solver backend. 

A backend can be added by adding a new method dispatch for your algorithm type. For 
example: _solve_nl(sys::PowerFlowSystem, alg::MyNewAlgorithm) = ...
"
function _solve_nl(sys::PowerFlowSystem, alg; kwargs...)
    @_error("no power flow solver available for an algorithm of type `$(typeof(alg))`, use `NativeNewton()` instead")
end


function _solve_nl(sys::PowerFlowSystem, alg::NativeNewton)
    x = copy(sys.x0)
    p = sys.p0

    res = similar(x)
    res_trial = similar(x)
    x_trial = similar(x)
    J = copy(sys.jac_prototype)

    sys.f!(res, x, p)
    residual_norm = LinearAlgebra.norm(res, Inf)
    if residual_norm <= alg.abstol
        return PowerFlowSolution(x, true, 0, residual_norm)
    end

    for iter in 1:alg.maxiters
        sys.j!(J, x, p)

        dx = try
            -(J \ res)
        catch err
            # errors other than a singular jacobian propagate to the caller
            err isa LinearAlgebra.SingularException || rethrow(err)
            @_debug("newton iteration $(iter) produced a singular jacobian")
            return PowerFlowSolution(x, false, iter - 1, residual_norm)
        end

        # cap the step length in the infinity norm
        dx_norm = LinearAlgebra.norm(dx, Inf)
        if dx_norm > alg.maxstep
            dx .*= alg.maxstep / dx_norm
        end

        if alg.linesearch
            # backtracking line search with a sufficient decrease condition
            res_norm = LinearAlgebra.norm(res)
            alpha = 1.0
            accepted = false
            for _ in 1:10
                x_trial .= x .+ alpha .* dx
                sys.f!(res_trial, x_trial, p)
                if LinearAlgebra.norm(res_trial) <= (1.0 - 1.0e-4*alpha) * res_norm
                    accepted = true
                    break
                end
                alpha *= 0.5
            end
            if !accepted
                # take the smallest evaluated step anyway, a stalled
                # iteration is caught by the maxiters limit
                @_debug("newton iteration $(iter) line search failed to make progress")
            end
            copyto!(x, x_trial)
            copyto!(res, res_trial)
        else
            x .+= dx
            sys.f!(res, x, p)
        end

        residual_norm = LinearAlgebra.norm(res, Inf)
        if residual_norm <= alg.abstol
            return PowerFlowSolution(x, true, iter, residual_norm)
        end
    end

    return PowerFlowSolution(x, false, alg.maxiters, residual_norm)
end
