

function check_tnep_status(sol)
    for (idx,val) in sol["ne_branch"]
        @test isapprox(val["built"], 0.0, atol=1e-6, rtol=1e-6) || isapprox(val["built"], 1.0, atol=1e-6, rtol=1e-6)
    end
end


@testset "test ac tnep" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        calc_thermal_limits!(data)
        result = run_tnep(data, ACPPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", ACPPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test soc tnep" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        calc_thermal_limits!(data)
        result = run_tnep(data, SOCWRPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus rts case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", SOCWRPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test qc tnep" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        calc_thermal_limits!(data)
        result = run_tnep(data, QCRMPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus rts case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", QCRMPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test dc tnep" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        calc_thermal_limits!(data)
        result = run_tnep(data, DCPPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", DCPPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test matpower dc tnep" begin
    @testset "5-bus case with matpower DCMP model and TNEP" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", DCMPPowerModel, juniper_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["solution"]["ne_branch"]["1"]["built"], 1.0; atol = 1e-5)
        @test isapprox(result["solution"]["ne_branch"]["2"]["built"], 0.0; atol = 1e-5)
    end
end


@testset "test dc-losses tnep" begin
    #=
    # turn off due to numerical stability across operating systems
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        calc_thermal_limits!(data)
        result = run_tnep(data, DCPLLPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end
    =#

    @testset "5-bus case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", DCPLLPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test tnep branch flow output" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        calc_thermal_limits!(data)
        result = run_tnep(data, SOCWRPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2; atol = 1e-2)

        branches = result["solution"]["branch"]
        ne_branches = result["solution"]["ne_branch"]
        flow_keys = ["pf","qf","pt","qt"]

        for fk in flow_keys
            @test !isnan(branches["1"][fk])
            @test !isnan(ne_branches["1"][fk])
            @test !isnan(ne_branches["2"][fk])
            @test !isnan(ne_branches["3"][fk])
        end
    end
end
