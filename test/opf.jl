

@testset "test ac polar opf" begin
    @testset "3-bus case" begin
        result = solve_ac_opf("../test/data/matpower/case3.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus tranformer swap case" begin
        result = solve_ac_opf("../test/data/matpower/case5.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18269; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_ac_opf("../test/data/matpower/case5_asym.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_ac_opf("../test/data/matpower/case5_gap.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = solve_ac_opf("../test/data/matpower/case5_dc.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18156.2; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_ac_opf("../test/data/pti/case5_alc.raw", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = solve_ac_opf("../test/data/matpower/case5_npg.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8190.09; atol = 1e0)
    end
    @testset "5-bus with only current limit data" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_clm.m")
        calc_thermal_limits!(data)
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16513.6; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_ac_opf("../test/data/matpower/case5_pwlc.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "5-bus with gen lb" begin
        result = solve_ac_opf("../test/data/matpower/case5_uc.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18742.2; atol = 1e0)
    end
    @testset "5-bus with dangling bus" begin
        result = solve_ac_opf("../test/data/matpower/case5_db.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16739.1; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_ac_opf("../test/data/matpower/case6.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", ACPPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test ac rect opf" begin
    #=
    # numerical issue
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", ACRPowerModel, nlp_solver)

        #@test result["termination_status"] == LOCALLY_SOLVED
        #@test isapprox(result["objective"], 5812; atol = 1e0)
        @test result["status"] == :Error
    end
    =#
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", ACRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", ACRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", ACRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_ac_opf("../test/data/matpower/case5_pwlc.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", ACRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["vi"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["vi"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", ACRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", ACRPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test ac tan opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27438.7; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", ACTPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", ACTPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test iv opf" begin
    @testset "3-bus case" begin
        result = solve_opf_iv("../test/data/matpower/case3.m", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf_iv("../test/data/matpower/case5_asym.m", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf_iv("../test/data/matpower/case5_gap.m", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e2) #numerically challenging , returns 27438.7
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf_iv("../test/data/pti/case5_alc.raw", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end

    @testset "5-bus with pwl costs" begin
        result = solve_opf_iv("../test/data/matpower/case5_pwlc.m", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf_iv("../test/data/matpower/case6.m", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["vi"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["vi"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf_iv("../test/data/matpower/case24.m", IVRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
       pm = instantiate_model("../test/data/matpower/case14.m", IVRPowerModel, PowerModels.build_opf_iv)
       @test check_variable_bounds(pm.model)
   end
end



@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = solve_dc_opf("../test/data/matpower/case3.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5782; atol = 1e0)
    end
    @testset "5-bus case, LP solver" begin
        result = solve_dc_opf("../test/data/matpower/case5.m", milp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 17613; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_dc_opf("../test/data/matpower/case5_asym.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17479; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_dc_opf("../test/data/matpower/case5_gap.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_dc_opf("../test/data/pti/case5_alc.raw", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_dc_opf("../test/data/matpower/case5_pwlc.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42575; atol = 1e0)
    end
    @testset "5-bus with gen lb" begin
        result = solve_dc_opf("../test/data/matpower/case5_uc.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18064.5; atol = 1e0)
    end
    @testset "5-bus with dangling bus" begin
        result = solve_dc_opf("../test/data/matpower/case5_db.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16710.0; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_dc_opf("../test/data/matpower/case6.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11391.8; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = solve_opf("../test/data/matpower/case24.m", DCPPowerModel, nlp_solver)

    #    @test result["termination_status"] == LOCALLY_SOLVED
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", DCPPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test matpower dc opf" begin
    @testset "5-bus case with matpower DCMP model" begin
        result = solve_opf("../test/data/matpower/case5.m", DCMPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED

        @test isapprox(result["solution"]["bus"]["1"]["va"],  0.0591772; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["2"]["va"],  0.0017285; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["3"]["va"], 0.0120486; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-7)

    end
end


@testset "test nfa opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42575.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", NFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 61001.2; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", NFAPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test dc+ll opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5885; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17693; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -32710.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1001.17; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42947; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11574.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", DCPLLPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 82240; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", DCPLLPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test lpac-c opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5908.98; atol = 1e0)
    end
    @testset "5-bus tranformer swap case" begin
        result = solve_opf("../test/data/matpower/case5.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18288.1; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17645.6; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27554.5; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = solve_opf("../test/data/matpower/case5_dc.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18253.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1004.58; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = solve_opf("../test/data/matpower/case5_npg.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8082.54; atol = 1e0)
    end
    @testset "5-bus with only current limit data" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_clm.m")
        calc_thermal_limits!(data)
        result = solve_opf(data, LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16559.3; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42863.4; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", LPACCPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11615.1; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    # TODO uderstand why this is infeasible
    #@testset "24-bus rts case" begin
    #    result = solve_opf("../test/data/matpower/case24.m", LPACCPowerModel, nlp_solver)

    #    @test result["termination_status"] == LOCALLY_SOLVED
    #    @test isapprox(result["objective"], 79805; atol = 1e0)
    #end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", LPACCPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test soc (BIM) opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        result = solve_opf("../test/data/matpower/case5.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -28237.3; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = solve_opf("../test/data/matpower/case5_npg.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 3603.91; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "5-bus with dangling bus" begin
        result = solve_opf("../test/data/matpower/case5_db.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16739.1; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", SOCWRPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test soc conic form opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 5736.94; atol = 2e0)
        @test isapprox(result["objective"], 5747.37; atol = 2e0)
    end
    @testset "5-bus transformer swap case" begin
        result = solve_opf("../test/data/matpower/case5.m", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 15051.4; atol = 1e1)
    end
    @testset "5-bus asymmetric case" begin
       result = solve_opf("../test/data/matpower/case5_asym.m", SOCWRConicPowerModel, sdp_solver)

       @test result["termination_status"] == OPTIMAL
       @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], -28236.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
       result = solve_opf("../test/data/matpower/case5_npg.m", SOCWRConicPowerModel, sdp_solver)

       @test result["termination_status"] == OPTIMAL
       #@test isapprox(result["objective"], 3551.71; atol = 40)
       @test isapprox(result["objective"], 3602.11; atol = 40)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 42889; atol = 1e0)
        #@test isapprox(result["objective"], 42906; atol = 1e0)
        @test isapprox(result["objective"], 42908; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 11472.2; atol = 3e0)
        #@test isapprox(result["objective"], 11451.5; atol = 3e0)
        @test isapprox(result["objective"], 11473.4; atol = 3e0)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 70693.9; atol = 1e0)
        #@test isapprox(result["objective"], 70670.0; atol = 1e0)
        @test isapprox(result["objective"], 70683.5; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", SOCWRConicPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test soc distflow opf_bf" begin
    @testset "3-bus case" begin
        result = solve_opf_bf("../test/data/matpower/case3.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        result = solve_opf_bf("../test/data/matpower/case5.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15051; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf_bf("../test/data/matpower/case5_asym.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf_bf("../test/data/matpower/case5_gap.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf_bf("../test/data/pti/case5_alc.raw", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf_bf("../test/data/matpower/case5_pwlc.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf_bf("../test/data/matpower/case6.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11472.3; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = solve_opf_bf("../test/data/matpower/case24.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
    @testset "3-bus case w/ r,x=0 on branch" begin
        mp_data = PowerModels.parse_file("../test/data/matpower/case3.m")
        mp_data["branch"]["1"]["br_r"] = mp_data["branch"]["1"]["br_x"] = 0.0
        result = solve_opf_bf(mp_data, SOCBFPowerModel, nlp_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", SOCBFPowerModel, PowerModels.build_opf_bf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test soc conic distflow opf_bf" begin
    @testset "3-bus case" begin
        result = solve_opf_bf("../test/data/matpower/case3.m", SOCBFConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 5746.7; atol = 5e1)
    end
    @testset "5-bus transformer swap case" begin
        result = solve_opf_bf("../test/data/matpower/case5.m", SOCBFConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 15051; atol = 1e1)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf_bf("../test/data/matpower/case5_asym.m", SOCBFConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 14999; atol = 1e1)
    end
    @testset "5-bus with negative generators" begin
        result = solve_opf_bf("../test/data/matpower/case5_npg.m", SOCBFConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 3593.0; atol = 1e1)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", SOCBFConicPowerModel, PowerModels.build_opf_bf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test linear distflow opf_bf" begin
    @testset "3-bus case" begin
        result = solve_opf_bf("../test/data/matpower/case3.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus transformer swap case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = solve_opf_bf(data, BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810; atol = 1e0)
        @test isapprox(sum(l["pd"] for l in values(data["load"])),
            sum(g["pg"] for g in values(result["solution"]["gen"]));
            atol = 1e-3)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf_bf("../test/data/matpower/case5_asym.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf_bf("../test/data/matpower/case5_gap.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf_bf("../test/data/pti/case5_alc.raw", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1002.46; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf_bf("../test/data/matpower/case5_pwlc.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42575.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf_bf("../test/data/matpower/case6.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    # @testset "24-bus rts case" begin
    #     result = solve_opf_bf("../test/data/matpower/case24.m", BFAPowerModel, nlp_solver)
    #
    #     @test result["termination_status"] == LOCALLY_SOLVED
    #     @test isapprox(result["objective"], 70690.7; atol = 1e0)
    # end
    @testset "3-bus case w/ r,x=0 on branch" begin
        mp_data = PowerModels.parse_file("../test/data/matpower/case3.m")
        mp_data["branch"]["1"]["br_r"] = mp_data["branch"]["1"]["br_x"] = 0.0
        result = solve_opf_bf(mp_data, BFAPowerModel, nlp_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", BFAPowerModel, PowerModels.build_opf_bf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5780; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15921; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1005.27; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = solve_opf("../test/data/matpower/case5_pwlc.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11484.2; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 76599.9; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", QCRMPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end

@testset "test qc opf with trilinear convexhull relaxation" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", QCLSPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5817.91; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", QCLSPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 15929.2; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", QCLSPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27659.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", QCLSPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11512.9; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = solve_opf("../test/data/matpower/case24.m", QCLSPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 76785.4; atol = 1e0)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", QCLSPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test sdp opf" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 5818.00; atol = 1e1)
        @test isapprox(result["objective"], 5852.51; atol = 1e1)

        @test haskey(result["solution"],"WR")
        @test haskey(result["solution"],"WI")
        #@test isapprox(result["solution"]["bus"]["1"]["w"], 1.179, atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["w"], 1.209, atol = 1e-2)
        @test isapprox(result["solution"]["branch"]["1"]["wr"], 0.941, atol = 1e-2)
        #@test isapprox(result["solution"]["branch"]["1"]["wi"], 0.269, atol = 1e-2)
        @test isapprox(result["solution"]["branch"]["1"]["wi"], 0.284, atol = 1e-2)
    end
    @testset "5-bus asymmetric case" begin
        result = solve_opf("../test/data/matpower/case5_asym.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 16662.0; atol = 1e1)
    end
    @testset "5-bus gap case" begin
        result = solve_opf("../test/data/matpower/case5_gap.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], -28236.1; atol = 1e1)
    end
    @testset "5-bus with asymmetric line charge" begin
       result = solve_opf("../test/data/pti/case5_alc.raw", SDPWRMPowerModel, sdp_solver)

       @test result["termination_status"] == OPTIMAL
       @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = solve_opf("../test/data/matpower/case5_npg.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 6827.34; atol = 1e0)
        #@test isapprox(result["objective"], 6735.17; atol = 1e0)
        @test isapprox(result["objective"], 6827.71; atol = 1e0)
    end
    # too slow for unit tests
    # @testset "14-bus case" begin
    #     result = solve_opf("../test/data/matpower/case14.m", SDPWRMPowerModel, sdp_solver)

    #     @test result["termination_status"] == OPTIMAL
    #     @test isapprox(result["objective"], 8081.52; atol = 1e0)
    # end
    @testset "6-bus case" begin
        result = solve_opf("../test/data/matpower/case6.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 11580.8; atol = 1e1)
        #@test isapprox(result["objective"], 11507.7; atol = 1e1)
        @test isapprox(result["objective"], 11580.5; atol = 1e1)
    end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", SDPWRMPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
end


@testset "test sdp opf with constraint decomposition" begin
    @testset "3-bus case" begin
        result = solve_opf("../test/data/matpower/case3.m", SparseSDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        #@test isapprox(result["objective"], 5851.23; atol = 1e1)
        #@test isapprox(result["objective"], 5818.00; atol = 1e1)
        @test isapprox(result["objective"], 5852.51; atol = 1e1)

        @test haskey(result["solution"]["w_group"]["1"],"WR")
        @test haskey(result["solution"]["w_group"]["1"],"WI")
        #@test isapprox(result["solution"]["bus"]["1"]["w"], 1.179, atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["w"], 1.209, atol = 1e-2)
        @test isapprox(result["solution"]["branch"]["1"]["wr"], 0.941, atol = 1e-2)
        #@test isapprox(result["solution"]["branch"]["1"]["wi"], 0.269, atol = 1e-2)
        @test isapprox(result["solution"]["branch"]["1"]["wi"], 0.284, atol = 1e-2)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = solve_opf("../test/data/pti/case5_alc.raw", SparseSDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
    @testset "9-bus cholesky PosDefException" begin
        result = solve_opf("../test/data/matpower/case9.m", SparseSDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 347.746; atol = 1e0)
    end
    @testset "14-bus case" begin
        result = solve_opf("../test/data/matpower/case14.m", SparseSDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 8081.5; atol = 1e0)
    end
    # multiple components are not currently supported by this form
    # @testset "6-bus case" begin
    #     result = solve_opf("../test/data/matpower/case6.m", SparseSDPWRMPowerModel, sdp_solver)

    #     @test result["termination_status"] == OPTIMAL
    #     @test isapprox(result["objective"], 11578.8; atol = 1e0)
    # end
    @testset "14-bus variable bounds" begin
        pm = instantiate_model("../test/data/matpower/case14.m", SparseSDPWRMPowerModel, PowerModels.build_opf)
        @test check_variable_bounds(pm.model)
    end
    @testset "passing in decomposition" begin
        # too slow for unit tests
        #data = PowerModels.parse_file("../test/data/matpower/case14.m")
        data = PowerModels.parse_file("../test/data/pti/case5_alc.raw")
        pm = InfrastructureModels.InitializeInfrastructureModel(SparseSDPWRMPowerModel, data, PowerModels._pm_global_keys, PowerModels.pm_it_sym)
        PowerModels.ref_add_core!(pm.ref)

        nw = collect(nw_ids(pm))[1]

        cadj, lookup_index, sigma = PowerModels._chordal_extension(pm, nw)
        cliques = PowerModels._maximal_cliques(cadj)
        lookup_bus_index = Dict((reverse(p) for p = pairs(lookup_index)))
        groups = [[lookup_bus_index[gi] for gi in g] for g in cliques]
        @test PowerModels._problem_size(groups) == 83

        pm.ext[:SDconstraintDecomposition] = PowerModels._SDconstraintDecomposition(groups, lookup_index, sigma)

        PowerModels.build_opf(pm)
        result = optimize_model!(pm, optimizer=sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 1005.31; atol = 1e0)
    end
end
