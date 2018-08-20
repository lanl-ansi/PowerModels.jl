

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
        @test isapprox(result["objective"], 11567; atol = 1e0)
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
        @test isapprox(result["objective"], 11567; atol = 1e0)
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
        @test isapprox(result["objective"], 11567; atol = 1e0)
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
        @test isapprox(result["objective"], 11396; atol = 1e0)
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
        @test isapprox(result["objective"], 11515; atol = 1e0)
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
        @test isapprox(result["objective"], 11560; atol = 1e0)
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

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5746.7; atol = 2e0)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf("../test/data/matpower/case5.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/matpower/case5_asym.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opf("../test/data/matpower/case5_gap.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], -28237.3; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf("../test/data/matpower/case5_npg.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 3613.72; atol = 40)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/matpower/case5_pwlc.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11560; atol = 3e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", SOCWRConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 70690.7; atol = 8e0)
    end
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
        @test isapprox(result["objective"], 11567.1; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf_bf("../test/data/matpower/case24.m", SOCBFPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
end

@testset "test soc conic distflow opf_bf" begin
    @testset "3-bus case" begin
        result = run_opf_bf("../test/data/matpower/case3.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5746.7; atol = 1e1)
    end
    @testset "5-bus transformer swap case" begin
        result = run_opf_bf("../test/data/matpower/case5.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15051; atol = 1e1)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf_bf("../test/data/matpower/case5_asym.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999; atol = 1e1)
    end
    @testset "5-bus with negative generators" begin
        result = run_opf_bf("../test/data/matpower/case5_npg.m", SOCBFConicPowerModel, scs_solver)

        @test result["status"] == :Optimal
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
        @test isapprox(result["objective"], 11567; atol = 1e0)
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
        @test isapprox(result["objective"], 11567.1; atol = 1e0)
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

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5851.3; atol = 1e0)
    end
    # TODO see if convergence time can be improved
    #@testset "5-bus asymmetric case" begin
    #    result = run_opf("../test/data/matpower/case5_asym.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 16664; atol = 1e0)
    #end
    #@testset "5-bus gap case" begin
    #    result = run_opf("../test/data/matpower/case5_gap.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], TBD; atol = 1e0)
    #end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opf("../test/data/pti/case5_alc.raw", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 1005.31; atol = 1e-1)
    end
    #@testset "5-bus with negative generators" begin
    #    result = run_opf("../test/data/matpower/case5_npg.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 7291.69; atol = 1e0) # Mosek v8 value
    #end
    @testset "14-bus case" begin
        result = run_opf("../test/data/matpower/case14.m", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 8079.97; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/matpower/case6.m", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11558.5; atol = 1e0)
    end
    # TODO replace this with smaller case, way too slow for unit testing
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/matpower/case24.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end
