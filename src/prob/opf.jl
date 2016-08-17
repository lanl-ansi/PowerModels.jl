export post_opf, run_opf

function run_opf(file, model_constructor, solver)
    data = parse_file(file)

    pm = model_constructor(data; solver = solver)

    post_opf(pm)
    return solve(pm)
end


function post_opf{T}(pm::GenericPowerModel{T})
    constraint_theta_ref(pm)

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

    objective_min_fuel_cost(pm)
end

