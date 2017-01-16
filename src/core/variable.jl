################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################

# extracts the start value fro,
function getstart(set, item_key, value_key, default = 0.0)
    try
        return set[item_key][value_key]
    catch
        return default
    end
end

function variable_phase_angle{T}(pm::GenericPowerModel{T}; bounded = true)
    @variable(pm.model, t[i in keys(pm.ref[:bus])], start = getstart(pm.ref[:bus], i, "t_start"))
    return t
end

function variable_voltage_magnitude{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:bus][i]["vmin"] <= v[i in keys(pm.ref[:bus])] <= pm.ref[:bus][i]["vmax"], start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    else
        @variable(pm.model, v[i in keys(pm.ref[:bus])] >= 0, start = getstart(pm.ref[:bus], i, "v_start", 1.0))
    end
    return v
end

function variable_voltage_magnitude_sqr{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:bus][i]["vmin"]^2 <= w[i in keys(pm.ref[:bus])] <= pm.ref[:bus][i]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_start", 1.001))
    else
        @variable(pm.model, w[i in keys(pm.ref[:bus])] >= 0, start = getstart(pm.ref[:bus], i, "w_start", 1.001))
    end
    return w
end

function variable_voltage_magnitude_sqr_from_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= w_from[i in keys(pm.ref[:branch])] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_from_start", 1.001))

    return w_from
end

