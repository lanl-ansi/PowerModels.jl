################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

"extracts the start value"
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded::Bool = true)
    var(pm, n, h)[:va] = @variable(pm.model,
        [i in ids(pm, n, h, :bus)], basename="$(n)_$(h)_va",
        start = getstart(ref(pm, n, h, :bus), i, "va_start")
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:vm] = @variable(pm.model,
            [i in ids(pm, n, h, :bus)], basename="$(n)_vm",
            lowerbound = ref(pm, n, h, :bus, i)["vmin"],
            upperbound = ref(pm, n, h, :bus, i)["vmax"],
            start = getstart(ref(pm, n, h, :bus), i, "vm_start", 1.0)
        )
    else
        var(pm, n, h)[:vm] = @variable(pm.model,
            [i in ids(pm, n, h, :bus)], basename="$(n)_vm",
            lowerbound = 0,
            start = getstart(ref(pm, n, h, :bus), i, "vm_start", 1.0))
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded::Bool = true)
    var(pm, n, h)[:vr] = @variable(pm.model,
        [i in ids(pm, n, h, :bus)], basename="$(n)_vr",
        lowerbound = -ref(pm, n, h, :bus, i)["vmax"],
        upperbound =  ref(pm, n, h, :bus, i)["vmax"],
        start = getstart(pm.ref[:nw][n][:bus], i, "vr_start", 1.0)
    )
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded::Bool = true)
    var(pm, n, h)[:vi] = @variable(pm.model,
        [i in ids(pm, n, h, :bus)], basename="$(n)_vi",
        lowerbound = -ref(pm, n, h, :bus, i)["vmax"],
        upperbound =  ref(pm, n, h, :bus, i)["vmax"],
        start = getstart(ref(pm, n, h, :bus), i, "vi_start")
    )
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    var(pm, n, h)[:vm_fr] = @variable(pm.model,
        [i in ids(pm, n, h, :branch)], basename="$(n)_vm_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"],
        start = getstart(ref(pm, n, h, :bus), i, "vm_fr_start", 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    var(pm, n, h)[:vm_to] = @variable(pm.model,
        [i in ids(pm, n, h, :branch)], basename="$(n)_vm_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"],
        start = getstart(ref(pm, n, h, :bus), i, "vm_to_start", 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:w] = @variable(pm.model,
            [i in ids(pm, n, h, :bus)], basename="$(n)_w",
            lowerbound = ref(pm, n, h, :bus, i)["vmin"]^2,
            upperbound = ref(pm, n, h, :bus, i)["vmax"]^2,
            start = getstart(ref(pm, n, h, :bus), i, "w_start", 1.001)
        )
    else
        var(pm, n, h)[:w] = @variable(pm.model,
            [i in ids(pm, n, h, :bus)], basename="$(n)_w",
            lowerbound = 0,
            start = getstart(ref(pm, n, h, :bus), i, "w_start", 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    var(pm, n, h)[:w_fr] = @variable(pm.model,
        [i in ids(pm, n, h, :branch)], basename="$(n)_w_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(ref(pm, n, h, :bus), i, "w_fr_start", 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    var(pm, n, h)[:w_to] = @variable(pm.model,
        [i in ids(pm, n, h, :branch)], basename="$(n)_w_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"]^2,
        start = getstart(ref(pm, n, h, :bus), i, "w_to_start", 1.001)
    )
end


""
function variable_voltage_product(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, n, h, :buspairs))

        var(pm, n, h)[:wr] = @variable(pm.model,
            [bp in ids(pm, n, h, :buspairs)], basename="$(n)_wr",
            lowerbound = wr_min[bp],
            upperbound = wr_max[bp],
            start = getstart(ref(pm, n, h, :buspairs), bp, "wr_start", 1.0)
        )
        var(pm, n, h)[:wi] = @variable(pm.model,
            wi[bp in ids(pm, n, h, :buspairs)], basename="$(n)_wi",
            lowerbound = wi_min[bp],
            upperbound = wi_max[bp],
            start = getstart(ref(pm, n, h, :buspairs), bp, "wi_start")
        )
    else
        var(pm, n, h)[:wr] = @variable(pm.model,
            [bp in ids(pm, n, h, :buspairs)], basename="$(n)_wr",
            start = getstart(ref(pm, n, h, :buspairs), bp, "wr_start", 1.0)
        )
        var(pm, n, h)[:wi] = @variable(pm.model,
            [bp in ids(pm, n, h, :buspairs)], basename="$(n)_wi",
            start = getstart(ref(pm, n, h, :buspairs), bp, "wi_start")
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, n, h, :buspairs))
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, n, h, :branch)])

    var(pm, n, h)[:wr] = @variable(pm.model,
        wr[b in ids(pm, n, h, :branch)], basename="$(n)_wr",
        lowerbound = min(0, wr_min[bi_bp[b]]),
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getstart(ref(pm, n, h, :buspairs), bi_bp[b], "wr_start", 1.0)
    )
    var(pm, n, h)[:wi] = @variable(pm.model,
        wi[b in ids(pm, n, h, :branch)], basename="$(n)_wi",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]),
        start = getstart(ref(pm, n, h, :buspairs), bi_bp[b], "wi_start")
    )
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; kwargs...)
    variable_active_generation(pm, n; kwargs...)
    variable_reactive_generation(pm, n; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:pg] = @variable(pm.model,
            [i in ids(pm, n, h, :gen)], basename="$(n)_pg",
            lowerbound = ref(pm, n, h, :gen, i)["pmin"],
            upperbound = ref(pm, n, h, :gen, i)["pmax"],
            start = getstart(ref(pm, n, h, :gen), i, "pg_start")
        )
    else
        var(pm, n, h)[:pg] = @variable(pm.model,
            [i in ids(pm, n, h, :gen)], basename="$(n)_pg",
            start = getstart(ref(pm, n, h, :gen), i, "pg_start")
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:qg] = @variable(pm.model,
            [i in ids(pm, n, h, :gen)], basename="$(n)_qg",
            lowerbound = ref(pm, n, h, :gen, i)["qmin"],
            upperbound = ref(pm, n, h, :gen, i)["qmax"],
            start = getstart(ref(pm, n, h, :gen), i, "qg_start")
        )
    else
        var(pm, n, h)[:qg] = @variable(pm.model,
            [i in ids(pm, n, h, :gen)], basename="$(n)_qg",
            start = getstart(ref(pm, n, h, :gen), i, "qg_start")
        )
    end
