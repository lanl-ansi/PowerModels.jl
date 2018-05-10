################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

"extracts the start value"
function getstart(set, item_key, value_key, default = 0.0)
    return get(get(set, item_key, Dict()), value_key, default)
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel, n::Int=pm.cnw; bounded::Bool = true)
    pm.var[:nw][n][:va] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_va",
        start = getstart(pm.ref[:nw][n][:bus], i, "va_start")
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:vm] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_vm",
            lowerbound = pm.ref[:nw][n][:bus][i]["vmin"],
            upperbound = pm.ref[:nw][n][:bus][i]["vmax"],
            start = getstart(pm.ref[:nw][n][:bus], i, "vm_start", 1.0)
        )
    else
        pm.var[:nw][n][:vm] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_vm",
            lowerbound = 0,
            start = getstart(pm.ref[:nw][n][:bus], i, "vm_start", 1.0))
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel, n::Int=pm.cnw; bounded::Bool = true)
    pm.var[:nw][n][:vr] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_vr",
        lowerbound = -pm.ref[:nw][n][:bus][i]["vmax"],
        upperbound =  pm.ref[:nw][n][:bus][i]["vmax"],
        start = getstart(pm.ref[:nw][n][:bus], i, "vr_start", 1.0)
    )
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel, n::Int=pm.cnw; bounded::Bool = true)
    pm.var[:nw][n][:vi] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_vi",
        lowerbound = -pm.ref[:nw][n][:bus][i]["vmax"],
        upperbound =  pm.ref[:nw][n][:bus][i]["vmax"],
        start = getstart(pm.ref[:nw][n][:bus], i, "vi_start")
    )
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel, n::Int=pm.cnw)
    buses = pm.ref[:nw][n][:bus]
    branches = pm.ref[:nw][n][:branch]

    pm.var[:nw][n][:vm_fr] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:branch])], basename="$(n)_vm_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"],
        start = getstart(pm.ref[:nw][n][:bus], i, "vm_fr_start", 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel, n::Int=pm.cnw)
    buses = pm.ref[:nw][n][:bus]
    branches = pm.ref[:nw][n][:branch]

    pm.var[:nw][n][:vm_to] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:branch])], basename="$(n)_vm_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"],
        start = getstart(pm.ref[:nw][n][:bus], i, "vm_to_start", 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:w] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_w",
            lowerbound = pm.ref[:nw][n][:bus][i]["vmin"]^2,
            upperbound = pm.ref[:nw][n][:bus][i]["vmax"]^2,
            start = getstart(pm.ref[:nw][n][:bus], i, "w_start", 1.001)
        )
    else
        pm.var[:nw][n][:w] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:bus])], basename="$(n)_w",
            lowerbound = 0,
            start = getstart(pm.ref[:nw][n][:bus], i, "w_start", 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel, n::Int=pm.cnw)
    buses = pm.ref[:nw][n][:bus]
    branches = pm.ref[:nw][n][:branch]

    pm.var[:nw][n][:w_fr] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:branch])], basename="$(n)_w_fr",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:nw][n][:bus], i, "w_fr_start", 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel, n::Int=pm.cnw)
    buses = pm.ref[:nw][n][:bus]
    branches = pm.ref[:nw][n][:branch]

    pm.var[:nw][n][:w_to] = @variable(pm.model,
        [i in keys(pm.ref[:nw][n][:branch])], basename="$(n)_w_to",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:nw][n][:bus], i, "w_to_start", 1.001)
    )
end


""
function variable_voltage_product(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:nw][n][:buspairs])

        pm.var[:nw][n][:wr] = @variable(pm.model,
            [bp in keys(pm.ref[:nw][n][:buspairs])], basename="$(n)_wr",
            lowerbound = wr_min[bp],
            upperbound = wr_max[bp],
            start = getstart(pm.ref[:nw][n][:buspairs], bp, "wr_start", 1.0)
        )
        pm.var[:nw][n][:wi] = @variable(pm.model,
            [bp in keys(pm.ref[:nw][n][:buspairs])], basename="$(n)_wi",
            lowerbound = wi_min[bp],
            upperbound = wi_max[bp],
            start = getstart(pm.ref[:nw][n][:buspairs], bp, "wi_start")
        )
    else
        pm.var[:nw][n][:wr] = @variable(pm.model,
            [bp in keys(pm.ref[:nw][n][:buspairs])], basename="$(n)_wr",
            start = getstart(pm.ref[:nw][n][:buspairs], bp, "wr_start", 1.0)
        )
        pm.var[:nw][n][:wi] = @variable(pm.model,
            [bp in keys(pm.ref[:nw][n][:buspairs])], basename="$(n)_wi",
            start = getstart(pm.ref[:nw][n][:buspairs], bp, "wi_start")
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel, n::Int=pm.cnw)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:nw][n][:buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:nw][n][:branch]])

    pm.var[:nw][n][:wr] = @variable(pm.model,
        [b in keys(pm.ref[:nw][n][:branch])], basename="$(n)_wr",
        lowerbound = min(0, wr_min[bi_bp[b]]),
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getstart(pm.ref[:nw][n][:buspairs], bi_bp[b], "wr_start", 1.0)
    )
    pm.var[:nw][n][:wi] = @variable(pm.model,
        [b in keys(pm.ref[:nw][n][:branch])], basename="$(n)_wi",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]),
        start = getstart(pm.ref[:nw][n][:buspairs], bi_bp[b], "wi_start")
    )
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel, n::Int=pm.cnw; kwargs...)
    variable_active_generation(pm, n; kwargs...)
    variable_reactive_generation(pm, n; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:pg] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:gen])], basename="$(n)_pg",
            lowerbound = pm.ref[:nw][n][:gen][i]["pmin"],
            upperbound = pm.ref[:nw][n][:gen][i]["pmax"],
            start = getstart(pm.ref[:nw][n][:gen], i, "pg_start")
        )
    else
        pm.var[:nw][n][:pg] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:gen])], basename="$(n)_pg",
            start = getstart(pm.ref[:nw][n][:gen], i, "pg_start")
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:qg] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:gen])], basename="$(n)_qg",
            lowerbound = pm.ref[:nw][n][:gen][i]["qmin"],
            upperbound = pm.ref[:nw][n][:gen][i]["qmax"],
            start = getstart(pm.ref[:nw][n][:gen], i, "qg_start")
        )
    else
        pm.var[:nw][n][:qg] = @variable(pm.model,
            [i in keys(pm.ref[:nw][n][:gen])], basename="$(n)_qg",
            start = getstart(pm.ref[:nw][n][:gen], i, "qg_start")
        )
    end
