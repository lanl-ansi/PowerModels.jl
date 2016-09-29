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
    @variable(pm.model, t[i in pm.set.bus_indexes], start = getstart(pm.set.buses, i, "t_start"))
    return t
end

function variable_voltage_magnitude{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.set.buses[i]["vmin"] <= v[i in pm.set.bus_indexes] <= pm.set.buses[i]["vmax"], start = getstart(pm.set.buses, i, "v_start", 1.0))
    else
        @variable(pm.model, v[i in pm.set.bus_indexes] >= 0, start = getstart(pm.set.buses, i, "v_start", 1.0))
    end
    return v
end

function variable_voltage_magnitude_sqr{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.set.buses[i]["vmin"]^2 <= w[i in pm.set.bus_indexes] <= pm.set.buses[i]["vmax"]^2, start = getstart(pm.set.buses, i, "w_start", 1.001))
    else
        @variable(pm.model, w[i in pm.set.bus_indexes] >= 0, start = getstart(pm.set.buses, i, "w_start", 1.001))
    end
    return w
end

function variable_voltage_magnitude_sqr_from_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.set.branches

    @variable(pm.model, 0 <= w_from[i in pm.set.branch_indexes] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.set.buses, i, "w_from_start", 1.001))

    return w_from
end

function variable_voltage_magnitude_sqr_to_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.set.branches

    @variable(pm.model, 0 <= w_to[i in pm.set.branch_indexes] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.set.buses, i, "w_to", 1.001))

    return w_to
end

function variable_active_generation{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.set.gens[i]["pmin"] <= pg[i in pm.set.gen_indexes] <= pm.set.gens[i]["pmax"], start = getstart(pm.set.gens, i, "pg_start"))
    else
        @variable(pm.model, pg[i in pm.set.gen_indexes], start = getstart(pm.set.gens, i, "pg_start"))
    end
    return pg
end

function variable_reactive_generation{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, pm.set.gens[i]["qmin"] <= qg[i in pm.set.gen_indexes] <= pm.set.gens[i]["qmax"], start = getstart(pm.set.gens, i, "qg_start"))
    else
        @variable(pm.model, qg[i in pm.set.gen_indexes], start = getstart(pm.set.gens, i, "qg_start"))
    end
    return qg
end

function variable_active_line_flow{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, -pm.set.branches[l]["rate_a"] <= p[(l,i,j) in pm.set.arcs] <= pm.set.branches[l]["rate_a"], start = getstart(pm.set.branches, l, "p_start"))
    else
        @variable(pm.model, p[(l,i,j) in pm.set.arcs], start = getstart(pm.set.branches, l, "p_start"))
    end
    return p
end

function variable_reactive_line_flow{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, -pm.set.branches[l]["rate_a"] <= q[(l,i,j) in pm.set.arcs] <= pm.set.branches[l]["rate_a"], start = getstart(pm.set.branches, l, "q_start"))
    else
        @variable(pm.model, q[(l,i,j) in pm.set.arcs], start = getstart(pm.set.branches, l, "q_start"))
    end
    return q
end

function compute_voltage_product_bounds{T}(pm::GenericPowerModel{T})
    buspairs = pm.set.buspairs
    buspair_indexes = pm.set.buspair_indexes

    wr_min = Dict(bp => -Inf for bp in buspair_indexes)
    wr_max = Dict(bp =>  Inf for bp in buspair_indexes)
    wi_min = Dict(bp => -Inf for bp in buspair_indexes)
    wi_max = Dict(bp =>  Inf for bp in buspair_indexes)

    for bp in buspair_indexes
        i,j = bp
        buspair = buspairs[bp]
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
        wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm)

        @variable(pm.model, wr_min[bp] <= wr[bp in pm.set.buspair_indexes] <= wr_max[bp], start = getstart(pm.set.buspairs, bp, "wr_start", 1.0))
        @variable(pm.model, wi_min[bp] <= wi[bp in pm.set.buspair_indexes] <= wi_max[bp], start = getstart(pm.set.buspairs, bp, "wi_start"))
    else
        @variable(pm.model, wr[bp in pm.set.buspair_indexes], start = getstart(pm.set.buspairs, bp, "wr_start", 1.0))
        @variable(pm.model, wi[bp in pm.set.buspair_indexes], start = getstart(pm.set.buspairs, bp, "wi_start"))
    end
    return wr, wi
