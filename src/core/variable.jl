################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################


function getval(comp::Dict{String,<:Any}, key::String, conductor::Int, default=0.0)
    if haskey(comp, key)
        vals = comp[key]
        return getmcv(vals, conductor)
    end
    return default
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    var(pm, nw, cnd)[:va] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_va",
        start = getval(ref(pm, nw, :bus, i), "va_start", cnd, 1.0)
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:vm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vm",
            lowerbound = ref(pm, nw, :bus, i, "vmin", cnd),
            upperbound = ref(pm, nw, :bus, i, "vmax", cnd),
            start = getval(ref(pm, nw, :bus, i), "vm_start", cnd, 1.0)
        )
    else
        var(pm, nw, cnd)[:vm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vm",
            start = getval(ref(pm, nw, :bus, i), "vm_start", cnd, 1.0)
        )
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    if bounded
        var(pm, nw, cnd)[:vr] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vr",
            lowerbound = -ref(pm, nw, :bus, i, "vmax", cnd),
            upperbound =  ref(pm, nw, :bus, i, "vmax", cnd),
            start = getval(ref(pm, nw, :bus, i), "vr_start", cnd, 1.0)
        )
    else
        var(pm, nw, cnd)[:vr] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vr",
            start = getval(ref(pm, nw, :bus, i), "vr_start", cnd, 1.0)
        )
    end
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    if bounded
        var(pm, nw, cnd)[:vi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vi",
            lowerbound = -ref(pm, nw, :bus, i, "vmax", cnd),
            upperbound =  ref(pm, nw, :bus, i, "vmax", cnd),
            start = getval(ref(pm, nw, :bus, i), "vi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:vi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vi",
            start = getval(ref(pm, nw, :bus, i), "vi_start", cnd)
        )
    end
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:vm_fr] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_vm_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"][cnd],
        start = getval(ref(pm, nw, :branch, i), "vm_fr_start", cnd, 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:vm_to] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_vm_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"][cnd],
        start = getval(ref(pm, nw, :branch, i), "vm_to_start", cnd, 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:w] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_w",
            lowerbound = ref(pm, nw, :bus, i, "vmin", cnd)^2,
            upperbound = ref(pm, nw, :bus, i, "vmax", cnd)^2,
            start = getval(ref(pm, nw, :bus, i), "w_start", cnd, 1.001)
        )
    else
        var(pm, nw, cnd)[:w] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_w",
            lowerbound = 0.0,
            start = getval(ref(pm, nw, :bus, i), "w_start", cnd, 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:w_fr] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_w_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"][cnd]^2,
        start = getval(ref(pm, nw, :branch, i), "w_fr_start", cnd, 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:w_to] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_w_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"][cnd]^2,
        start = getval(ref(pm, nw, :branch, i), "w_to_start", cnd, 1.001)
    )
end

""
function variable_cosine(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    cos_min = Dict((bp, -Inf) for bp in ids(pm, nw, :buspairs))
    cos_max = Dict((bp,  Inf) for bp in ids(pm, nw, :buspairs))

    for (bp, buspair) in ref(pm, nw, :buspairs)
        angmin = buspair["angmin"][cnd]
        angmax = buspair["angmax"][cnd]
        if angmin >= 0
            cos_max[bp] = cos(angmin)
            cos_min[bp] = cos(angmax)
        end
        if angmax <= 0
            cos_max[bp] = cos(angmax)
            cos_min[bp] = cos(angmin)
        end
        if angmin < 0 && angmax > 0
            cos_max[bp] = 1.0
            cos_min[bp] = min(cos(angmin), cos(angmax))
        end
    end

    var(pm, nw, cnd)[:cs] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_cs",
        lowerbound = cos_min[bp],
        upperbound = cos_max[bp],
        start = getval(ref(pm, nw, :buspairs, bp), "cs_start", cnd, 1.0)
    )
end

""
function variable_sine(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:si] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_si",
        lowerbound = sin(ref(pm, nw, :buspairs, bp, "angmin", cnd)),
        upperbound = sin(ref(pm, nw, :buspairs, bp, "angmax", cnd)),
        start = getval(ref(pm, nw, :buspairs, bp), "si_start", cnd)
    )
end

