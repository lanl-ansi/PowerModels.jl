# tools for working with a PowerModels ref dict structures


""
function calc_series_active_power_bound(branches, buses, phase::Int=1)
    pmax = Dict([(key, 0.0) for key in keys(branches)])
    for (key, branch) in branches
        bus_fr = buses[branch["f_bus"]]
        g_sh_fr = branch["g_fr"][phase]
        vmax_fr = bus_fr["vmax"][phase]
        tap_fr = branch["tap"][phase]
        smax = branch["rate_a"][phase]

        pmax[key] = smax + abs(g_sh_fr) * (vmax_fr/tap_fr)^2
    end
    return pmax
end


""
function calc_series_reactive_power_bound(branches, buses, phase::Int=1)
    qmax = Dict([(key, 0.0) for key in keys(branches)])
    for (key, branch) in branches
        bus_fr = buses[branch["f_bus"]]
        b_sh_fr = branch["g_fr"][phase]
        vmax_fr = bus_fr["vmax"][phase]
        tap_fr = branch["tap"][phase]
        smax = branch["rate_a"][phase]

        qmax[key] = smax + abs(b_sh_fr) * (vmax_fr/tap_fr)^2
    end
    return qmax
end


""
function calc_voltage_product_bounds(buspairs, phase::Int=1)
    wr_min = Dict([(bp, -Inf) for bp in keys(buspairs)])
    wr_max = Dict([(bp,  Inf) for bp in keys(buspairs)])
    wi_min = Dict([(bp, -Inf) for bp in keys(buspairs)])
    wi_max = Dict([(bp,  Inf) for bp in keys(buspairs)])

    buspairs_phase = Dict()
    for (bp, buspair) in buspairs
        buspairs_phase[bp] = Dict([(k, getmpv(v, phase)) for (k,v) in buspair])
    end

    for (bp, buspair) in buspairs_phase
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
