#### General Assumptions of these OTS Models ####
#
# - if the branch status is 0 in the input, it is out of service and forced to 0 in OTS
# - the network will be maintained as one connected component (i.e. at least n-1 edges)
#

""
function run_ots(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, post_ots; ref_extensions=[ref_add_on_off_va_bounds!], solution_builder = solution_ots!, kwargs...)
end

""
function post_ots(pm::AbstractPowerModel)
    variable_branch_indicator(pm)
    variable_voltage_on_off(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage_on_off(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
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
function ref_add_on_off_va_bounds!(pm::AbstractPowerModel)
    if InfrastructureModels.ismultinetwork(pm.data)
        nws_data = pm.data["nw"]
    else
        nws_data = Dict("0" => pm.data)
    end

    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref(pm, nw_id)

        off_angmin, off_angmax = calc_theta_delta_bounds(nw_data)
        nw_ref[:off_angmin] = off_angmin
        nw_ref[:off_angmax] = off_angmax
    end
end

""
function solution_ots!(pm::AbstractPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_branch_status!(sol, pm)
end
