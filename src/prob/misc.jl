export
    run_api_opf, run_sad_opf

""
function run_api_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_api_opf; kwargs...)
end

""
function post_api_opf(pm::GenericPowerModel)
    variable_voltage(pm)
    for (i,bus) in nw_ref(pm, :bus)
        bounds_tighten_voltage(pm, bus)
    end

    variable_generation(pm, bounded = false)
    for (i,gen) in nw_ref(pm, :gen)
        upperbound_negative_active_generation(pm, gen)
    end

    variable_line_flow(pm)
    variable_dcline_flow(pm)


    variable_load_factor(pm)


    objective_max_loading(pm)

    constraint_voltage(pm)

    for (i,bus) in nw_ref(pm, :ref_buses)
        constraint_theta_ref(pm, bus)
    end

    for (i,gen) in nw_ref(pm, :gen)
        pg = nw_var(pm, :pg)[i]
        @constraint(pm.model, pg >= gen["pmin"])
    end

    for (i,bus) in nw_ref(pm, :bus)
        constraint_kcl_shunt_scaled(pm, bus)
    end

    for (i,branch) in nw_ref(pm, :branch)
        constraint_ohms_yt_from(pm, branch)
        constraint_ohms_yt_to(pm, branch)

        constraint_phase_angle_difference(pm, branch)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end

    for (i,dcline) in nw_ref(pm, :dcline)
        constraint_dcline(pm, dcline)
    end
end

""
function run_sad_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_sad_opf; kwargs...)
end

""
function post_sad_opf{T <: Union{AbstractACPForm, AbstractDCPForm}}(pm::GenericPowerModel{T})
    variable_voltage(pm)
    variable_generation(pm)
    variable_line_flow(pm)
    variable_dcline_flow(pm, bounded = false)

    @variable(pm.model, theta_delta_bound >= 0.0, start = 0.523598776)

    @objective(pm.model, Min, theta_delta_bound)

    constraint_voltage(pm)

    for (i,bus) in nw_ref(pm, :ref_buses)
        constraint_theta_ref(pm, bus)
    end

    for (i,bus) in nw_ref(pm, :bus)
        constraint_kcl_shunt(pm, bus)
    end

    for (i,branch) in nw_ref(pm, :branch)
        constraint_ohms_yt_from(pm, branch)
        constraint_ohms_yt_to(pm, branch)

        constraint_phase_angle_difference(pm, branch)
        theta_fr = nw_var(pm, :t)[branch["f_bus"]]
        theta_to = nw_var(pm, :t)[branch["t_bus"]]

        @constraint(pm.model, theta_fr - theta_to <=  theta_delta_bound)
        @constraint(pm.model, theta_fr - theta_to >= -theta_delta_bound)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end

    for (i,dcline) in nw_ref(pm, :dcline)
        constraint_dcline(pm, dcline)
    end
end
