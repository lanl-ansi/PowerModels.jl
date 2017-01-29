# tools for working with PowerModels internal data format

function calc_voltage_product_bounds(buspairs)
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

function calc_theta_delta_bounds(data::Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    branches = [branch for branch in data["branch"]]
    if haskey(data, "ne_branch")
        append!(branches, data["ne_branch"])
    end

    angle_mins = [branch["angmin"] for branch in branches]
    angle_maxs = [branch["angmax"] for branch in branches]

    sort!(angle_mins)
    sort!(angle_maxs, rev=true)

    if length(angle_mins) > 1
        angle_min = sum(angle_mins[1:bus_count-1])
        angle_max = sum(angle_maxs[1:bus_count-1])
    else
        angle_min = angle_mins[1]
        angle_max = angle_maxs[1]
    end

    return angle_min, angle_max
end

function calc_branch_t(branch::Dict{AbstractString,Any})
    tap_ratio = branch["tap"]
    angle_shift = branch["shift"]

    tr = tap_ratio*cos(angle_shift)
    ti = tap_ratio*sin(angle_shift)

    return tr, ti
end

function calc_branch_y(branch::Dict{AbstractString,Any})
    r = branch["br_r"]
    x = branch["br_x"]

    g =  r/(x^2 + r^2)
    b = -x/(x^2 + r^2)

    return g, b
end


function check_keys(data, keys)
    for key in keys
        if haskey(data, key)
            error("attempting to overwrite value of $(key) in PowerModels data,\n$(data)")
        end
    end
end

