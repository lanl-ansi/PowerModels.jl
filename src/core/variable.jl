################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

"extracts the start value"
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end


"variable: `t[i]` for `i` in `bus`es"
function variable_phase_angle(pm::GenericPowerModel, n::Symbol=:base; bounded::Bool = true)
    pm.var[n][:t] = @variable(pm.model,
        [i in keys(pm.ref[n][:bus])], basename="$(n)_t",
        start = getstart(pm.ref[n][:bus], i, "t_start")
    )
    return pm.var[n][:t]
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    if bounded
        pm.var[n][:v] = @variable(pm.model,
            [i in keys(pm.ref[n][:bus])], basename="$(n)_v",
            lowerbound = pm.ref[n][:bus][i]["vmin"],
            upperbound = pm.ref[n][:bus][i]["vmax"],
            start = getstart(pm.ref[n][:bus], i, "v_start", 1.0)
        )
    else
        pm.var[n][:v] = @variable(pm.model,
            [i in keys(pm.ref[n][:bus])], basename="$(n)_v",
            lowerbound = 0,
            start = getstart(pm.ref[n][:bus], i, "v_start", 1.0))
    end
    return pm.var[n][:v]
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel; bounded::Bool = true)
    pm.var[:vr] = @variable(pm.model, 
        [i in keys(pm.ref[:bus])], basename="vr",
        lowerbound = -pm.ref[:bus][i]["vmax"],
        upperbound =  pm.ref[:bus][i]["vmax"], 
        start = getstart(pm.ref[:bus], i, "vr_start", 1.0)
    )
    return pm.var[:vr]
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel; bounded::Bool = true)
    pm.var[:vi] = @variable(pm.model, 
        [i in keys(pm.ref[:bus])], basename="vi",
        lowerbound = -pm.ref[:bus][i]["vmax"],
        upperbound =  pm.ref[:bus][i]["vmax"],
        start = getstart(pm.ref[:bus], i, "vi_start")
    )
    return pm.var[:vi]
end



"variable: `0 <= v_from[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:v_from] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="v_from",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"],
        start = getstart(pm.ref[:bus], i, "v_from_start", 1.0)
    )

    return pm.var[:v_from]
end

"variable: `0 <= v_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:v_to] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="v_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"],
        start = getstart(pm.ref[:bus], i, "v_to_start", 1.0)
    )

    return pm.var[:v_to]
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
    return pm.var[:w]
end

"variable: `0 <= w_from[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    pm.var[:w_from] = @variable(pm.model,
        [i in keys(pm.ref[:branch])], basename="w_from",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:bus], i, "w_from_start", 1.001)
    )

    return pm.var[:w_from]
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

    return pm.var[:w_to]
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
    return pm.var[:wr], pm.var[:wi]
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

    return pm.var[:wr], pm.var[:wi]
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    if bounded
        pm.var[n][:pg] = @variable(pm.model,
            [i in keys(pm.ref[n][:gen])], basename="$(n)_pg",
            lowerbound = pm.ref[n][:gen][i]["pmin"],
            upperbound = pm.ref[n][:gen][i]["pmax"],
            start = getstart(pm.ref[n][:gen], i, "pg_start")
        )
    else
        pm.var[n][:pg] = @variable(pm.model,
            [i in keys(pm.ref[n][:gen])], basename="$(n)_pg",
            start = getstart(pm.ref[n][:gen], i, "pg_start")
        )
    end
    return pm.var[n][:pg]
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    if bounded
        pm.var[n][:qg] = @variable(pm.model,
            [i in keys(pm.ref[n][:gen])], basename="$(n)_qg",
            lowerbound = pm.ref[n][:gen][i]["qmin"],
            upperbound = pm.ref[n][:gen][i]["qmax"],
            start = getstart(pm.ref[n][:gen], i, "qg_start")
        )
    else
        pm.var[:qg] = @variable(pm.model,
            [i in keys(pm.ref[n][:gen])], basename="$(n)_qg",
            start = getstart(pm.ref[n][:gen], i, "qg_start")
        )
    end
    return pm.var[n][:qg]
end

