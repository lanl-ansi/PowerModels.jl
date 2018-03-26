export run_opf_bf, run_ac_opf_bf, run_dc_opf_bf

""
function run_ac_opf_bf(file, solver; kwargs...)
    return run_opf_bf(file, ACPPowerModel, solver; kwargs...)
end

""
function run_dc_opf_bf(file, solver; kwargs...)
    return run_opf_bf(file, DCPPowerModel, solver; kwargs...)
end

""
function run_opf_bf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_opf_bf; kwargs...)
end

""
function post_opf_bf(pm::GenericPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_cost(pm)

    constraint_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_power_flow_losses(pm, i)
        constraint_kvl(pm, i)
        constraint_series_current(pm, i)

        #constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end
