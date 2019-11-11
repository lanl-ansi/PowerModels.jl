#
# Shared Formulation Definitions
#################################
#
# This is the home of functions that are shared across multiple branches
# of the type hierarchy.  Hence all function in this file should be over
# union types.
#
# The types defined in this file should not be exported because they exist
# only to prevent code replication
#

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::AbstractPolarModels, n::Int, c::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, c, :va)[i] == 0)
end

"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_voltage_angle_difference(pm::AbstractPolarModels, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin)
end


""
function variable_bus_voltage(pm::AbstractWModels; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
end

""
function constraint_voltage_magnitude_setpoint(pm::AbstractWModels, n::Int, c::Int, i, vm)
    w = var(pm, n, c, :w, i)

    JuMP.@constraint(pm.model, w == vm^2)
end

"Do nothing, no way to represent this in these variables"
function constraint_theta_ref(pm::AbstractWModels, n::Int, c::Int, ref_bus::Int)
end


""
function constraint_power_balance(pm::AbstractWModels, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, c, :w, i)
    p    = get(var(pm, n, c),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n, c),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n, c),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n, c),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n, c),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n, c),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n, c),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n, c),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n, c), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n, c), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")


    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*w
    )
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*w
    )
end


""
function constraint_power_balance_ne(pm::AbstractWModels, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_arcs_ne, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, c, :w, i)
    p    = get(var(pm, n, c),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n, c),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n, c),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n, c),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n, c),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n, c),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n, c),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n, c),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n, c), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n, c), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")
    p_ne = get(var(pm, n, c), :p_ne, Dict()); _check_var_keys(p_ne, bus_arcs_ne, "active power", "ne_branch")
    q_ne = get(var(pm, n, c), :q_ne, Dict()); _check_var_keys(q_ne, bus_arcs_ne, "reactive power", "ne_branch")


    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        + sum(p_ne[a] for a in bus_arcs_ne)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*w
    )
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        + sum(q_ne[a] for a in bus_arcs_ne)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*w
    )
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::AbstractWRModels, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    w_fr = var(pm, n, c, :w, f_bus)
    wr   = var(pm, n, c, :wr, (f_bus, t_bus))
    wi   = var(pm, n, c, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::AbstractWRModels, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    q_to = var(pm, n, c, :q, t_idx)
    p_to = var(pm, n, c, :p, t_idx)
    w_to = var(pm, n, c, :w, t_bus)
    wr   = var(pm, n, c, :wr, (f_bus, t_bus))
    wi   = var(pm, n, c, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end


""
function constraint_voltage_angle_difference(pm::AbstractWModels, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    wr   = var(pm, n, c, :wr, (f_bus, t_bus))
    wi   = var(pm, n, c, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)
    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end


""
function constraint_network_power_balance(pm::AbstractWModels, n::Int, c::Int, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b)
    for (i,(i,j,r,x,tm,g_fr,g_to)) in comp_branch_g
        @assert(r >= 0 && x >= 0) # requirement for the relaxation property
    end

    pg = var(pm, n, c, :pg)
    qg = var(pm, n, c, :qg)
    w = var(pm, n, c, :w)

    JuMP.@constraint(pm.model, sum(pg[g] for g in comp_gen_ids) >= sum(pd for (i,pd) in values(comp_pd)) + sum(gs*w[i] for (i,gs) in values(comp_gs)) + sum(g_fr*w[i]/tm^2 + g_to*w[j] for (i,j,r,x,tm,g_fr,g_to) in values(comp_branch_g)))
    JuMP.@constraint(pm.model, sum(qg[g] for g in comp_gen_ids) >= sum(qd for (i,qd) in values(comp_qd)) - sum(bs*w[i] for (i,bs) in values(comp_bs)) - sum(b_fr*w[i]/tm^2 + b_to*w[j] for (i,j,r,x,tm,b_fr,b_to) in values(comp_branch_b)))
end


""
function constraint_switch_state_closed(pm::AbstractWModels, n::Int, c::Int, f_bus, t_bus)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)

    JuMP.@constraint(pm.model, w_fr == w_to)
end

""
function constraint_switch_voltage_on_off(pm::AbstractWModels, n::Int, c::Int, i, f_bus, t_bus, vad_min, vad_max)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    z = var(pm, n, :z_switch, i)

    w_fr_lb, w_fr_ub = InfrastructureModels.variable_domain(w_fr)
    w_to_lb, w_to_ub = InfrastructureModels.variable_domain(w_to)

    @assert w_fr_lb >= 0.0 && w_to_lb >= 0.0

    off_ub = w_fr_ub - w_to_lb
    off_lb = w_fr_lb - w_to_ub

    JuMP.@constraint(pm.model, 0.0 <= (w_fr - w_to) + off_ub*(1-z))
    JuMP.@constraint(pm.model, 0.0 >= (w_fr - w_to) + off_lb*(1-z))
end



""
function constraint_current_limit(pm::AbstractWModels, n::Int, c::Int, f_idx, c_rating_a)
    l,i,j = f_idx
    t_idx = (l,j,i)

    w_fr = var(pm, n, c, :w, i)
    w_to = var(pm, n, c, :w, j)

    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w_fr*c_rating_a^2)

    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= w_to*c_rating_a^2)
end


""
function add_setpoint_bus_voltage!(sol, pm::AbstractWModels)
    add_setpoint!(sol, pm, "bus", "vm", :w, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"], scale = (x,item,cnd) -> sqrt(x))
    # What should the default value be?
    add_setpoint!(sol, pm, "bus", "va", :va, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"])
end
