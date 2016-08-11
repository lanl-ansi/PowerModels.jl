isdefined(Base, :__precompile__) && __precompile__()

include("var.jl")
include("constraint.jl")
include("obj.jl")

export run_load_shed, run_load_shed_file, run_load_shed_string
export AC_LS, QC_LS, SOC_LS, DC_LS, SDP_LS, AC_LS_UC, QC_LS_UC, SOC_LS_UC, DC_LS_UC, SDP_LS_UC, AC_LS_UC_TS, DC_LS_UC_TS, SOC_LS_UC_TS


function run_load_shed(; file = "../test/data/case3.json", model_builder = AC_LS, solver = IpoptSolver(tol=1e-6, print_level=1))
    return run_power_model(file, model_builder, solver)
end

function run_load_shed_file(; file = "../test/data/case3.json", model_builder = AC_LS, solver = IpoptSolver(tol=1e-6, print_level=1))
    return run_power_model_file(file, model_builder, solver)
end

function run_load_shed_string(data_string; model_builder = AC_LS, solver = IpoptSolver(tol=1e-6, print_level=1))
    return run_power_model_string(data_string, model_builder, solver)
end



# Implementation of the linearized DC OPF
function DC_LS(data, settings)
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
    pd = active_load_variables(m, buses, bus_indexes)
    p  = line_flow_variables(m, arcs_from, branches, branch_indexes)

    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in arcs_from])


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_const(m, p_expr, pg, bus, bus_branches, bus_gens[i];pd=pd[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_linear(m, p[(l,i,j)], t[i], t[j], branch)
        constraint_phase_angle_diffrence_t(m, t[i], t[j], branch)
        # Note the thermal limit constraint is captured by the variable bounds
    end

    objective_max_active_load(m, pd, buses, bus_indexes)

    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> NaN

    pd_val = i -> getvalue(pd[i])
    qd_val = i -> NaN
        
    v_val = i -> 1.0
    t_val = i -> getvalue(t[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end

function AC_LS(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))


    println("build model...")
    m = Model()


    println("add vars...")

    add_default_start_values(buses, bus_indexes, "theta_start", 0.0)
    add_default_start_values(buses, bus_indexes, "v_start", 1.0) 
    add_default_start_values(gens, gen_indexes, "pg_start", 0.0) 
    add_default_start_values(gens, gen_indexes, "qg_start", 0.0)     
    add_default_start_values(buses, bus_indexes, "pd_start", 0.0) 
    add_default_start_values(buses, bus_indexes, "qd_start", 0.0) 
    add_default_start_values(branches, branch_indexes, "p_start", 0.0) 
    add_default_start_values(branches, branch_indexes, "q_start", 0.0) 
            
    t  = phase_angle_variables(m, bus_indexes; start = buses)
    v  = voltage_magnitude_variables(m, buses, bus_indexes; start = buses)

    pg = active_generation_variables(m, gens, gen_indexes; start = gens)
    qg = reactive_generation_variables(m, gens, gen_indexes; start = gens)
    
    pd = active_load_variables(m, buses, bus_indexes; start = buses)
    qd = reactive_load_variables(m, buses, bus_indexes; start = buses)    

    p  = line_flow_variables(m, arcs, branches, branch_indexes; tag = "p_start", start = branches)
    q  = line_flow_variables(m, arcs, branches, branch_indexes; tag = "q_start", start = branches)    


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i]; pd = pd[i])
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i]; qd = qd[i])
    end

    for (l,i,j) in arcs_from
        branch = branches[l]
        constraint_active_ohms_v_yt(m, p[(l,i,j)], p[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        constraint_reactive_ohms_v_yt(m, q[(l,i,j)], q[(l,j,i)], v[i], v[j], t[i], t[j], branch)
        
        constraint_phase_angle_diffrence_t(m, t[i], t[j], branch)

        constraint_thermal_limit(m, p[(l,i,j)], q[(l,i,j)], branch)
        constraint_thermal_limit(m, p[(l,j,i)], q[(l,j,i)], branch)
    end

    objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)

    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> getvalue(v[i])
    t_val = i -> getvalue(t[i])
    
    pd_val = i -> getvalue(pd[i])
    qd_val = i -> getvalue(qd[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end


# Implementation of the second order cone relaxation of the optimal power flow model
function SOC_LS(data, settings)
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
    
    pd = active_load_variables(m, buses, bus_indexes)
    qd = reactive_load_variables(m, buses, bus_indexes)    
    

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i]; pd = pd[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i]; qd = qd[i])
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
    objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> 0
    
    pd_val = i -> getvalue(pd[i])
    qd_val = i -> getvalue(qd[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end




# Implementation of the convex quadratic relaxation of the optimal power flow model
function QC_LS(data, settings)
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
    
    pd = active_load_variables(m, buses, bus_indexes)
    qd = reactive_load_variables(m, buses, bus_indexes)    
 
    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,bus) in buses
        sqr_relaxation(m, v[i], w[i])

        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i]; pd = pd[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i]; qd = qd[i])
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

    objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> getvalue(t[i])

    pd_val = i -> getvalue(pd[i])
    qd_val = i -> getvalue(qd[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end


function SDP_LS(data, settings)
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
    
    pd = active_load_variables(m, buses, bus_indexes)
    qd = reactive_load_variables(m, buses, bus_indexes)    
    
    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    


    println("add const...")

    for (i,bus) in buses
        w_idx = lookup_w_index[i]
        w_i = WR[w_idx,w_idx]

        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w_i, bus, bus_branches, bus_gens[i]; pd = pd[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w_i, bus, bus_branches, bus_gens[i]; qd = qd[i])
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

    objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    v_val = i -> sqrt(getvalue(WR[lookup_w_index[i], lookup_w_index[i]]))
    t_val = i -> 0
    
    pd_val = i -> getvalue(pd[i])
    qd_val = i -> getvalue(qd[i])

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)

    return m, abstract_sol
end

function DC_LS_UC(data, settings)
  m, abstract_sol = DC_LS(data, settings)

  # this only works if these functions are deterministic
  ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)   
  gen_indexes = collect(keys(gens))
  
  uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))
  pg = getvariable(m, :pg)
  
  
  for (i,gen) in gens
    constraint_active_generation(m, pg[i], gen; var = uc[i])
  end
  
  uc_val = i -> getvalue(uc[i]) 
  add_generator_status_setpoint(abstract_sol, data, uc_val)
   
  return m, abstract_sol
