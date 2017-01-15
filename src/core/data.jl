# tools for working with PowerModels internal data format

# updates values that are derived from other values in PM data structure 
function update_derived_values(data::Dict{AbstractString,Any})
    min_theta_delta, max_theta_delta = calc_theta_delta_bounds(data)

    add_branch_parameters(data, min_theta_delta, max_theta_delta)
end

function calc_theta_delta_bounds(data::Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    branches = data["branch"]
    if haskey(data, "branch_ne")
        append!(branches, data["branch_ne"])
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

# NOTE, this function assumes all values are p.u. and angles are in radians
function add_branch_parameters(data, min_theta_delta, max_theta_delta)
    branches = data["branch"]
    if haskey(data, "branch_ne")
        append!(branches, data["branch_ne"])
    end

    for branch in branches
        r = branch["br_r"]
        x = branch["br_x"]
        tap_ratio = branch["tap"]
        angle_shift = branch["shift"]

        branch["g"] =  r/(x^2 + r^2)
        branch["b"] = -x/(x^2 + r^2)
        branch["tr"] = tap_ratio*cos(angle_shift)
        branch["ti"] = tap_ratio*sin(angle_shift)

        branch["off_angmin"] = min_theta_delta
        branch["off_angmax"] = max_theta_delta
    end
end
