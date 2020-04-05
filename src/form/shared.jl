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


""
function variable_shunt_factor(pm::AbstractWConvexModels; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    if !relax
        z_shunt = var(pm, nw)[:z_shunt] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :shunt)], base_name="$(nw)_z_shunt",
            binary = true,
            start = comp_start_value(ref(pm, nw, :shunt, i), "z_shunt_start", 1.0)
        )
    else
        z_shunt = var(pm, nw)[:z_shunt] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :shunt)], base_name="$(nw)_z_shunt",
            upper_bound = 1,
            lower_bound = 0,
            start = comp_start_value(ref(pm, nw, :shunt, i), "z_shunt_start", 1.0)
        )
    end
    wz_shunt = var(pm, nw)[:wz_shunt] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :shunt)], base_name="$(nw)_wz_shunt",
        lower_bound = 0,
        upper_bound = ref(pm, nw, :bus)[ref(pm, nw, :shunt, i)["shunt_bus"]]["vmax"]^2,
        start = comp_start_value(ref(pm, nw, :shunt, i), "wz_shunt_start", 1.001)
    )

    report && _IM.sol_component_value(pm, nw, :shunt, :status, ids(pm, nw, :shunt), z_shunt)
    report && _IM.sol_component_value(pm, nw, :shunt, :wz_shunt, ids(pm, nw, :shunt), wz_shunt)
end


"do nothing by default but some formulations require this"
function variable_current_storage(pm::AbstractWConvexModels; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    ccms = var(pm, nw)[:ccms] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_ccms",
        start = comp_start_value(ref(pm, nw, :storage, i), "ccms_start")
    )

    if bounded
        bus = ref(pm, nw, :bus)
        for (i, storage) in ref(pm, nw, :storage)
            ub = Inf
            if haskey(storage, "thermal_rating")
                sb = bus[storage["storage_bus"]]
                ub = (storage["thermal_rating"]/sb["vmin"])^2
            end

            JuMP.set_lower_bound(ccms[i], 0.0)
            if !isinf(ub)
                JuMP.set_upper_bound(ccms[i], ub)
            end
        end
    end

    report && _IM.sol_component_value(pm, nw, :storage, :ccms, ids(pm, nw, :storage), ccms)
end


"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::AbstractPolarModels, n::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, :va)[i] == 0)
end

"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_voltage_angle_difference(pm::AbstractPolarModels, n::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin)
end


""
function variable_bus_voltage(pm::AbstractWModels; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
end

""
function constraint_voltage_magnitude_setpoint(pm::AbstractWModels, n::Int, i, vm)
    w = var(pm, n, :w, i)

    JuMP.@constraint(pm.model, w == vm^2)
end

"Do nothing, no way to represent this in these variables"
function constraint_theta_ref(pm::AbstractWModels, n::Int, ref_bus::Int)
end

""
function sol_data_model!(pm::AbstractWModels, solution::Dict)
    if haskey(solution, "nw")
        nws_data = solution["nw"]
    else
        nws_data = Dict("0" => solution)
    end

    for (n, nw_data) in nws_data
        if haskey(nw_data, "bus")
            for (i,bus) in nw_data["bus"]
                if haskey(bus, "w")
                    bus["vm"] = sqrt(bus["w"])
                    delete!(bus, "w")
                end
            end
        end
    end
end


""
function constraint_power_balance(pm::AbstractWModels, n::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, :w, i)
    p    = get(var(pm, n),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")


    cstr_p = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*w
    )
    cstr_q = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*w
    )

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end


""
function constraint_power_balance_ls(pm::AbstractWConvexModels, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, :w, i)
    p    = get(var(pm, n),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")

    z_demand = get(var(pm, n), :z_demand, Dict()); _check_var_keys(z_demand, keys(bus_pd), "power factor", "load")
    z_shunt = get(var(pm, n), :z_shunt, Dict()); _check_var_keys(z_shunt, keys(bus_gs), "power factor", "shunt")
    wz_shunt = get(var(pm, n), :wz_shunt, Dict()); _check_var_keys(wz_shunt, keys(bus_gs), "voltage square power factor", "shunt")

    cstr_p = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd*z_demand[i] for (i,pd) in bus_pd)
        - sum(gs*wz_shunt[i] for (i,gs) in bus_gs)
    )
    cstr_q = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd*z_demand[i] for (i,qd) in bus_qd)
        + sum(bs*wz_shunt[i] for (i,bs) in bus_bs)
    )

    for s in keys(bus_gs)
        _IM.relaxation_product(pm.model, w, z_shunt[s], wz_shunt[s])
    end

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end


