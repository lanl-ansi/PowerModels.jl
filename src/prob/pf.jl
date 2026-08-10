"solves the AC Power Flow in polar coordinates using a JuMP model"
function solve_ac_pf(file, optimizer; kwargs...)
    return solve_pf(file, ACPPowerModel, optimizer; kwargs...)
end

"solves the linear DC Power Flow using a JuMP model"
function solve_dc_pf(file, optimizer; kwargs...)
    return solve_pf(file, DCPPowerModel, optimizer; kwargs...)
end

"solves a formulation-agnostic Power Flow using a JuMP model"
function solve_pf(file, model_type::Type, optimizer; kwargs...)
    return solve_model(file, model_type, optimizer, build_pf; kwargs...)
end

"specification of the formulation agnostic Power Flow model"
function build_pf(pm::AbstractPowerModel)
    variable_bus_voltage(pm, bounded=false)
    variable_gen_power(pm, bounded=false)
    variable_dcline_power(pm, bounded=false)

    for i in ids(pm, :branch)
        expression_branch_power_ohms_yt_from(pm, i)
        expression_branch_power_ohms_yt_to(pm, i)
    end

    constraint_model_voltage(pm)

    for (i, bus) in ref(pm, :ref_buses)
        @assert is_slack_bus(bus)
        constraint_theta_ref(pm, i)
        constraint_voltage_magnitude_setpoint(pm, i)

        # if multiple generators, fix power generation degeneracies
        if length(ref(pm, :bus_gens, i)) > 1
            for j in collect(ref(pm, :bus_gens, i))[2:end]
                constraint_gen_setpoint_active(pm, j)
                constraint_gen_setpoint_reactive(pm, j)
            end
        end
    end

    for (i, bus) in ref(pm, :bus)
        constraint_power_balance(pm, i)

        # PV Bus Constraints
        if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm, :ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert is_pv_bus(bus)

            constraint_voltage_magnitude_setpoint(pm, i)
            for j in ref(pm, :bus_gens, i)
                constraint_gen_setpoint_active(pm, j)
            end
        end
    end


    for (i, dcline) in ref(pm, :dcline)
        #constraint_dcline_power_losses(pm, i) not needed, active power flow fully defined by dc line setpoints
        constraint_dcline_setpoint_active(pm, i)

        f_bus = ref(pm, :bus)[dcline["f_bus"]]
        if is_pq_bus(f_bus)
            constraint_voltage_magnitude_setpoint(pm, f_bus["index"])
        end

        t_bus = ref(pm, :bus)[dcline["t_bus"]]
        if is_pq_bus(t_bus)
            constraint_voltage_magnitude_setpoint(pm, t_bus["index"])
        end
    end
end



function compute_dc_pf(file::String; kwargs...)
    data = parse_file(file)
    return compute_dc_pf(data, kwargs...)
end

"""
computes a linear DC power flow based on the susceptance matrix of the network
data using Julia's native linear equation solvers.

returns a solution data structure in PowerModels Dict format
"""
function compute_dc_pf(data::Dict{String,<:Any})
    time_start = time()
    #TODO check single connected component and ref bus

    ref_bus = reference_bus(data)

    bi = calc_bus_injection_active(data)

    # accounts for vm = 1.0 assumption
    for (i, shunt) in data["shunt"]
        if shunt["status"] != 0 && !isapprox(shunt["gs"], 0.0)
            bi[shunt["shunt_bus"]] += shunt["gs"]
        end
    end

    sm = calc_susceptance_matrix(data)

    bi_idx = [bi[bus_id] for bus_id in sm.idx_to_bus]

    ref_idx = sm.bus_to_idx[ref_bus["index"]]

    theta_idx = solve_theta(sm, ref_idx, bi_idx)

    bus_assignment = Dict{String,Any}()
    for (i, bus) in data["bus"]
        va = NaN
        if haskey(sm.bus_to_idx, bus["index"])
            va = theta_idx[sm.bus_to_idx[bus["index"]]]
        end
        bus_assignment[i] = Dict("va" => va)
    end

    solution = Dict("per_unit" => data["per_unit"], "bus" => bus_assignment)

    result = Dict(
        "optimizer" => string(\),
        "termination_status" => true,
        "objective" => 0.0,
        "solution" => solution,
        "solve_time" => time() - time_start
    )

    return result
