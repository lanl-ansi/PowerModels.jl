# Test cases for PTI RAW export function
# Later put in pti.jl test set
# 
using Pkg
Pkg.activate(".")
cd("test")

using PowerModels
import InfrastructureModels
import Memento

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
PowerModels.logger_config!("error")

using Test

include("common.jl")

TESTLOG = Memento.getlogger(PowerModels)

function generate_pm_dicts(file_case)
    file_tmp = "../test/data/tmp.raw"
    case_base = PowerModels.parse_file(file_case)

    export_pti(file_tmp, case_base)

    case_tmp = PowerModels.parse_file(file_tmp)
    rm(file_tmp)

    return case_base, case_tmp
end

@testset "test components" begin

    @testset "Test Buses" begin
        file_case = "../test/data/pti/parser_test_i.raw"
        case_base, case_tmp = generate_pm_dicts(file_case)

        @test InfrastructureModels.compare_dict(case_base["bus"], case_tmp["bus"])
    end

    @testset "Test Loads" begin
        file_case = "../test/data/pti/case14.raw"
        case_base, case_tmp = generate_pm_dicts(file_case)

        @test InfrastructureModels.compare_dict(case_base["load"], case_tmp["load"])
    end
end