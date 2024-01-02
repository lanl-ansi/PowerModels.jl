
# used by OTS models
function check_br_status(sol, active_lb::Real, active_ub::Real; tol=1e-6)
    active = 0
    for (i,branch) in sol["branch"]
        @test isapprox(branch["br_status"], 0.0, atol=1e-6, rtol=1e-6) || isapprox(branch["br_status"], 1.0, atol=1e-6, rtol=1e-6)
        active += branch["br_status"]
    end
    @test active_lb - tol <= active
    @test active <= active_ub + tol
end


@testset "test ac ots" begin
    @testset "3-bus case" begin
        result = solve_ots("../test/data/matpower/case3.m", ACPPowerModel, minlp_solver)

        check_br_status(result["solution"], 3, 3)

        @test result["termination_status"] == LOCALLY_SOLVED
        #@test isapprox(result["objective"], 5812; atol = 1e0) # true opt objective
        @test isapprox(result["objective"], 5906.8; atol = 1e0)
    end
    #=
    # remove due to linux stability issue
    @testset "5-bus case" begin
        result = solve_ots("../test/data/matpower/case5.m", ACPPowerModel, minlp_solver)

        check_br_status(result["solution"], 0, 0)

        @test result["termination_status"] == LOCALLY_SOLVED
        #@test isapprox(result["objective"], 15174; atol = 1e0)
        # increased from 15174 to 16588 in Ipopt v0.4.4 to v0.5.0
        @test result["objective"] < 16600
    end
    =#
    @testset "5-bus with negative branch reactance case" begin
        result = solve_ots("../test/data/matpower/case5_ext.m", ACPPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15174; atol = 1e0)
        # increased from 15174 to 16588 in Ipopt v0.4.4 to v0.5.0
        #@test result["objective"] < 16600
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_ots("../test/data/pti/case5_alc.raw", ACPPowerModel, minlp_solver)

        check_br_status(result["solution"], 4, 4)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1002.52; atol = 1e1)
    end
    #Omitting this test, returns local infeasible
    #@testset "6-bus case" begin
    #    result = solve_ots("../test/data/matpower/case6.m", ACPPowerModel, minlp_solver)

    #    check_br_status(result["solution"], 0, 0)

    #    @test result["termination_status"] == LOCALLY_SOLVED
    #    println(result["objective"])
    #    @test isapprox(result["objective"], 15174; atol = 1e0)
    #end
end


@testset "test dc ots" begin
    @testset "3-bus case" begin
        result = solve_ots("../test/data/matpower/case3.m", DCPPowerModel, minlp_solver)

        check_br_status(result["solution"], 3, 3)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5782.0; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = solve_ots("../test/data/matpower/case5.m", DCPPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14991.2; atol = 1e0)
    end
    @testset "5-bus case, MIP solver" begin
        result = solve_ots("../test/data/matpower/case5.m", DCPPowerModel, milp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 14991.3; atol = 1e0)
    end
    @testset "5-bus with negative branch reactance case" begin
        result = solve_ots("../test/data/matpower/case5_ext.m", DCPPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14991.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_ots("../test/data/matpower/case6.m", DCPPowerModel, minlp_solver)

        check_br_status(result["solution"], 6, 6)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11391.8; atol = 1e0)
    end
end


@testset "test dc+ll ots" begin
    @testset "3-bus case" begin
        result = solve_ots("../test/data/matpower/case3.m", DCPLLPowerModel, minlp_solver)

        check_br_status(result["solution"], 3, 3)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5885.2; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = solve_ots("../test/data/matpower/case5.m", DCPLLPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15275.2; atol = 1e0)
    end
    @testset "5-bus with negative branch reactance case" begin
        result = solve_ots("../test/data/matpower/case5_ext.m", DCPLLPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15275.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_ots("../test/data/matpower/case6.m", DCPLLPowerModel, minlp_solver)

        check_br_status(result["solution"], 6, 6)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11574.3; atol = 1e0)
    end
end


@testset "test soc ots" begin
    @testset "3-bus case" begin
        result = solve_ots("../test/data/matpower/case3.m", SOCWRPowerModel, minlp_solver)

        check_br_status(result["solution"], 3, 3)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = solve_ots("../test/data/matpower/case5.m", SOCWRPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15051.4; atol = 5e1)
    end
    @testset "5-bus with negative branch reactance case" begin
        result = solve_ots("../test/data/matpower/case5_ext.m", SOCWRPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15009.9; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_ots("../test/data/pti/case5_alc.raw", SOCWRPowerModel, minlp_solver)

        check_br_status(result["solution"], 4, 4)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1004.8; atol = 5e0)
    end
    @testset "6-bus case" begin
        result = solve_ots("../test/data/matpower/case6.m", SOCWRPowerModel, minlp_solver)

        check_br_status(result["solution"], 6, 6)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
end


@testset "test qc ots" begin
    @testset "3-bus case" begin
        result = solve_ots("../test/data/matpower/case3.m", QCRMPowerModel, minlp_solver)

        check_br_status(result["solution"], 3, 3)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5748.0; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = solve_ots("../test/data/matpower/case5.m", QCRMPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15051.4; atol = 5e1)
    end
    @testset "5-bus with negative branch reactance case" begin
        result = solve_ots("../test/data/matpower/case5_ext.m", QCRMPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15010.0; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_ots("../test/data/matpower/case5_asym.m", QCRMPowerModel, minlp_solver)

        check_br_status(result["solution"], 6, 6)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15036.9; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_ots("../test/data/pti/case5_alc.raw", QCRMPowerModel, minlp_solver)

        # updated ub to 5 on 04/21/2021 to fix cross platform stability
        check_br_status(result["solution"], 4, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1003.97; atol = 5e0)
    end
    @testset "6-bus case" begin
        result = solve_ots("../test/data/matpower/case6.m", QCRMPowerModel, minlp_solver)

        check_br_status(result["solution"], 6, 6)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
end


@testset "test lpac ots" begin
    @testset "3-bus case" begin
        result = solve_ots("../test/data/matpower/case3.m", LPACCPowerModel, minlp_solver)

        check_br_status(result["solution"], 3, 3)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5908.98; atol = 1e0)
    end
    @testset "5-bus case" begin
        result = solve_ots("../test/data/matpower/case5.m", LPACCPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15241.4; atol = 5e1)
    end
    @testset "5-bus with negative branch reactance case" begin
        result = solve_ots("../test/data/matpower/case5_ext.m", LPACCPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15241.4; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_ots("../test/data/matpower/case5_asym.m", LPACCPowerModel, minlp_solver)

        check_br_status(result["solution"], 5, 5)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15246.9; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_ots("../test/data/pti/case5_alc.raw", LPACCPowerModel, minlp_solver)

        check_br_status(result["solution"], 4, 4)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 998.4; atol = 5e0)
    end
    @testset "6-bus case" begin
        result = solve_ots("../test/data/matpower/case6.m", LPACCPowerModel, minlp_solver)

        check_br_status(result["solution"], 6, 6)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11615.1; atol = 1e0)
    end
end