end




"""
internal data required used solving an ac power flow

the primary use of this data structure is to prevent re-allocation of memory
between successive power flow solves

* `data` -- a power models data dictionary
* `bus_gens` -- for each bus id, a list of active generators
* `am` -- an admittance matrix computed from the data dictionary
* `bus_type_idx` -- bus types (i.e., 1, 2, 3)
* `p_delta_base_idx` -- fixed active power delta at a bus
* `q_delta_base_idx` -- fixed reactive power delta at a bus
* `p_inject_idx` -- variable active power generator injection at a bus
* `q_inject_idx` -- variable reactive power generator injection at a bus
* `vm_idx` -- variable voltage magnitude at a bus
* `va_idx` -- variable voltage angle at a bus
* `neighbors` -- neighboring buses to a given bus
* `x0` -- 2*|N| variables, one for each bus, varies based on bus type
* `F0` -- 2*|N| bus power balance evaluation values, active power followed by reactive power
* `J0` -- a sparse matrix holding the Jacobian of the F0 power balance evaluation function

The postfix `_idx` indicates the admittance matrix indexing convention.
"""
struct PowerFlowData
    data::Dict{String,<:Any}
    bus_gens::Dict{Int,Vector}
    am::AdmittanceMatrix{Complex{Float64}}
    bus_type_idx::Vector{Int}
    p_delta_base_idx::Vector{Float64}
    q_delta_base_idx::Vector{Float64}
    p_inject_idx::Vector{Float64}
    q_inject_idx::Vector{Float64}
    vm_idx::Vector{Float64}
    va_idx::Vector{Float64}
    neighbors::Vector{Set{Int}}
    x0::Vector{Float64}
    F0::Vector{Float64}
    J0::SparseArrays.SparseMatrixCSC{Float64,Int}
end


function instantiate_pf_data(data::Dict{String,<:Any})
    p_delta, q_delta = calc_bus_injection(data)

    # remove gen injections from slack and pv buses
    for (i, gen) in data["gen"]
        gen_bus = data["bus"]["$(gen["gen_bus"])"]
        if gen["gen_status"] != 0
            if is_slack_bus(gen_bus)
                p_delta[gen_bus["index"]] -= gen["pg"]
                q_delta[gen_bus["index"]] -= gen["qg"]
            elseif is_pv_bus(gen_bus)
                q_delta[gen_bus["index"]] -= gen["qg"]
            else
                @assert false
            end
        end
    end


    bus_gens = Dict{Int,Array{Any}}()
    for (i, gen) in data["gen"]
        # skip inactive generators
        if gen["gen_status"] == 0
            continue
        end

        gen_bus_id = gen["gen_bus"]
        if !haskey(bus_gens, gen_bus_id)
            bus_gens[gen_bus_id] = []
        end
        push!(bus_gens[gen_bus_id], gen)
    end

    for (bus_id, gens) in bus_gens
        sort!(gens, by=x -> (x["qmax"] - x["qmin"], x["index"]))
    end


    am = calc_admittance_matrix(data)

    bus_type_idx = Int[data["bus"]["$(bus_id)"]["bus_type"] for bus_id in am.idx_to_bus]

    p_delta_base_idx = Float64[-p_delta[bus_id] for bus_id in am.idx_to_bus]
    q_delta_base_idx = Float64[-q_delta[bus_id] for bus_id in am.idx_to_bus]

    p_inject_idx = [0.0 for bus_id in am.idx_to_bus]
    q_inject_idx = [0.0 for bus_id in am.idx_to_bus]

    vm_idx = [1.0 for bus_id in am.idx_to_bus]
    va_idx = [0.0 for bus_id in am.idx_to_bus]

    # for buses with non-1.0 bus voltages
    for (i, bus) in data["bus"]
        if is_pv_bus(bus) || is_slack_bus(bus)
            vm_idx[am.bus_to_idx[bus["index"]]] = bus["vm"]
        end
    end


    neighbors = [Set{Int}([i]) for i in eachindex(am.idx_to_bus)]
    I, J, V = SparseArrays.findnz(am.matrix)
    for nz in eachindex(V)
        push!(neighbors[I[nz]], J[nz])
        push!(neighbors[J[nz]], I[nz])
    end

    x0 = [0.0 for i in 1:(2*length(am.idx_to_bus))]
    F0 = similar(x0)

    J0_I = Int[]
    J0_J = Int[]
    J0_V = Float64[]

    for i in eachindex(am.idx_to_bus)
        f_i_r = 2*i - 1
        f_i_i = 2*i

        for j in neighbors[i]
            x_j_fst = 2*j - 1
            x_j_snd = 2*j

            push!(J0_I, f_i_r);
            push!(J0_J, x_j_fst);
            push!(J0_V, 0.0)
            push!(J0_I, f_i_r);
            push!(J0_J, x_j_snd);
            push!(J0_V, 0.0)
            push!(J0_I, f_i_i);
            push!(J0_J, x_j_fst);
            push!(J0_V, 0.0)
            push!(J0_I, f_i_i);
            push!(J0_J, x_j_snd);
            push!(J0_V, 0.0)
        end
    end
    J0 = SparseArrays.sparse(J0_I, J0_J, J0_V)

    return PowerFlowData(data, bus_gens, am, bus_type_idx, p_delta_base_idx, q_delta_base_idx, p_inject_idx, q_inject_idx, vm_idx, va_idx, neighbors, x0, F0, J0)
