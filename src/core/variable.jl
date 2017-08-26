################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

"extracts the start value"
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel; bounded::Bool = true)
    pm.var[:va] = @variable(pm.model,
        [i in keys(pm.ref[:bus])], basename="va",
        start = getstart(pm.ref[:bus], i, "t_start")
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:vm] = @variable(pm.model,
            [i in keys(pm.ref[:bus])], basename="vm",
            lowerbound = pm.ref[:bus][i]["vmin"],
            upperbound = pm.ref[:bus][i]["vmax"],
            start = getstart(pm.ref[:bus], i, "v_start", 1.0)
        )
    else
        pm.var[:vm] = @variable(pm.model,
            [i in keys(pm.ref[:bus])], basename="vm",
            lowerbound = 0,
            start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel; bounded::Bool = true)
    pm.var[:vr] = @variable(pm.model,
        [i in keys(pm.ref[:bus])], basename="vr",
        lowerbound = -pm.ref[:bus][i]["vmax"],
        upperbound =  pm.ref[:bus][i]["vmax"],
        start = getstart(pm.ref[:bus], i, "vr_start", 1.0)
    )
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel; bounded::Bool = true)
    pm.var[:vi] = @variable(pm.model,
        [i in keys(pm.ref[:bus])], basename="vi",
        lowerbound = -pm.ref[:bus][i]["vmax"],
        upperbound =  pm.ref[:bus][i]["vmax"],
        start = getstart(pm.ref[:bus], i, "vi_start")
    )
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:vm_fr] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="vm_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"],
        start = getstart(pm.ref[:bus], i, "vm_fr_start", 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:vm_to] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="vm_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"],
        start = getstart(pm.ref[:bus], i, "vm_to_start", 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:w] = @variable(pm.model,
            [i in keys(pm.ref[:bus])], basename="w",
            lowerbound = pm.ref[:bus][i]["vmin"]^2,
            upperbound = pm.ref[:bus][i]["vmax"]^2,
            start = getstart(pm.ref[:bus], i, "w_start", 1.001)
        )
    else
        pm.var[:w] = @variable(pm.model,
            [i in keys(pm.ref[:bus])], basename="w",
            lowerbound = 0,
            start = getstart(pm.ref[:bus], i, "w_start", 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:w_fr] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="w_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:bus], i, "w_fr_start", 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:w_to] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="w_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:bus], i, "w_to_start", 1.001)
    )
end


""
function variable_voltage_product(pm::GenericPowerModel; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

        pm.var[:wr] = @variable(pm.model,
            [bp in keys(pm.ref[:buspairs])], basename="wr",
            lowerbound = wr_min[bp],
            upperbound = wr_max[bp],
            start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0)
        )
        pm.var[:wi] = @variable(pm.model,
            wi[bp in keys(pm.ref[:buspairs])], basename="wi",
            lowerbound = wi_min[bp],
            upperbound = wi_max[bp],
            start = getstart(pm.ref[:buspairs], bp, "wi_start")
        )
    else
        pm.var[:wr] = @variable(pm.model,
            [bp in keys(pm.ref[:buspairs])], basename="wr",
            start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0)
        )
        pm.var[:wi] = @variable(pm.model,
            [bp in keys(pm.ref[:buspairs])], basename="wi",
            start = getstart(pm.ref[:buspairs], bp, "wi_start")
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    pm.var[:wr] = @variable(pm.model,
        wr[b in keys(pm.ref[:branch])], basename="wr",
        lowerbound = min(0, wr_min[bi_bp[b]]),
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getstart(pm.ref[:buspairs], bi_bp[b], "wr_start", 1.0)
    )
    pm.var[:wi] = @variable(pm.model,
        wi[b in keys(pm.ref[:branch])], basename="wi",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]),
        start = getstart(pm.ref[:buspairs], bi_bp[b], "wi_start")
    )
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:pg] = @variable(pm.model,
            [i in keys(pm.ref[:gen])], basename="pg",
            lowerbound = pm.ref[:gen][i]["pmin"],
            upperbound = pm.ref[:gen][i]["pmax"],
            start = getstart(pm.ref[:gen], i, "pg_start")
        )
    else
        pm.var[:pg] = @variable(pm.model,
            [i in keys(pm.ref[:gen])], basename="pg",
            start = getstart(pm.ref[:gen], i, "pg_start")
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:qg] = @variable(pm.model,
            [i in keys(pm.ref[:gen])], basename="qg",
            lowerbound = pm.ref[:gen][i]["qmin"],
            upperbound = pm.ref[:gen][i]["qmax"],
            start = getstart(pm.ref[:gen], i, "qg_start")
        )
    else
        pm.var[:qg] = @variable(pm.model,
            [i in keys(pm.ref[:gen])], basename="qg",
            start = getstart(pm.ref[:gen], i, "qg_start")
        )
    end
end

""
function variable_line_flow(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow(pm; kwargs...)
    variable_reactive_line_flow(pm; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_line_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:arcs]], basename="p",
            lowerbound = -pm.ref[:branch][l]["rate_a"],
            upperbound =  pm.ref[:branch][l]["rate_a"],
            start = getstart(pm.ref[:branch], l, "p_start")
        )
    else
        pm.var[:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:arcs]], basename="p",
            start = getstart(pm.ref[:branch], l, "p_start")
        )
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_line_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:q] = @variable(pm.model,
            [(l,i,j) in pm.ref[:arcs]], basename="q",
            lowerbound = -pm.ref[:branch][l]["rate_a"],
            upperbound =  pm.ref[:branch][l]["rate_a"],
            start = getstart(pm.ref[:branch], l, "q_start")
        )
    else
        pm.var[:q] = @variable(pm.model,
            [(l,i,j) in pm.ref[:arcs]], basename="q",
            start = getstart(pm.ref[:branch], l, "q_start")
        )
    end
