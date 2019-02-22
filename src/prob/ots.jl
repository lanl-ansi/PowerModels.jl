#### General Assumptions of these OTS Models ####
#
# - if the branch status is 0 in the input, it is out of service and forced to 0 in OTS
# - the network will be maintained as one connected component (i.e. at least n-1 edges)
#

export run_ots

""
function run_ots(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_ots; solution_builder = get_ots_solution, kwargs...)
end

""
function post_ots(pm::GenericPowerModel)
    variable_branch_indicator(pm)
    variable_voltage_on_off(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_cost(pm)

    constraint_voltage_on_off(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from_on_off(pm, i)
        constraint_ohms_yt_to_on_off(pm, i)

        constraint_voltage_angle_difference_on_off(pm, i)

        constraint_thermal_limit_from_on_off(pm, i)
        constraint_thermal_limit_to_on_off(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end

""
function get_ots_solution(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_status_setpoint(sol, pm)
end
