using Ipopt

export test_ac_opf, test_dc_opf

function post_objective_min_fuel_cost(pm::Union{ACPPowerModel, DCPPowerModel})
    objective_min_fuel_cost(pm.model, pm.ext.pg, pm.set.gens, pm.set.gen_indexes)
end

function post_opf{T}(pm::GenericPowerModel{T})
    add_vars(pm)
    post_opf_constraints(pm)
    post_objective_min_fuel_cost(pm)
end


function test_ac_opf()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"));
    data = parse_matpower(data_string);

    apm = ACPPowerModel(data);
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end

function test_dc_opf()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"));
    data = parse_matpower(data_string);

    apm = DCPPowerModel(data);
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


function post_opf_constraints(pm::ACPPowerModel)
    @constraint(pm.model, pm.ext.t[pm.set.ref_bus] == 0)

    for (i,bus) in pm.set.buses
        bus_branches = filter(x -> x[2] == i, pm.set.arcs)
        constraint_active_kcl_shunt_v(pm.model, pm.ext.p, pm.ext.pg, pm.ext.v[i], bus, bus_branches, pm.set.bus_gens[i])
        constraint_reactive_kcl_shunt_v(pm.model, pm.ext.q, pm.ext.qg, pm.ext.v[i], bus, bus_branches, pm.set.bus_gens[i])
    end

    for (l,i,j) in pm.set.arcs_from
        branch = pm.set.branches[l]
        constraint_active_ohms_v_yt(pm.model, pm.ext.p[(l,i,j)], pm.ext.p[(l,j,i)], pm.ext.v[i], pm.ext.v[j], pm.ext.t[i], pm.ext.t[j], branch)
        constraint_reactive_ohms_v_yt(pm.model, pm.ext.q[(l,i,j)], pm.ext.q[(l,j,i)], pm.ext.v[i], pm.ext.v[j], pm.ext.t[i], pm.ext.t[j], branch)
        
        constraint_phase_angle_diffrence_t(pm.model, pm.ext.t[i], pm.ext.t[j], branch)

        constraint_thermal_limit(pm.model, pm.ext.p[(l,i,j)], pm.ext.q[(l,i,j)], branch)
        constraint_thermal_limit(pm.model, pm.ext.p[(l,j,i)], pm.ext.q[(l,j,i)], branch)
    end
end


function post_opf_constraints(pm::DCPPowerModel)
    @constraint(pm.model, pm.ext.t[pm.set.ref_bus] == 0)

    for (i,bus) in pm.set.buses
        bus_branches = filter(x -> x[2] == i, pm.set.arcs)
        constraint_active_kcl_shunt_const(pm.model, pm.ext.p, pm.ext.pg, bus, bus_branches, pm.set.bus_gens[i])
    end

    for (l,i,j) in pm.set.arcs_from
        branch = pm.set.branches[l]
        constraint_active_ohms_linear(pm.model, pm.ext.p[(l,i,j)], pm.ext.t[i], pm.ext.t[j], branch)

        constraint_phase_angle_diffrence_t(pm.model, pm.ext.t[i], pm.ext.t[j], branch)
        # Note the thermal limit constraint is captured by the variable bounds
    end
end




#=

include("var.jl")
include("constraint.jl")
include("obj.jl")

export run_opf, run_opf_file, run_opf_string
export AC_OPF, QC_OPF, SOC_OPF, DC_OPF, SDP_OPF


function run_opf(; file = "../test/data/case3.json", model_builder = AC_OPF, solver = IpoptSolver(tol=1e-6, print_level=1))
    return run_power_model(file, model_builder, solver)
end

function run_opf_file(; file = "../test/data/case3.json", model_builder = AC_OPF, solver = IpoptSolver(tol=1e-6, print_level=1))
    return run_power_model_file(file, model_builder, solver)
end

function run_opf_string(data_string; model_builder = AC_OPF, solver = IpoptSolver(tol=1e-6, print_level=1))
    return run_power_model_string(data_string, model_builder, solver)
end


