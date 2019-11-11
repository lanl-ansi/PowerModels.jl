### the LPAC approximation

""
function variable_voltage(pm::AbstractLPACModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
    variable_cosine(pm; kwargs...)
end

""
function variable_voltage_magnitude(pm::AbstractLPACModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:phi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_phi",
            lower_bound = ref(pm, nw, :bus, i, "vmin", cnd) - 1.0,
            upper_bound = ref(pm, nw, :bus, i, "vmax", cnd) - 1.0,
            start = comp_start_value(ref(pm, nw, :bus, i), "phi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:phi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_phi",
            start = comp_start_value(ref(pm, nw, :bus, i), "phi_start", cnd)
        )
    end
end

""
function constraint_model_voltage(pm::AbstractLPACModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:va,:cs], typeof(pm))

    t = var(pm, n, c, :va)
    cs = var(pm, n, c, :cs)

    for (bp, buspair) in ref(pm, n, :buspairs)
        i,j = bp
        vad_max = max(abs(buspair["angmin"]), abs(buspair["angmax"]))
        JuMP.@constraint(pm.model, cs[bp] <= 1 - (1-cos(vad_max))/vad_max^2*(t[i] - t[j])^2)
   end
end


""
function constraint_power_balance(pm::AbstractLPACModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    phi  = var(pm, n, c, :phi, i)
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
        - sum(gs for gs in values(bus_gs))*(1.0 + 2*phi)
    )
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*(1.0 + 2*phi)
    )
end


""
function constraint_ohms_yt_from(pm::AbstractLPACCModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr   = var(pm, n, c, :p, f_idx)
    q_fr   = var(pm, n, c, :q, f_idx)
    phi_fr = var(pm, n, c, :phi, f_bus)
    phi_to = var(pm, n, c, :phi, t_bus)
    va_fr  = var(pm, n, c, :va, f_bus)
    va_to  = var(pm, n, c, :va, t_bus)
    cs     = var(pm, n, c, :cs, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(1.0 + 2*phi_fr) + (-g*tr+b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr-g*ti)/tm^2*(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(1.0 + 2*phi_fr) - (-b*tr-g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr+b*ti)/tm^2*(va_fr-va_to) )
end

""
function constraint_ohms_yt_to(pm::AbstractLPACCModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    p_to   = var(pm, n, c, :p, t_idx)
    q_to   = var(pm, n, c, :q, t_idx)
    phi_fr = var(pm, n, c, :phi, f_bus)
    phi_to = var(pm, n, c, :phi, t_bus)
    va_fr  = var(pm, n, c, :va, f_bus)
    va_to  = var(pm, n, c, :va, t_bus)
    cs     = var(pm, n, c, :cs, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(1.0 + 2*phi_to) + (-g*tr-b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr+g*ti)/tm^2*-(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(1.0 + 2*phi_to) - (-b*tr+g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr-b*ti)/tm^2*-(va_fr-va_to) )
end


""
function add_setpoint_bus_voltage!(sol, pm::AbstractLPACModel)
    add_setpoint!(sol, pm, "bus", "vm", :phi, status_name="bus_type", inactive_status_value = 4, scale = (x,item,cnd) -> 1.0+x)
    add_setpoint!(sol, pm, "bus", "va", :va, status_name="bus_type", inactive_status_value = 4)
end