end  

function AC_LS_UC(data, settings)
  m, abstract_sol = AC_LS(data, settings)

  # this only works if these functions are deterministic
  ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)   
  gen_indexes = collect(keys(gens))
  
  uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))
  pg = getvariable(m, :pg)
  qg = getvariable(m, :qg)
  
  for (i,gen) in gens
    constraint_active_generation(m, pg[i], gen; var = uc[i])
    constraint_reactive_generation(m, qg[i], gen; var = uc[i])     
  end
  
  uc_val = i -> getvalue(uc[i]) 
  add_generator_status_setpoint(abstract_sol, data, uc_val)
   
  return m, abstract_sol
end  

function SOC_LS_UC(data, settings)
  m, abstract_sol = SOC_LS(data, settings)

  # this only works if these functions are deterministic
  ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)   
  gen_indexes = collect(keys(gens))
  
  uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))
  pg = getvariable(m, :pg)
  qg = getvariable(m, :qg)
  
  
  for (i,gen) in gens
    constraint_active_generation(m, pg[i], gen; var = uc[i])
    constraint_reactive_generation(m, qg[i], gen; var = uc[i])     
  end
  
  uc_val = i -> getvalue(uc[i]) 
  add_generator_status_setpoint(abstract_sol, data, uc_val)
   
  return m, abstract_sol
end  

function SDP_LS_UC(data, settings)
  m, abstract_sol = SDP_LS(data, settings)

  # this only works if these functions are deterministic
  ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)   
  gen_indexes = collect(keys(gens))
  
  uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))
  pg = getvariable(m, :pg)
  qg = getvariable(m, :qg)
  
  
  for (i,gen) in gens
    constraint_active_generation(m, pg[i], gen; var = uc[i])
    constraint_reactive_generation(m, qg[i], gen; var = uc[i])     
  end
  
  uc_val = i -> getvalue(uc[i]) 
  add_generator_status_setpoint(abstract_sol, data, uc_val)
   
  return m, abstract_sol
end  


function QC_LS_UC(data, settings)
  m, abstract_sol = QC_LS(data, settings)

  # this only works if these functions are deterministic
  ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)   
  gen_indexes = collect(keys(gens))
  
  uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))
  pg = getvariable(m, :pg)
  qg = getvariable(m, :qg)
  
  for (i,gen) in gens
    constraint_active_generation(m, pg[i], gen; var = uc[i])
    constraint_reactive_generation(m, qg[i], gen; var = uc[i])     
  end
  
  uc_val = i -> getvalue(uc[i]) 
  add_generator_status_setpoint(abstract_sol, data, uc_val)
   
  return m, abstract_sol
end  





