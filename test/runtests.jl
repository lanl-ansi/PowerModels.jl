using PowerModels
import InfrastructureModels
import Memento

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
Memento.setlevel!(Memento.getlogger(PowerModels), "error")

import Cbc
import Ipopt
import SCS
# import Pavito
# import Juniper

import JuMP
import JSON

import LinearAlgebra
using Test

# default setup for optimizers
ipopt_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
cbc_solver = JuMP.with_optimizer(Cbc.Optimizer)
# juniper_solver = JuniperSolver(IpoptSolver(tol=1e-4, print_level=0), mip_solver=cbc_solver, log_levels=[])  # MOI not yet supported
# pavito_solver = PavitoSolver(mip_solver=cbc_solver, cont_solver=ipopt_solver, mip_solver_drives=false, log_level=0)  # MOI not yet supported
scs_solver = JuMP.with_optimizer(SCS.Optimizer, max_iters=500000, acceleration_lookback=1, verbose=0)

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

    # include("ots.jl")  # MOI not yet supported

    # include("tnep.jl")  # MOI not yet supported

    include("multinetwork.jl")

    include("multiconductor.jl")

    include("multi-nw-cnd.jl")

    include("util.jl")

    include("docs.jl")

end
