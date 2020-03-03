### w-theta form of the non-convex AC equations

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::AbstractACTModel, n::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, :va)[i] == 0)
end

""
function variable_voltage(pm::AbstractACTModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_model_voltage(pm::AbstractACTModel, n::Int)
    _check_missing_keys(var(pm, n), [:va,:w,:wr,:wi], typeof(pm))

    t  = var(pm, n, :va)
    w  = var(pm, n,  :w)
    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)

    for (i,j) in ids(pm, n, :buspairs)
        JuMP.@constraint(pm.model, wr[(i,j)]^2 + wi[(i,j)]^2 == w[i]*w[j])
        JuMP.@NLconstraint(pm.model, wi[(i,j)] == tan(t[i] - t[j])*wr[(i,j)])
    end
end


""
function constraint_power_balance_ls(pm::AbstractACTModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
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

    cstr_p = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd*z_demand[i] for (i,pd) in bus_pd)
        - sum(gs*z_shunt[i] for (i,gs) in bus_gs)*w
    )
    cstr_q = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd*z_demand[i] for (i,qd) in bus_qd)
        + sum(bs*z_shunt[i] for (i,bs) in bus_bs)*w
    )

    if report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end


"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_voltage_angle_difference(pm::AbstractACTModel, n::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, :va)[f_bus]
    va_to = var(pm, n, :va)[t_bus]

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin)
end