end



function compute_ac_pf(file::String; kwargs...)
    data = parse_file(file)
    return compute_ac_pf(data; kwargs...)
end

function compute_ac_pf(data::Dict{String,<:Any}; kwargs...)
    # TODO check invariants
    # single connected component
    # all buses of type 2/3 have generators on them

    pf_data = instantiate_pf_data(data)
    return compute_ac_pf(pf_data; kwargs...)
end


"""
Computes a nonlinear AC power flow in polar coordinates based on the admittance
matrix of the network data using a built-in Newton solver.  The solver is
configured with the `solver` keyword argument, e.g.
`solver = NativeNewton(abstol = 1e-10)`, see `NativeNewton` for the available
settings.  The `flat_start` keyword argument disables warm starting from
`_start` values in the network data.

Returns a solution data structure in PowerModels Dict format.  In addition to
the standard result keys, `"termination_status"` holds a `Bool` indicating
convergence and `"iterations"` holds the number of solver iterations taken.
"""
function compute_ac_pf(pf_data::PowerFlowData; kwargs...)
    time_start = time()

    pf_result, solver = _compute_ac_pf(pf_data; kwargs...)

    solution = Dict("per_unit" => pf_data.data["per_unit"])

    converged = pf_result.converged

    if !converged
        @_warn("ac power flow solver did not converge after $(pf_result.iterations) iterations (final residual norm $(pf_result.residual_norm))")
    else
        data = pf_data.data
        bus_gens = pf_data.bus_gens
        am = pf_data.am
        bus_type_idx = pf_data.bus_type_idx

        bus_assignment = Dict{String,Any}()
        for (i, bus) in data["bus"]
            if !is_inactive_bus(bus)
                bus_idx = am.bus_to_idx[bus["index"]]

                bus_assignment[i] = Dict{String,Float64}(
                    "vm" => pf_data.vm_idx[bus_idx],
                    "va" => pf_data.va_idx[bus_idx]
                )
            end
        end

        gen_assignment = Dict{String,Any}()
        for (i, gen) in data["gen"]
            if gen["gen_status"] != 0
                gen_assignment[i] = Dict{String,Float64}(
                    "pg" => gen["pg"],
                    "qg" => gen["qg"]
                )
            end
        end


        for (i, bid) in enumerate(am.idx_to_bus)
            bus = bus_assignment["$(bid)"]

            if is_pq_bus(bus_type_idx[i])
                @assert !haskey(bus_gens, bid)
                bus["vm"] = pf_result.x[2*i-1]
                bus["va"] = pf_result.x[2*i]

            elseif is_pv_bus(bus_type_idx[i])
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["qg"] = 0.0
                end

                qg_remaining = -pf_result.x[2*i-1]
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)

                bus["va"] = pf_result.x[2*i]

            elseif is_slack_bus(bus_type_idx[i])
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["pg"] = 0.0
                    sol_gen["qg"] = 0.0
                end

                pg_remaining = -pf_result.x[2*i-1]
                _assign_pg!(gen_assignment, bus_gens[bid], pg_remaining)

                qg_remaining = -pf_result.x[2*i]
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
            else
                @assert false
            end
        end

        solution = Dict(
            "per_unit" => data["per_unit"],
            "bus" => bus_assignment,
            "gen" => gen_assignment,
        )
    end

    result = Dict(
        "optimizer" => string(nameof(typeof(solver))),
        "termination_status" => converged,
        "iterations" => pf_result.iterations,
        "objective" => 0.0,
        "solution" => solution,
        "solve_time" => time() - time_start
    )

    return result
