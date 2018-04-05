using PowerModels
using Memento

# Suppress warnings during testing.
setlevel!(getlogger(InfrastructureModels), "error")
setlevel!(getlogger(PowerModels), "error")

using Ipopt
using Pajarito
using GLPKMathProgInterface
using SCS

# needed for Non-convex OTS tests
if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)
    using AmplNLWriter
    using CoinOptServices
end

using Base.Test

# default setup for solvers
ipopt_solver = IpoptSolver(tol=1e-6, print_level=0)
pajarito_solver = PajaritoSolver(mip_solver=GLPKSolverMIP(), cont_solver=ipopt_solver, log_level=0)
scs_solver = SCSSolver(max_iters=1000000, verbose=0)


@testset "PowerModels" begin
include("common.jl")

include("matpower.jl")

include("pti.jl")

include("output.jl")

include("modify.jl")

include("data.jl")

include("pf.jl")

include("opf.jl")

include("ots.jl")

include("tnep.jl")

include("multinetwork.jl")

include("docs.jl")

end
