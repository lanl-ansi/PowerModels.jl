################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

# extracts the start value fro,
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end

function variable_phase_angle(pm::GenericPowerModel; bounded::Bool = true)
    @variable(pm.model, t[i in keys(pm.ref[:bus])], start = getstart(pm.ref[:bus], i, "t_start"))
    return t
end

function variable_voltage_magnitude(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:bus][i]["vmin"] <= v[i in keys(pm.ref[:bus])] <= pm.ref[:bus][i]["vmax"], start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    else
        @variable(pm.model, v[i in keys(pm.ref[:bus])] >= 0, start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    end
    return v
end

function variable_voltage_magnitude_sqr(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:bus][i]["vmin"]^2 <= w[i in keys(pm.ref[:bus])] <= pm.ref[:bus][i]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_start", 1.001))
    else
        @variable(pm.model, w[i in keys(pm.ref[:bus])] >= 0, start = getstart(pm.ref[:bus], i, "w_start", 1.001))
    end
    return w
end

function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= w_from[i in keys(pm.ref[:branch])] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_from_start", 1.001))

    return w_from
end

function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel)
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= w_to[i in keys(pm.ref[:branch])] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_to", 1.001))

    return w_to
end


function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end

function variable_active_generation(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:gen][i]["pmin"] <= pg[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["pmax"], start = getstart(pm.ref[:gen], i, "pg_start"))
    else
        @variable(pm.model, pg[i in keys(pm.ref[:gen])], start = getstart(pm.ref[:gen], i, "pg_start"))
    end
    return pg
end

function variable_reactive_generation(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:gen][i]["qmin"] <= qg[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["qmax"], start = getstart(pm.ref[:gen], i, "qg_start"))
    else
        @variable(pm.model, qg[i in keys(pm.ref[:gen])], start = getstart(pm.ref[:gen], i, "qg_start"))
    end
    return qg
end


function variable_line_flow(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow(pm; kwargs...)
    variable_reactive_line_flow(pm; kwargs...)
end

function variable_active_line_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= p[(l,i,j) in pm.ref[:arcs]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "p_start"))
    else
        @variable(pm.model, p[(l,i,j) in pm.ref[:arcs]], start = getstart(pm.ref[:branch], l, "p_start"))
    end
    return p
end

function variable_reactive_line_flow(pm::GenericPowerModel; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= q[(l,i,j) in pm.ref[:arcs]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "q_start"))
    else
        @variable(pm.model, q[(l,i,j) in pm.ref[:arcs]], start = getstart(pm.ref[:branch], l, "q_start"))
    end
    return q
end


function variable_line_flow_ne(pm::GenericPowerModel; kwargs...)
    variable_active_line_flow_ne(pm; kwargs...)
    variable_reactive_line_flow_ne(pm; kwargs...)
end

function variable_active_line_flow_ne(pm::GenericPowerModel)
    @variable(pm.model, -pm.ref[:ne_branch][l]["rate_a"] <= p_ne[(l,i,j) in pm.ref[:ne_arcs]] <= pm.ref[:ne_branch][l]["rate_a"], start = getstart(pm.ref[:ne_branch], l, "p_start"))
    return p_ne
end

function variable_reactive_line_flow_ne(pm::GenericPowerModel)
    @variable(pm.model, -pm.ref[:ne_branch][l]["rate_a"] <= q_ne[(l,i,j) in pm.ref[:ne_arcs]] <= pm.ref[:ne_branch][l]["rate_a"], start = getstart(pm.ref[:ne_branch], l, "q_start"))
    return q_ne
end


function variable_line_indicator(pm::GenericPowerModel)
    @variable(pm.model, 0 <= line_z[l in keys(pm.ref[:branch])] <= 1, Int, start = getstart(pm.ref[:branch], l, "line_z_start", 1.0))
    return line_z
end

function variable_line_ne(pm::GenericPowerModel)
    branches = pm.ref[:ne_branch]
    @variable(pm.model, 0 <= line_ne[l in keys(branches)] <= 1, Int, start = getstart(branches, l, "line_tnep_start", 1.0))
    return line_ne
end

