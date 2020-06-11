### the LPAC approximation

""
function variable_bus_voltage(pm::AbstractLPACModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)
    variable_buspair_cosine(pm; kwargs...)
end

""
function variable_bus_voltage_magnitude(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
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

    report && _IM.sol_component_value(pm, nw, :bus, :phi, ids(pm, nw, :bus), phi)
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

    if _IM.report_duals(pm)
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

"`angmin*branch_ne[i] + vad_min*(1-branch_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_ne[i] + vad_max*(1-branch_ne[i])`"
function constraint_ne_voltage_angle_difference(pm::AbstractLPACCModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

""
function variable_ne_branch_voltage(pm::AbstractLPACCModel; kwargs...)
    variable_ne_branch_voltage_magnitude_fr(pm; kwargs...)
    variable_ne_branch_voltage_magnitude_to(pm; kwargs...)
    variable_ne_branch_voltage_angle_fr(pm; kwargs...)
    variable_ne_branch_voltage_angle_to(pm; kwargs...)
    variable_ne_branch_cosine(pm; kwargs...)
end

""
function variable_ne_branch_voltage_magnitude_fr(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    phi_fr_ne = var(pm, nw)[:phi_fr_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_phi_fr_ne",
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["f_bus"]), "phi_fr_start")
    )

    if bounded
        for (i, branch) in ref(pm, nw, :ne_branch)
            JuMP.set_lower_bound(phi_fr_ne[i], buses[branches[i]["f_bus"]]["vmin"] - 1.0)
            JuMP.set_upper_bound(phi_fr_ne[i], buses[branches[i]["f_bus"]]["vmax"] - 1.0)
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_branch, :phi_fr, ids(pm, nw, :ne_branch), phi_fr_ne)
end

""
function variable_ne_branch_voltage_magnitude_to(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    phi_to_ne = var(pm, nw)[:phi_to_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_phi_to_ne",
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["t_bus"]), "phi_to_start")
    )

    if bounded
        for (i, branch) in ref(pm, nw, :ne_branch)
            JuMP.set_lower_bound(phi_to_ne[i], buses[branches[i]["t_bus"]]["vmin"] - 1.0)
            JuMP.set_upper_bound(phi_to_ne[i], buses[branches[i]["t_bus"]]["vmax"] - 1.0)
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_branch, :phi_to, ids(pm, nw, :ne_branch), phi_to_ne)
end

""
function variable_ne_branch_voltage_angle_fr(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    va_fr_ne = var(pm, nw)[:va_fr_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_va_fr_ne",
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["f_bus"]), "va_fr_start")
    )

    # may be bounds can be added in future
    report && _IM.sol_component_value(pm, nw, :ne_branch, :va_fr, ids(pm, nw, :ne_branch), va_fr_ne)
end

""
function variable_ne_branch_voltage_angle_to(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    va_to_ne = var(pm, nw)[:va_to_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_va_to_ne",
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["t_bus"]), "va_to_start")
    )

    # may be bounds can be added in future
    report && _IM.sol_component_value(pm, nw, :ne_branch, :va_to, ids(pm, nw, :ne_branch), va_to_ne)
end


function variable_ne_branch_cosine(pm::AbstractLPACCModel; nw::Int=pm.cnw, report::Bool=true)

    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :ne_branch))
    buspair = ref(pm, nw, :ne_buspairs)
    cs_ne = var(pm, nw)[:cs_ne] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :ne_branch)], base_name="$(nw)_cs_ne",
        lower_bound = 0,
        upper_bound = 1,
        start = comp_start_value(ref(pm, nw, :ne_buspairs, bi_bp[b]), "cs_start", 1.0)
    )

    report && _IM.sol_component_value(pm, nw, :ne_branch, :cs_ne, ids(pm, nw, :ne_branch), cs_ne)
end