""
function variable_voltage_product(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)

        var(pm, nw, cnd)[:wr] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wr",
            lowerbound = wr_min[bp],
            upperbound = wr_max[bp],
            start = getval(ref(pm, nw, :buspairs, bp), "wr_start", cnd, 1.0)
        )
        var(pm, nw, cnd)[:wi] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wi",
            lowerbound = wi_min[bp],
            upperbound = wi_max[bp],
            start = getval(ref(pm, nw, :buspairs, bp), "wi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:wr] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wr",
            start = getval(ref(pm, nw, :buspairs, bp), "wr_start", cnd, 1.0)
        )
        var(pm, nw, cnd)[:wi] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wi",
            start = getval(ref(pm, nw, :buspairs, bp), "wi_start", cnd)
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :branch))

    var(pm, nw, cnd)[:wr] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_wr",
        lowerbound = min(0, wr_min[bi_bp[b]]),
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getval(ref(pm, nw, :buspairs, bi_bp[b]), "wr_start", cnd, 1.0)
    )
    var(pm, nw, cnd)[:wi] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_wi",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]),
        start = getval(ref(pm, nw, :buspairs, bi_bp[b]), "wi_start", cnd)
    )
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:pg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_pg",
            lowerbound = ref(pm, nw, :gen, i, "pmin", cnd),
            upperbound = ref(pm, nw, :gen, i, "pmax", cnd),
            start = getval(ref(pm, nw, :gen, i), "pg_start", cnd)
        )
    else
        var(pm, nw, cnd)[:pg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_pg",
            start = getval(ref(pm, nw, :gen, i), "pg_start", cnd)
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:qg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_qg",
            lowerbound = ref(pm, nw, :gen, i, "qmin", cnd),
            upperbound = ref(pm, nw, :gen, i, "qmax", cnd),
            start = getval(ref(pm, nw, :gen, i), "qg_start", cnd)
        )
    else
        var(pm, nw, cnd)[:qg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_qg",
            start = getval(ref(pm, nw, :gen, i), "qg_start", cnd)
        )
    end
end


function variable_generation_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, relax=false)
    if !relax
        var(pm, nw)[:z_gen] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_z_gen",
            lowerbound = 0,
            upperbound = 1,
            category = :Int,
            start = getval(ref(pm, nw, :gen, i), "z_gen_start", 1, 1.0)
        )
    else
        var(pm, nw)[:z_gen] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_z_gen",
            lowerbound = 0,
            upperbound = 1,
            start = getval(ref(pm, nw, :gen, i), "z_gen_start", 1, 1.0)
        )
    end
end


function variable_generation_on_off(pm::GenericPowerModel; kwargs...)
    variable_active_generation_on_off(pm; kwargs...)
    variable_reactive_generation_on_off(pm; kwargs...)
end

function variable_active_generation_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:pg] = JuMP.@variable(pm.model, 
        [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_pg",
        lowerbound = min(0, ref(pm, nw, :gen, i, "pmin", cnd)),
        upperbound = max(0, ref(pm, nw, :gen, i, "pmax", cnd)),
        start = getval(ref(pm, nw, :gen, i), "pg_start", cnd)
    )
end

function variable_reactive_generation_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:qg] = JuMP.@variable(pm.model, 
        [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_qg",
        lowerbound = min(0, ref(pm, nw, :gen, i, "qmin", cnd)),
        upperbound = max(0, ref(pm, nw, :gen, i, "qmax", cnd)), 
        start = getval(ref(pm, nw, :gen, i), "qg_start", cnd)
    )
end



""
function variable_branch_flow(pm::GenericPowerModel; kwargs...)
    variable_active_branch_flow(pm; kwargs...)
    variable_reactive_branch_flow(pm; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)

        p = var(pm, nw, cnd)[:p] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_p",
            lowerbound = flow_lb[l],
            upperbound = flow_ub[l],
        )
    else
        p = var(pm, nw, cnd)[:p] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_p",
        )
    end

    for (l,branch) in ref(pm, nw, :branch)
        if haskey(branch, "pf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.setvalue(p[f_idx], branch["pf_start"])
        end
        if haskey(branch, "pt_start")
            t_idx = (l, branch["t_bus"], branch["f_bus"])
            JuMP.setvalue(p[t_idx], branch["pt_start"])
        end
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)

        q = var(pm, nw, cnd)[:q] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_q",
            lowerbound = flow_lb[l],
            upperbound = flow_ub[l],
        )
    else
        q = var(pm, nw, cnd)[:q] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_q",
        )
    end

    for (l,branch) in ref(pm, nw, :branch)
        if haskey(branch, "qf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.setvalue(q[f_idx], branch["qf_start"])
        end
        if haskey(branch, "qt_start")
            t_idx = (l, branch["t_bus"], branch["f_bus"])
            JuMP.setvalue(q[t_idx], branch["qt_start"])
        end
    end
end

function variable_dcline_flow(pm::GenericPowerModel; kwargs...)
    variable_active_dcline_flow(pm; kwargs...)
    variable_reactive_dcline_flow(pm; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:p_dc] = JuMP.@variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_p_dc",
            lowerbound = ref(pm, nw, :arcs_dc_param, arc, "pmin", cnd),
            upperbound = ref(pm, nw, :arcs_dc_param, arc, "pmax", cnd),
            start = ref(pm, nw, :arcs_dc_param, arc, "pref", cnd)
        )
    else
        var(pm, nw, cnd)[:p_dc] = JuMP.@variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_p_dc",
            start = ref(pm, nw, :arcs_dc_param, arc, "pref", cnd)
        )
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:q_dc] = JuMP.@variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_q_dc",
            lowerbound = ref(pm, nw, :arcs_dc_param, arc, "qmin", cnd),
            upperbound = ref(pm, nw, :arcs_dc_param, arc, "qmax", cnd),
            start = ref(pm, nw, :arcs_dc_param, arc, "qref", cnd)
        )
    else
        var(pm, nw, cnd)[:q_dc] = JuMP.@variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_q_dc",
            start = ref(pm, nw, :arcs_dc_param, arc, "qref", cnd)
        )
    end
