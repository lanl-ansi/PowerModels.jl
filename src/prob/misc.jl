export
    run_api_opf, run_sad_opf

""
function run_api_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_api_opf; kwargs...)
end

""
function post_api_opf(pm::GenericPowerModel)
    variable_voltage(pm)
    bounds_tighten_voltage(pm)

    variable_generation(pm, bounded = false)
    upperbound_negative_active_generation(pm)

    variable_line_flow(pm)
    variable_dcline_flow(pm)


    variable_load_factor(pm)


    objective_max_loading(pm)
    #objective_max_loading_voltage_norm(pm)
    #objective_max_loading_gen_output(pm)

    constraint_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for (i,gen) in ref(pm, :gen)
        pg = var(pm,:pg,i)
        @constraint(pm.model, pg >= gen["pmin"])
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt_scaled(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i; scale = 0.999)
        constraint_thermal_limit_to(pm, i; scale = 0.999)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end

""
function get_solution(pm::APIACPPowerModel, sol::Dict{String,Any})
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_bus_demand_setpoint(sol, pm)
end

""
function add_bus_demand_setpoint(sol, pm::APIACPPowerModel)
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "bus", "pd", :load_factor; default_value = (item) -> item["pd"], scale = (x,item) -> item["pd"] > 0 && item["qd"] > 0 ? x*item["pd"] : item["pd"], extract_var = (var,idx,item) -> var)
    add_setpoint(sol, pm, "bus", "qd", :load_factor; default_value = (item) -> item["qd"], scale = (x,item) -> item["qd"], extract_var = (var,idx,item) -> var)
end


""
function run_sad_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_sad_opf; kwargs...)
end

""
function post_sad_opf{T <: AbstractPForms}(pm::GenericPowerModel{T})
    variable_voltage(pm)
    variable_generation(pm)
    variable_line_flow(pm)
    variable_dcline_flow(pm, bounded = false)

    @variable(pm.model, theta_delta_bound >= 0.0, start = 0.523598776)

    @objective(pm.model, Min, theta_delta_bound)

    constraint_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt(pm, i)
    end

    for (i,branch) in ref(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)
        theta_fr = var(pm, :va, branch["f_bus"])
        theta_to = var(pm, :va, branch["t_bus"])

        @constraint(pm.model, theta_fr - theta_to <=  theta_delta_bound)
        @constraint(pm.model, theta_fr - theta_to >= -theta_delta_bound)

        constraint_thermal_limit_from(pm, i; scale = 0.999)
        constraint_thermal_limit_to(pm, i; scale = 0.999)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end
