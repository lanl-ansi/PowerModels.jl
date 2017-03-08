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
    branches = [branch for branch in values(data["branch"])]
    if haskey(data, "ne_branch")
        append!(branches, values(data["ne_branch"]))
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

# Recusivly applies new_data to data, overwritting information
function update_data(data::Dict{AbstractString,Any}, new_data::Dict{AbstractString,Any})
    for (key, new_v) in new_data
        if haskey(data, key)
            v = data[key]
            if isa(v, Dict) && isa(new_v, Dict)
                update_data(v, new_v)
            else
                data[key] = new_v
            end
        else
            data[key] = new_v
        end
    end
end

function apply_func(data::Dict{AbstractString,Any}, key::AbstractString, func)
    if haskey(data, key)
        data[key] = func(data[key])
    end
end

# Transforms network data into per-unit
function make_per_unit(data::Dict{AbstractString,Any})
    if !haskey(data, "per_unit") || data["per_unit"] == false
        data["per_unit"] = true
        mva_base = data["baseMVA"]

        rescale = x -> x/mva_base

        if haskey(data, "bus")
            for (i, bus) in data["bus"]
                apply_func(bus, "pd", rescale)
                apply_func(bus, "qd", rescale)

                apply_func(bus, "gs", rescale)
                apply_func(bus, "bs", rescale)

                apply_func(bus, "va", deg2rad)
            end
        end

        branches = []
        if haskey(data, "branch")
            append!(branches, values(data["branch"]))
        end
        if haskey(data, "ne_branch")
            append!(branches, values(data["ne_branch"]))
        end

        for branch in branches
            apply_func(branch, "rate_a", rescale)
            apply_func(branch, "rate_b", rescale)
            apply_func(branch, "rate_c", rescale)

            apply_func(branch, "shift", deg2rad)
            apply_func(branch, "angmax", deg2rad)
            apply_func(branch, "angmin", deg2rad)
        end

        if haskey(data, "gen")
            for (i, gen) in data["gen"]
                apply_func(gen, "pg", rescale)
                apply_func(gen, "qg", rescale)

                apply_func(gen, "pmax", rescale)
                apply_func(gen, "pmin", rescale)

                apply_func(gen, "qmax", rescale)
                apply_func(gen, "qmin", rescale)

                if "model" in keys(gen) && "cost" in keys(gen)
                    if gen["model"] != 2
                        warn("Skipping generator cost model of type other than 2")
                    else
                        degree = length(gen["cost"])
                        for (i, item) in enumerate(gen["cost"])
                            gen["cost"][i] = item*mva_base^(degree-i)
                        end
                    end
                end
            end
        end

    end
end


# Transforms network data into mixed-units (inverse of per-unit)
function make_mixed_units(data::Dict{AbstractString,Any})
    if haskey(data, "per_unit") && data["per_unit"] == true
        data["per_unit"] = false
        mva_base = data["baseMVA"]

        rescale = x -> x*mva_base

        if haskey(data, "bus")
            for (i, bus) in data["bus"]
                apply_func(bus, "pd", rescale)
                apply_func(bus, "qd", rescale)

                apply_func(bus, "gs", rescale)
                apply_func(bus, "bs", rescale)

                apply_func(bus, "va", rad2deg)
            end
        end

        branches = []
        if haskey(data, "branch")
            append!(branches, values(data["branch"]))
        end
        if haskey(data, "ne_branch")
            append!(branches, values(data["ne_branch"]))
        end

        for branch in branches
            apply_func(branch, "rate_a", rescale)
            apply_func(branch, "rate_b", rescale)
            apply_func(branch, "rate_c", rescale)

            apply_func(branch, "shift", rad2deg)
            apply_func(branch, "angmax", rad2deg)
            apply_func(branch, "angmin", rad2deg)
        end

        if haskey(data, "gen")
            for (i, gen) in data["gen"]
                apply_func(gen, "pg", rescale)
                apply_func(gen, "qg", rescale)

                apply_func(gen, "pmax", rescale)
                apply_func(gen, "pmin", rescale)

                apply_func(gen, "qmax", rescale)
                apply_func(gen, "qmin", rescale)

                if "model" in keys(gen) && "cost" in keys(gen)
                    if gen["model"] != 2
                        warn("Skipping generator cost model of type other than 2")
                    else
                        degree = length(gen["cost"])
                        for (i, item) in enumerate(gen["cost"])
                            gen["cost"][i] = item/mva_base^(degree-i)
                        end
                    end
                end
            end
        end

    end
