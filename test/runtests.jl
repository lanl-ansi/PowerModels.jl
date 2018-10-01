using PowerModels
using InfrastructureModels
using Memento

# Suppress warnings during testing.
setlevel!(getlogger(InfrastructureModels), "error")
setlevel!(getlogger(PowerModels), "error")

#using Cbc
using Ipopt
using SCS
#using Pavito
#using Juniper

using Base.Test

using JuMP

# default setup for solvers
ipopt_solver = with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
#cbc_solver = CbcSolver()
#juniper_solver = JuniperSolver(IpoptSolver(tol=1e-4, print_level=0), mip_solver=cbc_solver, log_levels=[])
##juniper_solver = JuniperSolver(IpoptSolver(tol=1e-4, print_level=0), mip_solver=cbc_solver)
#pavito_solver = PavitoSolver(mip_solver=cbc_solver, cont_solver=ipopt_solver, mip_solver_drives=false, log_level=0)
# TODO uncomment when https://github.com/JuliaOpt/SCS.jl/issues/113 is resolved
#scs_solver = with_optimizer(SCS.Optimizer, max_iters=1000000, alpha=1.9, acceleration_lookback=1, verbose=0)
scs_solver = with_optimizer(SCS.Optimizer)


include("common.jl")

@testset "PowerModels" begin

    include("matpower.jl")

    include("pti.jl")

    include("psse.jl")

    include("output.jl")

    include("modify.jl")

    include("data.jl")

    include("opb.jl")

    include("pf.jl")

    include("opf.jl")

    include("opf-var.jl")

    # needs MI solvers
    #include("ots.jl")

    # needs MI solvers
    #include("tnep.jl")

    include("multinetwork.jl")

    include("multiconductor.jl")

    include("multi-nw-cnd.jl")

    include("util.jl")

    include("docs.jl")

end
