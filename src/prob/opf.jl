export post_opf, run_opf

function run_opf(file, model_constructor, solver; kwargs...)
    data = PowerModels.parse_file(file)

    pm = model_constructor(data; solver = solver, kwargs...)

    post_opf(pm)

    status, solve_time = solve(pm)

    return build_solution(pm, status, solve_time)
end


function post_opf{T}(pm::GenericPowerModel{T})
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
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_diffrence(pm, branch)

        constraint_thermal_limit_from(pm, branch)
        constraint_thermal_limit_to(pm, branch)
    end
end