""
function variable_line_flow(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow(pm; kwargs...)
    variable_reactive_line_flow(pm; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_line_flow(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    if bounded
        pm.var[n][:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[n][:arcs]], basename="$(n)_p",
            lowerbound = -pm.ref[n][:branch][l]["rate_a"],
            upperbound =  pm.ref[n][:branch][l]["rate_a"],
            start = getstart(pm.ref[n][:branch], l, "p_start")
        )
    else
        pm.var[:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[n][:arcs]], basename="$(n)_p",
            start = getstart(pm.ref[n][:branch], l, "p_start")
        )
    end
    return pm.var[n][:p]
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_line_flow(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    if bounded
        pm.var[n][:q] = @variable(pm.model,
            [(l,i,j) in pm.ref[n][:arcs]], basename="$(n)_q",
            lowerbound = -pm.ref[n][:branch][l]["rate_a"],
            upperbound =  pm.ref[n][:branch][l]["rate_a"],
            start = getstart(pm.ref[n][:branch], l, "q_start")
        )
    else
        pm.var[:q] = @variable(pm.model, 
            [(l,i,j) in pm.ref[n][:arcs]], basename="$(n)_q",
            start = getstart(pm.ref[n][:branch], l, "q_start")
        )
    end
    return pm.var[n][:q]
end

function variable_dcline_flow(pm::GenericPowerModel; kwargs...)
    variable_active_dcline_flow(pm; kwargs...)
    variable_reactive_dcline_flow(pm; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    # build bounds lookups based over arcs set
    pmin = Dict()
    pref = Dict()
    pmax = Dict()
    for (l,i,j) in pm.ref[n][:arcs_from_dc]
        pmin[(l,i,j)] = pm.ref[n][:dcline][l]["pminf"]
        pmax[(l,i,j)] = pm.ref[n][:dcline][l]["pmaxf"]
        pref[(l,i,j)] = pm.ref[n][:dcline][l]["pf"]
    end
    for (l,i,j) in pm.ref[n][:arcs_to_dc]
        pmin[(l,i,j)] = pm.ref[n][:dcline][l]["pmint"]
        pmax[(l,i,j)] = pm.ref[n][:dcline][l]["pmaxt"]
        pref[(l,i,j)] = pm.ref[n][:dcline][l]["pt"]
    end

    if bounded
        pm.var[n][:p_dc] = @variable(pm.model,
            [(l,i,j) in pm.ref[n][:arcs_dc]], basename="$(n)_p_dc",
            lowerbound = pmin[(l,i,j)],
            upperbound = pmax[(l,i,j)], 
            start = pref[(l,i,j)]
        )
    else
        pm.var[n][:p_dc] = @variable(pm.model,
            [(l,i,j) in pm.ref[n][:arcs_dc]], basename="$(n)_p_dc",
            start = pref[(l,i,j)]
        )
    end
    return pm.var[n][:p_dc]
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel, n::Symbol=:base; bounded = true)
    # build bounds lookups based over arcs set
    qmin = Dict()
    qref = Dict()
    qmax = Dict()
    for (l,i,j) in pm.ref[n][:arcs_from_dc]
        qmin[(l,i,j)] = pm.ref[n][:dcline][l]["qminf"]
        qmax[(l,i,j)] = pm.ref[n][:dcline][l]["qmaxf"]
        qref[(l,i,j)] = pm.ref[n][:dcline][l]["qf"]
    end
    for (l,i,j) in pm.ref[n][:arcs_to_dc]
        qmin[(l,i,j)] = pm.ref[n][:dcline][l]["qmint"]
        qmax[(l,i,j)] = pm.ref[n][:dcline][l]["qmaxt"]
        qref[(l,i,j)] = pm.ref[n][:dcline][l]["qt"]
    end

    if bounded
        pm.var[n][:q_dc] = @variable(pm.model, 
            q_dc[(l,i,j) in pm.ref[n][:arcs_dc]], basename="$(n)_q_dc",
            lowerbound = qmin[(l,i,j)],
            upperbound = qmax[(l,i,j)],
            start = qref[(l,i,j)]
        )
    else
        pm.var[n][:q_dc] = @variable(pm.model,
            [(l,i,j) in pm.ref[n][:arcs_dc]], basename="$(n)_q_dc",
            start = qref[(l,i,j)]
        )
    end
    return pm.var[n][:q_dc]
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
    return pm.var[:p_ne]
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_line_flow_ne(pm::GenericPowerModel)
    pm.var[:q_ne] = @variable(pm.model,
        q_ne[(l,i,j) in pm.ref[:ne_arcs]], basename="q_ne",
        lowerbound = -pm.ref[:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:ne_branch], l, "q_start")
    )
    return pm.var[:q_ne]
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
    return pm.var[:line_z]
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
    return pm.var[:line_ne]
end
