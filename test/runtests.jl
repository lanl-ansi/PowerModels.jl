using PowerModels
using Logging
# suppress warnings during testing
Logging.configure(level=ERROR)

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

include("matpower.jl")

include("output.jl")

include("modify.jl")

# used by OTS and Loadshed TS models
function check_br_status(sol)
    for (idx,val) in sol["branch"]
        @test val["br_status"] == 0.0 || val["br_status"] == 1.0
    end
end

include("pf.jl")

include("opf.jl")

include("misc.jl")

include("ots.jl")

include("tnep.jl")

include("docs.jl")
