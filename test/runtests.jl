using PowerModels
using InfrastructureModels
using Memento

using MathProgBase

# Suppress warnings during testing.
setlevel!(getlogger(InfrastructureModels), "error")
setlevel!(getlogger(PowerModels), "error")

using Cbc
using Ipopt
using SCS
using Pavito
using Juniper
using Compat

using JuMP
using JSON

using Compat.LinearAlgebra
using Compat.Test
import Compat: pairs

if VERSION < v"0.7.0-"
    LinearAlgebra = Compat.LinearAlgebra
end


# default setup for solvers
ipopt_solver = IpoptSolver(tol=1e-6, print_level=0)
ipopt_ws_solver = IpoptSolver(tol=1e-6, mu_init=1e-4, print_level=0)
#ipopt_solver = IpoptSolver(tol=1e-6)
#ipopt_ws_solver = IpoptSolver(tol=1e-6, mu_init=1e-4)

cbc_solver = CbcSolver()
juniper_solver = JuniperSolver(IpoptSolver(tol=1e-4, print_level=0), mip_solver=cbc_solver, log_levels=[])
#juniper_solver = JuniperSolver(IpoptSolver(tol=1e-4, print_level=0), mip_solver=cbc_solver)
pavito_solver = PavitoSolver(mip_solver=cbc_solver, cont_solver=ipopt_solver, mip_solver_drives=false, log_level=0)
scs_solver = SCSSolver(max_iters=500000, acceleration_lookback=1, verbose=0)

include("common.jl")

@testset "PowerModels" begin
    include("matpower.jl")

    include("pti.jl")

    include("psse.jl")

    include("output.jl")

    include("modify.jl")

    include("data.jl")

    include("model.jl")

    include("opb.jl")

    include("pf.jl")

    include("opf.jl")

    include("opf-var.jl")

    include("opf-obj.jl")

    include("ots.jl")

    include("tnep.jl")

    include("multinetwork.jl")

    include("multiconductor.jl")

    include("multi-nw-cnd.jl")

    include("util.jl")

    include("warmstart.jl")

    #include("docs.jl")

end
