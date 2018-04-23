#
# NOTE: This is not a formulation of any particular problem
# It is only for testing and illustration purposes
#

using JuMP
PMs = PowerModels

@testset "test multinetwork" begin

    function build_mn_data(base_data)
        mp_data = PowerModels.parse_file(base_data)
        return InfrastructureModels.replicate(mp_data, 2)
    end

    function build_mn_data(base_data_1, base_data_2)
        mp_data_1 = PowerModels.parse_file(base_data_1)
        mp_data_2 = PowerModels.parse_file(base_data_2)
        
        @assert mp_data_1["per_unit"] == mp_data_2["per_unit"]
        @assert mp_data_1["baseMVA"] == mp_data_2["baseMVA"]

        mn_data = Dict{String,Any}(
            "name" => "$(mp_data_1["name"]) + $(mp_data_2["name"])",
            "multinetwork" => true,
            "per_unit" => mp_data_1["per_unit"],
            "baseMVA" => mp_data_1["baseMVA"],
            "nw" => Dict{String,Any}()
        )

        delete!(mp_data_1, "multinetwork")
        delete!(mp_data_1, "per_unit")
        delete!(mp_data_1, "baseMVA")
        mn_data["nw"]["1"] = mp_data_1

        delete!(mp_data_2, "multinetwork")
        delete!(mp_data_2, "per_unit")
        delete!(mp_data_2, "baseMVA")
        mn_data["nw"]["2"] = mp_data_2

        return mn_data
    end

    @testset "idempotent unit transformation" begin
        @testset "5-bus replicate case" begin
            mn_data = build_mn_data("../test/data/matpower/case5_dc.m")
            PowerModels.make_mixed_units(mn_data)
            PowerModels.make_per_unit(mn_data)

            @test InfrastructureModels.compare_dict(mn_data, build_mn_data("../test/data/matpower/case5_dc.m"))
        end
        @testset "14+24 hybrid case" begin
            mn_data = build_mn_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m")
            PowerModels.make_mixed_units(mn_data)
            PowerModels.make_per_unit(mn_data)

            @test InfrastructureModels.compare_dict(mn_data, build_mn_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m"))
        end
    end


    @testset "topology processing" begin
        @testset "7-bus replicate status case" begin
            mn_data = build_mn_data("../test/data/matpower/case7_tplgy.m")
            PowerModels.propagate_topology_status(mn_data)

            active_buses = Set(["2", "4", "5", "7"])
            active_branches = Set(["8"])
            active_dclines = Set(["3"])

            for (i,nw_data) in mn_data["nw"]
                for (i,bus) in nw_data["bus"]
                    if i in active_buses
                        @test bus["bus_type"] != 4
                    else
                        @test bus["bus_type"] == 4
                    end
                end

                for (i,branch) in nw_data["branch"]
                    if i in active_branches
                        @test branch["br_status"] == 1
                    else
                        @test branch["br_status"] == 0
                    end
                end

                for (i,dcline) in nw_data["dcline"]
                    if i in active_dclines
                        @test dcline["br_status"] == 1
                    else
                        @test dcline["br_status"] == 0
                    end
                end
            end
        end
        @testset "7-bus replicate filer case" begin
            mn_data = build_mn_data("../test/data/matpower/case7_tplgy.m")
            PowerModels.propagate_topology_status(mn_data)
            PowerModels.select_largest_component(mn_data)

            active_buses = Set(["4", "5", "7"])
            active_branches = Set(["8"])
            active_dclines = Set(["3"])

            for (i,nw_data) in mn_data["nw"]
                for (i,bus) in nw_data["bus"]
                    if i in active_buses
                        @test bus["bus_type"] != 4
                    else
                        @test bus["bus_type"] == 4
                    end
                end

                for (i,branch) in nw_data["branch"]
                    if i in active_branches
                        @test branch["br_status"] == 1
                    else
                        @test branch["br_status"] == 0
                    end
                end

                for (i,dcline) in nw_data["dcline"]
                    if i in active_dclines
                        @test dcline["br_status"] == 1
                    else
                        @test dcline["br_status"] == 0
                    end
                end
            end
        end
        @testset "7+14 hybrid filer case" begin
            mn_data = build_mn_data("../test/data/matpower/case7_tplgy.m", "../test/data/matpower/case14.m")
            PowerModels.propagate_topology_status(mn_data)
            PowerModels.select_largest_component(mn_data)

            case7_data = mn_data["nw"]["1"]
            case14_data = mn_data["nw"]["2"]

            case7_active_buses = filter((i, bus) -> bus["bus_type"] != 4, case7_data["bus"])
            case14_active_buses = filter((i, bus) -> bus["bus_type"] != 4, case14_data["bus"])

            @test length(case7_active_buses) == 3
            @test length(case14_active_buses) == 14
        end
    end


    function post_mpopf_test(pm::GenericPowerModel)
        for (n, network) in pm.ref[:nw]
            PMs.variable_voltage(pm, n)
            PMs.variable_generation(pm, n)
            PMs.variable_branch_flow(pm, n)
            PMs.variable_dcline_flow(pm, n)

            PMs.constraint_voltage(pm, n)

            for i in ids(pm, n, :ref_buses)
                PMs.constraint_theta_ref(pm, n, i)
            end

            for i in ids(pm, n, :bus)
                PMs.constraint_kcl_shunt(pm, n, i)
            end

            for i in ids(pm, n, :branch)
                PMs.constraint_ohms_yt_from(pm, n, i)
                PMs.constraint_ohms_yt_to(pm, n, i)

                PMs.constraint_voltage_angle_difference(pm, n, i)

                PMs.constraint_thermal_limit_from(pm, n, i)
                PMs.constraint_thermal_limit_to(pm, n, i)
            end

            for i in ids(pm, n, :dcline)
                PMs.constraint_dcline(pm, n, i)
            end
        end

        # cross network constraint, just for illustration purposes
        # designed to be feasible with two copies of case5_asym.m 
        t1_pg = var(pm, 1, :pg)
        t2_pg = var(pm, 2, :pg)
        @constraint(pm.model, t1_pg[2] == t2_pg[4])

        PMs.objective_min_fuel_cost(pm)
    end

    @testset "2 period 5-bus asymmetric case" begin
        mn_data = build_mn_data("../test/data/matpower/case5_asym.m")

        @testset "test ac polar opf" begin
            result = run_generic_model(mn_data, ACPPowerModel, ipopt_solver, post_mpopf_test, multinetwork=true)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 35184.2; atol = 1e0)
            @test isapprox(
                result["solution"]["nw"]["1"]["gen"]["2"]["pg"],
                result["solution"]["nw"]["2"]["gen"]["4"]["pg"]; 
                atol = 1e-3
            )
        end
    end

    @testset "2 period 5-bus dual variable case" begin
        mn_data = build_mn_data("../test/data/matpower/case5.m")

        @testset "test dc polar opf" begin
            result = run_generic_model(mn_data, DCPPowerModel, ipopt_solver, post_mpopf_test, multinetwork=true, setting = Dict("output" => Dict("duals" => true)))

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 35446; atol = 1e0)

            for (i,nw_data) in result["solution"]["nw"]
                for (i, bus) in nw_data["bus"]
                    @test haskey(bus, "lam_kcl_r")
                    @test bus["lam_kcl_r"] >= -4000 && bus["lam_kcl_r"] <= 0
                    @test haskey(bus, "lam_kcl_i")
                    @test isnan(bus["lam_kcl_i"])
                end
                for (i, branch) in nw_data["branch"]
                    @test haskey(branch, "mu_sm_fr")
                    @test branch["mu_sm_fr"] >= -1 && branch["mu_sm_fr"] <= 6000
                    @test haskey(branch, "mu_sm_to")
                    @test isnan(branch["mu_sm_to"])
                end
            end
        end
    end

    @testset "hybrid network case - polar" begin
        mn_data = build_mn_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m")

        @testset "test ac polar opf" begin
            result = run_generic_model(mn_data, ACPPowerModel, ipopt_solver, post_mpopf_test, multinetwork=true)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 88289.0; atol = 1e0)
            @test isapprox(
                result["solution"]["nw"]["1"]["gen"]["2"]["pg"],
                result["solution"]["nw"]["2"]["gen"]["4"]["pg"]; 
                atol = 1e-3
            )
        end
    end

    @testset "hybrid network case - rect" begin
        mn_data = build_mn_data("../test/data/matpower/case14.m", "../test/data/matpower/case24.m")

        @testset "test ac polar opf" begin
            result = run_generic_model(mn_data, ACRPowerModel, ipopt_solver, post_mpopf_test, multinetwork=true)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 88289.0; atol = 1e0)
            @test isapprox(
                result["solution"]["nw"]["1"]["gen"]["2"]["pg"],
                result["solution"]["nw"]["2"]["gen"]["4"]["pg"]; 
                atol = 1e-3
            )
        end
    end

    # currently classed as an error
    #=
    @testset "single-network model with multi-network data" begin
        # this works, but should throw a warning
        mn_data = build_mn_data("../test/data/matpower/case5_asym.m")
        result = run_ac_opf(mn_data, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    =#

    function post_mppf_test(pm::GenericPowerModel)
        for (n, network) in pm.ref[:nw]
            PMs.variable_voltage(pm, n, bounded = false)
            PMs.variable_generation(pm, n, bounded = false)
            PMs.variable_branch_flow(pm, n, bounded = false)
            PMs.variable_dcline_flow(pm, n, bounded = false)

            PMs.constraint_voltage(pm, n)

            for i in ids(pm, n, :ref_buses)
                PMs.constraint_theta_ref(pm, n, i)
                PMs.constraint_voltage_magnitude_setpoint(pm, n, i)
            end

            for (i,bus) in ref(pm, n, :bus)
                PMs.constraint_kcl_shunt(pm, n, i)

                # PV Bus Constraints
                if length(ref(pm, n, :bus_gens, i)) > 0 && !(i in ids(pm, n, :ref_buses))
                    @assert bus["bus_type"] == 2

                    PMs.constraint_voltage_magnitude_setpoint(pm, n, i)
                    for j in ref(pm, n, :bus_gens, i)
                        PMs.constraint_active_gen_setpoint(pm, n, j)
                    end
                end
            end

            for i in ids(pm, n, :branch)
                PMs.constraint_ohms_yt_from(pm, n, i)
                PMs.constraint_ohms_yt_to(pm, n, i)
            end

            for (i,dcline) in ref(pm, n, :dcline)
                PMs.constraint_active_dcline_setpoint(pm, n, i)

                f_bus = ref(pm, :bus)[dcline["f_bus"]]
                if f_bus["bus_type"] == 1
                    PMs.constraint_voltage_magnitude_setpoint(pm, n, f_bus["index"])
                end

                t_bus = ref(pm, :bus)[dcline["t_bus"]]
                if t_bus["bus_type"] == 1
                    PMs.constraint_voltage_magnitude_setpoint(pm, n, t_bus["index"])
                end
            end
        end
    end


    @testset "test solution feedback" begin
        mn_data = build_mn_data("../test/data/matpower/case5_asym.m")

        opf_result = run_generic_model(mn_data, ACPPowerModel, ipopt_solver, post_mpopf_test, multinetwork=true)
        @test opf_result["status"] == :LocalOptimal
        @test isapprox(opf_result["objective"], 35184.2; atol = 1e0)
        #@test isapprox(opf_result["objective"], 35533.8; atol = 1e0) # case5_dc (out of date)

        PowerModels.update_data(mn_data, opf_result["solution"])

        pf_result = run_generic_model(mn_data, ACPPowerModel, ipopt_solver, post_mppf_test, multinetwork=true)
        @test pf_result["status"] == :LocalOptimal
        @test isapprox(pf_result["objective"], 0.0; atol = 1e-3)

        for (n, nw_data) in mn_data["nw"]
            #println(n)
            for (i,bus) in nw_data["bus"]
                #println(opf_result["solution"]["nw"][n]["bus"][i]["va"])
                #println(pf_result["solution"]["nw"][n]["bus"][i]["va"])
                #println()

                @test isapprox(opf_result["solution"]["nw"][n]["bus"][i]["va"], pf_result["solution"]["nw"][n]["bus"][i]["va"]; atol = 1e-3)
                @test isapprox(opf_result["solution"]["nw"][n]["bus"][i]["vm"], pf_result["solution"]["nw"][n]["bus"][i]["vm"]; atol = 1e-3)
            end

            for (i,gen) in nw_data["gen"]
                @test isapprox(opf_result["solution"]["nw"][n]["gen"][i]["pg"], pf_result["solution"]["nw"][n]["gen"][i]["pg"]; atol = 1e-3)
                # cannot check this value solution does not appeat to be unique; verify this!
                #@test isapprox(opf_result["solution"]["gen"][i]["qg"], pf_result["solution"]["gen"][i]["qg"]; atol = 1e-3)
            end

            for (i,dcline) in nw_data["dcline"]
                @test isapprox(opf_result["solution"]["nw"][n]["dcline"][i]["pf"], pf_result["solution"]["nw"][n]["dcline"][i]["pf"]; atol = 1e-3)
                @test isapprox(opf_result["solution"]["nw"][n]["dcline"][i]["pt"], pf_result["solution"]["nw"][n]["dcline"][i]["pt"]; atol = 1e-3)
            end
        end

    end

end