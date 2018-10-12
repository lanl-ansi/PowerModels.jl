################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################


function getval(comp::Dict{String,Any}, key::String, conductor::Int, default=0.0)
    if haskey(comp, key)
        vals = comp[key]
        return getmcv(vals, conductor)
    end
    return default
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    var(pm, nw, cnd)[:va] = @variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_va",
        start = getval(ref(pm, nw, :bus, i), "va_start", cnd, 1.0)
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:vm] = @variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vm",
            lower_bound = ref(pm, nw, :bus, i, "vmin", cnd),
            upper_bound = ref(pm, nw, :bus, i, "vmax", cnd),
            start = getval(ref(pm, nw, :bus, i), "vm_start", cnd, 1.0)
        )
    else
        var(pm, nw, cnd)[:vm] = @variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vm",
            lower_bound = 0,
            start = getval(ref(pm, nw, :bus, i), "vm_start", cnd, 1.0)
        )
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    var(pm, nw, cnd)[:vr] = @variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vr",
        lower_bound = -ref(pm, nw, :bus, i, "vmax", cnd),
        upper_bound =  ref(pm, nw, :bus, i, "vmax", cnd),
        start = getval(ref(pm, nw, :bus, i), "vr_start", cnd, 1.0)
    )
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    var(pm, nw, cnd)[:vi] = @variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_vi",
        lower_bound = -ref(pm, nw, :bus, i, "vmax", cnd),
        upper_bound =  ref(pm, nw, :bus, i, "vmax", cnd),
        start = getval(ref(pm, nw, :bus, i), "vi_start", cnd)
    )
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:vm_fr] = @variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_vm_fr",
        lower_bound = 0,
        upper_bound = buses[branches[i]["f_bus"]]["vmax"][cnd],
        start = getval(ref(pm, nw, :branch, i), "vm_fr_start", cnd, 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:vm_to] = @variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_vm_to",
        lower_bound = 0,
        upper_bound = buses[branches[i]["t_bus"]]["vmax"][cnd],
        start = getval(ref(pm, nw, :branch, i), "vm_to_start", cnd, 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:w] = @variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_w",
            lower_bound = ref(pm, nw, :bus, i, "vmin", cnd)^2,
            upper_bound = ref(pm, nw, :bus, i, "vmax", cnd)^2,
            start = getval(ref(pm, nw, :bus, i), "w_start", cnd, 1.001)
        )
    else
        var(pm, nw, cnd)[:w] = @variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(cnd)_w",
            lower_bound = 0,
            start = getval(ref(pm, nw, :bus, i), "w_start", cnd, 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:w_fr] = @variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_w_fr",
        lower_bound = 0,
        upper_bound = buses[branches[i]["f_bus"]]["vmax"][cnd]^2,
        start = getval(ref(pm, nw, :branch, i), "w_fr_start", cnd, 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:w_to] = @variable(pm.model,
        [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_w_to",
        lower_bound = 0,
        upper_bound = buses[branches[i]["t_bus"]]["vmax"][cnd]^2,
        start = getval(ref(pm, nw, :branch, i), "w_to_start", cnd, 1.001)
    )
end


""
function variable_voltage_product(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)

        var(pm, nw, cnd)[:wr] = @variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wr",
            lower_bound = wr_min[bp],
            upper_bound = wr_max[bp],
            start = getval(ref(pm, nw, :buspairs, bp), "wr_start", cnd, 1.0)
        )
        var(pm, nw, cnd)[:wi] = @variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wi",
            lower_bound = wi_min[bp],
            upper_bound = wi_max[bp],
            start = getval(ref(pm, nw, :buspairs, bp), "wi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:wr] = @variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wr",
            start = getval(ref(pm, nw, :buspairs, bp), "wr_start", cnd, 1.0)
        )
        var(pm, nw, cnd)[:wi] = @variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], basename="$(nw)_$(cnd)_wi",
            start = getval(ref(pm, nw, :buspairs, bp), "wi_start", cnd)
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :branch)])

    var(pm, nw, cnd)[:wr] = @variable(pm.model,
        [b in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_wr",
        lower_bound = min(0, wr_min[bi_bp[b]]),
        upper_bound = max(0, wr_max[bi_bp[b]]),
        start = getval(ref(pm, nw, :buspairs, bi_bp[b]), "wr_start", cnd, 1.0)
    )
    var(pm, nw, cnd)[:wi] = @variable(pm.model,
        [b in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_wi",
        lower_bound = min(0, wi_min[bi_bp[b]]),
        upper_bound = max(0, wi_max[bi_bp[b]]),
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
        var(pm, nw, cnd)[:pg] = @variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_pg",
            lower_bound = ref(pm, nw, :gen, i, "pmin", cnd),
            upper_bound = ref(pm, nw, :gen, i, "pmax", cnd),
            start = getval(ref(pm, nw, :gen, i), "pg_start", cnd)
        )
    else
        var(pm, nw, cnd)[:pg] = @variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_pg",
            start = getval(ref(pm, nw, :gen, i), "pg_start", cnd)
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:qg] = @variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_qg",
            lower_bound = ref(pm, nw, :gen, i, "qmin", cnd),
            upper_bound = ref(pm, nw, :gen, i, "qmax", cnd),
            start = getval(ref(pm, nw, :gen, i), "qg_start", cnd)
        )
    else
        var(pm, nw, cnd)[:qg] = @variable(pm.model,
            [i in ids(pm, nw, :gen)], basename="$(nw)_$(cnd)_qg",
            start = getval(ref(pm, nw, :gen, i), "qg_start", cnd)
        )
    end
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

        var(pm, nw, cnd)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_p",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = getval(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    else
        var(pm, nw, cnd)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_p",
            start = getval(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)

        var(pm, nw, cnd)[:q] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_q",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = getval(ref(pm, nw, :branch, l), "q_start", cnd)
        )
    else
        var(pm, nw, cnd)[:q] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], basename="$(nw)_$(cnd)_q",
            start = getval(ref(pm, nw, :branch, l), "q_start", cnd)
        )
    end
