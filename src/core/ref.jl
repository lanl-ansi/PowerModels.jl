# tools for working with a PowerModels ref dict structures

""
function calc_series_current_magnitude_bound(branches, buses, phase::Int=1)
    cmax = Dict([(key, 0.0) for key in keys(branches)])

    for (key, branch) in branches
        bus_fr = buses[branch["f_bus"]]
        bus_to = buses[branch["t_bus"]]

        g_sh_fr = getmpv(branch["g_fr"], phase)
        g_sh_to = getmpv(branch["g_to"], phase)
        b_sh_fr = getmpv(branch["b_fr"], phase)
        b_sh_to = getmpv(branch["b_to"], phase)
        zmag_fr = abs(g_sh_fr + im*b_sh_fr)
        zmag_to = abs(g_sh_to + im*b_sh_to)

        vmax_fr = getmpv(bus_fr["vmax"], phase)
        vmax_to = getmpv(bus_fr["vmax"], phase)
        vmin_fr = getmpv(bus_fr["vmin"], phase)
        vmin_to = getmpv(bus_fr["vmin"], phase)

        tap_fr = getmpv(branch["tap"], phase)
        tap_to = 1 # no transformer on to side, keeps expressions symmetric.
        smax = getmpv(branch["rate_a"], phase)

        cmax_tot_fr = smax*tap_fr/vmin_fr
        cmax_tot_to = smax*tap_to/vmin_to

        cmax_sh_fr = zmag_fr * vmax_fr
        cmax_sh_to = zmag_to * vmax_to

        cmax[key] = max(cmax_tot_fr + cmax_sh_fr, cmax_tot_to + cmax_sh_to)
    end

    return cmax
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
