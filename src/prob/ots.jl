#### General Assumptions of these OTS Models ####
#
# - if the branch status is 0 in the input, it is out of service and forced to 0 in OTS
# - the network will be maintained as one connected component (i.e. at least n-1 edges)
#

export run_ots

function run_ots(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_ots; solution_builder = get_ots_solution, kwargs...) 
end

function post_ots{T}(pm::GenericPowerModel{T})
    variable_line_indicator(pm)
    variable_voltage_on_off(pm)
    variable_generation(pm)
    variable_line_flow(pm)

    objective_min_fuel_cost(pm)

    constraint_theta_ref(pm)
    constraint_voltage_on_off(pm)

    for (i,bus) in pm.ref[:bus]
        constraint_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.ref[:branch]
        constraint_ohms_yt_from_on_off(pm, branch)
        constraint_ohms_yt_to_on_off(pm, branch)

        constraint_phase_angle_difference_on_off(pm, branch)

        constraint_thermal_limit_from_on_off(pm, branch)
        constraint_thermal_limit_to_on_off(pm, branch)
    end
end

function get_ots_solution{T}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_status_setpoint(sol, pm)
    return sol
end
