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

"`angmin*z_branch[i] + vad_min*(1-z_branch[i]) <= t[f_bus] - t[t_bus] <= angmax*z_branch[i] + vad_max*(1-z_branch[i])`"
function constraint_voltage_angle_difference_on_off(pm::AbstractLPACCModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

""
function variable_ne_branch_voltage(pm::AbstractLPACCModel; kwargs...)
    variable_ne_branch_voltage_magnitude_fr(pm; kwargs...)
    variable_ne_branch_voltage_magnitude_to(pm; kwargs...)
    variable_ne_branch_voltage_product_angle(pm; kwargs...)
    variable_ne_branch_cosine(pm; kwargs...)
end

""
function variable_ne_branch_voltage_magnitude_fr(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    phi_fr_ne = var(pm, nw)[:phi_fr_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_phi_fr_ne",
        lower_bound = min(0, buses[branches[i]["f_bus"]]["vmin"] - 1.0),
        upper_bound = max(0, buses[branches[i]["f_bus"]]["vmax"] - 1.0),
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["f_bus"]), "phi_fr_start")
    )

    report && _IM.sol_component_value(pm, nw, :ne_branch, :phi_fr, ids(pm, nw, :ne_branch), phi_fr_ne)
end

""
function variable_ne_branch_voltage_magnitude_to(pm::AbstractLPACModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    phi_to_ne = var(pm, nw)[:phi_to_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_phi_to_ne",
        lower_bound = min(0, buses[branches[i]["t_bus"]]["vmin"] - 1.0),
        upper_bound = max(0, buses[branches[i]["t_bus"]]["vmax"] - 1.0),
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["t_bus"]), "phi_to_start")
    )


    report && _IM.sol_component_value(pm, nw, :ne_branch, :phi_to, ids(pm, nw, :ne_branch), phi_to_ne)
end

""
function variable_ne_branch_cosine(pm::AbstractLPACCModel; nw::Int=pm.cnw, report::Bool=true)
    cos_min = Dict((l, -Inf) for l in ids(pm, nw, :ne_branch))
    cos_max = Dict((l,  Inf) for l in ids(pm, nw, :ne_branch))

    for (l, branch) in ref(pm, nw, :ne_branch)
        angmin = branch["angmin"]
        angmax = branch["angmax"]
        if angmin >= 0
            cos_max[l] = cos(angmin)
            cos_min[l] = cos(angmax)
        end
        if angmax <= 0
            cos_max[l] = cos(angmax)
            cos_min[l] = cos(angmin)
        end
        if angmin < 0 && angmax > 0
            cos_max[l] = 1.0
            cos_min[l] = min(cos(angmin), cos(angmax))
        end
    end

    cs_ne = var(pm, nw)[:cs_ne] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :ne_branch)], base_name="$(nw)_cs_ne",
        lower_bound = min(0, cos_min[l]),
        upper_bound = max(0, cos_max[l]),
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "cs_start", 1.0)
    )

    report && _IM.sol_component_value(pm, nw, :ne_branch, :cs_ne, ids(pm, nw, :ne_branch), cs_ne)
end

""
function variable_ne_branch_voltage_product_angle(pm::AbstractLPACCModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :ne_branch))
     buspair = ref(pm, nw, :ne_buspairs)
     td_ne = var(pm, nw)[:td_ne] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :ne_branch)], base_name="$(nw)_td_ne",
        lower_bound = min(0, buspair[bi_bp[b]]["angmin"]),
        upper_bound = max(0, buspair[bi_bp[b]]["angmax"]),
        start = comp_start_value(ref(pm, nw, :ne_buspairs, bi_bp[b]), "td_start")
    )

    report && _IM.sol_component_value(pm, nw, :ne_branch, :td_ne, ids(pm, nw, :ne_branch), td_ne)
end