end

function variable_dcline_flow(pm::GenericPowerModel; kwargs...)
    variable_active_dcline_flow(pm; kwargs...)
    variable_reactive_dcline_flow(pm; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:p_dc] = @variable(pm.model,
            [a in pm.ref[:arcs_dc]], basename="p_dc",
            lowerbound = pm.ref[:arcs_dc_param][a]["pmin"],
            upperbound = pm.ref[:arcs_dc_param][a]["pmax"],
            start = pm.ref[:arcs_dc_param][a]["pref"]
        )
    else
        pm.var[:p_dc] = @variable(pm.model,
            [a in pm.ref[:arcs_dc]], basename="p_dc",
            start = pm.ref[:arcs_dc_param][a]["pref"]
        )
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        pm.var[:q_dc] = @variable(pm.model,
            q_dc[a in pm.ref[:arcs_dc]], basename="q_dc",
            lowerbound = pm.ref[:arcs_dc_param][a]["qmin"],
            upperbound = pm.ref[:arcs_dc_param][a]["qmax"],
            start = pm.ref[:arcs_dc_param][a]["qref"]
        )
    else
        pm.var[:q_dc] = @variable(pm.model,
            [a in pm.ref[:arcs_dc]], basename="q_dc",
            start = pm.ref[:arcs_dc_param][a]["qref"]
        )
    end
end

"variable: `va_shift[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_phase_shift(pm::GenericPowerModel; bounded = true)

    shift_min = Dict()
    shift_max = Dict()
    shift = Dict()
    for (l,i,j) in pm.ref[:arcs_from]
        shift_min[(l,i,j)] = pm.ref[:branch][l]["shift_fr_min"]
        shift_max[(l,i,j)] = pm.ref[:branch][l]["shift_fr_max"]
        shift[(l,i,j)] = pm.ref[:branch][l]["shift_fr"]
    end
    for (l,i,j) in pm.ref[:arcs_to]
        shift_min[(l,i,j)] = pm.ref[:branch][l]["shift_to_min"]
        shift_max[(l,i,j)] = pm.ref[:branch][l]["shift_to_max"]
        shift[(l,i,j)] = pm.ref[:branch][l]["shift_to"]
    end

    pm.var[:va_shift] = @variable(pm.model,
        [(l,i,j) in pm.ref[:arcs]], basename="va_shift",
        lowerbound = shift_min[(l,i,j)],
        upperbound = shift_max[(l,i,j)],
        start = shift[(l,i,j)]
    )

    return pm.var[:va_shift]
end

"variable: `vm_tap[(l,i,j)]` for `(l,i,j)` in `arcs`"
function variable_voltage_tap(pm::GenericPowerModel; bounded = true)

    vm_tap_min = Dict()
    vm_tap_max = Dict()
    vm_tap = Dict()
    for (l,i,j) in pm.ref[:arcs_from]
        vm_tap_min[(l,i,j)] = pm.ref[:bus][i]["vmin"] / pm.ref[:branch][l]["tap_fr_max"]
        vm_tap_max[(l,i,j)] = pm.ref[:bus][i]["vmax"] / pm.ref[:branch][l]["tap_fr_min"]
        vm_tap[(l,i,j)] = pm.ref[:bus][i]["vm"] /pm.ref[:branch][l]["tap_fr"]
    end
    for (l,j,i) in pm.ref[:arcs_to]
        vm_tap_min[(l,j,i)] = pm.ref[:bus][j]["vmin"] / pm.ref[:branch][l]["tap_to_max"]
        vm_tap_max[(l,j,i)] = pm.ref[:bus][j]["vmax"] / pm.ref[:branch][l]["tap_to_min"]
        vm_tap[(l,j,i)] = pm.ref[:bus][i]["vm"] /pm.ref[:branch][l]["tap_to"]
    end

    pm.var[:vm_tap] = @variable(pm.model,
        [(l,i,j) in pm.ref[:arcs]], basename="vm_tap",
        lowerbound = vm_tap_min[(l,i,j)],
        upperbound = vm_tap_max[(l,i,j)],
        start = vm_tap[(l,i,j)]
    )

    return pm.var[:vm_tap]
end

##################################################################

"generates variables for both `active` and `reactive` `line_flow_ne`"
function variable_line_flow_ne(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow_ne(pm; kwargs...)
    variable_reactive_line_flow_ne(pm; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_line_flow_ne(pm::GenericPowerModel)
    pm.var[:p_ne] = @variable(pm.model,
        [(l,i,j) in pm.ref[:ne_arcs]], basename="p_ne",
        lowerbound = -pm.ref[:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:ne_branch], l, "p_start")
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_line_flow_ne(pm::GenericPowerModel)
    pm.var[:q_ne] = @variable(pm.model,
        q_ne[(l,i,j) in pm.ref[:ne_arcs]], basename="q_ne",
        lowerbound = -pm.ref[:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:ne_branch], l, "q_start")
    )
end

"variable: `0 <= line_z[l] <= 1` for `l` in `branch`es"
function variable_line_indicator(pm::GenericPowerModel)
    pm.var[:line_z] = @variable(pm.model,
        [l in keys(pm.ref[:branch])], basename="line_z",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(pm.ref[:branch], l, "line_z_start", 1.0)
    )
end

"variable: `0 <= line_ne[l] <= 1` for `l` in `branch`es"
function variable_line_ne(pm::GenericPowerModel)
    branches = pm.ref[:ne_branch]
    pm.var[:line_ne] = @variable(pm.model,
        [l in keys(branches)], basename="line_ne",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(branches, l, "line_tnep_start", 1.0)
    )
end