end

function variable_complex_voltage_product_on_off{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm)

    bi_bp = Dict(i => (b["f_bus"], b["t_bus"]) for (i,b) in pm.set.branches)

    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr[b in pm.set.branch_indexes] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.set.buspairs, bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi[b in pm.set.branch_indexes] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.set.buspairs, bi_bp[b], "wr_start"))

    return wr, wi
end

function variable_complex_voltage_product_matrix{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm)

    w_index = 1:length(pm.set.bus_indexes)
    lookup_w_index = Dict(bi => i for (i,bi) in enumerate(pm.set.bus_indexes))

    @variable(pm.model, WR[1:length(pm.set.bus_indexes), 1:length(pm.set.bus_indexes)], Symmetric)
    @variable(pm.model, WI[1:length(pm.set.bus_indexes), 1:length(pm.set.bus_indexes)])

    # bounds on diagonal
    for (i, bus) in pm.set.buses
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
    for (i,j) in pm.set.buspair_indexes
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
    @variable(pm.model, pm.set.buspairs[bp]["angmin"] <= td[bp in pm.set.buspair_indexes] <= pm.set.buspairs[bp]["angmax"], start = getstart(pm.set.buspairs, bp, "td_start"))
    return td
end

# Creates the voltage magnitude product variables
function variable_voltage_magnitude_product{T}(pm::GenericPowerModel{T})
    vv_min = Dict(bp => pm.set.buspairs[bp]["v_from_min"]*pm.set.buspairs[bp]["v_to_min"] for bp in pm.set.buspair_indexes)
    vv_max = Dict(bp => pm.set.buspairs[bp]["v_from_max"]*pm.set.buspairs[bp]["v_to_max"] for bp in pm.set.buspair_indexes)

    @variable(pm.model,  vv_min[bp] <= vv[bp in pm.set.buspair_indexes] <=  vv_max[bp], start = getstart(pm.set.buspairs, bp, "vv_start", 1.0))
    return vv
end

function variable_cosine{T}(pm::GenericPowerModel{T})
    cos_min = Dict(bp => -Inf for bp in pm.set.buspair_indexes)
    cos_max = Dict(bp =>  Inf for bp in pm.set.buspair_indexes)

    for bp in pm.set.buspair_indexes
        buspair = pm.set.buspairs[bp]
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

    @variable(pm.model, cos_min[bp] <= cs[bp in pm.set.buspair_indexes] <= cos_max[bp], start = getstart(pm.set.buspairs, bp, "cs_start", 1.0))
    return cs
end

function variable_sine{T}(pm::GenericPowerModel{T})
    @variable(pm.model, sin(pm.set.buspairs[bp]["angmin"]) <= si[bp in pm.set.buspair_indexes] <= sin(pm.set.buspairs[bp]["angmax"]), start = getstart(pm.set.buspairs, bp, "si_start"))
    return si
end

function variable_current_magnitude_sqr{T}(pm::GenericPowerModel{T})
    buspairs = pm.set.buspairs
    cm_min = Dict(bp => 0 for bp in pm.set.buspair_indexes)
    cm_max = Dict(bp => (buspairs[bp]["rate_a"]*buspairs[bp]["tap"]/buspairs[bp]["v_from_min"])^2 for bp in pm.set.buspair_indexes)

    @variable(pm.model, cm_min[bp] <= cm[bp in pm.set.buspair_indexes] <=  cm_max[bp], start = getstart(pm.set.buspairs, bp, "cm_start"))
    return cm
end

function variable_line_indicator{T}(pm::GenericPowerModel{T})
    @variable(pm.model, 0 <= line_z[l in pm.set.branch_indexes] <= 1, Int, start = getstart(pm.set.branches, l, "line_z_start", 1.0))
    return line_z
end
