using PowerModels
import InfrastructureModels
import Memento

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
PowerModels.logger_config!("error")

# for checking status codes
import MathOptInterface
const MOI = MathOptInterface

import Cbc
import Ipopt
import SCS
import Juniper

import JuMP
import JSON

import LinearAlgebra
using Test

# default setup for solvers
ipopt_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
ipopt_ws_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, mu_init=1e-4, print_level=0)

cbc_solver = JuMP.with_optimizer(Cbc.Optimizer, logLevel=0)
juniper_solver = JuMP.with_optimizer(Juniper.Optimizer, nl_solver=JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0), log_levels=[])
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

    include("ots.jl")

    include("tnep.jl")

    include("multinetwork.jl")

    include("multiconductor.jl")

    include("multi-nw-cnd.jl")

    include("util.jl")

    include("warmstart.jl")

    include("docs.jl")

end
