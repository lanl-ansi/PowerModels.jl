# A place for miscellaneous models that don't have a place elsewhere

include("var.jl")
include("constraint.jl")
include("obj.jl")

export AC_API, AC_SAD


# Active Power Increase Optimization (API)
# increases active power demands until constraints are binding
function AC_API(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))


    println("build model...")
    m = Model()


    println("add vars...")

    @variable(m, load_factor >= 1.0, start = 1.0)

    t  = phase_angle_variables(m, bus_indexes)
    v  = voltage_magnitude_variables(m, buses, bus_indexes)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    

    for (i,gen) in gens
        if gen["pmax"] > 0 
            setupperbound(pg[i], Inf)
        end
        setupperbound(qg[i],  Inf)
        setlowerbound(qg[i], -Inf)
    end

    for (i,bus) in buses
        setupperbound(v[i], bus["vmax"]*0.999)
        setlowerbound(v[i], bus["vmin"]*1.001)
    end


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        if bus["pd"] > 0 && bus["qd"] > 0
            #println(bus["pd"])
            #println(load_factor)
            @constraint(m, sum{p[a], a=bus_branches} == sum{pg[g], g=bus_gens[i]} - bus["pd"]*load_factor - bus["gs"]*v[i]^2)
        else
            constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i])
        end
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]

        # this does not appear to make a difference over _yt variant.
        constraint_active_ohms_v_yt(m, p[(l,i,j)], p[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        constraint_reactive_ohms_v_yt(m, q[(l,i,j)], q[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        
        constraint_phase_angle_diffrence_t(m, t[i], t[j], branch)
        # this is the original *incorrect* implementation
        #@constraint(m, t[i] - t[j] - branch["shift"] <= branch["angmax"])
        #@constraint(m, t[i] - t[j] - branch["shift"] >= branch["angmin"])

        #constraint_thermal_limit(m, p[(l,i,j)], q[(l,i,j)], branch)
        #constraint_thermal_limit(m, p[(l,j,i)], q[(l,j,i)], branch)
        @constraint(m, p[(l,i,j)]^2 + q[(l,i,j)]^2 <= branch["rate_a"]^2*0.999)
        @constraint(m, p[(l,j,i)]^2 + q[(l,j,i)]^2 <= branch["rate_a"]^2*0.999)
    end

    @objective(m, Max, load_factor)

    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> getvalue(v[i])
    t_val = i -> getvalue(t[i])

    pd_val = i -> buses[i]["pd"] > 0 && buses[i]["qd"] > 0 ? buses[i]["pd"]*getvalue(load_factor) : buses[i]["pd"]
    qd_val = i -> buses[i]["qd"]

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end



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





