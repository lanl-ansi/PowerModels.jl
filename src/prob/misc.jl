export 
    run_api_opf, run_sad_opf


function run_api_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_api_opf; kwargs...) 
end

function post_api_opf{T}(pm::GenericPowerModel{T})
    variable_complex_voltage(pm)
    bounds_tighten_voltage(pm)

    variable_active_generation(pm, bounded = false)
    variable_reactive_generation(pm, bounded = false)
    upperbound_negative_active_generation(pm)

    variable_active_line_flow(pm)
    variable_reactive_line_flow(pm)

    variable_load_factor(pm)


    objective_max_loading(pm)


    constraint_theta_ref(pm)
    constraint_complex_voltage(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt_scaled(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_diffrence(pm, branch)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end
end




function run_sad_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_sad_opf; kwargs...) 
end

function post_sad_opf{T <: Union{AbstractACPForm, AbstractDCPForm}}(pm::GenericPowerModel{T})
    variable_complex_voltage(pm)

    variable_active_generation(pm)
    variable_reactive_generation(pm)

    variable_active_line_flow(pm)
    variable_reactive_line_flow(pm)

    @variable(pm.model, theta_delta_bound >= 0.0, start = 0.523598776)


    @objective(pm.model, Min, theta_delta_bound)


    constraint_theta_ref(pm)
    constraint_complex_voltage(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_y(pm, branch)
        constraint_reactive_ohms_y(pm, branch)

        #constraint_phase_angle_diffrence_flexible(pm, branch)
        theta_fr = getvariable(pm.model, :t)[branch["f_bus"]]
        theta_to = getvariable(pm.model, :t)[branch["t_bus"]]

        @constraint(pm.model, theta_fr - theta_to <=  theta_delta_bound)
        @constraint(pm.model, theta_fr - theta_to >= -theta_delta_bound)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end
end