function variable_voltage_magnitude_sqr_to_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    @variable(pm.model, 0 <= w_to[i in keys(pm.ref[:branch])] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_to", 1.001))

    return w_to
end

function variable_active_generation{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:gen][i]["pmin"] <= pg[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["pmax"], start = getstart(pm.ref[:gen], i, "pg_start"))
    else
        @variable(pm.model, pg[i in keys(pm.ref[:gen])], start = getstart(pm.ref[:gen], i, "pg_start"))
    end
    return pg
end

function variable_reactive_generation{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.ref[:gen][i]["qmin"] <= qg[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["qmax"], start = getstart(pm.ref[:gen], i, "qg_start"))
    else
        @variable(pm.model, qg[i in keys(pm.ref[:gen])], start = getstart(pm.ref[:gen], i, "qg_start"))
    end
    return qg
end

function variable_active_line_flow{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= p[(l,i,j) in pm.ref[:arcs]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "p_start"))
    else
        @variable(pm.model, p[(l,i,j) in pm.ref[:arcs]], start = getstart(pm.ref[:branch], l, "p_start"))
    end
    return p
end

function variable_active_line_flow_ne{T}(pm::GenericPowerModel{T})
    @variable(pm.model, -pm.ext[:ne].branches[l]["rate_a"] <= p_ne[(l,i,j) in pm.ext[:ne].arcs] <= pm.ext[:ne].branches[l]["rate_a"], start = getstart(pm.ext[:ne].branches, l, "p_start"))
    return p_ne
end


function variable_reactive_line_flow{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= q[(l,i,j) in pm.ref[:arcs]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "q_start"))
    else
        @variable(pm.model, q[(l,i,j) in pm.ref[:arcs]], start = getstart(pm.ref[:branch], l, "q_start"))
    end
    return q
end

function variable_reactive_line_flow_ne{T}(pm::GenericPowerModel{T})
    @variable(pm.model, -pm.ext[:ne].branches[l]["rate_a"] <= q_ne[(l,i,j) in pm.ext[:ne].arcs] <= pm.ext[:ne].branches[l]["rate_a"], start = getstart(pm.ext[:ne].branches, l, "q_start"))
    return q_ne
end


function compute_voltage_product_bounds(buspairs)
    wr_min = Dict([(bp, -Inf) for bp in keys(buspairs)])
    wr_max = Dict([(bp,  Inf) for bp in keys(buspairs)])
    wi_min = Dict([(bp, -Inf) for bp in keys(buspairs)])
    wi_max = Dict([(bp,  Inf) for bp in keys(buspairs)])

    for (bp, buspair) in buspairs
        i,j = bp

        if buspair["angmin"] >= 0
            wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*cos(buspair["angmin"])
            wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*cos(buspair["angmax"])
            wi_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmax"])
            wi_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*sin(buspair["angmin"])
        end
        if buspair["angmax"] <= 0
            wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*cos(buspair["angmax"])
            wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*cos(buspair["angmin"])
            wi_max[bp] = buspair["v_from_min"]*buspair["v_to_min"]*sin(buspair["angmax"])
            wi_min[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmin"])
        end
        if buspair["angmin"] < 0 && buspair["angmax"] > 0
            wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*1.0
            wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*min(cos(buspair["angmin"]), cos(buspair["angmax"]))
            wi_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmax"])
            wi_min[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmin"])
        end
    end

    return wr_min, wr_max, wi_min, wi_max
end

function variable_complex_voltage_product{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

        @variable(pm.model, wr_min[bp] <= wr[bp in keys(pm.ref[:buspairs])] <= wr_max[bp], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi_min[bp] <= wi[bp in keys(pm.ref[:buspairs])] <= wi_max[bp], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    else
        @variable(pm.model, wr[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    end
    return wr, wi
end

function variable_complex_voltage_product_on_off{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr[b in keys(pm.ref[:branch])] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi[b in keys(pm.ref[:branch])] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wi_start"))

    return wr, wi
end

function variable_complex_voltage_product_matrix{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

    w_index = 1:length(keys(pm.ref[:bus]))
    lookup_w_index = Dict([(bi, i) for (i,bi) in enumerate(keys(pm.ref[:bus]))])

    @variable(pm.model, WR[1:length(keys(pm.ref[:bus])), 1:length(keys(pm.ref[:bus]))], Symmetric)
    @variable(pm.model, WI[1:length(keys(pm.ref[:bus])), 1:length(keys(pm.ref[:bus]))])

    # bounds on diagonal
    for (i, bus) in pm.ref[:bus]
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        setlowerbound(wr_ii, bus["vmin"]^2)
        setupperbound(wr_ii, bus["vmax"]^2)

        #this breaks SCS on the 3 bus exmple
        #setlowerbound(wi_ii, 0)
        #setupperbound(wi_ii, 0)
    end

    # bounds on off-diagonal
    for (i,j) in keys(pm.ref[:buspairs])
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
        setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

        setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
        setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
    end

    pm.model.ext[:lookup_w_index] = lookup_w_index
    return WR, WI
end

# Creates variables associated with differences in phase angles
function variable_phase_angle_difference{T}(pm::GenericPowerModel{T})
    @variable(pm.model, pm.ref[:buspairs][bp]["angmin"] <= td[bp in keys(pm.ref[:buspairs])] <= pm.ref[:buspairs][bp]["angmax"], start = getstart(pm.ref[:buspairs], bp, "td_start"))
    return td
end

# Creates the voltage magnitude product variables
function variable_voltage_magnitude_product{T}(pm::GenericPowerModel{T})
    vv_min = Dict([(bp, buspair["v_from_min"]*buspair["v_to_min"]) for (bp, buspair) in pm.ref[:buspairs]])
    vv_max = Dict([(bp, buspair["v_from_max"]*buspair["v_to_max"]) for (bp, buspair) in pm.ref[:buspairs]])

    @variable(pm.model,  vv_min[bp] <= vv[bp in keys(pm.ref[:buspairs])] <=  vv_max[bp], start = getstart(pm.ref[:buspairs], bp, "vv_start", 1.0))
    return vv
end

function variable_cosine{T}(pm::GenericPowerModel{T})
    cos_min = Dict([(bp, -Inf) for bp in keys(pm.ref[:buspairs])])
    cos_max = Dict([(bp,  Inf) for bp in keys(pm.ref[:buspairs])])

    for (bp, buspair) in pm.ref[:buspairs]
        if buspair["angmin"] >= 0
            cos_max[bp] = cos(buspair["angmin"])
            cos_min[bp] = cos(buspair["angmax"])
        end
        if buspair["angmax"] <= 0
            cos_max[bp] = cos(buspair["angmax"])
            cos_min[bp] = cos(buspair["angmin"])
        end
        if buspair["angmin"] < 0 && buspair["angmax"] > 0
            cos_max[bp] = 1.0
            cos_min[bp] = min(cos(buspair["angmin"]), cos(buspair["angmax"]))
        end
    end

    @variable(pm.model, cos_min[bp] <= cs[bp in keys(pm.ref[:buspairs])] <= cos_max[bp], start = getstart(pm.ref[:buspairs], bp, "cs_start", 1.0))
    return cs
end

function variable_sine{T}(pm::GenericPowerModel{T})
    @variable(pm.model, sin(pm.ref[:buspairs][bp]["angmin"]) <= si[bp in keys(pm.ref[:buspairs])] <= sin(pm.ref[:buspairs][bp]["angmax"]), start = getstart(pm.ref[:buspairs], bp, "si_start"))
    return si
end

function variable_current_magnitude_sqr{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    cm_min = Dict([(bp, 0) for bp in keys(pm.ref[:buspairs])])
    cm_max = Dict([(bp, (buspair["rate_a"]*buspair["tap"]/buspair["v_from_min"])^2) for (bp, buspair) in pm.ref[:buspairs]])

    @variable(pm.model, cm_min[bp] <= cm[bp in keys(pm.ref[:buspairs])] <=  cm_max[bp], start = getstart(pm.ref[:buspairs], bp, "cm_start"))
    return cm
end

function variable_line_indicator{T}(pm::GenericPowerModel{T})
    @variable(pm.model, 0 <= line_z[l in keys(pm.ref[:branch])] <= 1, Int, start = getstart(pm.ref[:branch], l, "line_z_start", 1.0))
    return line_z
end

function variable_line_ne{T}(pm::GenericPowerModel{T})
    branches = pm.ext[:ne].branches
    @variable(pm.model, 0 <= line_ne[l in keys(pm.ext[:ne].branches)] <= 1, Int, start = getstart(branches, l, "line_tnep_start", 1.0))
    return line_ne
end

