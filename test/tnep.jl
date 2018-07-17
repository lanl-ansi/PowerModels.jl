

function check_tnep_status(sol)
    for (idx,val) in sol["ne_branch"]
        @test isapprox(val["built"], 0.0, atol=1e-6, rtol=1e-6) || isapprox(val["built"], 1.0, atol=1e-6, rtol=1e-6)
    end
end


@testset "test ac tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/matpower/case3_tnep.m", ACPPowerModel, juniper_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end
    # omitting due to numerical stability issues on Linux
    #@testset "5-bus case" begin
    #    result = run_tnep("../test/data/matpower/case5_tnep.m", ACPPowerModel, juniper_solver)

    #    check_tnep_status(result["solution"])

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 1; atol = 1e-2)
    #end
end


@testset "test soc tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/matpower/case3_tnep.m", SOCWRPowerModel, pajarito_solver; setting = Dict("output" => Dict("branch_flows" => true)))

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end
    @testset "5-bus rts case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", SOCWRPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test qc tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/matpower/case3_tnep.m", QCWRPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end
    # omitting due to numerical stability issues on Linux
    #@testset "5-bus rts case" begin
    #    result = run_tnep("../test/data/matpower/case5_tnep.m", QCWRPowerModel, pajarito_solver)

    #    check_tnep_status(result["solution"])

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 1; atol = 1e-2)
    #end
end


@testset "test dc tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/matpower/case3_tnep.m", DCPPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    #=
    # skip this one becouse it is breaking Julia package tests
    @testset "5-bus case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", DCPPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
    =#
end

@testset "test dc-losses tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/matpower/case3_tnep.m", DCPLLPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_tnep("../test/data/matpower/case5_tnep.m", DCPLLPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


@testset "test tnep branch flow output" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/matpower/case3_tnep.m", SOCWRPowerModel, pajarito_solver; setting = Dict("output" => Dict("branch_flows" => true)))

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
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