end

function variable_dcline_flow(pm::GenericPowerModel; kwargs...)
    variable_active_dcline_flow(pm; kwargs...)
    variable_reactive_dcline_flow(pm; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:p_dc] = @variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_p_dc",
            lower_bound = ref(pm, nw, :arcs_dc_param, arc, "pmin", cnd),
            upper_bound = ref(pm, nw, :arcs_dc_param, arc, "pmax", cnd),
            start = ref(pm, nw, :arcs_dc_param, arc, "pref", cnd)
        )
    else
        var(pm, nw, cnd)[:p_dc] = @variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_p_dc",
            start = ref(pm, nw, :arcs_dc_param, arc, "pref", cnd)
        )
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:q_dc] = @variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_q_dc",
            lower_bound = ref(pm, nw, :arcs_dc_param, arc, "qmin", cnd),
            upper_bound = ref(pm, nw, :arcs_dc_param, arc, "qmax", cnd),
            start = ref(pm, nw, :arcs_dc_param, arc, "qref", cnd)
        )
    else
        var(pm, nw, cnd)[:q_dc] = @variable(pm.model,
            [arc in ref(pm, nw, :arcs_dc)], basename="$(nw)_$(cnd)_q_dc",
            start = ref(pm, nw, :arcs_dc_param, arc, "qref", cnd)
        )
    end
end


##################################################################

"generates variables for both `active` and `reactive` `branch_flow_ne`"
function variable_branch_flow_ne(pm::GenericPowerModel; kwargs...)
    variable_active_branch_flow_ne(pm; kwargs...)
    variable_reactive_branch_flow_ne(pm; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:p_ne] = @variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs)], basename="$(nw)_$(cnd)_p_ne",
        lower_bound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upper_bound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = getval(ref(pm, nw, :ne_branch, l), "p_start", cnd)
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:q_ne] = @variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs)], basename="$(nw)_$(cnd)_q_ne",
        lower_bound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upper_bound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = getval(ref(pm, nw, :ne_branch, l), "q_start", cnd)
    )
end

"variable: `0 <= branch_z[l] <= 1` for `l` in `branch`es"
function variable_branch_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:branch_z] = @variable(pm.model,
        [l in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_branch_z",
        lower_bound = 0,
        upper_bound = 1,
        category = :Int,
        start = getval(ref(pm, nw, :branch, l), "branch_z_start", cnd, 1.0)
    )
end

"variable: `0 <= branch_ne[l] <= 1` for `l` in `branch`es"
function variable_branch_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:branch_ne] = @variable(pm.model,
        [l in ids(pm, nw, :ne_branch)], basename="$(nw)_$(cnd)_branch_ne",
        lower_bound = 0,
        upper_bound = 1,
        category = :Int,
        start = getval(ref(pm, nw, :ne_branch, l), "branch_tnep_start", cnd, 1.0)
    )
end
