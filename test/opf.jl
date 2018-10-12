

@testset "test ac polar opf" begin
    @testset "3-bus case" begin
        result = run_ac_opf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus tranformer swap case" begin
        result = run_ac_opf("../test/data/matpower/case5.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 18269; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_ac_opf("../test/data/matpower/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_ac_opf("../test/data/matpower/case5_gap.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_ac_opf("../test/data/matpower/case5_dc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 18156.2; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_ac_opf("../test/data/pti/case5_alc.raw", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_ac_opf("../test/data/matpower/case5_npg.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 9003.35; atol = 1e0)
    end
    @testset "5-bus with only current limit data" begin
        result = run_ac_opf("../test/data/matpower/case5_clm.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 16987.4; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ac_opf("../test/data/matpower/case6.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end


@testset "test ac rect opf" begin
    #=
    # numerical issue
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", ACRPowerModel, ipopt_solver)

        #@test result["status"] == :LocalOptimal
        #@test isapprox(result["objective"], 5812; atol = 1e0)
        @test result["status"] == :Error
    end
    =#
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end


@testset "test ac tan opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27438.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
end


@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = run_dc_opf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5782; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_opf("../test/data/matpower/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17479; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_dc_opf("../test/data/matpower/case5_gap.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_dc_opf("../test/data/pti/case5_alc.raw", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_dc_opf("../test/data/matpower/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42565; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_dc_opf("../test/data/matpower/case6.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11391.8; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", DCPPowerModel, ipopt_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
end

@testset "test nfa opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42565.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", NFAPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 61001.2; atol = 1e0)
    end
end

@testset "test dc+ll opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5885; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17693; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -32710.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1001.17; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42937; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11574.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 82240; atol = 1e0)
    end
end


@testset "test soc (BIM) opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -28237.3; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf("../test/data/matpower/case5_npg.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 3613.72; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
end

@testset "test soc conic form opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5176.71; atol = 2e0)
    end
    #=
    # TODO: requires increased iteration limit to work with MOI
    @testset "5-bus transformer swap case" begin
        result = run_opf("../test/data/matpower/case5.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15051.4; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -28237.3; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    =#
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus with negative generators" begin
    #    result = run_opf("../test/data/matpower/case5_npg.m", SOCWRConicPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 3613.72; atol = 40)
    #end
    # TODO: figure out why this test fails
    # @testset "5-bus with pwl costs" begin
    #     result = run_opf("../test/data/matpower/case5_pwlc.m", SOCWRConicPowerModel, scs_solver)
    #
    #     @test result["status"] == :LocalOptimal
    #     @test isapprox(result["objective"], 42895; atol = 1e0)
    # end
    # Turn off due to numerical stability
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 10343.3; atol = 3e0)
    end
    # does not converge in SCS.jl v0.4.0
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", SOCWRConicPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 70690.7; atol = 8e0)
    #end
end

@testset "test soc distflow opf_bf" begin
    @testset "3-bus case" begin
        result = run_opf_bf("../test/data/matpower/case3.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf_bf("../test/data/matpower/case5.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf_bf("../test/data/matpower/case5_asym.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf_bf("../test/data/matpower/case5_gap.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf_bf("../test/data/pti/case5_alc.raw", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf_bf("../test/data/matpower/case5_pwlc.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf_bf("../test/data/matpower/case6.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf_bf("../test/data/matpower/case24.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
end

@testset "test soc conic distflow opf_bf" begin
    # TODO: requires increased iteration limit to work with MOI
    #@testset "3-bus case" begin
    #    result = run_opf_bf("../test/data/matpower/case3.m", SOCBFConicPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 5746.7; atol = 1e1)
    #end
    @testset "5-bus transformer swap case" begin
        result = run_opf_bf("../test/data/matpower/case5.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15051; atol = 1e1)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf_bf("../test/data/matpower/case5_asym.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14999; atol = 1e1)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf_bf("../test/data/matpower/case5_npg.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 3610.49; atol = 1e1)
    end
end


@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5780; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15921; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11484.2; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 76599.9; atol = 1e0)
    end
end


@testset "test qc opf with trilinear convexhull relaxation" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5817.91; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15929.2; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11512.9; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 76785.4; atol = 1e0)
    end
end



@testset "test sdp opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5852.59; atol = 1e0)
    end
    # TODO see if convergence time can be improved
    #@testset "5-bus asymmetric case" begin
    #    result = run_opf("../test/data/matpower/case5_asym.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 16664; atol = 1e0)
    #end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus gap case" begin
    #    result = run_opf("../test/data/matpower/case5_gap.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], TBD; atol = 1e0)
    #end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus with asymmetric line charge" begin
    #    result = run_opf("../test/data/pti/case5_alc.raw", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 1005.31; atol = 1e-1)
    #end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus with negative generators" begin
    #    result = run_opf("../test/data/matpower/case5_npg.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 7291.69; atol = 1e0) # Mosek v8 value
    #end
    # TODO: requires increased iteration limit to work with MOI
    #@testset "14-bus case" begin
    #    result = run_opf("../test/data/matpower/case14.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 8079.97; atol = 1e0)
    #end
    # TODO: requires increased iteration limit to work with MOI
    #@testset "6-bus case" begin
    #    result = run_opf("../test/data/matpower/case6.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 11560.8; atol = 1e0)
    #end
    # TODO replace this with smaller case, way too slow for unit testing
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end


@testset "test sdp opf with constraint decomposition" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/matpower/case3.m", SparseSDPWRMPowerModel, scs_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5852.35; atol = 1e0)
    end
    # does not converge in SCS.jl v0.4.0
    #@testset "5-bus with asymmetric line charge" begin
    #    result = run_opf("../test/data/pti/case5_alc.raw", SparseSDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 1005.31; atol = 1e-1)
    #end
    # does not converge in SCS.jl v0.4.0 (need long iter limit)
    #@testset "14-bus case" begin
    #    result = run_opf("../test/data/matpower/case14.m", SparseSDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 8081.5; atol = 1e0)
    #end
    # multiple components are not currently supported by this form
    #@testset "6-bus case" begin
    #    result = run_opf("../test/data/matpower/case6.m", SparseSDPWRMPowerModel, scs_solver)
    #
    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 11578.8; atol = 1e0)
    #end
    # does not converge in SCS.jl v0.4.0 (need long iter limit)
    #@testset "passing in decomposition" begin
    #    PMs = PowerModels
    #    data = PMs.parse_file("../test/data/matpower/case14.m")
    #    pm = GenericPowerModel(data, SparseSDPWRMForm)

    #    cadj, lookup_index, sigma = PMs.chordal_extension(pm)
    #    cliques = PMs.maximal_cliques(cadj)
    #    lookup_bus_index = map(reverse, lookup_index)
    #    groups = [[lookup_bus_index[gi] for gi in g] for g in cliques]
    #    @test PMs.problem_size(groups) == 344

    #    pm.ext[:SDconstraintDecomposition] = PMs.SDconstraintDecomposition(groups, lookup_index, sigma)

    #    PMs.post_opf(pm)
    #    result = solve_generic_model(pm, scs_solver; solution_builder=PMs.get_solution)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 8081.5; atol = 1e0)
    #end
end

