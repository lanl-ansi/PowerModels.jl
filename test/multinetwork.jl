#
# NOTE: This is not a formulation of any particular problem
# It is only for testing and illustration purposes
#

using JuMP
PMs = PowerModels

function post_mpopf_test(pm::GenericPowerModel)
    for (n, network) in pm.ref[:nw]
        PMs.variable_voltage(pm, n)
        PMs.variable_generation(pm, n)
        PMs.variable_line_flow(pm, n)
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
    @constraint(pm.model, t1_pg[1] == t2_pg[4])

    PMs.objective_min_fuel_cost(pm)
end


@testset "2 period 5-bus asymmetric case" begin
    mp_data = PowerModels.parse_file("../test/data/case5_asym.m")

    mn_data = Dict{String,Any}(
        "name" => "an awesome multinetwork",
        "multinetwork" => true,
        "per_unit" => mp_data["per_unit"],
        "baseMVA" => mp_data["baseMVA"]
    )
    delete!(mp_data, "multinetwork")
    delete!(mp_data, "per_unit")
    delete!(mp_data, "baseMVA")

    mn_data["nw"] = Dict{String,Any}()
    mn_data["nw"]["1"] = mp_data
    mn_data["nw"]["2"] = mp_data

    @testset "test ac polar opf" begin
        result = run_generic_model(mn_data, ACPPowerModel, ipopt_solver, post_mpopf_test)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 35117.1; atol = 1e0)
        @test isapprox(
            result["solution"]["nw"]["1"]["gen"]["1"]["pg"],
            result["solution"]["nw"]["2"]["gen"]["4"]["pg"]; 
            atol = 1e-3
        )
    end
end