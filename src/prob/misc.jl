export 
    post_api_opf, run_api_opf,
    post_sad_opf, run_sad_opf


function run_api_opf(file, model_constructor, solver)
    data = parse_file(file)

    pm = model_constructor(data; solver = solver)

    post_api_opf(pm)
    return solve(pm)
end

function post_api_opf{T}(pm::GenericPowerModel{T})
    free_api_variables(pm)

    constraint_theta_ref(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt_scaled(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_diffrence(pm, branch)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end

    objective_max_loading(pm)
end


function run_sad_opf(file, model_constructor, solver)
    data = parse_file(file)

    pm = model_constructor(data; solver = solver)

    post_sad_opf(pm)
    return solve(pm)
end

function post_sad_opf{T}(pm::GenericPowerModel{T})
    constraint_theta_ref(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_y(pm, branch)
        constraint_reactive_ohms_y(pm, branch)

        constraint_phase_angle_diffrence_flexible(pm, branch)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end

    objective_min_theta_delta(pm)
end




