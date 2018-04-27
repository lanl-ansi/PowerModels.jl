################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

"extracts the start value"
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end

function get(comp::Dict{String,Any}, key::String, phase::Int, default=0.0)
    if haskey(comp, key)
        vals = comp[key]
        if length(vals) <= phase
            return vals[phase]
        end
    end
    return default
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded::Bool = true)
    var(pm, nw, ph)[:va] = @variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(ph)_va",
        start = get(ref(pm, nw, :bus, i), "va_start", ph, 1.0)
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:vm] = @variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(ph)_vm",
            lowerbound = ref(pm, nw, :bus, i, "vmin", ph),
            upperbound = ref(pm, nw, :bus, i, "vmax", ph),
            start = get(ref(pm, nw, :bus, i), "vm_start", ph, 1.0)
        )
    else
        var(pm, nw, ph)[:vm] = @variable(pm.model,
            [i in ids(pm, nw, :bus)], basename="$(nw)_$(ph)_vm",
            lowerbound = 0,
            start = get(ref(pm, nw, :bus, i), "vm_start", ph, 1.0)
        )
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded::Bool = true)
    var(pm, nw, ph)[:vr] = @variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(ph)_vr",
        lowerbound = -ref(pm, nw, ph, :bus, i)["vmax"],
        upperbound =  ref(pm, nw, ph, :bus, i)["vmax"],
        start = getstart(ref(pm, nw, ph, :bus), i, "vr_start", 1.0)
    )
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded::Bool = true)
    var(pm, nw, ph)[:vi] = @variable(pm.model,
        [i in ids(pm, nw, :bus)], basename="$(nw)_$(ph)_vi",
        lowerbound = -ref(pm, nw, :bus, i, ph)["vmax"],
        upperbound =  ref(pm, nw, :bus, i, ph)["vmax"],
        start = getstart(ref(pm, nw, :bus, i, ph), "vi_start")
    )
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    buses = ref(pm, nw, ph, :bus)
    branches = ref(pm, nw, ph, :branch)

    var(pm, nw, ph)[:vm_fr] = @variable(pm.model,
        [i in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_vm_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"],
        start = getstart(ref(pm, nw, ph, :bus), i, "vm_fr_start", 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    buses = ref(pm, nw, ph, :bus)
    branches = ref(pm, nw, ph, :branch)

    var(pm, nw, ph)[:vm_to] = @variable(pm.model,
        [i in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_vm_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"],
        start = getstart(ref(pm, nw, ph, :bus), i, "vm_to_start", 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:w] = @variable(pm.model,
            [i in ids(pm, nw, ph, :bus)], basename="$(nw)_$(ph)_w",
            lowerbound = ref(pm, nw, ph, :bus, i)["vmin"]^2,
            upperbound = ref(pm, nw, ph, :bus, i)["vmax"]^2,
            start = getstart(ref(pm, nw, ph, :bus), i, "w_start", 1.001)
        )
    else
        var(pm, nw, ph)[:w] = @variable(pm.model,
            [i in ids(pm, nw, ph, :bus)], basename="$(nw)_$(ph)_w",
            lowerbound = 0,
            start = getstart(ref(pm, nw, ph, :bus), i, "w_start", 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    buses = ref(pm, nw, ph, :bus)
    branches = ref(pm, nw, ph, :branch)

    var(pm, nw, ph)[:w_fr] = @variable(pm.model,
        [i in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_w_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(ref(pm, nw, ph, :bus), i, "w_fr_start", 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    buses = ref(pm, nw, ph, :bus)
    branches = ref(pm, nw, ph, :branch)

    var(pm, nw, ph)[:w_to] = @variable(pm.model,
        [i in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_w_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"]^2,
        start = getstart(ref(pm, nw, ph, :bus), i, "w_to_start", 1.001)
    )
end


""
function variable_voltage_product(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, ph, :buspairs))

        var(pm, nw, ph)[:wr] = @variable(pm.model,
            [bp in ids(pm, nw, ph, :buspairs)], basename="$(nw)_$(ph)_wr",
            lowerbound = wr_min[bp],
            upperbound = wr_max[bp],
            start = getstart(ref(pm, nw, ph, :buspairs), bp, "wr_start", 1.0)
        )
        var(pm, nw, ph)[:wi] = @variable(pm.model,
            wi[bp in ids(pm, nw, ph, :buspairs)], basename="$(nw)_$(ph)_wi",
            lowerbound = wi_min[bp],
            upperbound = wi_max[bp],
            start = getstart(ref(pm, nw, ph, :buspairs), bp, "wi_start")
        )
    else
        var(pm, nw, ph)[:wr] = @variable(pm.model,
            [bp in ids(pm, nw, ph, :buspairs)], basename="$(nw)_$(ph)_wr",
            start = getstart(ref(pm, nw, ph, :buspairs), bp, "wr_start", 1.0)
        )
        var(pm, nw, ph)[:wi] = @variable(pm.model,
            [bp in ids(pm, nw, ph, :buspairs)], basename="$(nw)_$(ph)_wi",
            start = getstart(ref(pm, nw, ph, :buspairs), bp, "wi_start")
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, ph, :buspairs))
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, ph, :branch)])

    var(pm, nw, ph)[:wr] = @variable(pm.model,
        wr[b in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_wr",
        lowerbound = min(0, wr_min[bi_bp[b]]),
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getstart(ref(pm, nw, ph, :buspairs), bi_bp[b], "wr_start", 1.0)
    )
    var(pm, nw, ph)[:wi] = @variable(pm.model,
        wi[b in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_wi",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]),
        start = getstart(ref(pm, nw, ph, :buspairs), bi_bp[b], "wi_start")
    )
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:pg] = @variable(pm.model,
            [i in ids(pm, nw, ph, :gen)], basename="$(nw)_$(ph)_pg",
            lowerbound = ref(pm, nw, ph, :gen, i)["pmin"],
            upperbound = ref(pm, nw, ph, :gen, i)["pmax"],
            start = getstart(ref(pm, nw, ph, :gen), i, "pg_start")
        )
    else
        var(pm, nw, ph)[:pg] = @variable(pm.model,
            [i in ids(pm, nw, ph, :gen)], basename="$(nw)_$(ph)_pg",
            start = getstart(ref(pm, nw, ph, :gen), i, "pg_start")
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:qg] = @variable(pm.model,
            [i in ids(pm, nw, ph, :gen)], basename="$(nw)_$(ph)_qg",
            lowerbound = ref(pm, nw, ph, :gen, i)["qmin"],
            upperbound = ref(pm, nw, ph, :gen, i)["qmax"],
            start = getstart(ref(pm, nw, ph, :gen), i, "qg_start")
        )
    else
        var(pm, nw, ph)[:qg] = @variable(pm.model,
            [i in ids(pm, nw, ph, :gen)], basename="$(nw)_$(ph)_qg",
            start = getstart(ref(pm, nw, ph, :gen), i, "qg_start")
        )
    end
end



""
function variable_branch_flow(pm::GenericPowerModel; kwargs...)
    variable_active_branch_flow(pm; kwargs...)
    variable_reactive_branch_flow(pm; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, ph, :arcs)], basename="$(nw)_$(ph)_p",
            lowerbound = -ref(pm, nw, ph, :branch, l)["rate_a"],
            upperbound =  ref(pm, nw, ph, :branch, l)["rate_a"],
            start = getstart(ref(pm, nw, ph, :branch), l, "p_start")
        )
    else
        var(pm, nw, ph)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, ph, :arcs)], basename="$(nw)_$(ph)_p",
            start = getstart(ref(pm, nw, ph, :branch), l, "p_start")
        )
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:q] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, ph, :arcs)], basename="$(nw)_$(ph)_q",
            lowerbound = -ref(pm, nw, ph, :branch, l)["rate_a"],
            upperbound =  ref(pm, nw, ph, :branch, l)["rate_a"],
            start = getstart(ref(pm, nw, ph, :branch), l, "q_start")
        )
    else
        var(pm, nw, ph)[:q] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, ph, :arcs)], basename="$(nw)_$(ph)_q",
            start = getstart(ref(pm, nw, ph, :branch), l, "q_start")
        )
    end
