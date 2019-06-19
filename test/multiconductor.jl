TESTLOG = Memento.getlogger(PowerModels)

"an example of building a multi-phase model in an extention package"
function post_tp_opf(pm::PowerModels.GenericPowerModel)
    for c in PowerModels.conductor_ids(pm)
        PowerModels.variable_voltage(pm, cnd=c)
        PowerModels.variable_generation(pm, cnd=c)
        PowerModels.variable_branch_flow(pm, cnd=c)
        PowerModels.variable_dcline_flow(pm, cnd=c)
    end

    for c in PowerModels.conductor_ids(pm)
        PowerModels.constraint_model_voltage(pm, cnd=c)

        for i in ids(pm, :ref_buses)
            PowerModels.constraint_theta_ref(pm, i, cnd=c)
        end

        for i in ids(pm, :bus)
            PowerModels.constraint_power_balance_shunt(pm, i, cnd=c)
        end

        for i in ids(pm, :branch)
            PowerModels.constraint_ohms_yt_from(pm, i, cnd=c)
            PowerModels.constraint_ohms_yt_to(pm, i, cnd=c)

            PowerModels.constraint_voltage_angle_difference(pm, i, cnd=c)

            PowerModels.constraint_thermal_limit_from(pm, i, cnd=c)
            PowerModels.constraint_thermal_limit_to(pm, i, cnd=c)
        end

        for i in ids(pm, :dcline)
            PowerModels.constraint_dcline(pm, i, cnd=c)
        end
    end

    PowerModels.objective_min_fuel_and_flow_cost(pm)
end


