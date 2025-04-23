# Copyright (c) 2016: Los Alamos National Security, LLC
#
# Use of this source code is governed by a BSD-style license that can be found
# in the LICENSE.md file.

using PowerModels
using Test

import HiGHS
import InfrastructureModels
import Ipopt
import JSON
import JuMP
import Juniper
import LinearAlgebra
import Memento
import SCS
import SparseArrays

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
PowerModels.logger_config!("error")

# default setup for solvers
nlp_solver = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "tol"=>1e-6,
    "print_level"=>0,
)

nlp_ws_solver = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "tol"=>1e-6,
    "mu_init"=>1e-4,
    "print_level"=>0,
)

milp_solver =
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)

minlp_solver = JuMP.optimizer_with_attributes(
    Juniper.Optimizer,
    "nl_solver"=>JuMP.optimizer_with_attributes(
        Ipopt.Optimizer,
        "tol"=>1e-4,
        "print_level"=>0,
    ),
    "log_levels"=>[],
)

sdp_solver = JuMP.optimizer_with_attributes(SCS.Optimizer, "verbose"=>false)

include("common.jl")

@testset verbose=true "PowerModels" begin
    @testset verbose=true "$file" for file in readdir(@__DIR__)
        if !endswith(file, ".jl") || file in ("common.jl", "runtests.jl")
            continue
        end
        include(joinpath(@__DIR__, file))
    end
end