end

function variable_dcline_flow(pm::GenericPowerModel; kwargs...)
    variable_active_dcline_flow(pm; kwargs...)
    variable_reactive_dcline_flow(pm; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:p_dc] = @variable(pm.model,
            [a in ref(pm, nw, ph, :arcs_dc)], basename="$(nw)_$(ph)_p_dc",
            lowerbound = ref(pm, nw, ph, :arcs_dc_param, a)["pmin"],
            upperbound = ref(pm, nw, ph, :arcs_dc_param, a)["pmax"],
            start = ref(pm, nw, ph, :arcs_dc_param, a)["pref"]
        )
    else
        var(pm, nw, ph)[:p_dc] = @variable(pm.model,
            [a in ref(pm, nw, ph, :arcs_dc)], basename="$(nw)_$(ph)_p_dc",
            start = ref(pm, nw, ph, :arcs_dc_param, a)["pref"]
        )
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        var(pm, nw, ph)[:q_dc] = @variable(pm.model,
            [a in ref(pm, nw, ph, :arcs_dc)], basename="$(nw)_$(ph)_q_dc",
            lowerbound = ref(pm, nw, ph, :arcs_dc_param, a)["qmin"],
            upperbound = ref(pm, nw, ph, :arcs_dc_param, a)["qmax"],
            start = ref(pm, nw, ph, :arcs_dc_param, a)["qref"]
        )
    else
        var(pm, nw, ph)[:q_dc] = @variable(pm.model,
            [a in ref(pm, nw, ph, :arcs_dc)], basename="$(nw)_$(ph)_q_dc",
            start = ref(pm, nw, ph, :arcs_dc_param, a)["qref"]
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
function variable_active_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    var(pm, nw, ph)[:p_ne] = @variable(pm.model,
        [(l,i,j) in ref(pm, nw, ph, :ne_arcs)], basename="$(nw)_$(ph)_p_ne",
        lowerbound = -ref(pm, nw, ph, :ne_branch, l)["rate_a"],
        upperbound =  ref(pm, nw, ph, :ne_branch, l)["rate_a"],
        start = getstart(ref(pm, nw, ph, :ne_branch), l, "p_start")
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    var(pm, nw, ph)[:q_ne] = @variable(pm.model,
        q_ne[(l,i,j) in ref(pm, nw, ph, :ne_arcs)], basename="$(nw)_$(ph)_q_ne",
        lowerbound = -ref(pm, nw, ph, :ne_branch, l)["rate_a"],
        upperbound =  ref(pm, nw, ph, :ne_branch, l)["rate_a"],
        start = getstart(ref(pm, nw, ph, :ne_branch), l, "q_start")
    )
end

"variable: `0 <= branch_z[l] <= 1` for `l` in `branch`es"
function variable_branch_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    var(pm, nw, ph)[:branch_z] = @variable(pm.model,
        [l in ids(pm, nw, ph, :branch)], basename="$(nw)_$(ph)_branch_z",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(ref(pm, nw, ph, :branch), l, "branch_z_start", 1.0)
    )
end

"variable: `0 <= branch_ne[l] <= 1` for `l` in `branch`es"
function variable_branch_ne(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    branches = ref(pm, nw, ph, :ne_branch)
    var(pm, nw, ph)[:branch_ne] = @variable(pm.model,
        [l in keys(branches)], basename="$(nw)_$(ph)_branch_ne",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(branches, l, "branch_tnep_start", 1.0)
    )
end