""
function constraint_power_balance_ne(pm::AbstractWModels, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_arcs_ne, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, :w, i)
    p    = get(var(pm, n),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")
    p_ne = get(var(pm, n), :p_ne, Dict()); _check_var_keys(p_ne, bus_arcs_ne, "active power", "ne_branch")
    q_ne = get(var(pm, n), :q_ne, Dict()); _check_var_keys(q_ne, bus_arcs_ne, "reactive power", "ne_branch")


    cstr_p = JuMP.@constraint(pm.model,
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
    cstr_q = JuMP.@constraint(pm.model,
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

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end


""
function expression_branch_flow_yt_from(pm::AbstractWRModels, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    w_fr = var(pm, n, :w, f_bus)
    wr   = var(pm, n, :wr, (f_bus, t_bus))
    wi   = var(pm, n, :wi, (f_bus, t_bus))

    var(pm, n, :p)[f_idx] =  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi
    var(pm, n, :q)[f_idx] = -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi
end


""
function expression_branch_flow_yt_to(pm::AbstractWRModels, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    w_to = var(pm, n, :w, t_bus)
    wr   = var(pm, n, :wr, (f_bus, t_bus))
    wi   = var(pm, n, :wi, (f_bus, t_bus))

    var(pm, n, :p)[t_idx] =  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi
    var(pm, n, :q)[t_idx] = -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::AbstractWRModels, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    w_fr = var(pm, n, :w, f_bus)
    wr   = var(pm, n, :wr, (f_bus, t_bus))
    wi   = var(pm, n, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::AbstractWRModels, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    q_to = var(pm, n, :q, t_idx)
    p_to = var(pm, n, :p, t_idx)
    w_to = var(pm, n, :w, t_bus)
    wr   = var(pm, n, :wr, (f_bus, t_bus))
    wi   = var(pm, n, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end


""
function constraint_voltage_angle_difference(pm::AbstractWModels, n::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    wr   = var(pm, n, :wr, (f_bus, t_bus))
    wi   = var(pm, n, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)
    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end


""
function constraint_network_power_balance(pm::AbstractWModels, n::Int, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b)
    for (i,(i,j,r,x,tm,g_fr,g_to)) in comp_branch_g
        @assert(r >= 0 && x >= 0) # requirement for the relaxation property
    end

    pg = var(pm, n, :pg)
    qg = var(pm, n, :qg)
    w = var(pm, n, :w)

    JuMP.@constraint(pm.model, sum(pg[g] for g in comp_gen_ids) >= sum(pd for (i,pd) in values(comp_pd)) + sum(gs*w[i] for (i,gs) in values(comp_gs)) + sum(g_fr*w[i]/tm^2 + g_to*w[j] for (i,j,r,x,tm,g_fr,g_to) in values(comp_branch_g)))
    JuMP.@constraint(pm.model, sum(qg[g] for g in comp_gen_ids) >= sum(qd for (i,qd) in values(comp_qd)) - sum(bs*w[i] for (i,bs) in values(comp_bs)) - sum(b_fr*w[i]/tm^2 + b_to*w[j] for (i,j,r,x,tm,b_fr,b_to) in values(comp_branch_b)))
end


""
function constraint_switch_state_closed(pm::AbstractWModels, n::Int, f_bus, t_bus)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)

    JuMP.@constraint(pm.model, w_fr == w_to)
end

""
function constraint_switch_voltage_on_off(pm::AbstractWModels, n::Int, i, f_bus, t_bus, vad_min, vad_max)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    z = var(pm, n, :z_switch, i)

    w_fr_lb, w_fr_ub = _IM.variable_domain(w_fr)
    w_to_lb, w_to_ub = _IM.variable_domain(w_to)

    @assert w_fr_lb >= 0.0 && w_to_lb >= 0.0

    off_ub = w_fr_ub - w_to_lb
    off_lb = w_fr_lb - w_to_ub

    JuMP.@constraint(pm.model, 0.0 <= (w_fr - w_to) + off_ub*(1-z))
    JuMP.@constraint(pm.model, 0.0 >= (w_fr - w_to) + off_lb*(1-z))
end



""
function constraint_current_limit(pm::AbstractWModels, n::Int, f_idx, c_rating_a)
    l,i,j = f_idx
    t_idx = (l,j,i)

    w_fr = var(pm, n, :w, i)
    w_to = var(pm, n, :w, j)

    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w_fr*c_rating_a^2)

    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= w_to*c_rating_a^2)
end

""
function constraint_storage_loss(pm::AbstractWConvexModels, n::Int, i, bus, r, x, p_loss, q_loss; conductors=[1])
    w = var(pm, n, :w, bus)
    ccms = var(pm, n, :ccms, i)
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    for c in conductors
        JuMP.@constraint(pm.model, ps[c]^2 + qs[c]^2 <= w[c]*ccms[c])
    end

    JuMP.@constraint(pm.model,
        sum(ps[c] for c in conductors) + (sd - sc)
        ==
        p_loss + sum(r[c]*ccms[c] for c in conductors)
    )

    JuMP.@constraint(pm.model,
        sum(qs[c] for c in conductors)
        ==
        q_loss + sum(x[c]*ccms[c] for c in conductors)
    )
end