""
function constraint_model_voltage_on_off(pm::AbstractLPACCModel, n::Int)
    phi  = var(pm, n, :phi)
    t = var(pm, n, :va)
    phi_fr = var(pm, n, :phi_fr)
    phi_to = var(pm, n, :phi_to)

    td = var(pm, n, :td)
    cs = var(pm, n, :cs)

    z = var(pm, n, :z_branch)

    td_lb = ref(pm, n, :off_angmin)
    td_ub = ref(pm, n, :off_angmax)
    td_max = max(abs(td_lb), abs(td_ub))


    for (l, branch) in ref(pm, n, :branch)
        i = branch["f_bus"]
        j = branch["t_bus"]

        JuMP.@constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        JuMP.@constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))
        relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)

        _IM.constraint_bounds_on_off(pm.model, td[l], z[l])
        _IM.constraint_bounds_on_off(pm.model, phi_fr[l], z[l])
        _IM.constraint_bounds_on_off(pm.model, phi_to[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, phi[i], phi_fr[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, phi[j], phi_to[l], z[l])
    end
end

""
function constraint_ne_model_voltage(pm::AbstractLPACCModel, n::Int)
    phi  = var(pm, n, :phi)
    t = var(pm, n, :va)
    phi_fr_ne = var(pm, n, :phi_fr_ne)
    phi_to_ne = var(pm, n, :phi_to_ne)

    cs_ne = var(pm, n, :cs_ne)
    td_ne = var(pm, n , :td_ne)

    z = var(pm, n, :branch_ne)

    td_lb = ref(pm, n, :off_angmin)
    td_ub = ref(pm, n, :off_angmax)
    td_max = max(abs(td_lb), abs(td_ub))

    for (l,branch) in ref(pm, n, :ne_branch)
        i = branch["f_bus"]
        j = branch["t_bus"]
        JuMP.@constraint(pm.model, t[i] - t[j] >= td_ne[l] + td_lb*(1-z[l]))
        JuMP.@constraint(pm.model, t[i] - t[j] <= td_ne[l] + td_ub*(1-z[l]))

        relaxation_cos_on_off(pm.model, td_ne[l], cs_ne[l], z[l], td_max)

        _IM.constraint_bounds_on_off(pm.model, phi_fr_ne[l], z[l])
        _IM.constraint_bounds_on_off(pm.model, phi_to_ne[l], z[l])
        _IM.constraint_bounds_on_off(pm.model, td_ne[l], z[l])

        _IM.relaxation_equality_on_off(pm.model, phi[i], phi_fr_ne[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, phi[j], phi_to_ne[l], z[l])
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
    td = var(pm, n, :td_ne, i)
    cs = var(pm, n, :cs_ne, i)
    z = var(pm, n, :branch_ne, i)
    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(z + 2*phi_fr) + (-g*tr+b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr-g*ti)/tm^2*(td))
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(z + 2*phi_fr) - (-b*tr-g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr+b*ti)/tm^2*(td))
end

""
function constraint_ne_ohms_yt_to(pm::AbstractLPACCModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n,    :p_ne, t_idx)
    q_to = var(pm, n,    :q_ne, t_idx)
    phi_fr = var(pm, n, :phi_fr_ne, i)
    phi_to = var(pm, n, :phi_to_ne, i)
    td = var(pm, n, :td_ne, i)
    cs = var(pm, n, :cs_ne, i)
    z = var(pm, n, :branch_ne, i)
    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(z + 2*phi_to) + (-g*tr-b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr+g*ti)/tm^2*-(td) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(z + 2*phi_to) - (-b*tr+g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr-b*ti)/tm^2*-(td) )
end

""

function variable_bus_voltage_on_off(pm::AbstractLPACCModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)

    variable_branch_voltage_magnitude_fr_on_off(pm; kwargs...)
    variable_branch_voltage_magnitude_to_on_off(pm; kwargs...)
    variable_branch_voltage_product_angle_on_off(pm; kwargs...)
    variable_branch_cosine_on_off(pm; kwargs...)
end


""
function variable_branch_voltage_magnitude_fr_on_off(pm::AbstractLPACCModel; nw::Int=pm.cnw, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    phi_fr = var(pm, nw)[:phi_fr] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], base_name="$(nw)_phi_fr",
        lower_bound = min(0, buses[branches[i]["f_bus"]]["vmin"] - 1.0),
        upper_bound = max(0, buses[branches[i]["f_bus"]]["vmax"] - 1.0),
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["f_bus"]), "phi_fr_start")
    )

    report && _IM.sol_component_value(pm, nw, :branch, :phi_fr, ids(pm, nw, :branch), phi_fr)
end

""
function variable_branch_voltage_magnitude_to_on_off(pm::AbstractLPACCModel; nw::Int=pm.cnw, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    phi_to = var(pm, nw)[:phi_to] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], base_name="$(nw)_phi_to",
        lower_bound = min(0, buses[branches[i]["t_bus"]]["vmin"] - 1.0),
        upper_bound = max(0, buses[branches[i]["t_bus"]]["vmax"] - 1.0),
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["t_bus"]), "phi_to_start")
    )

    report && _IM.sol_component_value(pm, nw, :branch, :phi_to, ids(pm, nw, :branch), phi_to)
end


function constraint_ohms_yt_from_on_off(pm::AbstractLPACCModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n,    :p, f_idx)
    q_fr = var(pm, n,    :q, f_idx)
    phi_fr = var(pm, n, :phi_fr, i)
    phi_to = var(pm, n, :phi_to, i)
    td = var(pm, n, :td, i)
    cs = var(pm, n, :cs, i)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(z + 2*phi_fr) + (-g*tr+b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr-g*ti)/tm^2*(td))
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(z + 2*phi_fr) - (-b*tr-g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr+b*ti)/tm^2*(td))
end


function constraint_ohms_yt_to_on_off(pm::AbstractLPACCModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n,    :p, t_idx)
    q_to = var(pm, n,    :q, t_idx)
    phi_fr = var(pm, n, :phi_fr, i)
    phi_to = var(pm, n, :phi_to, i)
    td = var(pm, n, :td, i)
    cs = var(pm, n, :cs, i)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(z + 2*phi_to) + (-g*tr-b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr+g*ti)/tm^2*-(td) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(z + 2*phi_to) - (-b*tr+g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr-b*ti)/tm^2*-(td) )
end
