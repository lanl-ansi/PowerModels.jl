include("var.jl")
include("constraint.jl")

export run_pf, run_pf_file, run_pf_string
export AC_PF, SOC_PF, DC_PF


function run_pf(; file = "../test/data/case3.json", model_builder = AC_PF, solver = build_solver(IPOPT_SOLVER))
    return run_power_model(file, model_builder, solver)
end

function run_pf_file(; file = "../test/data/case3.json", model_builder = AC_PF, solver = build_solver(IPOPT_SOLVER))
    return run_power_model_file(file, model_builder, solver)
end

function run_pf_string(data_string; model_builder = AC_PF, solver = build_solver(IPOPT_SOLVER))
    return run_power_model_string(data_string, model_builder, solver)
end


# Implementation of the linearized DC PF
function DC_PF(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))

    println("build model...")

    m = Model()

    println("add vars...")

    t  = phase_angle_variables(m, bus_indexes)
    pg = active_generation_variables(m, gens, gen_indexes)
    p  = line_flow_variables(m, arcs_from, branches, branch_indexes)

    # relax gen bounds at the slack bus
    for i in bus_gens[ref_bus]
        setupperbound(pg[i], Inf)
        setlowerbound(pg[i], -Inf)
    end
    for (l,i,j) in arcs_from
        setupperbound(p[(l,i,j)], Inf)
        setlowerbound(p[(l,i,j)], -Inf)
    end

    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in arcs_from])


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_const(m, p_expr, pg, bus, bus_branches, bus_gens[i])

        if i != ref_bus
            for j in bus_gens[i]
                constraint_active_gen_setpoint(m, pg[j], gens[j])
            end
        end
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_linear(m, p[(l,i,j)], t[i], t[j], branch)
    end

    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> NaN

    v_val = i -> 1.0
    t_val = i -> getvalue(t[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end


function AC_PF(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))


    println("build model...")
    m = Model()


    println("add vars...")

    t  = phase_angle_variables(m, bus_indexes)
    v  = voltage_magnitude_variables(m, buses, bus_indexes)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    # relax gen bounds at the slack bus
    for i in bus_gens[ref_bus]
        setupperbound(pg[i], Inf)
        setlowerbound(pg[i], -Inf)

        setupperbound(qg[i], Inf)
        setlowerbound(qg[i], -Inf)
    end
    # relax gen bounds on voltages
    for i in bus_indexes
        setupperbound(v[i], Inf)
        setlowerbound(v[i], 0)
    end
    # relax gen bounds on line flows
    for (l,i,j) in arcs
        setupperbound(p[(l,i,j)], Inf)
        setlowerbound(p[(l,i,j)], -Inf)

        setupperbound(q[(l,i,j)], Inf)
        setlowerbound(q[(l,i,j)], -Inf)
    end

    println("add const...")

    # V-Theta Bus Constraints
    @constraint(m, t[ref_bus] == 0)
    constraint_voltage_magnitude_setpoint(m, v[ref_bus], buses[ref_bus])

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i])

        # P-V Bus Constraints
        if length(bus_gens[i]) > 0 && i != ref_bus
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2
            # soft equality needed becouse V in file is not precice enough
            # worth revising this once ipopt is built with HSL
            constraint_voltage_magnitude_setpoint(m, v[i], bus; epsilon = 0.00001)
            for j in bus_gens[i]
                constraint_active_gen_setpoint(m, pg[j], gens[j])
            end
        end

    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_v_yt(m, p[(l,i,j)], p[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        constraint_reactive_ohms_v_yt(m, q[(l,i,j)], q[(l,j,i)], v[i], v[j], t[i], t[j], branch)
    end


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


function AC_PF_no_lines(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))


    println("build model...")
    m = Model()


    println("add vars...")

    t  = phase_angle_variables(m, bus_indexes)
    v  = voltage_magnitude_variables(m, buses, bus_indexes; start = 1.0)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    #p  = line_flow_variables(m, arcs, branches)
    #q  = line_flow_variables(m, arcs, branches)    


    # relax gen bounds at the slack bus
    for i in bus_gens[ref_bus]
        setupperbound(pg[i], Inf)
        setlowerbound(pg[i], -Inf)

        setupperbound(qg[i], Inf)
        setlowerbound(qg[i], -Inf)
    end
    # relax gen bounds on voltages
    for i in bus_indexes
        setupperbound(v[i], Inf)
        setlowerbound(v[i], 0)
    end

    println("add const...")

    # V-Theta Bus Constraints
    @constraint(m, t[ref_bus] == 0)
    constraint_voltage_magnitude_setpoint(m, v[ref_bus], buses[ref_bus])

    for (i,bus) in buses
        bus_branches_from = filter(x -> x[2] == i, arcs_from)
        bus_branches_to = filter(x -> x[2] == i, arcs_to)

        # TODO figure out why building these constraints is super slow
        constraint_active_kcl_shunt_v(m, v, t, pg, v[i], bus, bus_branches_from, bus_branches_to, bus_gens[i], branches)
        constraint_reactive_kcl_shunt_v(m, v, t, qg, v[i], bus, bus_branches_from, bus_branches_to, bus_gens[i], branches)

        # P-V Bus Constraints
        if length(bus_gens[i]) > 0 && i != ref_bus
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2
            # soft equality needed becouse V in file is not precice enough
            # worth revising this once ipopt is built with HSL
            constraint_voltage_magnitude_setpoint(m, v[i], bus; epsilon = 0.00001)
            for j in bus_gens[i]
                constraint_active_gen_setpoint(m, pg[j], gens[j])
            end
        end

    end

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


# Implementation of the second order cone relaxation of the optimal power flow model
function SOC_PF(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))

    println("build model...")
    
    m = Model()

    buspair_indexes = collect(Set([(i,j) for (l,i,j) in arcs_from]))
    buspairs = buspair_parameters(buspair_indexes, branches, buses)  

    println("add vars...")

    w  = voltage_magnitude_sqr_variables(m, buses, bus_indexes)
    wr = real_complex_product_variables(m, buspairs, buspair_indexes)
    wi = imaginary_complex_product_variables(m, buspairs, buspair_indexes)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    # relax gen bounds at the slack bus
    for i in bus_gens[ref_bus]
        setupperbound(pg[i], Inf)
        setlowerbound(pg[i], -Inf)

        setupperbound(qg[i], Inf)
        setlowerbound(qg[i], -Inf)
    end
    for i in bus_indexes
        setupperbound(w[i], Inf)
        setlowerbound(w[i], 0)
    end
    for (l,i,j) in arcs
        setupperbound(p[(l,i,j)], Inf)
        setlowerbound(p[(l,i,j)], -Inf)

        setupperbound(q[(l,i,j)], Inf)
        setlowerbound(q[(l,i,j)], -Inf)
    end
    for (i,j) in buspair_indexes
        setupperbound(wr[(i,j)], Inf)
        setlowerbound(wr[(i,j)], -Inf)

        setupperbound(wi[(i,j)], Inf)
        setlowerbound(wi[(i,j)], -Inf)
    end

    println("add const...")

    # V-Theta Bus Constraints
    constraint_voltage_magnitude_setpoint_w(m, w[ref_bus], buses[ref_bus])

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i])

        # P-V Bus Constraints
        if length(bus_gens[i]) > 0 && i != ref_bus
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2
            constraint_voltage_magnitude_setpoint_w(m, w[i], bus)
            for j in bus_gens[i]
                constraint_active_gen_setpoint(m, pg[j], gens[j])
            end
        end
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_w_yt(m, p[(l,i,j)], p[(l,j,i)], w[i], w[j], wr[(i,j)], wi[(i,j)], branch)
        constraint_reactive_ohms_w_yt(m, q[(l,i,j)], q[(l,j,i)], w[i], w[j], wr[(i,j)], wi[(i,j)], branch)

        if buspairs[(i,j)]["line"] == l
            complex_product_relaxation(m, w[i], w[j], wr[(i,j)], wi[(i,j)])
        end
    end

    #println("add obj...")
    #objective_min_fuel_cost(m, pg, gens, gen_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> 0

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end