end



""
function variable_branch_flow(pm::GenericPowerModel, n::Int=pm.cnw; kwargs...)
    variable_active_branch_flow(pm, n; kwargs...)
    variable_reactive_branch_flow(pm, n; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_branch_flow(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs]], basename="$(n)_p",
            lowerbound = -pm.ref[:nw][n][:branch][l]["rate_a"],
            upperbound =  pm.ref[:nw][n][:branch][l]["rate_a"],
            start = getstart(pm.ref[:nw][n][:branch], l, "p_start")
        )
    else
        pm.var[:nw][n][:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs]], basename="$(n)_p",
            start = getstart(pm.ref[:nw][n][:branch], l, "p_start")
        )
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_branch_flow(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:q] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs]], basename="$(n)_q",
            lowerbound = -pm.ref[:nw][n][:branch][l]["rate_a"],
            upperbound =  pm.ref[:nw][n][:branch][l]["rate_a"],
            start = getstart(pm.ref[:nw][n][:branch], l, "q_start")
        )
    else
        pm.var[:nw][n][:q] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs]], basename="$(n)_q",
            start = getstart(pm.ref[:nw][n][:branch], l, "q_start")
        )
    end
end

function variable_dcline_flow(pm::GenericPowerModel, n::Int=pm.cnw; kwargs...)
    variable_active_dcline_flow(pm, n; kwargs...)
    variable_reactive_dcline_flow(pm, n; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:p_dc] = @variable(pm.model,
            [a in pm.ref[:nw][n][:arcs_dc]], basename="$(n)_p_dc",
            lowerbound = pm.ref[:nw][n][:arcs_dc_param][a]["pmin"],
            upperbound = pm.ref[:nw][n][:arcs_dc_param][a]["pmax"],
            start = pm.ref[:nw][n][:arcs_dc_param][a]["pref"]
        )
    else
        pm.var[:nw][n][:p_dc] = @variable(pm.model,
            [a in pm.ref[:nw][n][:arcs_dc]], basename="$(n)_p_dc",
            start = pm.ref[:nw][n][:arcs_dc_param][a]["pref"]
        )
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:q_dc] = @variable(pm.model,
            [a in pm.ref[:nw][n][:arcs_dc]], basename="$(n)_q_dc",
            lowerbound = pm.ref[:nw][n][:arcs_dc_param][a]["qmin"],
            upperbound = pm.ref[:nw][n][:arcs_dc_param][a]["qmax"],
            start = pm.ref[:nw][n][:arcs_dc_param][a]["qref"]
        )
    else
        pm.var[:nw][n][:q_dc] = @variable(pm.model,
            [a in pm.ref[:nw][n][:arcs_dc]], basename="$(n)_q_dc",
            start = pm.ref[:nw][n][:arcs_dc_param][a]["qref"]
        )
    end
end


##################################################################

"generates variables for both `active` and `reactive` `branch_flow_ne`"
function variable_branch_flow_ne(pm::GenericPowerModel, n::Int=pm.cnw; kwargs...)
    variable_active_branch_flow_ne(pm, n; kwargs...)
    variable_reactive_branch_flow_ne(pm, n; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_branch_flow_ne(pm::GenericPowerModel, n::Int=pm.cnw)
    pm.var[:nw][n][:p_ne] = @variable(pm.model,
        [(l,i,j) in pm.ref[:nw][n][:ne_arcs]], basename="$(n)_p_ne",
        lowerbound = -pm.ref[:nw][n][:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:nw][n][:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:nw][n][:ne_branch], l, "p_start")
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel, n::Int=pm.cnw)
    pm.var[:nw][n][:q_ne] = @variable(pm.model,
        [(l,i,j) in pm.ref[:nw][n][:ne_arcs]], basename="$(n)_q_ne",
        lowerbound = -pm.ref[:nw][n][:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:nw][n][:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:nw][n][:ne_branch], l, "q_start")
    )
end

"variable: `0 <= branch_z[l] <= 1` for `l` in `branch`es"
function variable_branch_indicator(pm::GenericPowerModel, n::Int=pm.cnw)
    pm.var[:nw][n][:branch_z] = @variable(pm.model,
        [l in keys(pm.ref[:nw][n][:branch])], basename="$(n)_branch_z",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(pm.ref[:nw][n][:branch], l, "branch_z_start", 1.0)
    )
end

"variable: `0 <= branch_ne[l] <= 1` for `l` in `branch`es"
function variable_branch_ne(pm::GenericPowerModel, n::Int=pm.cnw)
    branches = pm.ref[:nw][n][:ne_branch]
    pm.var[:nw][n][:branch_ne] = @variable(pm.model,
        [l in keys(branches)], basename="$(n)_branch_ne",
        lowerbound = 0,
        upperbound = 1,
        category = :Int,
        start = getstart(branches, l, "branch_tnep_start", 1.0)
    )
end
