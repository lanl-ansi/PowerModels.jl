#### General Assumptions of these OTS Models ####
#
# - if the branch status is 0 in the input, it is out of service and forced to 0 in OTS
# - the network will be maintained as one connected component (i.e. at least n-1 edges)
#

include("var.jl")
include("constraint.jl")
include("obj.jl")

export run_ots, run_ots_file, run_ots_string
export AC_OTS, DC_OTS, DC_LL_OTS, SOC_OTS


function run_ots(; file = "../test/data/case3.json", model_builder = AC_OTS, solver = BonminNLSolver())
    return run_power_model(file, model_builder, solver)
end

function run_ots_file(; file = "../test/data/case3.json", model_builder = AC_OTS, solver = BonminNLSolver())
    return run_power_model_file(file, model_builder, solver)
end

function run_ots_string(data_string; model_builder = AC_OTS, solver = BonminNLSolver())
    return run_power_model_string(data_string, model_builder, solver)
end


function AC_OTS(data, settings)
    warn("Bonmin sometimes returns a solution without the integrality constraint.  Use at your own risk!!!  And check the branch status of the solution");

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
    v  = voltage_magnitude_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes, 1.0, "v_start"))

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    

    z = line_indicator_variables(m, branch_indexes)


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_v_yt_on_off(m, p[(l,i,j)], p[(l,j,i)], v[i], v[j], t[i], t[j], z[l], branch)
        constraint_reactive_ohms_v_yt_on_off(m, q[(l,i,j)], q[(l,j,i)], v[i], v[j], t[i], t[j], z[l], branch)

        constraint_phase_angle_diffrence_t_on_off_nl(m, t[i], t[j], z[l], branch)

        constraint_thermal_limit_on_off(m, p[(l,i,j)], q[(l,i,j)], z[l], branch)
        constraint_thermal_limit_on_off(m, p[(l,j,i)], q[(l,j,i)], z[l], branch)
    end


    println("add obj...")

    # good for testing
    #objective_min_vars(m, z)

    objective_min_fuel_cost(m, pg, gens, gen_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> getvalue(v[i])
    t_val = i -> getvalue(t[i])

    z_val = i -> getvalue(z[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end



# Implementation of the linearized DC OTS
function DC_OTS(data, settings)
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
    z = line_indicator_variables(m, branch_indexes)

    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in arcs_from])

    println("add const...")

    min_t_delta = calc_min_phase_angle(buses, branches)
    max_t_delta = calc_max_phase_angle(buses, branches)

    @constraint(m, t[ref_bus] == 0)
    
    # does not seem to help
    #constraint_min_edge_count(m, z, buses)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_const(m, p_expr, pg, bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_linear_on_off(m, p[(l,i,j)], t[i], t[j], z[l], min_t_delta, max_t_delta, branch)
        constraint_phase_angle_diffrence_t_on_off(m, t[i], t[j], z[l], min_t_delta, max_t_delta, branch)
        # Note the thermal limit constraint is captured by the variable bounds
    end


    println("add obj...")

    # good for testing
    #objective_min_vars(m, z)

    # needed for guorbi
    objective_min_fuel_cost(m, pg, gens, gen_indexes)

    # needed for bonmin
    #objective_min_fuel_cost_nl(m, pg, gens, gen_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> NaN

    v_val = i -> 1.0
    t_val = i -> getvalue(t[i])

    z_val = i -> getvalue(z[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end


# Implementation of the linearized DC with lines losses
function DC_LL_OTS(data, settings)
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
    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    z = line_indicator_variables(m, branch_indexes)

    println("add const...")

    min_t_delta = calc_min_phase_angle(buses, branches)
    max_t_delta = calc_max_phase_angle(buses, branches)

    @constraint(m, t[ref_bus] == 0)

    # does not seem to help
    #constraint_min_edge_count(m, z, buses)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_const(m, p, pg, bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_loss_on_off(m, p[(l,i,j)], p[(l,j,i)], t[i], t[j], z[l], min_t_delta, max_t_delta, branch)
        constraint_phase_angle_diffrence_t_on_off(m, t[i], t[j], z[l], min_t_delta, max_t_delta, branch)
        # Note the thermal limit constraint is captured by the variable bounds
    end


    println("add obj...")

    # good for testing
    #objective_min_vars(m, z)

    # needed for guorbi
    objective_min_fuel_cost(m, pg, gens, gen_indexes)

    # needed for bonmin
    #objective_min_fuel_cost_nl(m, pg, gens, gen_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> NaN

    v_val = i -> 1.0
    t_val = i -> getvalue(t[i])

    z_val = i -> getvalue(z[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end



# Implementation of the second order cone relaxation of the optimal power flow model
function SOC_OTS(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))

    println("build model...")
    
    m = Model()

    println("add vars...")

    w  = voltage_magnitude_sqr_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes, 1.001, "w_start"))

    z = line_indicator_variables(m, branch_indexes)

    w_line_from = voltage_magnitude_sqr_from_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes, 1.001, "w_from_start"))
    w_line_to = voltage_magnitude_sqr_to_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes, 1.001, "w_to_start"))

    wr = real_complex_product_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes, 1.0, "wr_start"))
    wi = imaginary_complex_product_on_off_variables(m, z, branch_indexes, branches, buses)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    min_t_delta = calc_min_phase_angle(buses, branches)
    max_t_delta = calc_max_phase_angle(buses, branches)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]

        constraint_var_link_on_off(m, w[i], w_line_from[l], z[l])
        constraint_var_link_on_off(m, w[j], w_line_to[l], z[l])

        constraint_active_ohms_w_yt(m, p[(l,i,j)], p[(l,j,i)], w_line_from[l], w_line_to[l], wr[l], wi[l], branch)
        constraint_reactive_ohms_w_yt(m, q[(l,i,j)], q[(l,j,i)], w_line_from[l], w_line_to[l], wr[l], wi[l], branch)

        constraint_thermal_limit_on_off(m, p[(l,i,j)], q[(l,i,j)], z[l], branch)
        constraint_thermal_limit_on_off(m, p[(l,j,i)], q[(l,j,i)], z[l], branch)

        constraint_phase_angle_diffrence_w(m, wr[l], wi[l], branch)
        complex_product_relaxation_on_off(m, w[i], w[j], wr[l], wi[l], z[l])

        if branch["br_r"] >= 0
            constraint_active_loss_lb(m, p[(l,i,j)], p[(l,j,i)], branch)
        end
        if branch["br_x"] >= 0
            constraint_reactive_loss_lb(m, q[(l,i,j)], q[(l,j,i)], w_line_from[l], w_line_to[l], branch)
        end
    end


    println("add obj...")

    # good for testing
    #objective_min_vars(m, z)

    # needed for guorbi
    objective_min_fuel_cost(m, pg, gens, gen_indexes)

    # needed for bonmin
    #objective_min_fuel_cost_nl(m, pg, gens, gen_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> 0

    z_val = i -> getvalue(z[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end