function AC_LS_UC_TS(data, settings)
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
    v  = voltage_magnitude_variables(m, buses, bus_indexes)

    pd = active_load_variables(m, buses, bus_indexes)
    qd = reactive_load_variables(m, buses, bus_indexes)    

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    

    z = line_indicator_variables(m, branch_indexes)
    uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))


    println("add const...")

    @constraint(m, t[ref_bus] == 0)

    for (i,gen) in gens
        constraint_active_generation(m, pg[i], gen; var = uc[i])
        constraint_reactive_generation(m, qg[i], gen; var = uc[i])     
    end

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_v(m, p, pg, v[i], bus, bus_branches, bus_gens[i]; pd = pd[i])
        constraint_reactive_kcl_shunt_v(m, q, qg, v[i], bus, bus_branches, bus_gens[i]; qd = qd[i])
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

    objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    pd_val = i -> getvalue(pd[i])
    qd_val = i -> getvalue(qd[i])

    v_val = i -> getvalue(v[i])
    t_val = i -> getvalue(t[i])

    z_val = i -> getvalue(z[i])
    uc_val = i -> getvalue(uc[i]) 

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_status_setpoint(abstract_sol, data, uc_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end



# Implementation of the linearized DC OTS
function DC_LS_UC_TS(data, settings)
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
    pd = active_load_variables(m, buses, bus_indexes)
    pg = active_generation_variables(m, gens, gen_indexes)
    p  = line_flow_variables(m, arcs_from, branches, branch_indexes)
    z = line_indicator_variables(m, branch_indexes)
    uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))

    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in arcs_from])

    println("add const...")

    min_t_delta = calc_min_phase_angle(buses, branches)
    max_t_delta = calc_max_phase_angle(buses, branches)

    @constraint(m, t[ref_bus] == 0)
    
    # does not seem to help
    #constraint_min_edge_count(m, z, buses)

    for (i,gen) in gens
        constraint_active_generation(m, pg[i], gen; var = uc[i])
    end

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_const(m, p_expr, pg, bus, bus_branches, bus_gens[i]; pd = pd[i])
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
    objective_max_active_load(m, pd, buses, bus_indexes)

    # needed for bonmin
    #objective_min_fuel_cost_nl(m, pg, gens, gen_indexes)


    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> NaN

    pd_val = i -> getvalue(pd[i])
    qd_val = i -> NaN

    v_val = i -> 1.0
    t_val = i -> getvalue(t[i])

    z_val = i -> getvalue(z[i])
    uc_val = i -> getvalue(uc[i]) 

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_status_setpoint(abstract_sol, data, uc_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end



# Implementation of the second order cone relaxation of the optimal power flow model
function SOC_LS_UC_TS(data, settings)
    println("build lookups...")
    ref_bus, buses, gens, branches, bus_gens, arcs_from, arcs_to, arcs = build_sets(data)

    println("build sets...")
    bus_indexes = collect(keys(buses))
    branch_indexes = collect(keys(branches))
    gen_indexes = collect(keys(gens))

    println("build model...")
    
    m = Model()

    println("add vars...")

    w  = voltage_magnitude_sqr_variables(m, buses, bus_indexes)

    z = line_indicator_variables(m, branch_indexes)
    uc = generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes, 1, "uc_start"))

    w_line_from = voltage_magnitude_sqr_from_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,1.001, "w_from_start"))
    w_line_to = voltage_magnitude_sqr_to_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,1.001, "w_to_start"))

    wr = real_complex_product_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,1.0, "wr_start"))
    wi = imaginary_complex_product_on_off_variables(m, z, branch_indexes, branches, buses)

    pd = active_load_variables(m, buses, bus_indexes)
    qd = reactive_load_variables(m, buses, bus_indexes)    

    pg = active_generation_variables(m, gens, gen_indexes)
    qg = reactive_generation_variables(m, gens, gen_indexes)

    p  = line_flow_variables(m, arcs, branches, branch_indexes)
    q  = line_flow_variables(m, arcs, branches, branch_indexes)    

    for (i,gen) in gens
        constraint_active_generation(m, pg[i], gen; var = uc[i])
        constraint_reactive_generation(m, qg[i], gen; var = uc[i])     
    end

    println("add const...")

    min_t_delta = calc_min_phase_angle(buses, branches)
    max_t_delta = calc_max_phase_angle(buses, branches)

    for (i,bus) in buses
        bus_branches = filter(x -> x[2] == i, arcs)
        constraint_active_kcl_shunt_w(m, p, pg, w[i], bus, bus_branches, bus_gens[i]; pd = pd[i])
        constraint_reactive_kcl_shunt_w(m, q, qg, w[i], bus, bus_branches, bus_gens[i]; qd = qd[i])
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
    objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)

    # needed for bonmin
    #objective_min_fuel_cost_nl(m, pg, gens, gen_indexes)


    println("add a-funs...")
    # build functions for getting values
    pg_val = i -> getvalue(pg[i])
    qg_val = i -> getvalue(qg[i])

    pd_val = i -> getvalue(pd[i])
    qd_val = i -> getvalue(qd[i])

    v_val = i -> sqrt(getvalue(w[i]))
    t_val = i -> 0

    z_val = i -> getvalue(z[i])
    uc_val = i -> getvalue(uc[i]) 

    abstract_sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(abstract_sol, data, v_val, t_val)
    add_bus_demand_setpoint(abstract_sol, data, pd_val, qd_val)
    add_generator_status_setpoint(abstract_sol, data, uc_val)
    add_generator_power_setpoint(abstract_sol, data, pg_val, qg_val)
    add_branch_status_setpoint(abstract_sol, data, z_val)

    return m, abstract_sol
end

