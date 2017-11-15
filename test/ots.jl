
# used by OTS models
function check_br_status(sol)
    for (i,branch) in sol["branch"]
        @test branch["br_status"] == 0.0 || branch["br_status"] == 1.0
    end
end


if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)
    @testset "test ac ots" begin
        #Omitting this test, until bugs can be resolved, bonmin does not report a integral solution
        #@testset "3-bus case" begin
        #    result = run_ots("../test/data/case3.m", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

        #    check_br_status(result["solution"])

        #    @test result["status"] == :LocalOptimal
        #    @test isapprox(result["objective"], 5812; atol = 1e0)
        #end
        @testset "5-bus case" begin
            result = run_ots("../test/data/case5.m", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

            check_br_status(result["solution"])

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15174; atol = 1e0)
        end
        #Omitting this test, returns local infeasible
        #@testset "6-bus case" begin
        #    result = run_ots("../test/data/case6.m", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

        #    check_br_status(result["solution"])

        #    @test result["status"] == :LocalOptimal
        #    println(result["objective"])
        #    @test isapprox(result["objective"], 15174; atol = 1e0)
        #end
    end
end


@testset "test dc ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/case3.m", DCPPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5782.0; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/case5.m", DCPPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14991.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/case6.m", DCPPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11396.3; atol = 1e0)
    end
end


@testset "test dc+ll ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/case3.m", DCPLLPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5885.2; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/case5.m", DCPLLPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15275.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/case6.m", DCPLLPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11515.6; atol = 1e0)
    end
end


@testset "test soc ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/case3.m", SOCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/case5.m", SOCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/case6.m", SOCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11559.8; atol = 1e0)
    end
end


@testset "test qc ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/case3.m", QCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/case5.m", QCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_ots("../test/data/case5_asym.m", QCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/case6.m", QCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11567.1; atol = 1e0)
    end
end