function constraint_ne_model_voltage(pm::AbstractLPACCModel, n::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :ne_branch)
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in branches)
    buspair = ref(pm, n, :ne_buspairs)
    cos_min, cos_max  = ref_calc_angle_difference_bounds(ref(pm, n, :ne_buspairs))

    phi  = var(pm, n, :phi)
    z  = var(pm, n, :branch_ne)

    cs = var(pm, n, :cs)
    cs_ne = var(pm, n, :cs_ne)
    phi_fr = var(pm, n, :phi_fr_ne)
    phi_to = var(pm, n, :phi_to_ne)
    for (l,i,j) in ref(pm, n, :ne_arcs_from)
        JuMP.@constraint(pm.model, phi_fr[l] <= z[l]*(buses[branches[l]["f_bus"]]["vmax"]-1))
        JuMP.@constraint(pm.model, phi_fr[l] >= z[l]*(buses[branches[l]["f_bus"]]["vmin"]-1))

        JuMP.@constraint(pm.model, cs_ne[l] <= z[l]*cos_max[bi_bp[l]])
        JuMP.@constraint(pm.model, cs_ne[l] >= z[l]*cos_min[bi_bp[l]])

        JuMP.@constraint(pm.model, phi_to[l] <= z[l]*(buses[branches[l]["t_bus"]]["vmax"]-1))
        JuMP.@constraint(pm.model, phi_to[l] >= z[l]*(buses[branches[l]["t_bus"]]["vmin"]-1))

        _IM.relaxation_equality_on_off(pm.model, phi[i], phi_fr[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, phi[j], phi_to[l], z[l])
    end

    # Cosine constraint can be moved to a different function for neatness
    _check_missing_keys(var(pm, n), [:va,:cs_ne], typeof(pm))
    t = var(pm, n, :va)
    cs = var(pm, n, :cs_ne)
    for (l,i,j) in ref(pm, n, :ne_arcs_from)
        vad_max = max(abs(buspair[bi_bp[l]]["angmin"]), abs(buspair[bi_bp[l]]["angmax"]))
        JuMP.@constraint(pm.model, cs[l] <= 1 - (1-cos(vad_max))/vad_max^2*(t[i] - t[j])^2)
   end
end

""
function constraint_ne_power_balance(pm::AbstractLPACCModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_arcs_ne, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
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
        - sum(gs for gs in values(bus_gs))*(1 + 2*phi)
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
        + sum(bs for bs in values(bus_bs))*(1 + 2*phi)
    )

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

""
function constraint_ne_ohms_yt_from(pm::AbstractLPACCModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n,    :p_ne, f_idx)
    q_fr = var(pm, n,    :q_ne, f_idx)
    phi_fr = var(pm, n, :phi_fr_ne, i)
    phi_to = var(pm, n, :phi_to_ne, i)
    va_fr  = var(pm, n, :va_fr_ne, i)
    va_to  = var(pm, n, :va_to_ne, i)
    cs     = var(pm, n, :cs_ne, i)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(z + 2*phi_fr) + (-g*tr+b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr-g*ti)/tm^2*(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(z + 2*phi_fr) - (-b*tr-g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr+b*ti)/tm^2*(va_fr-va_to) )
end

""
function constraint_ne_ohms_yt_to(pm::AbstractLPACCModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n,    :p_ne, t_idx)
    q_to = var(pm, n,    :q_ne, t_idx)
    phi_fr = var(pm, n, :phi_fr_ne, i)
    phi_to = var(pm, n, :phi_to_ne, i)
    va_fr  = var(pm, n, :va_fr_ne, i)
    va_to  = var(pm, n, :va_to_ne, i)
    cs     = var(pm, n, :cs_ne, i)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(z + 2*phi_to) + (-g*tr-b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr+g*ti)/tm^2*-(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(z + 2*phi_to) - (-b*tr+g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr-b*ti)/tm^2*-(va_fr-va_to) )
end


function ref_calc_angle_difference_bounds(buspairs, conductor::Int=1)
    cos_min = Dict((bp, -Inf) for bp in keys(buspairs))
    cos_max = Dict((bp, Inf) for bp in keys(buspairs))

    buspairs_conductor = Dict()
    for (bp, buspair) in buspairs
        buspairs_conductor[bp] = Dict( k => v[conductor] for (k,v) in buspair)
    end

    for (bp, buspair) in buspairs_conductor
        if buspair["angmin"] >= 0
            cos_max[bp] = cos(buspair["angmin"])
            cos_min[bp] = cos(buspair["angmax"])
        end
        if buspair["angmax"] <= 0
            cos_max[bp] = cos(buspair["angmax"])
            cos_min[bp] = cos(buspair["angmin"])
        end
        if buspair["angmin"] < 0 && buspair["angmax"] > 0
            cos_max[bp] = 1.0
            cos_min[bp] = min(cos(buspair["angmin"]), cos(buspair["angmax"]))
        end
    end

    return cos_min, cos_max

end
