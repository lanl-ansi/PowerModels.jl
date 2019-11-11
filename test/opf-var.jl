### Tests for OPF variants ###
TESTLOG = Memento.getlogger(PowerModels)

function build_current_data(base_data)
    c_data = PowerModels.parse_file(base_data)
    PowerModels.calc_current_limits!(c_data)
    for (i,branch) in c_data["branch"]
        delete!(branch, "rate_a")
    end
    return c_data
end


@testset "test current limit opf" begin

    @testset "test ac polar opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_cl_opf(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "5-bus current limit case" begin
           result = PowerModels._run_cl_opf("../test/data/matpower/case5_clm.m", ACPPowerModel, ipopt_solver)

           @test result["termination_status"] == LOCALLY_SOLVED
           @test isapprox(result["objective"], 17015.5; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_cl_opf(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test ac rect opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_cl_opf(data, ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_cl_opf(data, ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test ac tan opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_cl_opf(data, ACTPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_cl_opf(data, ACTPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_cl_opf(data, DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16154.5; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_cl_opf(data, DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 7642.59; atol = 1e0)
        end
    end

    @testset "test dc+ll opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_cl_opf(data, DCPLLPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16282.6; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_cl_opf(data, DCPLLPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8110.61; atol = 1e0)
        end
    end

    @testset "test soc (BIM) opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_cl_opf(data, SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15047.7; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_cl_opf(data, SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8075.12; atol = 1e0)
        end
    end

    @testset "test sdp opf" begin
        @testset "3-bus case" begin
            data = build_current_data("../test/data/matpower/case3.m")
            result = PowerModels._run_cl_opf(data, SDPWRMPowerModel, scs_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 5747.32; atol = 1e0)
        end
        #@testset "5-bus case" begin
        #    data = build_current_data("../test/data/matpower/case5.m")
        #    result = PowerModels._run_cl_opf(data, SDPWRMPowerModel, scs_solver)

        #    @test result["termination_status"] == OPTIMAL
        #    @test isapprox(result["objective"], 15418.4; atol = 1e0)
        #end

        # too slow of unit tests
        # @testset "14-bus case" begin
        #     data = build_current_data("../test/data/matpower/case14.m")
        #     result = PowerModels._run_cl_opf(data, SDPWRMPowerModel, scs_solver)

        #     @test result["termination_status"] == OPTIMAL
        #     @test isapprox(result["objective"], 8081.52; atol = 1e0)
        # end
    end

end


@testset "test unit commitment opf" begin

    @testset "test ac opf" begin
        @testset "5-bus uc case" begin
            result = PowerModels._run_uc_opf("../test/data/matpower/case5_uc.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 18270.0; atol = 1e0)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus uc case" begin
            result = PowerModels._run_uc_opf("../test/data/matpower/case5_uc.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 17613.2; atol = 1e0)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0)
        end
    end

    @testset "test ac opf" begin
        @testset "5-bus uc storage case" begin
            result = PowerModels._run_uc_opf("../test/data/matpower/case5_uc_strg.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17740.9; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["status"], 1.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["2"]["status"], 0.0, atol=1e-6)
        end
    end

end



@testset "test opf with swtiches" begin

    @testset "test ac opf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_sw_opf("../test/data/matpower/case5_sw.m", ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16641.2; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw"], 3.051, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw"], 0.885, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw"], 0.000, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw"], 0.000, atol=1e-3)
            @test isnan(result["solution"]["switch"]["3"]["psw"])
            @test isnan(result["solution"]["switch"]["3"]["qsw"])
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_sw_opf("../test/data/matpower/case5_sw_nb.m", ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17915.3; atol = 1e0)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_sw_opf("../test/data/matpower/case5_sw.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 16554.7; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw"], 3.050, atol=1e-2)
            @test isnan(result["solution"]["switch"]["1"]["qsw"])
            @test isapprox(result["solution"]["switch"]["2"]["psw"], 0.000, atol=1e-3)
            @test isnan(result["solution"]["switch"]["2"]["qsw"])
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_sw_opf("../test/data/matpower/case5_sw_nb.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 17751.3; atol = 1e0)
        end
    end

    @testset "test soc opf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_sw_opf("../test/data/matpower/case5_sw.m", SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15110.0; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw"], 3.048, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw"], 0.889, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw"], 0.000, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw"], 0.000, atol=1e-3)
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_sw_opf("../test/data/matpower/case5_sw_nb.m", SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15192.8; atol = 1e0)
        end
    end

end


@testset "test oswpf" begin

    @testset "test ac oswpf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15053.6; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw"],  5.468, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw"], -0.836, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw"], -2.426, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw"],  1.736, atol=1e-3)

            @test isapprox(result["solution"]["switch"]["1"]["status"], 1.00, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["status"], 1.00, atol=1e-3)
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw_nb.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16674.8; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test isapprox(switch_status_total, 12.00, atol=1e-4) # two swtiches off
        end
    end

    @testset "test dc oswpf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 15054.1; atol = 1e0)

            @test isapprox(result["solution"]["switch"]["1"]["psw"], 5.603, atol=1e-2)
            @test isnan(result["solution"]["switch"]["1"]["qsw"])
            @test isapprox(result["solution"]["switch"]["2"]["psw"], -2.553, atol=1e-3)
            @test isnan(result["solution"]["switch"]["2"]["qsw"])

            @test isapprox(result["solution"]["switch"]["1"]["status"], 1.00, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["status"], 1.00, atol=1e-3)
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw_nb.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 15141.2; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test switch_status_total <= 12.000 && switch_status_total >= 10.000 # two to four swtiches off
        end
    end

    @testset "test soc oswpf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw.m", SOCWRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15053.6; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw"],  5.469, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw"], -0.809, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw"], -2.426, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw"],  1.710, atol=1e-3)

            @test isapprox(result["solution"]["switch"]["1"]["status"], 1.00, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["status"], 1.00, atol=1e-3)
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw_nb.m", SOCWRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15175.7; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test isapprox(switch_status_total, 13.00, atol=1e-4) # one swtich off
        end
    end

end



@testset "test oswpf node-breaker" begin

    @testset "test ac oswpf node-breaker" begin
        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf_nb("../test/data/matpower/case5_sw_nb.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15350.4; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test isapprox(switch_status_total, 10.00, atol=1e-4) # four swtiches off

            branch_status_total = sum(branch["br_status"] for (i,branch) in result["solution"]["branch"])
            @test isapprox(branch_status_total, 5.00, atol=1e-4) # two branches off
        end
    end

    @testset "test dc oswpf node-breaker" begin
        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf_nb("../test/data/matpower/case5_sw_nb.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 15141.2; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test switch_status_total <= 13.000 && switch_status_total >= 12.000 # 1 to 2 swtiches off

            branch_status_total = sum(branch["br_status"] for (i,branch) in result["solution"]["branch"])
            @test branch_status_total >= 5.0 && branch_status_total <= 6.0  # one-two branches off
        end
    end

    @testset "test soc oswpf node-breaker" begin
        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf_nb("../test/data/matpower/case5_sw_nb.m", SOCWRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15175.7; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test isapprox(switch_status_total, 13.00, atol=1e-4) # one swtich off

            branch_status_total = sum(branch["br_status"] for (i,branch) in result["solution"]["branch"])
            @test isapprox(branch_status_total, 7.00, atol=1e-4) # no branches off
        end
    end

end


@testset "test storage opf" begin

    @testset "test ac polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_strg_opf("../test/data/matpower/case5_strg.m", PowerModels.ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17039.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end

    @testset "test mi ac polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_strg_mi_opf("../test/data/matpower/case5_strg.m", PowerModels.ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17039.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_strg_opf("../test/data/matpower/case5_strg.m", PowerModels.DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16840.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176871; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.2345009; atol = 1e-2)
        end
    end

    @testset "test mi dc opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_strg_mi_opf("../test/data/matpower/case5_strg.m", PowerModels.DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 16840.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end

    @testset "test dc+ll opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_strg_opf("../test/data/matpower/case5_strg.m", PowerModels.DCPLLPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17048.4; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176871; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.234501; atol = 1e-2)
        end
    end

    @testset "storage constraint warn" begin
        mp_data = PowerModels.parse_file("../test/data/matpower/case5_strg.m")
        delete!(mp_data, "time_elapsed")
        Memento.setlevel!(TESTLOG, "warn")
        @test_warn(TESTLOG, "network data should specify time_elapsed, using 1.0 as a default", PowerModels._run_strg_opf(mp_data, PowerModels.ACPPowerModel, ipopt_solver))
        Memento.setlevel!(TESTLOG, "error")
    end

end



@testset "test ac v+t polar opf" begin
    PMs = PowerModels

    function post_opf_var(pm::AbstractPowerModel)
        PMs.variable_voltage(pm)
        PMs.variable_generation(pm)
        PMs.variable_branch_flow(pm)
        PMs.variable_dcline_flow(pm)

        PMs.objective_min_fuel_and_flow_cost(pm)

        PMs.constraint_model_voltage(pm)

        for i in ids(pm,:ref_buses)
            PMs.constraint_theta_ref(pm, i)
        end

        for i in ids(pm,:bus)
            PMs.constraint_power_balance(pm, i)
        end

        for i in ids(pm,:branch)
            # these are the functions to be tested
            PMs.constraint_ohms_y_from(pm, i)
            PMs.constraint_ohms_y_to(pm, i)

            PMs.constraint_voltage_angle_difference(pm, i)

            PMs.constraint_thermal_limit_from(pm, i)
            PMs.constraint_thermal_limit_to(pm, i)
        end

        for i in ids(pm,:dcline)
            PMs.constraint_dcline(pm, i)
        end
    end

    @testset "3-bus case" begin
        result = run_model("../test/data/matpower/case3.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_model("../test/data/matpower/case5_asym.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_model("../test/data/matpower/case5_gap.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_model("../test/data/matpower/case5_dc.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18156.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_model("../test/data/matpower/case6.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_model("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end

