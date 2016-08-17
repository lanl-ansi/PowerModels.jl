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
        constraint_active_kcl_shunt(pm, bus)
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

function run_sad_opf{T}(pm::GenericPowerModel{T})
    constraint_theta_ref(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_diffrence(pm, branch)

        constraint_thermal_limit_from(pm, branch; scale = 0.999)
        constraint_thermal_limit_to(pm, branch; scale = 0.999)
    end

    objective_min_fuel_cost(pm)
end



#=


# Small Angle Difference Optimization (SAD)
# decreases phase angle bounds, until constraints are binding
function AC_SAD(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))


    println("build model...")
    m = Model()


    println("add vars...")

    @variable(m, theta_delta_bound >= 0.0, start = 0.523598776)

    t  = phase_angle_variables(m, bus_indexes)
    v  = voltage_magnitude_variables(m, buses, bus_indexes)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        # this actually makes a difference over _yt variant!
        constraint_active_ohms_v_y(m, p[(l,i,j)], p[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        constraint_reactive_ohms_v_y(m, q[(l,i,j)], q[(l,j,i)], v[i], v[j], t[i], t[j], branch)

        #constraint_phase_angle_diffrence_t(m, t[i], t[j], branch)
        @constraint(m, t[i] - t[j] <=  theta_delta_bound)
        @constraint(m, t[i] - t[j] >= -theta_delta_bound)

        #constraint_thermal_limit(m, p[(l,i,j)], q[(l,i,j)], branch)
        #constraint_thermal_limit(m, p[(l,j,i)], q[(l,j,i)], branch)
        @constraint(m, p[(l,i,j)]^2 + q[(l,i,j)]^2 <= branch["rate_a"]^2*0.999)
        @constraint(m, p[(l,j,i)]^2 + q[(l,j,i)]^2 <= branch["rate_a"]^2*0.999)
    end

    @objective(m, Min, theta_delta_bound)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> getvalue(v[i])
    t_val = i -> getvalue(t[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end


=#