end


function compute_ac_pf!(data::Dict{String,<:Any}; kwargs...)
    # TODO check invariants
    # single connected component
    # all buses of type 2/3 have generators on them

    pf_data = instantiate_pf_data(data)
    compute_ac_pf!(pf_data; kwargs...)
end


"""
similar to compute_ac_pf but places the solution in the power model's data
dict instead of a separate result object
"""
function compute_ac_pf!(pf_data::PowerFlowData; kwargs...)
    pf_result, solver = _compute_ac_pf(pf_data; kwargs...)

    if !pf_result.converged
        @_warn("ac power flow solver did not converge after $(pf_result.iterations) iterations (final residual norm $(pf_result.residual_norm))")
    end

    data = pf_data.data
    bus_gens = pf_data.bus_gens
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx


    for (i, bid) in enumerate(am.idx_to_bus)
        bus = data["bus"]["$(bid)"]

        bus["vm"] = pf_data.vm_idx[i]
        bus["va"] = pf_data.va_idx[i]

        if is_pq_bus(bus_type_idx[i])
            @assert !haskey(bus_gens, bid)
            #update covered by default update

        elseif is_pv_bus(bus_type_idx[i])
            for gen in bus_gens[bid]
                gen["qg"] = 0.0
            end

            qg_remaining = -pf_result.x[2*i-1]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)

        elseif is_slack_bus(bus_type_idx[i])
            for gen in bus_gens[bid]
                gen["pg"] = 0.0
                gen["qg"] = 0.0
            end

            pg_remaining = -pf_result.x[2*i-1]
            _assign_pg!(data["gen"], bus_gens[bid], pg_remaining)

            qg_remaining = -pf_result.x[2*i]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)
        else
            @assert false
        end
    end
end


function _assign_pg!(sol_gens::Dict{String,<:Any}, bus_gens::Vector, pg_remaining::Float64)
    for gen in bus_gens[1:(end-1)]
        pmin = gen["pmin"]
        pmax = gen["pmax"]

        if (pg_remaining <= 0.0 && pmin >= 0.0) || (pg_remaining >= 0.0 && pmax <= 0.0)
            # keep pg assignment as zero
            continue
        end

        sol_gen = sol_gens["$(gen["index"])"]
        if pg_remaining < pmin
            sol_gen["pg"] = pmin
        elseif pg_remaining > pmax
            sol_gen["pg"] = pmax
        else
            sol_gen["pg"] = pg_remaining
            pg_remaining = 0.0
            break
        end
        pg_remaining -= sol_gen["pg"]
    end
    if !isapprox(pg_remaining, 0.0)
        gen = bus_gens[end]
        sol_gen = sol_gens["$(gen["index"])"]
        sol_gen["pg"] = pg_remaining
    end
end


