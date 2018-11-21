# tools for working with a PowerModels ref dict structures


"computes flow bounds on branches"
function calc_branch_flow_bounds(branches, buses, conductor::Int=1)
    flow_lb = Dict() 
    flow_ub = Dict()

    for (i, branch) in branches
        flow_lb[i] = -Inf
        flow_ub[i] = Inf

        if haskey(branch, "rate_a")
            flow_lb[i] = max(flow_lb[i], -branch["rate_a"][conductor])
            flow_ub[i] = min(flow_ub[i],  branch["rate_a"][conductor])
        end

        if haskey(branch, "c_rating_a")
            fr_vmin = buses[branch["f_bus"]]["vmin"][conductor]
            to_vmin = buses[branch["t_bus"]]["vmin"][conductor]
            m_vmin = min(fr_vmin, to_vmin)

            flow_lb[i] = max(flow_lb[i], -branch["c_rating_a"][conductor]/m_vmin)
            flow_ub[i] = min(flow_ub[i],  branch["c_rating_a"][conductor]/m_vmin)
        end

    end

    return flow_lb, flow_ub
end


""
function calc_voltage_product_bounds(buspairs, conductor::Int=1)
    wr_min = Dict((bp, -Inf) for bp in keys(buspairs))
    wr_max = Dict((bp,  Inf) for bp in keys(buspairs))
    wi_min = Dict((bp, -Inf) for bp in keys(buspairs))
    wi_max = Dict((bp,  Inf) for bp in keys(buspairs))

    buspairs_conductor = Dict()
    for (bp, buspair) in buspairs
        buspairs_conductor[bp] = Dict((k, getmcv(v, conductor)) for (k,v) in buspair)
    end

    for (bp, buspair) in buspairs_conductor
        i,j = bp

        if buspair["angmin"] >= 0
            wr_max[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*cos(buspair["angmin"])
            wr_min[bp] = buspair["vm_fr_min"]*buspair["vm_to_min"]*cos(buspair["angmax"])
            wi_max[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*sin(buspair["angmax"])
            wi_min[bp] = buspair["vm_fr_min"]*buspair["vm_to_min"]*sin(buspair["angmin"])
        end
        if buspair["angmax"] <= 0
            wr_max[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*cos(buspair["angmax"])
            wr_min[bp] = buspair["vm_fr_min"]*buspair["vm_to_min"]*cos(buspair["angmin"])
            wi_max[bp] = buspair["vm_fr_min"]*buspair["vm_to_min"]*sin(buspair["angmax"])
            wi_min[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*sin(buspair["angmin"])
        end
        if buspair["angmin"] < 0 && buspair["angmax"] > 0
            wr_max[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*1.0
            wr_min[bp] = buspair["vm_fr_min"]*buspair["vm_to_min"]*min(cos(buspair["angmin"]), cos(buspair["angmax"]))
            wi_max[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*sin(buspair["angmax"])
            wi_min[bp] = buspair["vm_fr_max"]*buspair["vm_to_max"]*sin(buspair["angmin"])
        end

    end

    return wr_min, wr_max, wi_min, wi_max
end


"computes storage bounds"
function calc_storage_injection_bounds(storage, buses, conductor::Int=1)
    injection_lb = Dict() 
    injection_ub = Dict()

    for (i, strg) in storage
        injection_lb[i] = -Inf
        injection_ub[i] = Inf

        if haskey(strg, "thermal_rating")
            injection_lb[i] = max(injection_lb[i], -strg["thermal_rating"][conductor])
            injection_ub[i] = min(injection_ub[i],  strg["thermal_rating"][conductor])
        end

        if haskey(strg, "current_rating")
            vmin = buses[strg["storage_bus"]]["vmin"][conductor]

            injection_lb[i] = max(injection_lb[i], -strg["current_rating"][conductor]/vmin)
            injection_ub[i] = min(injection_ub[i],  strg["current_rating"][conductor]/vmin)
        end
    end

    return injection_lb, injection_ub
end
