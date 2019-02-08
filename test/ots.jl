
# used by OTS models
function check_br_status(sol)
    for (i,branch) in sol["branch"]
        @test isapprox(branch["br_status"], 0.0, atol=1e-6, rtol=1e-6) || isapprox(branch["br_status"], 1.0, atol=1e-6, rtol=1e-6)
    end
end


@testset "test ac ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/matpower/case3.m", ACPPowerModel, juniper_solver)

        check_br_status(result["solution"])

        @test result["status"] == :LocalOptimal
        #@test isapprox(result["objective"], 5812; atol = 1e0) # true opt objective
        @test isapprox(result["objective"], 5906.8; atol = 1e0)
    end
    #=
    # remove due to linux stability issue
    @testset "5-bus case" begin
        result = run_ots("../test/data/matpower/case5.m", ACPPowerModel, juniper_solver)

        check_br_status(result["solution"])

        @test result["status"] == :LocalOptimal
        #@test isapprox(result["objective"], 15174; atol = 1e0)
        # increased from 15174 to 16588 in Ipopt v0.4.4 to v0.5.0
        @test result["objective"] < 16600
    end
    =#
    @testset "5-bus with asymmetric line charge" begin
        result = run_ots("../test/data/pti/case5_alc.raw", ACPPowerModel, juniper_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1002.52; atol = 1e1)
    end
    #Omitting this test, returns local infeasible
    #@testset "6-bus case" begin
    #    result = run_ots("../test/data/matpower/case6.m", ACPPowerModel, juniper_solver)

    #    check_br_status(result["solution"])

    #    @test result["status"] == :LocalOptimal
    #    println(result["objective"])
    #    @test isapprox(result["objective"], 15174; atol = 1e0)
    #end
end


@testset "test dc ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/matpower/case3.m", DCPPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5782.0; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/matpower/case5.m", DCPPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14991.2; atol = 1e0)
    end
    @testset "5-bus case, MIP solver" begin
        result = run_ots("../test/data/matpower/case5.m", DCPPowerModel, cbc_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14991.3; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/matpower/case6.m", DCPPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11391.8; atol = 1e0)
    end
end


@testset "test dc+ll ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/matpower/case3.m", DCPLLPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5885.2; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/matpower/case5.m", DCPLLPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15275.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/matpower/case6.m", DCPLLPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11574.3; atol = 1e0)
    end
end


@testset "test soc ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/matpower/case3.m", SOCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/matpower/case5.m", SOCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15051.4; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_ots("../test/data/pti/case5_alc.raw", SOCWRPowerModel, pavito_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1004.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/matpower/case6.m", SOCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
end


@testset "test qc ots" begin
    @testset "3-bus case" begin
        result = run_ots("../test/data/matpower/case3.m", QCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = run_ots("../test/data/matpower/case5.m", QCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15051.4; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_ots("../test/data/matpower/case5_asym.m", QCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_ots("../test/data/pti/case5_alc.raw", QCWRPowerModel, pavito_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1003.97; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ots("../test/data/matpower/case6.m", QCWRPowerModel, pavito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
end
