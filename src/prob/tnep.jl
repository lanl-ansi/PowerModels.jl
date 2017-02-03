#### General Assumptions of these TNEP Models ####
#
#

export run_tnep

function run_tnep(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_tnep; solution_builder = get_tnep_solution, kwargs...) 
end

# the general form of the tnep optimization model
function post_tnep{T}(pm::GenericPowerModel{T})
    variable_line_ne(pm) 
    variable_voltage(pm)
    variable_voltage_ne(pm)
    variable_generation(pm)
    variable_line_flow(pm)
    variable_line_flow_ne(pm)

    objective_tnep_cost(pm)
       
    constraint_theta_ref(pm)
    constraint_voltage(pm)
    constraint_voltage_ne(pm)

    for (i,bus) in pm.ref[:bus]
        constraint_kcl_shunt_ne(pm, bus)
    end

    for (i,branch) in pm.ref[:branch]
        constraint_ohms_yt_from(pm, branch)
        constraint_ohms_yt_to(pm, branch)

        constraint_phase_angle_difference(pm, branch)

        constraint_thermal_limit_from(pm, branch)
        constraint_thermal_limit_to(pm, branch)
    end 

    for (i,branch) in pm.ref[:ne_branch]
        constraint_ohms_yt_from_ne(pm, branch)
        constraint_ohms_yt_to_ne(pm, branch) 

        constraint_phase_angle_difference_ne(pm, branch)

        constraint_thermal_limit_from_ne(pm, branch)
        constraint_thermal_limit_to_ne(pm, branch)
    end
end

function get_tnep_solution{T}(pm::GenericPowerModel{T})
    sol = init_solution(pm)
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_flow_setpoint_ne(sol, pm)    
    add_branch_ne_setpoint(sol, pm)
    return sol
end

