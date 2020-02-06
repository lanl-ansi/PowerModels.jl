### the LPAC approximation

""
function variable_voltage(pm::AbstractLPACModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
    variable_cosine(pm; kwargs...)
end

""
function variable_voltage_magnitude(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    phi = var(pm, nw)[:phi] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :bus)], base_name="$(nw)_phi",
        start = comp_start_value(ref(pm, nw, :bus, i), "phi_start")
    )

    if bounded
        for (i, bus) in ref(pm, nw, :bus)
            JuMP.set_lower_bound(phi[i], bus["vmin"] - 1.0)
            JuMP.set_upper_bound(phi[i], bus["vmax"] - 1.0)
        end
    end

    report && sol_component_value(pm, nw, :bus, :phi, ids(pm, nw, :bus), phi)
end

""
function sol_data_model!(pm::AbstractLPACModel, solution::Dict)
    if haskey(solution, "nw")
        nws_data = solution["nw"]
    else
        nws_data = Dict("0" => solution)
    end

    for (n, nw_data) in nws_data
        if haskey(nw_data, "bus")
            for (i,bus) in nw_data["bus"]
                if haskey(bus, "phi")
                    bus["vm"] = 1.0 + bus["phi"]
                    delete!(bus, "phi")
                end
            end
        end
    end
end

""
function constraint_model_voltage(pm::AbstractLPACModel, n::Int)
    _check_missing_keys(var(pm, n), [:va,:cs], typeof(pm))

    t = var(pm, n, :va)
    cs = var(pm, n, :cs)

    for (bp, buspair) in ref(pm, n, :buspairs)
        i,j = bp
        vad_max = max(abs(buspair["angmin"]), abs(buspair["angmax"]))
        JuMP.@constraint(pm.model, cs[bp] <= 1 - (1-cos(vad_max))/vad_max^2*(t[i] - t[j])^2)
   end
end


""
function constraint_power_balance(pm::AbstractLPACModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    phi  = var(pm, n, :phi, i)
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
        - sum(gs for gs in values(bus_gs))*(1.0 + 2*phi)
    )
    cstr_q = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*(1.0 + 2*phi)
    )

    if report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end


""
function constraint_ohms_yt_from(pm::AbstractLPACCModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr   = var(pm, n, :p, f_idx)
    q_fr   = var(pm, n, :q, f_idx)
    phi_fr = var(pm, n, :phi, f_bus)
    phi_to = var(pm, n, :phi, t_bus)
    va_fr  = var(pm, n, :va, f_bus)
    va_to  = var(pm, n, :va, t_bus)
    cs     = var(pm, n, :cs, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(1.0 + 2*phi_fr) + (-g*tr+b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr-g*ti)/tm^2*(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(1.0 + 2*phi_fr) - (-b*tr-g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr+b*ti)/tm^2*(va_fr-va_to) )
end

""
function constraint_ohms_yt_to(pm::AbstractLPACCModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    p_to   = var(pm, n, :p, t_idx)
    q_to   = var(pm, n, :q, t_idx)
    phi_fr = var(pm, n, :phi, f_bus)
    phi_to = var(pm, n, :phi, t_bus)
    va_fr  = var(pm, n, :va, f_bus)
    va_to  = var(pm, n, :va, t_bus)
    cs     = var(pm, n, :cs, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(1.0 + 2*phi_to) + (-g*tr-b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr+g*ti)/tm^2*-(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(1.0 + 2*phi_to) - (-b*tr+g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr-b*ti)/tm^2*-(va_fr-va_to) )
end

