

@testset "test ac polar opf" begin
    @testset "3-bus case" begin
        result = run_ac_opf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus tranformer swap case" begin
        result = run_ac_opf("../test/data/matpower/case5.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18269; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_ac_opf("../test/data/matpower/case5_asym.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_ac_opf("../test/data/matpower/case5_gap.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_ac_opf("../test/data/matpower/case5_dc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18156.2; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_ac_opf("../test/data/pti/case5_alc.raw", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_ac_opf("../test/data/matpower/case5_npg.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8190.09; atol = 1e0)
    end
    @testset "5-bus with only current limit data" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_clm.m")
        calc_thermal_limits!(data)
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16513.6; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "5-bus with gen lb" begin
        result = run_ac_opf("../test/data/matpower/case5_uc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18742.2; atol = 1e0)
    end
    @testset "5-bus with dangling bus" begin
        result = run_ac_opf("../test/data/matpower/case5_db.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16739.1; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ac_opf("../test/data/matpower/case6.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end


@testset "test ac rect opf" begin
    #=
    # numerical issue
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", ACRPowerModel, ipopt_solver)

        #@test result["termination_status"] == LOCALLY_SOLVED
        #@test isapprox(result["objective"], 5812; atol = 1e0)
        @test result["status"] == :Error
    end
    =#
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", ACRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", ACRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", ACRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", ACRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end


@testset "test ac tan opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27438.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
end


@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = run_dc_opf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5782; atol = 1e0)
    end
    @testset "5-bus case, LP solver" begin
        result = run_dc_opf("../test/data/matpower/case5.m", cbc_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 17613; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_opf("../test/data/matpower/case5_asym.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17479; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_dc_opf("../test/data/matpower/case5_gap.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_dc_opf("../test/data/pti/case5_alc.raw", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_dc_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42565; atol = 1e0)
    end
    @testset "5-bus with gen lb" begin
        result = run_dc_opf("../test/data/matpower/case5_uc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18064.5; atol = 1e0)
    end
    @testset "5-bus with dangling bus" begin
        result = run_dc_opf("../test/data/matpower/case5_db.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16710.0; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_dc_opf("../test/data/matpower/case6.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11391.8; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", DCPPowerModel, ipopt_solver)

    #    @test result["termination_status"] == LOCALLY_SOLVED
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
end

@testset "test nfa opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42565.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 61001.2; atol = 1e0)
    end
end

@testset "test dc+ll opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5885; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17693; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -32710.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1001.17; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42937; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11574.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", DCPLLPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 82240; atol = 1e0)
    end
end


@testset "test lpac-c opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5908.98; atol = 1e0)
    end
    @testset "5-bus tranformer swap case" begin
        result = run_opf("../test/data/matpower/case5.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18288.1; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17645.6; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27554.5; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_opf("../test/data/matpower/case5_dc.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18253.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1004.58; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf("../test/data/matpower/case5_npg.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8082.54; atol = 1e0)
    end
    @testset "5-bus with only current limit data" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_clm.m")
        calc_thermal_limits!(data)
        result = run_opf(data, LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16559.3; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42853.4; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", LPACCPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11615.1; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    # TODO uderstand why this is infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", LPACCPowerModel, ipopt_solver)

    #    @test result["termination_status"] == LOCALLY_SOLVED
    #    @test isapprox(result["objective"], 79805; atol = 1e0)
    #end
end


@testset "test soc (BIM) opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -28237.3; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf("../test/data/matpower/case5_npg.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 3603.91; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "5-bus with dangling bus" begin
        result = run_opf("../test/data/matpower/case5_db.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16739.1; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
end

@testset "test soc conic form opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 5746.61; atol = 2e0)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf("../test/data/matpower/case5.m", SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 15051.4; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    # convergence issue encountered when linear objective used, SCS.jl v0.4.1
    #@testset "5-bus gap case" begin
    #    result = run_opf("../test/data/matpower/case5_gap.m", SOCWRConicPowerModel, scs_solver)

    #    @test result["termination_status"] == OPTIMAL
    #    @test isapprox(result["objective"], -28237.3; atol = 1e0)
    #end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus with negative generators" begin
    #    result = run_opf("../test/data/matpower/case5_npg.m", SOCWRConicPowerModel, scs_solver)

    #    @test result["termination_status"] == OPTIMAL
    #    @test isapprox(result["objective"], 3613.72; atol = 40)
    #end
    # TODO: figure out why this test fails
    # @testset "5-bus with pwl costs" begin
    #     result = run_opf("../test/data/matpower/case5_pwlc.m", SOCWRConicPowerModel, scs_solver)
    #
    #     @test result["termination_status"] == OPTIMAL
    #     @test isapprox(result["objective"], 42895; atol = 1e0)
    # end
    # Turn off due to numerical stability
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 11472.2; atol = 3e0)
    end
    # does not converge in SCS.jl v0.4.0
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", SOCWRConicPowerModel, scs_solver)

    #    @test result["termination_status"] == OPTIMAL
    #    @test isapprox(result["objective"], 70690.7; atol = 8e0)
    #end
end

@testset "test soc distflow opf_bf" begin
    @testset "3-bus case" begin
        result = run_opf_bf("../test/data/matpower/case3.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf_bf("../test/data/matpower/case5.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf_bf("../test/data/matpower/case5_asym.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf_bf("../test/data/matpower/case5_gap.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf_bf("../test/data/pti/case5_alc.raw", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf_bf("../test/data/matpower/case5_pwlc.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf_bf("../test/data/matpower/case6.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf_bf("../test/data/matpower/case24.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
    @testset "3-bus case w/ r,x=0 on branch" begin
        mp_data = PowerModels.parse_file("../test/data/matpower/case3.m")
        mp_data["branch"]["1"]["br_r"] = mp_data["branch"]["1"]["br_x"] = 0.0
        result = run_opf_bf(mp_data, SOCBFPowerModel, ipopt_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
    end
end

@testset "test soc conic distflow opf_bf" begin
    @testset "3-bus case" begin
        result = run_opf_bf("../test/data/matpower/case3.m", SOCBFConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 5746.7; atol = 1e1)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf_bf("../test/data/matpower/case5.m", SOCBFConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 15051; atol = 1e1)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf_bf("../test/data/matpower/case5_asym.m", SOCBFConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 14999; atol = 1e1)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf_bf("../test/data/matpower/case5_npg.m", SOCBFConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 3593.0; atol = 1e1)
    end
end


@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5780; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15921; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11484.2; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 76599.9; atol = 1e0)
    end
end

@testset "test qc opf with trilinear convexhull relaxation" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", QCLSPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5817.91; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", QCLSPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15929.2; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", QCLSPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", QCLSPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11512.9; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", QCLSPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 76785.4; atol = 1e0)
    end
end


@testset "test sdp opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 5852.59; atol = 1e0)
    end
    # TODO see if convergence time can be improved
    #@testset "5-bus asymmetric case" begin
    #    result = run_opf("../test/data/matpower/case5_asym.m", SDPWRMPowerModel, scs_solver)

    #    @test result["termination_status"] == OPTIMAL
    #    @test isapprox(result["objective"], 16664; atol = 1e0)
    #end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus gap case" begin
    #    result = run_opf("../test/data/matpower/case5_gap.m", SDPWRMPowerModel, scs_solver)

    #    @test result["termination_status"] == OPTIMAL
    #    @test isapprox(result["objective"], TBD; atol = 1e0)
    #end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.31; atol = 1e-1)
    end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus with negative generators" begin
    #    result = run_opf("../test/data/matpower/case5_npg.m", SDPWRMPowerModel, scs_solver)

    #    @test result["termination_status"] == LOCALLY_SOLVED
    #    @test isapprox(result["objective"], 7291.69; atol = 1e0) # Mosek v8 value
    #end
    # too slow for unit tests
    # @testset "14-bus case" begin
    #     result = run_opf("../test/data/matpower/case14.m", SDPWRMPowerModel, scs_solver)

    #     @test result["termination_status"] == OPTIMAL
    #     @test isapprox(result["objective"], 8081.52; atol = 1e0)
    # end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 11580.8; atol = 1e0)
    end
    # TODO replace this with smaller case, way too slow for unit testing
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", SDPWRMPowerModel, scs_solver)

    #    @test result["termination_status"] == OPTIMAL
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end


@testset "test sdp opf with constraint decomposition" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SparseSDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 5852.35; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SparseSDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.31; atol = 1e-1)
    end
    # too slow for unit tests
    # @testset "14-bus case" begin
    #     result = run_opf("../test/data/matpower/case14.m", SparseSDPWRMPowerModel, scs_solver)

    #     @test result["termination_status"] == OPTIMAL
    #     @test isapprox(result["objective"], 8081.5; atol = 1e0)
    # end

    # multiple components are not currently supported by this form
    #=
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SparseSDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 11578.8; atol = 1e0)
    end
    =#

    @testset "passing in decomposition" begin
        # too slow for unit tests
        #data = PowerModels.parse_file("../test/data/matpower/case14.m")
        data = PowerModels.parse_file("../test/data/pti/case5_alc.raw")
        pm = InitializePowerModel(SparseSDPWRMPowerModel, data)
        PowerModels.ref_add_core!(pm)

        cadj, lookup_index, sigma = PowerModels._chordal_extension(pm)
        cliques = PowerModels._maximal_cliques(cadj)
        lookup_bus_index = Dict((reverse(p) for p = pairs(lookup_index)))
        groups = [[lookup_bus_index[gi] for gi in g] for g in cliques]
        @test PowerModels._problem_size(groups) == 83

        pm.ext[:SDconstraintDecomposition] = PowerModels._SDconstraintDecomposition(groups, lookup_index, sigma)

        PowerModels.post_opf(pm)
        result = optimize_model!(pm, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end

end

