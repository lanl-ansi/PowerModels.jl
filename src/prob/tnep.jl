#### General Assumptions of these TNEP Models ####
#
#

export run_tnep

function run_tnep(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_tnep; data_processor = process_raw_mp_ne_data, solution_builder = get_tnep_solution, kwargs...) 
end

# the general form of the tnep optimization model
function post_tnep{T}(pm::GenericPowerModel{T})
    variable_line_ne(pm) 

    variable_complex_voltage(pm)
    variable_complex_voltage_ne(pm)

    variable_active_generation(pm)
    variable_reactive_generation(pm)

    variable_active_line_flow(pm)
    variable_active_line_flow_ne(pm)
    variable_reactive_line_flow(pm)
    variable_reactive_line_flow_ne(pm)

    objective_tnep_cost(pm)
       
    constraint_theta_ref(pm)

    constraint_complex_voltage(pm)
    constraint_complex_voltage_ne(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt_ne(pm, bus)
        constraint_reactive_kcl_shunt_ne(pm, bus)
    end
    
    for (i,branch) in pm.ext[:ne].branches
        constraint_active_ohms_yt_ne(pm, branch)
        constraint_reactive_ohms_yt_ne(pm, branch) 

        constraint_phase_angle_difference_ne(pm, branch)
        constraint_thermal_limit_from_ne(pm, branch)
        constraint_thermal_limit_to_ne(pm, branch)
    end
        
    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_difference(pm, branch)
        constraint_thermal_limit_from(pm, branch)
        constraint_thermal_limit_to(pm, branch)
    end  
end

function get_tnep_solution{T}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_flow_setpoint_ne(sol, pm)    
    add_branch_ne_setpoint(sol, pm)
    return sol
end

