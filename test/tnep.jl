

function check_tnep_status(sol)
    for (idx,val) in sol["ne_branch"]
        @test val["built"] == 0.0 || val["built"] == 1.0
    end
end


@testset "test soc tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/case3_tnep.m", SOCWRPowerModel, pajarito_solver; setting = Dict("output" => Dict("branch_flows" => true)))

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end
    @testset "5-bus rts case" begin
        result = run_tnep("../test/data/case5_tnep.m", SOCWRPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end

@testset "test dc tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/case3_tnep.m", DCPPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_tnep("../test/data/case5_tnep.m", DCPPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end

@testset "test dc-losses tnep" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/case3_tnep.m", DCPLLPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_tnep("../test/data/case5_tnep.m", DCPLLPowerModel, pajarito_solver)

        check_tnep_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end


if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)

    @testset "test ac tnep" begin
        @testset "5-bus case" begin
            result = run_tnep("../test/data/case5_tnep.m", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

            check_tnep_status(result["solution"])

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 1; atol = 1e-2)
        end
    end

end


@testset "test tnep branch flow output" begin
    @testset "3-bus case" begin
        result = run_tnep("../test/data/case3_tnep.m", SOCWRPowerModel, pajarito_solver; setting = Dict("output" => Dict("branch_flows" => true)))

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
