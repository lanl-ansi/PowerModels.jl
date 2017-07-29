################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

"extracts the start value"
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end

"variable: `t[i]` for `i` in `bus`es"
function variable_phase_angle(pm::GenericPowerModel; bounded::Bool = true)
    @variable(pm.model, t[i in keys(pm.ref[:bus])], start = getstart(pm.ref[:bus], i, "t_start"))
    return t
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:bus][i]["vmin"] <= v[i in keys(pm.ref[:bus])] <= pm.ref[:bus][i]["vmax"], start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    else
        @variable(pm.model, v[i in keys(pm.ref[:bus])] >= 0, start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    end
    return v
end

"variable: `0 <= v_from[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= v_from[i in keys(pm.ref[:branch])] <= buses[branches[i]["f_bus"]]["vmax"], start = getstart(pm.ref[:bus], i, "v_from_start", 1.0))

    return v_from
end

"variable: `0 <= v_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= v_to[i in keys(pm.ref[:branch])] <= buses[branches[i]["t_bus"]]["vmax"], start = getstart(pm.ref[:bus], i, "v_to_start", 1.0))

    return v_to
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:bus][i]["vmin"]^2 <= w[i in keys(pm.ref[:bus])] <= pm.ref[:bus][i]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_start", 1.001))
    else
        @variable(pm.model, w[i in keys(pm.ref[:bus])] >= 0, start = getstart(pm.ref[:bus], i, "w_start", 1.001))
    end
    return w
end

"variable: `0 <= w_from[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= w_from[i in keys(pm.ref[:branch])] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_from_start", 1.001))

    return w_from
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= w_to[i in keys(pm.ref[:branch])] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_to_start", 1.001))

    return w_to
end


""
function variable_voltage_product(pm::GenericPowerModel; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

        @variable(pm.model, wr_min[bp] <= wr[bp in keys(pm.ref[:buspairs])] <= wr_max[bp], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi_min[bp] <= wi[bp in keys(pm.ref[:buspairs])] <= wi_max[bp], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    else
        @variable(pm.model, wr[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    end
    return wr, wi
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr[b in keys(pm.ref[:branch])] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi[b in keys(pm.ref[:branch])] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wi_start"))

    return wr, wi
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end

"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:gen][i]["pmin"] <= pg[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["pmax"], start = getstart(pm.ref[:gen], i, "pg_start"))
    else
        @variable(pm.model, pg[i in keys(pm.ref[:gen])], start = getstart(pm.ref[:gen], i, "pg_start"))
    end
    return pg
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:gen][i]["qmin"] <= qg[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["qmax"], start = getstart(pm.ref[:gen], i, "qg_start"))
    else
        @variable(pm.model, qg[i in keys(pm.ref[:gen])], start = getstart(pm.ref[:gen], i, "qg_start"))
    end
    return qg
end

""
function variable_line_flow(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow(pm; kwargs...)
    variable_reactive_line_flow(pm; kwargs...)
end

"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_line_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= p[(l,i,j) in pm.ref[:arcs]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "p_start"))
    else
        @variable(pm.model, p[(l,i,j) in pm.ref[:arcs]], start = getstart(pm.ref[:branch], l, "p_start"))
    end
    return p
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_line_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= q[(l,i,j) in pm.ref[:arcs]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "q_start"))
    else
        @variable(pm.model, q[(l,i,j) in pm.ref[:arcs]], start = getstart(pm.ref[:branch], l, "q_start"))
    end
    return q
end

"generates variables for both `active` and `reactive` `line_flow_ne`"
function variable_line_flow_ne(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow_ne(pm; kwargs...)
    variable_reactive_line_flow_ne(pm; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_line_flow_ne(pm::GenericPowerModel)
    @variable(pm.model, -pm.ref[:ne_branch][l]["rate_a"] <= p_ne[(l,i,j) in pm.ref[:ne_arcs]] <= pm.ref[:ne_branch][l]["rate_a"], start = getstart(pm.ref[:ne_branch], l, "p_start"))
    return p_ne
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_line_flow_ne(pm::GenericPowerModel)
    @variable(pm.model, -pm.ref[:ne_branch][l]["rate_a"] <= q_ne[(l,i,j) in pm.ref[:ne_arcs]] <= pm.ref[:ne_branch][l]["rate_a"], start = getstart(pm.ref[:ne_branch], l, "q_start"))
    return q_ne
end

"variable: `0 <= line_z[l] <= 1` for `l` in `branch`es"
function variable_line_indicator(pm::GenericPowerModel)
    @variable(pm.model, 0 <= line_z[l in keys(pm.ref[:branch])] <= 1, Int, start = getstart(pm.ref[:branch], l, "line_z_start", 1.0))
    return line_z
end

"variable: `0 <= line_ne[l] <= 1` for `l` in `branch`es"
function variable_line_ne(pm::GenericPowerModel)
    branches = pm.ref[:ne_branch]
    @variable(pm.model, 0 <= line_ne[l in keys(branches)] <= 1, Int, start = getstart(branches, l, "line_tnep_start", 1.0))
    return line_ne
end

