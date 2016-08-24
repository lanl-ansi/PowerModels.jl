
if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)

    @testset "test ac ots" begin
    #  Omitting this test, until bugs can be resolved
    #    @testset "3-bus case" begin
    #        result = run_ots_file(;file = "../test/data/case3.json", model_builder = AC_OTS, solver = BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))
    #
    #        check_br_status(result["solution"])
    #
    #        @test result["status"] == :LocalOptimal
    #        @test isapprox(result["objective"], 5812; atol = 1e0)
    #    end
        @testset "5-bus case" begin
            result = run_ots("../test/data/case5.json", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

            check_br_status(result["solution"])

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15174; atol = 1e0)
        end
    end

end

# at the moment only Gurobi is reliable enough to solve these models
if (Pkg.installed("Gurobi") != nothing)

    @testset "test dc ots" begin
        @testset "3-bus case" begin
            result = run_ots("../test/data/case3.json", DCPPowerModel, GurobiSolver(OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 5695.8; atol = 1e0)
        end

        @testset "5-bus case" begin
            result = run_ots("../test/data/case5.json", DCPPowerModel, GurobiSolver(OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 14991.2; atol = 1e0)
        end
    end

    @testset "test dc-losses ots" begin
        @testset "3-bus case" begin
            result = run_ots("../test/data/case3.json", DCPLLPowerModel, GurobiSolver(OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 5787.1; atol = 1e0)
        end

        @testset "5-bus case" begin
            result = run_ots("../test/data/case5.json", DCPLLPowerModel, GurobiSolver(OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 15275.2; atol = 1e0)
        end
    end

    @testset "test soc ots" begin
        @testset "3-bus case" begin
            result = run_ots("../test/data/case3.json", SOCWRPowerModel, GurobiSolver(OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 5736.2; atol = 1e0)
        end
        @testset "5-bus rts case" begin
            result = run_ots("../test/data/case5.json", SOCWRPowerModel, GurobiSolver(OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 14999.7; atol = 1e0)
        end
    end


end


