export run_opf, run_ac_opf, run_dc_opf

""
function run_ac_opf(file, solver; kwargs...)
    return run_opf(file, ACPPowerModel, solver; kwargs...)
end

""
function run_dc_opf(file, solver; kwargs...)
    return run_opf(file, DCPPowerModel, solver; kwargs...)
end

""
function run_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_opf; kwargs...)
end

""
function post_opf(pm::GenericPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_line_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_cost(pm)

    constraint_voltage(pm)

    for (i,bus) in pm.ref[:ref_buses]
        constraint_theta_ref(pm, bus)
    end

    for (i,bus) in pm.ref[:bus]
        constraint_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.ref[:branch]
        constraint_ohms_yt_from(pm, branch)
        constraint_ohms_yt_to(pm, branch)

        constraint_voltage_angle_difference(pm, branch)

        constraint_thermal_limit_from(pm, branch)
        constraint_thermal_limit_to(pm, branch)
    end
    for (i,dcline) in pm.ref[:dcline]
        constraint_dcline(pm, dcline)
    end
end
