using PowerModels
import InfrastructureModels
import Memento

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
PowerModels.logger_config!("error")

import HiGHS
import Ipopt
import SCS
import Juniper

import JuMP
import JSON

import LinearAlgebra
import SparseArrays
using Test


# compat for JuMP v0.22/v0.23 transition
# can be removed after dropping support for v0.22
if !isdefined(JuMP, :num_nonlinear_constraints)
    num_nonlinear_constraints = JuMP.num_nl_constraints
else
    num_nonlinear_constraints = JuMP.num_nonlinear_constraints
end


# default setup for solvers
nlp_solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)
nlp_ws_solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "mu_init"=>1e-4, "print_level"=>0)

milp_solver = JuMP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = JuMP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0), "log_levels"=>[])
sdp_solver = JuMP.optimizer_with_attributes(SCS.Optimizer, "verbose"=>false)

include("common.jl")

@testset "PowerModels" begin

    include("matpower.jl")

    include("pti.jl")

    include("psse.jl")

    include("io.jl")

    include("output.jl")

    include("modify.jl")

    include("data.jl")

    include("data-mc.jl")

    include("data-basic.jl")

    include("model.jl")

    include("am.jl")

    include("opb.jl")

    include("pf.jl")

    include("pf-native.jl")

    include("opf.jl")

    include("opf-var.jl")

    include("opf-obj.jl")

    include("opf-ptdf.jl")

    include("ots.jl")

    include("tnep.jl")

    include("multinetwork.jl")

    include("util.jl")

    include("warmstart.jl")

    include("docs.jl")

end