@testset "test multi-conductor" begin

    @testset "json parser" begin
        mc_data = build_mc_data!("../test/data/pti/parser_test_defaults.raw")
        mc_json_string = PowerModels.parse_json(JSON.json(mc_data))
        @test mc_data == mc_json_string

        io = PipeBuffer()
        JSON.print(io, mc_data)
        mc_json_file = PowerModels.parse_file(io)
        @test mc_data == mc_json_file

        mc_strg_data = build_mc_data!("../test/data/matpower/case5_strg.m")
        mc_strg_json_string = PowerModels.parse_json(JSON.json(mc_strg_data))
        @test mc_strg_data == mc_strg_json_string

        # test that non-multiconductor json still parses, pti_json_file will result in error if fails
        pti_data = PowerModels.parse_file("../test/data/pti/parser_test_defaults.raw")
        io = PipeBuffer()
        JSON.print(io, pti_data)
        pti_json_file = PowerModels.parse_file(io)
        @test pti_data == pti_json_file

        mc_data = build_mc_data!("../test/data/matpower/case5.m")
        mc_data["gen"]["1"]["pmax"] = PowerModels.MultiConductorVector([Inf, Inf, Inf])
        mc_data["gen"]["1"]["qmin"] = PowerModels.MultiConductorVector([-Inf, -Inf, -Inf])
        mc_data["gen"]["1"]["bool_test"] = PowerModels.MultiConductorVector([true, true, false])
        mc_data["gen"]["1"]["string_test"] = PowerModels.MultiConductorVector(["a", "b", "c"])
        mc_data["branch"]["1"]["br_x"][1,2] = -Inf
        mc_data["branch"]["1"]["br_x"][1,3] = Inf

        mc_data_json = PowerModels.parse_json(JSON.json(mc_data))
        @test mc_data_json == mc_data

        mc_data["gen"]["1"]["nan_test"] = PowerModels.MultiConductorVector([0, NaN, 0])
        mc_data_json = PowerModels.parse_json(JSON.json(mc_data))
        @test isnan(mc_data_json["gen"]["1"]["nan_test"][2])
    end

    @testset "idempotent unit transformation" begin
        @testset "5-bus replicate case" begin
            mp_data = build_mc_data!("../test/data/matpower/case5_dc.m")

            PowerModels.make_mixed_units!(mp_data)
            PowerModels.make_per_unit!(mp_data)

            @test InfrastructureModels.compare_dict(mp_data, build_mc_data!("../test/data/matpower/case5_dc.m"))
        end
        @testset "24-bus replicate case" begin
            mp_data = build_mc_data!("../test/data/matpower/case24.m")

            PowerModels.make_mixed_units!(mp_data)
            PowerModels.make_per_unit!(mp_data)

            @test InfrastructureModels.compare_dict(mp_data, build_mc_data!("../test/data/matpower/case24.m"))
        end
    end


    @testset "topology processing" begin
        @testset "7-bus replicate status case" begin
            mp_data = build_mc_data!("../test/data/matpower/case7_tplgy.m")
            PowerModels.propagate_topology_status!(mp_data)
            PowerModels.select_largest_component!(mp_data)

            active_buses = Set(["4", "5", "7"])
            active_branches = Set(["8"])
            active_dclines = Set(["3"])

            for (i,bus) in mp_data["bus"]
                if i in active_buses
                    @test bus["bus_type"] != 4
                else
                    @test bus["bus_type"] == 4
                end
            end

            for (i,branch) in mp_data["branch"]
                if i in active_branches
                    @test branch["br_status"] == 1
                else
                    @test branch["br_status"] == 0
                end
            end

            for (i,dcline) in mp_data["dcline"]
                if i in active_dclines
                    @test dcline["br_status"] == 1
                else
                    @test dcline["br_status"] == 0
                end
            end
        end

    end


    @testset "test multi-conductor ac opf" begin
        @testset "3-bus 3-conductor case" begin
            mp_data = build_mc_data!("../test/data/matpower/case3.m", conductors=3)
            result = PowerModels._run_mc_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 47267.9; atol = 1e-1)

            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c], 1.58067; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], 0.12669; atol = 1e-3)
            end
        end

        @testset "3-bus 3-conductor unbalanced case" begin
            # TESTS for add_setpoint! bug on multiconductor systems
            mp_data = build_mc_data!("../test/data/matpower/case3.m", conductors=3)
            for load in values(mp_data["load"])
                load["pd"][2] /= 2
                load["pd"][3] /= 3
            end
            result = PowerModels._run_mc_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 17826.8; atol = 1e-1)

            for (c, pg, va) in zip(1:mp_data["conductors"], [1.70667, 0.53344, 0.21976], [0.02996, 0.18645, 0.19194])
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c], pg; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], va; atol = 1e-3)
            end
        end

        @testset "3-bus 3-conductor case with theta_ref=pi" begin
            mp_data = build_mc_data!("../test/data/matpower/case3.m", conductors=3)
            pm = PowerModels.build_model(mp_data, ACRPowerModel, PowerModels._post_mc_opf, multiconductor=true)
            result = PowerModels.optimize_model!(pm, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 47267.9; atol = 1e-1)

            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c], 1.58067; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], 0.12669; atol = 1e-3)
            end
        end

        @testset "5-bus 5-conductor case" begin
            mp_data = build_mc_data!("../test/data/matpower/case5.m", conductors=5)

            result = PowerModels._run_mc_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 91345.5; atol = 1e-1)
            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], -0.00103692; atol = 1e-5)
            end
        end

        @testset "30-bus 3-conductor case" begin
            mp_data = build_mc_data!("../test/data/matpower/case30.m", conductors=3)

            result = PowerModels._run_mc_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 614.905; atol = 1e-1)

            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c],  2.18839; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], -0.071759; atol = 1e-4)
            end
        end
    end


    @testset "test multi-conductor opf variants" begin
        mp_data = build_mc_data!("../test/data/matpower/case5_dc.m")

        @testset "ac 5-bus case" begin
            result = PowerModels._run_mc_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 54468.5; atol = 1e-1)
            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], -0.0139117; atol = 1e-4)
            end
        end

        @testset "dc 5-bus case" begin
            result = PowerModels._run_mc_opf(mp_data, DCPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 54272.7; atol = 1e-1)
            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][c], -0.0135206; atol = 1e-4)
            end
        end

        @testset "soc 5-bus case" begin
            result = PowerModels._run_mc_opf(mp_data, SOCWRPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 46314.1; atol = 1e-1)
            for c in 1:mp_data["conductors"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][c],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["vm"][c],  1.08578; atol = 1e-3)
            end
        end

    end


    @testset "test multi-conductor uc opf variants" begin
        mp_data = build_mc_data!("../test/data/matpower/case5_uc.m")

        @testset "ac 5-bus case" begin
            result = PowerModels._run_uc_mc_opf(mp_data, ACPPowerModel, juniper_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 54810.0; atol = 1e-1)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0, atol=1e-6)
        end

        @testset "dc 5-bus case" begin
            result = PowerModels._run_uc_mc_opf(mp_data, DCPPowerModel, cbc_solver)

            @test result["termination_status"] == OPTIMAL
            @test isapprox(result["objective"], 52839.6; atol = 1e-1)
            @test isapprox(result["solution"]["gen"]["4"]["gen_status"], 0.0)
        end

    end


    @testset "dual variable case" begin

        @testset "test dc polar opf" begin
            mp_data = build_mc_data!("../test/data/matpower/case5.m")

            result = PowerModels._run_mc_opf(mp_data, DCPPowerModel, ipopt_solver, setting = Dict("output" => Dict("duals" => true)))

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 52839.6; atol = 1e0)


            for (i, bus) in result["solution"]["bus"]
                @test haskey(bus, "lam_kcl_r")
                @test haskey(bus, "lam_kcl_i")

                for c in 1:mp_data["conductors"]
                    @test bus["lam_kcl_r"][c] >= -4000 && bus["lam_kcl_r"][c] <= 0
                    @test isnan(bus["lam_kcl_i"][c])
                end
            end
            for (i, branch) in result["solution"]["branch"]
                @test haskey(branch, "mu_sm_fr")
                @test haskey(branch, "mu_sm_to")

                for c in 1:mp_data["conductors"]
                    @test branch["mu_sm_fr"][c] >= -1 && branch["mu_sm_fr"][c] <= 6000
                    @test isapprox(branch["mu_sm_to"][c], 0.0; atol = 1e-2)
                end
            end

        end
    end


    @testset "test solution feedback" begin
        mp_data = build_mc_data!("../test/data/matpower/case5_asym.m")

        result = PowerModels._run_mc_opf(mp_data, ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 52655.7; atol = 1e0)

        PowerModels.update_data!(mp_data, result["solution"])

        @test !InfrastructureModels.compare_dict(mp_data, build_mc_data!("../test/data/matpower/case5_asym.m"))
    end


    @testset "test errors and warnings" begin
        mp_data_2p = PowerModels.parse_file("../test/data/matpower/case3.m")
        mp_data_3p = PowerModels.parse_file("../test/data/matpower/case3.m")

        PowerModels.make_multiconductor!(mp_data_2p, 2)
        PowerModels.make_multiconductor!(mp_data_3p, 3)

        @test_throws(TESTLOG, ErrorException, PowerModels.update_data!(mp_data_2p, mp_data_3p))
        @test_throws(TESTLOG, ErrorException, PowerModels._check_keys(mp_data_3p, ["load"]))

        # check_cost_functions
        mp_data_3p["gen"]["1"]["model"] = 1
        mp_data_3p["gen"]["1"]["ncost"] = 1
        mp_data_3p["gen"]["1"]["cost"] = [0.0, 1.0, 0.0]
        @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(mp_data_3p))

        mp_data_3p["gen"]["1"]["cost"] = [0.0, 0.0]
        @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(mp_data_3p))

        mp_data_3p["gen"]["1"]["ncost"] = 2
        mp_data_3p["gen"]["1"]["cost"] = [0.0, 1.0, 0.0, 2.0]
        @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(mp_data_3p))

        mp_data_3p["gen"]["1"]["model"] = 2
        @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(mp_data_3p))

        Memento.setlevel!(TESTLOG, "info")

        mp_data_3p["gen"]["1"]["model"] = 3
        @test_warn(TESTLOG, "Skipping cost model of type 3 in per unit transformation", PowerModels.make_mixed_units!(mp_data_3p))
        @test_warn(TESTLOG, "Skipping cost model of type 3 in per unit transformation", PowerModels.make_per_unit!(mp_data_3p))
        @test_warn(TESTLOG, "Unknown cost model of type 3 on generator 1", PowerModels.correct_cost_functions!(mp_data_3p))

        mp_data_3p["gen"]["1"]["model"] = 1
        mp_data_3p["gen"]["1"]["cost"][3] = 3000
        @test_warn(TESTLOG, "pwl x value 3000.0 is outside the bounds 0.0-60.0 on generator 1", PowerModels.correct_cost_functions!(mp_data_3p))

        @test_nowarn PowerModels.correct_voltage_angle_differences!(mp_data_3p)

        mp_data_2p["branch"]["1"]["angmin"] = [-pi, 0]
        mp_data_2p["branch"]["1"]["angmax"] = [ pi, 0]

        @test_warn(TESTLOG, "this code only supports angmin values in -90 deg. to 90 deg., tightening the value on branch 1, conductor 1 from -180.0 to -60.0 deg.",
            PowerModels.correct_voltage_angle_differences!(mp_data_2p))

        mp_data_2p["branch"]["1"]["angmin"] = [-pi, 0]
        mp_data_2p["branch"]["1"]["angmax"] = [ pi, 0]

        @test_warn(TESTLOG, "angmin and angmax values are 0, widening these values on branch 1, conductor 2 to +/- 60.0 deg.",
            PowerModels.correct_voltage_angle_differences!(mp_data_2p))

        mp_data_2p["branch"]["1"]["angmin"] = [-pi, 0]
        mp_data_2p["branch"]["1"]["angmax"] = [ pi, 0]

        @test_warn(TESTLOG, "this code only supports angmax values in -90 deg. to 90 deg., tightening the value on branch 1, conductor 1 from 180.0 to 60.0 deg.",
            PowerModels.correct_voltage_angle_differences!(mp_data_2p))

        @test_warn(TESTLOG, "skipping network that is already multiconductor", PowerModels.make_multiconductor!(mp_data_3p, 3))

        mp_data_3p["load"]["1"]["pd"] = mp_data_3p["load"]["1"]["qd"] = [0, 0, 0]
        mp_data_3p["shunt"]["1"] = Dict("gs"=>[0,0,0], "bs"=>[0,0,0], "status"=>1, "shunt_bus"=>1, "index"=>1)

        Memento.TestUtils.@test_log(TESTLOG, "info", "deactivating load 1 due to zero pd and qd", PowerModels.propagate_topology_status!(mp_data_3p))
        @test mp_data_3p["load"]["1"]["status"] == 0
        @test mp_data_3p["shunt"]["1"]["status"] == 0

        mp_data_3p["dcline"]["1"]["loss0"][2] = -1.0
        @test_warn(TESTLOG, "this code only supports positive loss0 values, changing the value on dcline 1, conductor 2 from -100.0 to 0.0", PowerModels.correct_dcline_limits!(mp_data_3p))

        mp_data_3p["dcline"]["1"]["loss1"][2] = -1.0
        @test_warn(TESTLOG, "this code only supports positive loss1 values, changing the value on dcline 1, conductor 2 from -1.0 to 0.0", PowerModels.correct_dcline_limits!(mp_data_3p))

        @test mp_data_3p["dcline"]["1"]["loss0"][2] == 0.0
        @test mp_data_3p["dcline"]["1"]["loss1"][2] == 0.0

        mp_data_3p["dcline"]["1"]["loss1"][2] = 100.0
        @test_warn(TESTLOG, "this code only supports loss1 values < 1, changing the value on dcline 1, conductor 2 from 100.0 to 0.0", PowerModels.correct_dcline_limits!(mp_data_3p))

        delete!(mp_data_3p["branch"]["1"], "tap")
        @test_warn(TESTLOG, "branch found without tap value, setting a tap to 1.0", PowerModels.correct_transformer_parameters!(mp_data_3p))

        delete!(mp_data_3p["branch"]["1"], "shift")
        @test_warn(TESTLOG, "branch found without shift value, setting a shift to 0.0", PowerModels.correct_transformer_parameters!(mp_data_3p))

        mp_data_3p["branch"]["1"]["tap"][2] = -1.0
        @test_warn(TESTLOG, "branch found with non-positive tap value of -1.0, setting a tap to 1.0", PowerModels.correct_transformer_parameters!(mp_data_3p))

        mp_data_3p["branch"]["1"]["rate_a"][2] = -1.0
        @test_warn(TESTLOG, "this code only supports positive rate_a values, changing the value on branch 1, conductor 2 to 100.47", PowerModels.correct_thermal_limits!(mp_data_3p))
        @test isapprox(mp_data_3p["branch"]["1"]["rate_a"][2], 1.0047227335; atol=1e-6)

        mp_data_3p["branch"]["4"] = deepcopy(mp_data_3p["branch"]["1"])
        mp_data_3p["branch"]["4"]["f_bus"] = mp_data_3p["branch"]["1"]["t_bus"]
        mp_data_3p["branch"]["4"]["t_bus"] = mp_data_3p["branch"]["1"]["f_bus"]
        @test_warn(TESTLOG, "reversing the orientation of branch 1 (1, 3) to be consistent with other parallel branches", PowerModels.correct_branch_directions!(mp_data_3p))
        @test mp_data_3p["branch"]["4"]["f_bus"] == mp_data_3p["branch"]["1"]["f_bus"]
        @test mp_data_3p["branch"]["4"]["t_bus"] == mp_data_3p["branch"]["1"]["t_bus"]

        mp_data_3p["gen"]["1"]["vg"][2] = 2.0
        @test_warn(TESTLOG, "the conductor 2 voltage setpoint on generator 1 does not match the value at bus 1", PowerModels.check_voltage_setpoints(mp_data_3p))

        mp_data_3p["dcline"]["1"]["vf"][2] = 2.0
        @test_warn(TESTLOG, "the conductor 2 from bus voltage setpoint on dc line 1 does not match the value at bus 1", PowerModels.check_voltage_setpoints(mp_data_3p))

        mp_data_3p["dcline"]["1"]["vt"][2] = 2.0
        @test_warn(TESTLOG, "the conductor 2 to bus voltage setpoint on dc line 1 does not match the value at bus 2", PowerModels.check_voltage_setpoints(mp_data_3p))


        Memento.setlevel!(TESTLOG, "error")

        @test_throws(TESTLOG, ErrorException, PowerModels.run_ac_opf(mp_data_3p, ipopt_solver))

        mp_data_3p["branch"]["1"]["f_bus"] = mp_data_3p["branch"]["1"]["t_bus"] = 1
        @test_throws(TESTLOG, ErrorException, PowerModels.check_branch_loops(mp_data_3p))

        mp_data_3p["conductors"] = 0
        @test_throws(TESTLOG, ErrorException, PowerModels.check_conductors(mp_data_3p))
    end

    @testset "multiconductor extensions" begin
        mp_data = build_mc_data!("../test/data/matpower/case3.m")
        pm = build_model(mp_data, PowerModels.ACPPowerModel, post_tp_opf; multiconductor=true)

        @test haskey(var(pm, pm.cnw), :cnd)
        @test length(var(pm, pm.cnw)) == 1

        @test length(var(pm, pm.cnw, :cnd)) == 3
        @test length(var(pm, pm.cnw, :cnd, 1)) == 8
        @test length(var(pm)) == 8
        @test haskey(var(pm, pm.cnw, :cnd, 1), :vm)
        @test var(pm, :vm, 1) == var(pm, pm.cnw, pm.ccnd, :vm, 1)

        @test haskey(PowerModels.con(pm, pm.cnw), :cnd)
        @test length(PowerModels.con(pm, pm.cnw)) == 1
        @test length(PowerModels.con(pm, pm.cnw, :cnd)) == 3
        @test length(PowerModels.con(pm, pm.cnw, :cnd, 1)) == 4
        @test PowerModels.con(pm, pm.cnw, pm.ccnd, :kcl_p, 1) == PowerModels.con(pm, :kcl_p, 1)
        @test length(PowerModels.con(pm)) == 4

        @test PowerModels.ref(pm, pm.cnw, :bus, 1, "bus_i") == 1
        @test PowerModels.ref(pm, :bus, 1, "vmax") == 1.1

        @test PowerModels.ismulticonductor(pm)
        @test PowerModels.ismulticonductor(pm, pm.cnw)

        @test length(PowerModels.nw_ids(pm)) == 1
    end

    @testset "multiconductor operations" begin
        mp_data = build_mc_data!("../test/data/matpower/case3.m")

        a, b, c, d = mp_data["branch"]["1"]["br_r"], mp_data["branch"]["1"]["br_x"], mp_data["branch"]["1"]["b_fr"], mp_data["branch"]["1"]["b_to"]
        e = PowerModels.MultiConductorVector([0.225, 0.225, 0.225, 0.225])
        angs_rad = mp_data["branch"]["1"]["angmin"]

        # Transpose
        @test all(a' .== a)
        @test all(c' .== [0.225, 0.225, 0.225]')

        # Basic Math (Matrices)
        x = a + b
        y = a - b
        z = a * b
        w = a / b

        @test all(x.values - [0.685 0.0 0.0; 0.0 0.685 0.0; 0.0 0.0 0.685] .<= 1e-12)
        @test all(y.values - [-0.555 0.0 0.0; 0.0 -0.555 0.0; 0.0 0.0 -0.555] .<= 1e-12)
        @test all(z.values - [0.0403 0.0 0.0; 0.0 0.0403 0.0; 0.0 0.0 0.0403] .<= 1e-12)
        @test all(w.values - [0.104839 0.0 0.0; 0.0 0.104839 0.0; 0.0 0.0 0.104839] .<= 1e-12)

        @test isa(x, PowerModels.MultiConductorMatrix)
        @test isa(y, PowerModels.MultiConductorMatrix)
        @test isa(z, PowerModels.MultiConductorMatrix)
        @test isa(w, PowerModels.MultiConductorMatrix)

        # Basic Math Vectors
        x = c + d
        y = c - d
        z = c^2
        w = 1 ./ c
        u = 1 .* d

        @test all(x.values - [0.45, 0.45, 0.45] .<= 1e-12)
        @test all(y.values - [0.0, 0.0, 0.0] .<= 1e-12)
        @test all(c .* d - [0.050625, 0.050625, 0.050625] .<= 1e-12)
        @test all(c ./ d - [1.0, 1.0, 1.0] .<= 1e-12)
        @test all(z.values - [0.050625, 0.050625, 0.050625] .<= 1e-12)
        @test all(w.values - [4.444444444444445, 4.444444444444445, 4.444444444444445] .<= 1e-12)
        @test all(u.values - d.values .<= 1e-12)

        @test isa(x, PowerModels.MultiConductorVector)
        @test isa(y, PowerModels.MultiConductorVector)
        @test isa(z, PowerModels.MultiConductorVector)
        @test isa(w, PowerModels.MultiConductorVector)
        @test isa(u, PowerModels.MultiConductorVector)

        # Broadcasting
        @test all(a .+ c - [0.29   0.225  0.225; 0.225  0.29   0.225; 0.225  0.225  0.29] .<= 1e-12)
        @test all(c .+ b - [0.845  0.225  0.225; 0.225  0.845  0.225; 0.225  0.225  0.845] .<= 1e-12)
        @test all(a.values .+ c - [0.29   0.225  0.225; 0.225  0.29   0.225; 0.225  0.225  0.29] .<= 1e-12)
        @test all(c .+ b.values - [0.845  0.225  0.225; 0.225  0.845  0.225; 0.225  0.225  0.845] .<= 1e-12)

        # Custom Functions
        @test PowerModels.conductors(c) == 3
        @test PowerModels.conductors(a) == 3
        @test all(size(a) == (3,3))
        @test isa(JSON.lower(a), Dict)
        @test all(JSON.lower(a)["values"] == a.values)
        @test !isapprox(d, e)
        @test PowerModels.conductor_value(a, 1, 1) == a[1,1]

        # diagm
        @test all(LinearAlgebra.diagm(0 => c).values .== [0.225 0.0 0.0; 0.0 0.225 0.0; 0.0 0.0 0.225])

        # rad2deg/deg2rad
        angs_deg = rad2deg(angs_rad)
        angs_deg_rad = deg2rad(angs_deg)
        @test all(angs_deg.values - [-30.0, -30.0, -30.0] .<= 1e-12)
        @test all(angs_deg_rad.values - angs_rad.values .<= 1e-12)

        @test isa(angs_deg, PowerModels.MultiConductorVector)
        @test isa(deg2rad(angs_deg), PowerModels.MultiConductorVector)

        a_rad = rad2deg(a)
        @test all(a_rad.values - [3.72423 0.0 0.0; 0.0 3.72423 0.0; 0.0 0.0 3.72423] .<= 1e-12)
        @test isa(rad2deg(a), PowerModels.MultiConductorMatrix)
        @test isa(deg2rad(a), PowerModels.MultiConductorMatrix)

        Memento.setlevel!(TESTLOG, "warn")
        @test_nowarn show(devnull, a)

        @test_nowarn a[1, 1] = 9.0
        @test a[1,1] == 9.0

        @test_nowarn PowerModels.summary(devnull, mp_data)

        Memento.setlevel!(TESTLOG, "error")

        # Test broadcasting edge-case
        v = ones(Real, 3)
        mcv = PowerModels.MultiConductorVector(v)
        @test all(floor.(mcv) .+ mcv .== PowerModels.MultiConductorVector(floor.(v) .+ v))

        m = LinearAlgebra.diagm(0 => v)
        mcm = PowerModels.MultiConductorMatrix(m)
        @test all(floor.(mcm) .+ mcm .== PowerModels.MultiConductorMatrix(floor.(m) .+ m))
    end
end