end


# checks that phase angle differences are within 90 deg., if not tightens
function check_phase_angle_differences(data, default_pad = 1.0472)
    assert("per_unit" in keys(data) && data["per_unit"])

    for (i, branch) in data["branch"]
        if branch["angmin"] <= -pi/2
            warn("this code only supports angmin values in -90 deg. to 90 deg., tightening the value on branch $(branch["index"]) from $(rad2deg(branch["angmin"])) to -$(rad2deg(default_pad)) deg.")
            branch["angmin"] = -default_pad
        end
        if branch["angmax"] >= pi/2
            warn("this code only supports angmax values in -90 deg. to 90 deg., tightening the value on branch $(branch["index"]) from $(rad2deg(branch["angmax"])) to $(rad2deg(default_pad)) deg.")
            branch["angmax"] = default_pad
        end
        if branch["angmin"] == 0.0 && branch["angmax"] == 0.0
            warn("angmin and angmax values are 0, widening these values on branch $(branch["index"]) to +/- $(rad2deg(default_pad)) deg.")
            branch["angmin"] = -rad2deg(default_pad)
            branch["angmax"] = rad2deg(default_pad)
        end
    end
end


# checks that each line has a reasonable line thermal rating, if not computes one
function check_thermal_limits(data)
    assert("per_unit" in keys(data) && data["per_unit"])
    mva_base = data["baseMVA"]

    for (i, branch) in data["branch"]
        if branch["rate_a"] <= 0.0
            theta_max = max(abs(branch["angmin"]), abs(branch["angmax"]))

            r = branch["br_r"]
            x = branch["br_x"]
            g =  r / (r^2 + x^2)
            b = -x / (r^2 + x^2)

            y_mag = sqrt(g^2 + b^2)

            fr_vmax = data["bus"][string(branch["f_bus"])]["vmax"]
            to_vmax = data["bus"][string(branch["t_bus"])]["vmax"]
            m_vmax = max(fr_vmax, to_vmax)

            c_max = sqrt(fr_vmax^2 + to_vmax^2 - 2*fr_vmax*to_vmax*cos(theta_max))

            new_rate = y_mag*m_vmax*c_max

            warn("this code only supports positive rate_a values, changing the value on branch $(branch["index"]) from $(mva_base*branch["rate_a"]) to $(mva_base*new_rate)")
            branch["rate_a"] = new_rate
        end
    end
end


# checks that each line has a reasonable transformer parameters
# this is important becouse setting tap == 0.0 leads to NaN computations, which are hard to debug
function check_transformer_parameters(data)
    assert("per_unit" in keys(data) && data["per_unit"])

    for (i, branch) in data["branch"]
        if !haskey(branch, "tap")
            warn("branch found without tap value, setting a tap to 1.0")
            branch["tap"] = 1.0
        else
            if branch["tap"] <= 0.0
                warn("branch found with non-posative tap value of $(branch["tap"]), setting a tap to 1.0")
                branch["tap"] = 1.0
            end
        end
        if !haskey(branch, "shift")
            warn("branch found without shift value, setting a shift to 0.0")
            branch["shift"] = 0.0
        end
    end
end


# checks bus types are consistent with generator connections, if not, fixes them
function check_bus_types(data)
    bus_gens = Dict([(i, []) for (i,bus) in data["bus"]])

    for (i,gen) in data["gen"]
        #println(gen)
        if gen["gen_status"] == 1
            push!(bus_gens[string(gen["gen_bus"])], i)
        end
    end

    for (i, bus) in data["bus"]
        if bus["bus_type"] != 4 && bus["bus_type"] != 3
            bus_gens_count = length(bus_gens[i])

            if bus_gens_count == 0 && bus["bus_type"] != 1
                warn("no active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 1")
                bus["bus_type"] = 1
            end

            if bus_gens_count != 0 && bus["bus_type"] != 2
                warn("active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 2")
                bus["bus_type"] = 2
            end

        end
    end

end