function _assign_qg!(sol_gens::Dict{String,<:Any}, bus_gens::Vector, qg_remaining::Float64)
    for gen in bus_gens[1:(end-1)]
        qmin = gen["qmin"]
        qmax = gen["qmax"]

        if (qg_remaining <= 0.0 && qmin >= 0.0) || (qg_remaining >= 0.0 && qmax <= 0.0)
            # keep qg assignment as zero
            continue
        end

        sol_gen = sol_gens["$(gen["index"])"]
        if qg_remaining < qmin
            sol_gen["qg"] = qmin
        elseif qg_remaining > qmax
            sol_gen["qg"] = qmax
        else
            sol_gen["qg"] = qg_remaining
            qg_remaining = 0.0
            break
        end
        qg_remaining -= sol_gen["qg"]
    end
    if !isapprox(qg_remaining, 0.0)
        gen = bus_gens[end]
        sol_gen = sol_gens["$(gen["index"])"]
        sol_gen["qg"] = qg_remaining
    end
end


"""
    _update_pf_state!(pf_data::PowerFlowData, x::Vector{Float64})

Writes a solver state vector `x` into the `PowerFlowData` state vectors.
Depending on the bus type, the two entries of `x` for a bus hold different
quantities.  A PQ bus (type 1) holds `vm` and `va`, a PV bus (type 2) holds
`q_inject` and `va`, and a slack bus (type 3) holds `p_inject` and `q_inject`.
"""
function _update_pf_state!(pf_data::PowerFlowData, x::Vector{Float64})
    bus_type_idx = pf_data.bus_type_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx

    for i in eachindex(pf_data.am.idx_to_bus)
        if is_pq_bus(bus_type_idx[i])
            vm_idx[i] = x[2*i-1]
            va_idx[i] = x[2*i]
        elseif is_pv_bus(bus_type_idx[i])
            q_inject_idx[i] = x[2*i-1]
            va_idx[i] = x[2*i]
        elseif is_slack_bus(bus_type_idx[i])
            p_inject_idx[i] = x[2*i-1]
            q_inject_idx[i] = x[2*i]
        else
            @assert false
        end
    end
end