end



""
function variable_branch_flow(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; kwargs...)
    variable_active_branch_flow(pm, n; kwargs...)
    variable_reactive_branch_flow(pm, n; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_branch_flow(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, n, h, :arcs)], basename="$(n)_p",
            lowerbound = -ref(pm, n, h, :branch, l)["rate_a"],
            upperbound =  ref(pm, n, h, :branch, l)["rate_a"],
            start = getstart(ref(pm, n, h, :branch), l, "p_start")
        )
    else
        var(pm, n, h)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, n, h, :arcs)], basename="$(n)_p",
            start = getstart(ref(pm, n, h, :branch), l, "p_start")
        )
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_branch_flow(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:q] = @variable(pm.model,
            [(l,i,j) in ref(pm, n, h, :arcs)], basename="$(n)_q",
            lowerbound = -ref(pm, n, h, :branch, l)["rate_a"],
            upperbound =  ref(pm, n, h, :branch, l)["rate_a"],
            start = getstart(ref(pm, n, h, :branch), l, "q_start")
        )
    else
        var(pm, n, h)[:q] = @variable(pm.model,
            [(l,i,j) in ref(pm, n, h, :arcs)], basename="$(n)_q",
            start = getstart(ref(pm, n, h, :branch), l, "q_start")
        )
    end
end

function variable_dcline_flow(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; kwargs...)
    variable_active_dcline_flow(pm, n; kwargs...)
    variable_reactive_dcline_flow(pm, n; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:p_dc] = @variable(pm.model,
            [a in ref(pm, n, h, :arcs_dc)], basename="$(n)_p_dc",
            lowerbound = ref(pm, n, h, :arcs_dc_param, a)["pmin"],
            upperbound = ref(pm, n, h, :arcs_dc_param, a)["pmax"],
            start = ref(pm, n, h, :arcs_dc_param, a)["pref"]
        )
    else
        var(pm, n, h)[:p_dc] = @variable(pm.model,
            [a in ref(pm, n, h, :arcs_dc)], basename="$(n)_p_dc",
            start = ref(pm, n, h, :arcs_dc_param, a)["pref"]
        )
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; bounded = true)
    if bounded
        var(pm, n, h)[:q_dc] = @variable(pm.model,
            [a in ref(pm, n, h, :arcs_dc)], basename="$(n)_q_dc",
            lowerbound = ref(pm, n, h, :arcs_dc_param, a)["qmin"],
            upperbound = ref(pm, n, h, :arcs_dc_param, a)["qmax"],
            start = ref(pm, n, h, :arcs_dc_param, a)["qref"]
        )
    else
        var(pm, n, h)[:q_dc] = @variable(pm.model,
            [a in ref(pm, n, h, :arcs_dc)], basename="$(n)_q_dc",
            start = ref(pm, n, h, :arcs_dc_param, a)["qref"]
        )
    end
end


##################################################################

"generates variables for both `active` and `reactive` `branch_flow_ne`"
function variable_branch_flow_ne(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph; kwargs...)
    variable_active_branch_flow_ne(pm, n; kwargs...)
    variable_reactive_branch_flow_ne(pm, n; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_branch_flow_ne(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    var(pm, n, h)[:p_ne] = @variable(pm.model,
        [(l,i,j) in ref(pm, n, h, :ne_arcs)], basename="$(n)_p_ne",
        lowerbound = -ref(pm, n, h, :ne_branch, l)["rate_a"],
        upperbound =  ref(pm, n, h, :ne_branch, l)["rate_a"],
        start = getstart(ref(pm, n, h, :ne_branch), l, "p_start")
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    var(pm, n, h)[:q_ne] = @variable(pm.model,
        q_ne[(l,i,j) in ref(pm, n, h, :ne_arcs)], basename="$(n)_q_ne",
        lowerbound = -ref(pm, n, h, :ne_branch, l)["rate_a"],
        upperbound =  ref(pm, n, h, :ne_branch, l)["rate_a"],
        start = getstart(ref(pm, n, h, :ne_branch), l, "q_start")
    )
end

"variable: `0 <= branch_z[l] <= 1` for `l` in `branch`es"
function variable_branch_indicator(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    var(pm, n, h)[:branch_z] = @variable(pm.model,
        [l in ids(pm, n, h, :branch)], basename="$(n)_branch_z",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(ref(pm, n, h, :branch), l, "branch_z_start", 1.0)
    )
end

"variable: `0 <= branch_ne[l] <= 1` for `l` in `branch`es"
function variable_branch_ne(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    branches = ref(pm, n, h, :ne_branch)
    var(pm, n, h)[:branch_ne] = @variable(pm.model,
        [l in keys(branches)], basename="$(n)_branch_ne",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(branches, l, "branch_tnep_start", 1.0)
    )
end
