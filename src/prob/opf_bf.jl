export run_opf_bf, run_ac_opf_bf, run_dc_opf_bf

""
function run_opf_bf(file, model_constructor::Type{GenericPowerModel{T}}, solver; kwargs...) where T <: AbstractBFForm
    return run_generic_model(file, model_constructor, solver, post_opf_bf; kwargs...)
end

""
function run_opf_bf(file, model_constructor, solver; kwargs...)
    error(LOGGER, "The problem type opf_bf at the moment only supports subtypes of AbstractBFForm")
end

""
function post_opf_bf(pm::GenericPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_branch_current(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_cost(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_flow_losses(pm, i)
        constraint_voltage_magnitude_difference(pm, i)
        constraint_branch_current(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end