"""
    build_pf_system(pf_data::PowerFlowData; flat_start=false)

Builds a solver-agnostic `PowerFlowSystem` from a `PowerFlowData` data
structure.  The network topology, admittance values and index maps are
compiled into the system's residual and Jacobian functions.  The operating
point (nodal power injections) is placed in the parameter vector `p0`.

The system's `x0` and `jac_prototype` alias the `PowerFlowData`'s `x0` and
`J0` fields and its residual function writes the given state into the
`PowerFlowData`'s state vectors via `_update_pf_state!`.  Solver backends
operate on copies.
"""
function build_pf_system(pf_data::PowerFlowData; flat_start::Bool=false)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    x0 = pf_data.x0

    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64}, p::Vector{Float64})
        _update_pf_state!(pf_data, x)

        for i in eachindex(am.idx_to_bus)
            balance_real = p[2*i-1] + p_inject_idx[i]
            balance_imag = p[2*i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] * real(am.matrix[i, i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i, i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * (real(am.matrix[i, j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i, j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i, j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i, j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i-1] = balance_real
            F[2*i] = balance_imag
        end

        # complex varaint of above
        # for i in eachindex(am.idx_to_bus)
        #     balance = p_inject_idx[i] + q_inject_idx[i]im
        #     for j in neighbors[i]
        #         balance += vm_idx[i] * vm_idx[j] * (am.matrix[i,j] * (cos(va_idx[i] - va_idx[j]) + sin(va_idx[i] - va_idx[j])im))
        #     end
        #     F[2*i - 1] = real(balance)
        #     F[2*i] = imag(balance)
        # end
    end


    # ac power flow, sparse jacobian computation
    function j!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64}, p::Vector{Float64})
        _update_pf_state!(pf_data, x)

        for i in eachindex(am.idx_to_bus)
            f_i_r = 2*i - 1
            f_i_i = 2*i

            for j in neighbors[i]
                x_j_fst = 2*j - 1
                x_j_snd = 2*j

                bus_type = bus_type_idx[j]
                if is_pq_bus(bus_type)
                    if i == j
                        y_ii = am.matrix[i, i]
                        J[f_i_r, x_j_fst] = 2*real(y_ii)*vm_idx[i] + sum(real(am.matrix[i, k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i, k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_r, x_j_snd] = vm_idx[i] * sum(real(am.matrix[i, k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i, k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_fst] = -2*imag(y_ii)*vm_idx[i] + sum(-imag(am.matrix[i, k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) + real(am.matrix[i, k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_i, x_j_snd] = vm_idx[i] * sum(-imag(am.matrix[i, k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i, k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        y_ij = am.matrix[i, j]
                        J[f_i_r, x_j_fst] = vm_idx[i] * (real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) * sin(va_idx[i] - va_idx[j]))
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * (real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_fst] = vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) * sin(va_idx[i] - va_idx[j]))
                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif is_pv_bus(bus_type)
                    if i == j
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 1.0

                        y_ii = am.matrix[i, i]
                        J[f_i_r, x_j_snd] = vm_idx[i] * sum(real(am.matrix[i, k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i, k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_snd] = vm_idx[i] * sum(-imag(am.matrix[i, k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i, k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 0.0

                        y_ij = am.matrix[i, j]
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * (real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif is_slack_bus(bus_type)
                    # p_inject_idx[i] = p_delta_base_idx[i] + x[2*i - 1]
                    # q_inject_idx[i] = q_delta_base_idx[i] + x[2*i]
                    if i == j
                        J[f_i_r, x_j_fst] = 1.0
                        J[f_i_r, x_j_snd] = 0.0
                        J[f_i_i, x_j_fst] = 0.0
                        J[f_i_i, x_j_snd] = 1.0
                    end
                else
                    @assert false
                end
            end
        end
    end


    # basic init point
    for i in eachindex(am.idx_to_bus)
        if is_pq_bus(bus_type_idx[i])
            x0[2*i-1] = 1.0 #vm
        elseif is_pv_bus(bus_type_idx[i])
        elseif is_slack_bus(bus_type_idx[i])
        else
            @assert false
        end
    end

    # warm-start point
    if !flat_start
        p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i, bus) in data["bus"])
        q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i, bus) in data["bus"])
        for (i, gen) in data["gen"]
            if gen["gen_status"] != 0
                if haskey(gen, "pg_start")
                    p_inject[gen["gen_bus"]] += gen["pg_start"]
                end
                if haskey(gen, "qg_start")
                    q_inject[gen["gen_bus"]] += gen["qg_start"]
                end
            end
        end

        for (i, shunt) in data["shunt"]
            if shunt["status"] != 0
                bus = data["bus"]["$(shunt["shunt_bus"])"]
                if haskey(bus, "vm_start")
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
                else
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]
                end
            end
        end

        for (i, bid) in enumerate(am.idx_to_bus)
            bus = data["bus"]["$(bid)"]
            if is_pq_bus(bus_type_idx[i])
                if haskey(bus, "vm_start")
                    x0[2*i-1] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif is_pv_bus(bus_type_idx[i])
                x0[2*i-1] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif is_slack_bus(bus_type_idx[i])
                x0[2*i-1] = -p_inject[bid]
                x0[2*i] = -q_inject[bid]
            else
                @assert false
            end
        end
    end


    # the operating point parameter vector, with layout: 
    # p[2i-1] active power and p[2i] the reactive power injection of bus i
    p0 = Vector{Float64}(undef, 2*length(am.idx_to_bus))
    for i in eachindex(am.idx_to_bus)
        p0[2*i-1] = p_delta_base_idx[i]
        p0[2*i] = q_delta_base_idx[i]
    end

    return PowerFlowSystem(f!, j!, x0, p0, pf_data.J0)
end


function _compute_ac_pf(pf_data::PowerFlowData; solver=NativeNewton(), flat_start=false)
    sys = build_pf_system(pf_data; flat_start=flat_start)

    sol = _solve_nl(sys, solver)

    # sync the pf_data state vectors with the solution
    _update_pf_state!(pf_data, sol.x)

    return sol, solver
end


