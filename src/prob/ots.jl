#### General Assumptions of these OTS Models ####
#
# - if the branch status is 0 in the input, it is out of service and forced to 0 in OTS
# - the network will be maintained as one connected component (i.e. at least n-1 edges)
#

export post_ots, run_ots

function run_ots(file, model_constructor, solver)
    data = PowerModels.parse_file(file)

    pm = model_constructor(data; solver = solver)

    post_ots(pm)
    return solve(pm)
end


function post_ots{T}(pm::GenericPowerModel{T})
    variable_line_indicator(pm)
    variable_complex_voltage(pm)

    variable_active_generation(pm)
    variable_reactive_generation(pm)

    variable_active_line_flow(pm)
    variable_reactive_line_flow(pm)


    objective_min_fuel_cost(pm)


    constraint_theta_ref(pm)
    constraint_complex_voltage(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt_on_off(pm, branch)
        constraint_reactive_ohms_yt_on_off(pm, branch)

        constraint_phase_angle_diffrence_on_off(pm, branch)

        constraint_thermal_limit_from_on_off(pm, branch)
        constraint_thermal_limit_to_on_off(pm, branch)
    end
end