end




"variables for modeling storage units, includes grid injection and internal variables"
function variable_storage(pm::GenericPowerModel; kwargs...)
    variable_active_storage(pm; kwargs...)
    variable_reactive_storage(pm; kwargs...)
    variable_storage_energy(pm; kwargs...)
    variable_storage_charge(pm; kwargs...)
    variable_storage_discharge(pm; kwargs...)
end

""
function variable_active_storage(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    inj_lb, inj_ub = calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), cnd)

    var(pm, nw, cnd)[:ps] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], basename="$(nw)_$(cnd)_ps",
        lowerbound = inj_lb[i],
        upperbound = inj_ub[i],
        start = getval(ref(pm, nw, :storage, i), "ps_start", cnd)
    )
end

""
function variable_reactive_storage(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    inj_lb, inj_ub = calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), cnd)

    var(pm, nw, cnd)[:qs] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], basename="$(nw)_$(cnd)_qs",
        lowerbound = max(inj_lb[i], ref(pm, nw, :storage, i, "qmin", cnd)),
        upperbound = min(inj_ub[i], ref(pm, nw, :storage, i, "qmax", cnd)),
        start = getval(ref(pm, nw, :storage, i), "qs_start", cnd)
    )
end

""
function variable_storage_energy(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:se] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], basename="$(nw)_se",
        lowerbound = 0,
        upperbound = ref(pm, nw, :storage, i, "energy_rating"),
        start = getval(ref(pm, nw, :storage, i), "se_start", 1)
    )
end

""
function variable_storage_charge(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:sc] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], basename="$(nw)_sc",
        lowerbound = 0,
        upperbound = ref(pm, nw, :storage, i, "charge_rating"),
        start = getval(ref(pm, nw, :storage, i), "sc_start", 1)
    )
end

""
function variable_storage_discharge(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:sd] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], basename="$(nw)_sd",
        lowerbound = 0,
        upperbound = ref(pm, nw, :storage, i, "discharge_rating"),
        start = getval(ref(pm, nw, :storage, i), "sd_start", 1)
    )
end



##################################################################
### Network Expantion Variables

"generates variables for both `active` and `reactive` `branch_flow_ne`"
function variable_branch_flow_ne(pm::GenericPowerModel; kwargs...)
    variable_active_branch_flow_ne(pm; kwargs...)
    variable_reactive_branch_flow_ne(pm; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:p_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs)], basename="$(nw)_$(cnd)_p_ne",
        lowerbound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upperbound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = getval(ref(pm, nw, :ne_branch, l), "p_start", cnd)
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:q_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs)], basename="$(nw)_$(cnd)_q_ne",
        lowerbound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upperbound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = getval(ref(pm, nw, :ne_branch, l), "q_start", cnd)
    )
end

"variable: `0 <= branch_z[l] <= 1` for `l` in `branch`es"
function variable_branch_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:branch_z] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_branch_z",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getval(ref(pm, nw, :branch, l), "branch_z_start", cnd, 1.0)
    )
end

"variable: `0 <= branch_ne[l] <= 1` for `l` in `branch`es"
function variable_branch_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:branch_ne] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :ne_branch)], basename="$(nw)_$(cnd)_branch_ne",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getval(ref(pm, nw, :ne_branch, l), "branch_tnep_start", cnd, 1.0)
    )
end
