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
            result = PowerModels._run_opf_cl(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "5-bus current limit case" begin
           result = PowerModels._run_opf_cl("../test/data/matpower/case5_clm.m", ACPPowerModel, ipopt_solver)

           @test result["termination_status"] == LOCALLY_SOLVED
           @test isapprox(result["objective"], 17015.5; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_opf_cl(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test ac rect opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_opf_cl(data, ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_opf_cl(data, ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test ac tan opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_opf_cl(data, ACTPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_opf_cl(data, ACTPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_opf_cl(data, DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16154.5; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_opf_cl(data, DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 7642.59; atol = 1e0)
        end
    end

    @testset "test dc+ll opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_opf_cl(data, DCPLLPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16282.6; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_opf_cl(data, DCPLLPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8110.61; atol = 1e0)
        end
    end

    @testset "test soc (BIM) opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels._run_opf_cl(data, SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15047.7; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels._run_opf_cl(data, SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 8075.12; atol = 1e0)
        end
    end

    @testset "test sdp opf" begin
        @testset "3-bus case" begin
            data = build_current_data("../test/data/matpower/case3.m")
            result = PowerModels._run_opf_cl(data, SDPWRMPowerModel, scs_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 5747.32; atol = 1e0)
        end
        #@testset "5-bus case" begin
        #    data = build_current_data("../test/data/matpower/case5.m")
        #    result = PowerModels._run_opf_cl(data, SDPWRMPowerModel, scs_solver)

        #    @test result["termination_status"] == OPTIMAL
        #    @test isapprox(result["objective"], 15418.4; atol = 1e0)
        #end

        # too slow of unit tests
        # @testset "14-bus case" begin
        #     data = build_current_data("../test/data/matpower/case14.m")
        #     result = PowerModels._run_opf_cl(data, SDPWRMPowerModel, scs_solver)

        #     @test result["termination_status"] == OPTIMAL
        #     @test isapprox(result["objective"], 8081.52; atol = 1e0)
        # end
    end

end



@testset "test mld" begin

    @testset "test ac polar mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)

        end
        @testset "14-bus current" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)

            @test isapprox(sum(load["pd"] for (i,load) in result["solution"]["load"]), 2.5900; atol = 1e-4)
            @test isapprox(sum(load["qd"] for (i,load) in result["solution"]["load"]), 0.7349; atol = 1e-4)

            @test isapprox(sum(shunt["bs"] for (i,shunt) in result["solution"]["shunt"]), 0.19; atol = 1e-4)
            @test isapprox(sum(shunt["gs"] for (i,shunt) in result["solution"]["shunt"]), 0.00; atol = 1e-4)
        end
    end

    @testset "test ac rect mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
    end

    @testset "test ac tan mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", ACTPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", ACTPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
    end

    @testset "test nfa mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", NFAPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", NFAPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
    end

    @testset "test dc mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
    end

    @testset "test soc (BIM) mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result)
            @test all_shunts_on(result)
        end
    end

    @testset "test soc conic (BIM) mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", SOCWRConicPowerModel, scs_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result; atol=1e-4)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", SOCWRConicPowerModel, scs_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result; atol=1e-4)
            @test all_shunts_on(result; atol=1e-4)
        end
    end

    @testset "test sdp mld" begin
        @testset "5-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", SOCWRConicPowerModel, scs_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            @test isapprox(active_power_served(result), 10.0; atol = 1e-2)
            @test all_loads_on(result; atol=1e-4)
            @test all_shunts_on(result)
        end
        @testset "14-bus case" begin
            result = PowerModels._run_mld("../test/data/matpower/case14.m", SOCWRConicPowerModel, scs_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 3.59; atol = 1e-2)
            @test isapprox(active_power_served(result), 2.59; atol = 1e-2)
            @test all_loads_on(result, atol=1e-4)
            @test all_shunts_on(result, atol=1e-4)
        end
    end


    @testset "test mld duals" begin
        settings = Dict("output" => Dict("duals" => true))

        @testset "ac case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", ACPPowerModel, ipopt_solver, setting=settings)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            for (i, bus) in result["solution"]["bus"]
                @test bus["lam_kcl_r"] <=  1.0
                @test bus["lam_kcl_r"] >= -1.0
                @test bus["lam_kcl_i"] <=  1.0
                @test bus["lam_kcl_i"] >= -1.0
            end
        end

        @testset "soc case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver, setting=settings)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            for (i, bus) in result["solution"]["bus"]
                @test bus["lam_kcl_r"] <=  1.0
                @test bus["lam_kcl_r"] >= -1.0
                @test bus["lam_kcl_i"] <=  1.0
                @test bus["lam_kcl_i"] >= -1.0
            end
        end

        @testset "dc case" begin
            result = PowerModels._run_mld("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver, setting=settings)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
            for (i, bus) in result["solution"]["bus"]
                @test bus["lam_kcl_r"] <=  1.0
                @test bus["lam_kcl_r"] >= -1.0
            end
        end

    end

end


@testset "test unit commitment opf" begin

    @testset "test ac opf" begin
        @testset "5-bus uc case" begin
            result = PowerModels._run_ucopf("../test/data/matpower/case5_uc.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 18270.0; atol = 1e0)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
        end
    end

    @testset "test soc opf" begin
        @testset "5-bus uc case" begin
            result = PowerModels._run_ucopf("../test/data/matpower/case5_uc.m", SOCWRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15057.09; atol = 1e0)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus uc case" begin
            result = PowerModels._run_ucopf("../test/data/matpower/case5_uc.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 17613.2; atol = 1e0)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0)
        end

        @testset "5-bus uc pwl case" begin
            data = parse_file("../test/data/matpower/case5_pwlc.m")
            for (i,load) in data["load"]
                load["pd"] = 0.5*load["pd"]
            end
            result = PowerModels._run_ucopf(data, DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 8008.0; atol = 1e0)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0)
            @test isapprox(result["solution"]["gen"]["5"]["gen_status"], 0.0)
        end
    end


    @testset "test ac opf" begin
        @testset "5-bus uc storage case" begin
            result = PowerModels._run_ucopf("../test/data/matpower/case5_uc_strg.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17740.9; atol = 1e0)

            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["1"]["status"], 1.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["2"]["status"], 0.0, atol=1e-6)
        end
    end

    @testset "test soc opf" begin
        @testset "5-bus uc storage case" begin
            result = PowerModels._run_ucopf("../test/data/matpower/case5_uc_strg.m", SOCWRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 14525.0; atol = 1e0)

            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["1"]["status"], 1.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["2"]["status"], 0.0, atol=1e-6)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus uc storage case" begin
            result = PowerModels._run_ucopf("../test/data/matpower/case5_uc_strg.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 16833.2; atol = 1e0)

            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["1"]["status"], 1.0, atol=1e-6)
            @test isapprox(result["solution"]["storage"]["2"]["status"], 1.0, atol=1e-6)
        end
    end

end



@testset "test opf with switches" begin

    @testset "test ac opf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_opf_sw("../test/data/matpower/case5_sw.m", ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 16641.2; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw_fr"], 3.051, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw_fr"], 0.885, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw_fr"], 0.000, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw_fr"], 0.000, atol=1e-3)
            #@test isnan(result["solution"]["switch"]["3"]["psw_fr"])
            #@test isnan(result["solution"]["switch"]["3"]["qsw_fr"])
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_opf_sw("../test/data/matpower/case5_sw_nb.m", ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17915.3; atol = 1e0)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_opf_sw("../test/data/matpower/case5_sw.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 16554.7; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw_fr"], 3.050, atol=1e-2)
            #@test isnan(result["solution"]["switch"]["1"]["qsw_fr"])
            @test isapprox(result["solution"]["switch"]["2"]["psw_fr"], 0.000, atol=1e-3)
            #@test isnan(result["solution"]["switch"]["2"]["qsw_fr"])
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_opf_sw("../test/data/matpower/case5_sw_nb.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 17751.3; atol = 1e0)
        end
    end

    @testset "test soc opf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_opf_sw("../test/data/matpower/case5_sw.m", SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 15110.0; atol = 1e0)
            @test isapprox(result["solution"]["switch"]["1"]["psw_fr"], 3.048, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw_fr"], 0.889, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw_fr"], 0.000, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw_fr"], 0.000, atol=1e-3)
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_opf_sw("../test/data/matpower/case5_sw_nb.m", SOCWRPowerModel, ipopt_solver)

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
            @test isapprox(result["solution"]["switch"]["1"]["psw_fr"],  5.468, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw_fr"], -0.836, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw_fr"], -2.426, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw_fr"],  1.736, atol=1e-3)

            @test isapprox(result["solution"]["switch"]["1"]["status"], 1.00, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["status"], 1.00, atol=1e-3)
        end

        @testset "5-bus sw nb case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw_nb.m", ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17915.2; atol = 1e0)

            switch_status_total = sum(switch["status"] for (i,switch) in result["solution"]["switch"])
            @test isapprox(switch_status_total, 14.00, atol=1e-4) # zero swtiches off
        end
    end

    @testset "test dc oswpf" begin
        @testset "5-bus sw case" begin
            result = PowerModels._run_oswpf("../test/data/matpower/case5_sw.m", DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 15054.1; atol = 1e0)

            @test isapprox(result["solution"]["switch"]["1"]["psw_fr"], 5.603, atol=1e-2)
            #@test isnan(result["solution"]["switch"]["1"]["qsw_fr"])
            @test isapprox(result["solution"]["switch"]["2"]["psw_fr"], -2.553, atol=1e-3)
            #@test isnan(result["solution"]["switch"]["2"]["qsw_fr"])

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
            @test isapprox(result["solution"]["switch"]["1"]["psw_fr"],  5.469, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["1"]["qsw_fr"], -0.809, atol=1e-2)
            @test isapprox(result["solution"]["switch"]["2"]["psw_fr"], -2.426, atol=1e-3)
            @test isapprox(result["solution"]["switch"]["2"]["qsw_fr"],  1.710, atol=1e-3)

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
            @test branch_status_total >= 5.0 && branch_status_total <= 7.0  # zero-two branches off
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

    @testset "test acp polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg("../test/data/matpower/case5_strg.m", PowerModels.ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17039.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end

    @testset "test mi acp polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg_mi("../test/data/matpower/case5_strg.m", PowerModels.ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17039.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end


    @testset "test acr polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg("../test/data/matpower/case5_strg.m", PowerModels.ACRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17039.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end

    @testset "test mi acr polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg_mi("../test/data/matpower/case5_strg.m", PowerModels.ACRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17039.7; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.176572; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.233351; atol = 1e-2)
        end
    end


    @testset "test soc polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg("../test/data/matpower/case5_strg.m", PowerModels.SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 13799.5; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.177399; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.235288; atol = 1e-2)
        end
    end

    @testset "test mi soc polar opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg_mi("../test/data/matpower/case5_strg.m", PowerModels.SOCWRPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 13799.5; atol = 1e0)

            @test isapprox(result["solution"]["storage"]["1"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["1"]["ps"], -0.177399; atol = 1e-2)
            @test isapprox(result["solution"]["storage"]["2"]["se"],  0.0; atol = 1e0)
            @test isapprox(result["solution"]["storage"]["2"]["ps"], -0.235288; atol = 1e-2)
        end
    end


    @testset "test dc opf" begin
        @testset "5-bus case" begin
            result = PowerModels._run_opf_strg("../test/data/matpower/case5_strg.m", PowerModels.DCPPowerModel, ipopt_solver)

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
            result = PowerModels._run_opf_strg_mi("../test/data/matpower/case5_strg.m", PowerModels.DCPPowerModel, cbc_solver)

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
            result = PowerModels._run_opf_strg("../test/data/matpower/case5_strg.m", PowerModels.DCPLLPowerModel, ipopt_solver)

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
        @test_warn(TESTLOG, "network data should specify time_elapsed, using 1.0 as a default", PowerModels._run_opf_strg(mp_data, PowerModels.ACPPowerModel, ipopt_solver))
        Memento.setlevel!(TESTLOG, "error")
    end

end



@testset "test ac v+t polar opf" begin

    function build_opf_var(pm::AbstractPowerModel)
        PowerModels.variable_bus_voltage(pm)
        PowerModels.variable_gen_power(pm)
        PowerModels.variable_branch_power(pm)
        PowerModels.variable_dcline_power(pm)

        PowerModels.objective_min_fuel_and_flow_cost(pm)

        PowerModels.constraint_model_voltage(pm)

        for i in ids(pm,:ref_buses)
            PowerModels.constraint_theta_ref(pm, i)
        end

        for i in ids(pm,:bus)
            PowerModels.constraint_power_balance(pm, i)
        end

        for i in ids(pm,:branch)
            # these are the functions to be tested
            PowerModels.constraint_ohms_y_from(pm, i)
            PowerModels.constraint_ohms_y_to(pm, i)

            PowerModels.constraint_voltage_angle_difference(pm, i)

            PowerModels.constraint_thermal_limit_from(pm, i)
            PowerModels.constraint_thermal_limit_to(pm, i)
        end

        for i in ids(pm,:dcline)
            PowerModels.constraint_dcline_power_losses(pm, i)
        end
    end

    @testset "3-bus case" begin
        result = run_model("../test/data/matpower/case3.m", ACPPowerModel, ipopt_solver, build_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_model("../test/data/matpower/case5_asym.m", ACPPowerModel, ipopt_solver, build_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_model("../test/data/matpower/case5_gap.m", ACPPowerModel, ipopt_solver, build_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_model("../test/data/matpower/case5_dc.m", ACPPowerModel, ipopt_solver, build_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18156.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_model("../test/data/matpower/case6.m", ACPPowerModel, ipopt_solver, build_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_model("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver, build_opf_var)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end

@testset "test opf with optimization of oltc and pst" begin

    @testset "test ac polar opf" begin
        @testset "3-bus case with fixed phase shift / tap" begin
            file = "../test/data/matpower/case3_oltc_pst.m"
            data = PowerModels.parse_file(file)
            result = PowerModels.run_opf(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 5820.1; atol = 1e0)
        end

        @testset "3-bus case with optimal phase shifting / tap changing" begin
            file = "../test/data/matpower/case3_oltc_pst.m"
            data = PowerModels.parse_file(file)
            result = PowerModels._run_opf_oltc_pst(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 5738.6; atol = 1e0)

            @test haskey(result["solution"]["branch"]["1"], "tm")
            @test haskey(result["solution"]["branch"]["1"], "ta")

            @test isapprox(result["solution"]["branch"]["1"]["tm"], 0.948; atol = 1e-2)
            @test isapprox(result["solution"]["branch"]["1"]["ta"], 0.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["2"]["tm"], 1.100; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["2"]["ta"], 0.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["3"]["tm"], 1.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["3"]["ta"], 15.0/180*pi; atol = 1e-1)
        end


        @testset "3-bus case with optimal phase shifting / tap changing with equal lb/ub" begin
            file = "../test/data/matpower/case3_oltc_pst.m"
            data = PowerModels.parse_file(file)
            for (i, branch) in data["branch"]
                branch["ta_min"] = branch["shift"]
                branch["ta_max"] = branch["shift"]
                branch["tm_min"] = branch["tap"]
                branch["tm_max"] = branch["tap"]
            end
            result = PowerModels._run_opf_oltc_pst(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 5820.1; atol = 1e0)

            @test isapprox(result["solution"]["branch"]["1"]["tm"], 1.00; atol = 1e-2)
            @test isapprox(result["solution"]["branch"]["1"]["ta"], 0.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["2"]["tm"], 1.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["2"]["ta"], 0.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["3"]["tm"], 1.000; atol = 1e-3)
            @test isapprox(result["solution"]["branch"]["3"]["ta"], 5.0/180*pi; atol = 1e-1)
        end
    end
end
