

function check_exp_status(sol)
    for (idx,val) in sol["branch"]
        @test val["built"] == 0.0 || val["built"] == 1.0
    end
end



if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)

    @testset "test ac expansion" begin
        @testset "5-bus case" begin
            result = run_expansion("../test/data/case5_exp.json", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

            check_exp_status(result["solution"])

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 1; atol = 1e-2)
        end
    end
end


@testset "test dc expansion" begin
    @testset "3-bus case" begin
        result = run_expansion("../test/data/case3_exp.json", DCPPowerModel, pajarito_solver)

        check_exp_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_expansion("../test/data/case5_exp.json", DCPPowerModel, pajarito_solver)

        check_exp_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end

@testset "test dc-losses expansion" begin
    @testset "3-bus case" begin
        result = run_expansion("../test/data/case3_exp.json", DCPLLPowerModel, pajarito_solver)

        check_exp_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end

    @testset "5-bus case" begin
        result = run_expansion("../test/data/case5_exp.json", DCPLLPowerModel, pajarito_solver)

        check_exp_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end

@testset "test soc expansion" begin
    @testset "3-bus case" begin
        result = run_expansion("../test/data/case3_exp.json", SOCWRPowerModel, pajarito_solver)

        check_exp_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 2; atol = 1e-2)
    end
    @testset "5-bus rts case" begin
        result = run_expansion("../test/data/case5_exp.json", SOCWRPowerModel, pajarito_solver)

        check_exp_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1; atol = 1e-2)
    end
end

