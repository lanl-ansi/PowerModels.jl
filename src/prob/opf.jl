export run_opf, run_ac_opf, run_dc_opf

function run_ac_opf(file, solver; kwargs...)
    return run_opf(file, ACPPowerModel, solver; kwargs...)
end

function run_dc_opf(file, solver; kwargs...)
    return run_opf(file, DCPPowerModel, solver; kwargs...)
end

function run_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_opf; kwargs...) 
end

function post_opf{T}(pm::GenericPowerModel{T})
    variable_complex_voltage(pm)

    variable_active_generation(pm)
    variable_reactive_generation(pm)

    variable_active_line_flow(pm)
    variable_reactive_line_flow(pm)


    objective_min_fuel_cost(pm)


    constraint_theta_ref(pm)
    constraint_complex_voltage(pm)

    for (i,bus) in pm.ref[:bus]
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.ref[:branch]
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_difference(pm, branch)

        constraint_thermal_limit_from(pm, branch)
        constraint_thermal_limit_to(pm, branch)
    end
end