# Implementation of the linearized DC OPF
function DC_OPF(data, settings)
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

    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in arcs_from])


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_const(m, p_expr, pg, bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_linear(m, p[(l,i,j)], t[i], t[j], branch)
        constraint_phase_angle_diffrence_t(m, t[i], t[j], branch)
        # Note the thermal limit constraint is captured by the variable bounds
    end

    objective_min_fuel_cost(m, pg, gens, gen_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> NaN

    v_val = i -> 1.0
    t_val = i -> getvalue(t[i])

    p_fr_val = i -> getvalue(p[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    q_fr_val = i -> NaN
    p_to_val = i -> getvalue(p[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])
    q_to_val = i -> NaN

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_flow_setpoint(abstract_sol, data, settings, p_fr_val, q_fr_val, p_to_val, q_to_val)

    return m, abstract_sol
end



function AC_OPF(data, settings)
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


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_v_yt(m, p[(l,i,j)], p[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        constraint_reactive_ohms_v_yt(m, q[(l,i,j)], q[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        
        constraint_phase_angle_diffrence_t(m, t[i], t[j], branch)

        constraint_thermal_limit(m, p[(l,i,j)], q[(l,i,j)], branch)
        constraint_thermal_limit(m, p[(l,j,i)], q[(l,j,i)], branch)
    end

    objective_min_fuel_cost(m, pg, gens, gen_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> getvalue(v[i])
    t_val = i -> getvalue(t[i])

    p_fr_val = i -> getvalue(p[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    q_fr_val = i -> getvalue(q[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    p_to_val = i -> getvalue(p[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])
    q_to_val = i -> getvalue(q[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_flow_setpoint(abstract_sol, data, settings, p_fr_val, q_fr_val, p_to_val, q_to_val)

    return m, abstract_sol
end


# Implementation of the second order cone relaxation of the optimal power flow model
function SOC_OPF(data, settings)
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

    w  = voltage_magnitude_sqr_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes, 1.001, "w_start"))
    wr = real_complex_product_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes, 1.0, "wr_start"))
    wi = imaginary_complex_product_variables(m, buspairs, buspair_indexes)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_w_yt(m, p[(l,i,j)], p[(l,j,i)], w[i], w[j], wr[(i,j)], wi[(i,j)], branch)
        constraint_reactive_ohms_w_yt(m, q[(l,i,j)], q[(l,j,i)], w[i], w[j], wr[(i,j)], wi[(i,j)], branch)

        constraint_thermal_limit(m, p[(l,i,j)], q[(l,i,j)], branch)
        constraint_thermal_limit(m, p[(l,j,i)], q[(l,j,i)], branch)

        if buspairs[(i,j)]["line"] == l
            constraint_phase_angle_diffrence_w(m, wr[(i,j)], wi[(i,j)], buspairs[(i,j)])
            complex_product_relaxation(m, w[i], w[j], wr[(i,j)], wi[(i,j)])
        end
    end

    println("add obj...")
    objective_min_fuel_cost(m, pg, gens, gen_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> 0

    p_fr_val = i -> getvalue(p[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    q_fr_val = i -> getvalue(q[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    p_to_val = i -> getvalue(p[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])
    q_to_val = i -> getvalue(q[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_flow_setpoint(abstract_sol, data, settings, p_fr_val, q_fr_val, p_to_val, q_to_val)

    return m, abstract_sol
end




# Implementation of the convex quadratic relaxation of the optimal power flow model
function QC_OPF(data, settings)
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

    t  = phase_angle_variables(m, bus_indexes)
    v  = voltage_magnitude_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes, 1.0, "v_start"))

    w  = voltage_magnitude_sqr_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes, 1.001, "w_start"))
    wr = real_complex_product_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes, 1.0, "wr_start"))
    wi = imaginary_complex_product_variables(m, buspairs, buspair_indexes)

    td = phase_angle_diffrence_variables(m, buspairs, buspair_indexes)
    vv = voltage_magnitude_product_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes, 1.0, "vv_start"))
    cs = cosine_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes, 1.0, "cs_start")) 
    si = sine_variables(m, buspairs, buspair_indexes)
    cm = current_magnitude_sqr_variables(m, buspairs, buspair_indexes)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        sqr_relaxation(m, v[i], w[i])

        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_w_yt(m, p[(l,i,j)], p[(l,j,i)], w[i], w[j], wr[(i,j)], wi[(i,j)], branch)
        constraint_reactive_ohms_w_yt(m, q[(l,i,j)], q[(l,j,i)], w[i], w[j], wr[(i,j)], wi[(i,j)], branch)

        constraint_thermal_limit(m, p[(l,i,j)], q[(l,i,j)], branch)
        constraint_thermal_limit(m, p[(l,j,i)], q[(l,j,i)], branch)

        if buspairs[(i,j)]["line"] == l
            bp = (i,j)
            @constraint(m, t[i] - t[j] == td[bp])

            sin_relaxation(m, td[bp], si[bp])
            cos_relaxation(m, td[bp], cs[bp])
            product_relaxation(m, v[i], v[j], vv[bp])
            product_relaxation(m, vv[bp], cs[bp], wr[bp])
            product_relaxation(m, vv[bp], si[bp], wi[bp])

            # this constraint is redudant and useful for debugging
            #complex_product_relaxation(m, w[i], w[j], wr[bp], wi[bp])
            
            constraint_power_magnitude_sqr(m, p[(l,i,j)], q[(l,i,j)], w[i], cm[bp], branch)
            constraint_power_magnitude_link(m, w[i], w[j], wr[bp], wi[bp], cm[bp], q[(l,i,j)], branch)

            constraint_phase_angle_diffrence_w(m, wr[bp], wi[bp], buspairs[bp])
        end
    end

    println("add obj...")

    objective_min_fuel_cost(m, pg, gens, gen_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> 0

    p_fr_val = i -> getvalue(p[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    q_fr_val = i -> getvalue(q[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    p_to_val = i -> getvalue(p[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])
    q_to_val = i -> getvalue(q[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_flow_setpoint(abstract_sol, data, settings, p_fr_val, q_fr_val, p_to_val, q_to_val)

    return m, abstract_sol
end


function SDP_OPF(data, settings)
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

    WR, WI, lookup_w_index = complex_product_matrix_variables(m, buspairs, buspair_indexes, buses, bus_indexes)

    # Thanks to Sidhant!
    # follow this: http://docs.mosek.com/modeling-cookbook/sdo.html
    @SDconstraint(m, [WR WI; -WI WR] >= 0)

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    for (i,bus) in buses
        w_idx = lookup_w_index[i]
        w_i = WR[w_idx,w_idx]

        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w_i, bus, bus_branches, bus_gens[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w_i, bus, bus_branches, bus_gens[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        w_i = WR[wi_idx, wi_idx]
        w_j = WR[wj_idx, wj_idx]

        wr_ij = WR[wi_idx, wj_idx]
        wi_ij = WI[wi_idx, wj_idx]

        constraint_active_ohms_w_yt(m, p[(l,i,j)], p[(l,j,i)], w_i, w_j, wr_ij, wi_ij, branch)
        constraint_reactive_ohms_w_yt(m, q[(l,i,j)], q[(l,j,i)], w_i, w_j, wr_ij, wi_ij, branch)

        constraint_thermal_limit_conic(m, p[(l,i,j)], q[(l,i,j)], branch)
        constraint_thermal_limit_conic(m, p[(l,j,i)], q[(l,j,i)], branch)

        if buspairs[(i,j)]["line"] == l
            constraint_phase_angle_diffrence_w(m, wr_ij, wi_ij, buspairs[(i,j)])

            # this constraint is redudant and useful for debugging
            #@constraint(m, wr_ij^2 + wi_ij^2 <= w_i*w_j)
            #@constraint(m, norm([2*wr_ij, 2*wi_ij, w_i - w_j]) <= (w_i + w_j)) 
        end
    end

    println("add obj...")

    objective_min_fuel_cost_conic(m, pg, gens, gen_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(WR[lookup_w_index[i], lookup_w_index[i]]))
    t_val = i -> 0

    p_fr_val = i -> getvalue(p[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    q_fr_val = i -> getvalue(q[(i, branches[i]["f_bus"] , branches[i]["t_bus"])])
    p_to_val = i -> getvalue(p[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])
    q_to_val = i -> getvalue(q[(i, branches[i]["t_bus"] , branches[i]["f_bus"])])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_flow_setpoint(abstract_sol, data, settings, p_fr_val, q_fr_val, p_to_val, q_to_val)

    return m, abstract_sol
end

=#
