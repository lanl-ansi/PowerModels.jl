#### General Assumptions of these TNEP Models ####
#
#

export run_tnep

""
function run_tnep(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_tnep; solution_builder = get_tnep_solution, kwargs...)
end

"the general form of the tnep optimization model"
function post_tnep(pm::GenericPowerModel)
    variable_branch_ne(pm)
    variable_voltage(pm)
    variable_voltage_ne(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)
    variable_branch_flow_ne(pm)

    objective_tnep_cost(pm)

    constraint_voltage(pm)
    constraint_voltage_ne(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt_ne(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :ne_branch)
        constraint_ohms_yt_from_ne(pm, i)
        constraint_ohms_yt_to_ne(pm, i)

        constraint_voltage_angle_difference_ne(pm, i)

        constraint_thermal_limit_from_ne(pm, i)
        constraint_thermal_limit_to_ne(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end

""
function get_tnep_solution(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_flow_setpoint_ne(sol, pm)
    add_branch_ne_setpoint(sol, pm)
end
