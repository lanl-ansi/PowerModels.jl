#### General Assumptions of these OTS Models ####
#
# - if the branch status is 0 in the input, it is out of service and forced to 0 in OTS
# - the network will be maintained as one connected component (i.e. at least n-1 edges)
#

""
function run_ots(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, build_ots; ref_extensions=[ref_add_on_off_va_bounds!], kwargs...)
end

""
function build_ots(pm::AbstractPowerModel)
    variable_branch_indicator(pm)
    variable_bus_voltage_on_off(pm)
    variable_gen_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_dcline_power_losses(pm, i)
    end
end


""
function ref_add_on_off_va_bounds!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    apply_pm!(_ref_add_on_off_va_bounds!, ref, data)
end


""
function _ref_add_on_off_va_bounds!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    off_angmin, off_angmax = calc_theta_delta_bounds(data)
    ref[:off_angmin], ref[:off_angmax] = off_angmin, off_angmax
end
