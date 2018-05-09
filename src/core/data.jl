# tools for working with PowerModels internal data dict structure

""
function calc_voltage_product_bounds(buspairs)
    wr_min = Dict([(bp, -Inf) for bp in keys(buspairs)])
    wr_max = Dict([(bp,  Inf) for bp in keys(buspairs)])
    wi_min = Dict([(bp, -Inf) for bp in keys(buspairs)])
    wi_max = Dict([(bp,  Inf) for bp in keys(buspairs)])

    for (bp, buspair) in buspairs
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

""
function calc_series_current_magnitude_bound(branches, buses)
    cmax = Dict([(key, 0.0) for key in keys(branches)])
    for (key, branch) in branches
        bus_fr = buses[branch["f_bus"]]
        bus_to = buses[branch["t_bus"]]

        g_sh_fr = branch["g_fr"]
        g_sh_to = branch["g_to"]
        b_sh_fr = branch["b_fr"]
        b_sh_to = branch["b_to"]
        zmag_fr = abs(g_sh_fr + im*b_sh_fr)
        zmag_to = abs(g_sh_to + im*b_sh_to)

        vmax_fr = bus_fr["vmax"]
        vmax_to = bus_fr["vmax"]
        vmin_fr = bus_fr["vmin"]
        vmin_to = bus_fr["vmin"]

        tap_fr = branch["tap"]
        tap_to = 1 # no transformer on to side, keeps expressions symmetric.
        smax = branch["rate_a"]

        cmax_tot_fr = smax*tap_fr/vmin_fr
        cmax_tot_to = smax*tap_to/vmin_to

        cmax_sh_fr = zmag_fr * vmax_fr
        cmax_sh_to = zmag_to * vmax_to

        cmax[key] = max(cmax_tot_fr + cmax_sh_fr, cmax_tot_to + cmax_sh_to)
    end
    return cmax
end


""
function calc_theta_delta_bounds(data::Dict{String,Any})
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
        # note that, this can occur when dclines are present
        angle_count = min(bus_count-1, length(branches))

        angle_min = sum(angle_mins[1:angle_count])
        angle_max = sum(angle_maxs[1:angle_count])
    else
        angle_min = angle_mins[1]
        angle_max = angle_maxs[1]
    end

    return angle_min, angle_max
end

""
function calc_branch_t(branch::Dict{String,Any})
    tap_ratio = branch["tap"]
    angle_shift = branch["shift"]

    tr = tap_ratio*cos(angle_shift)
    ti = tap_ratio*sin(angle_shift)

    return tr, ti
end

""
function calc_branch_y(branch::Dict{String,Any})
    r = branch["br_r"]
    x = branch["br_x"]

    g =  r/(x^2 + r^2)
    b = -x/(x^2 + r^2)

    return g, b
end

""
function check_keys(data, keys)
    for key in keys
        if haskey(data, key)
            error("attempting to overwrite value of $(key) in PowerModels data,\n$(data)")
        end
    end
end


"prints the text summary for a data file or dictionary to STDOUT"
function print_summary(obj::Union{String, Dict{String,Any}}; kwargs...)
    summary(STDOUT, obj; kwargs...)
end

"prints the text summary for a data file to IO"
function summary(io::IO, file::String; kwargs...)
    data = parse_file(file)
    InfrastructureModels.summary(io, data; kwargs...)
    return data
end

"prints the text summary for a data dictionary to IO"
function summary(io::IO, data::Dict{String,Any}; kwargs...)
    InfrastructureModels.summary(io, data; kwargs...)
end


"recursively applies new_data to data, overwriting information"
function update_data(data::Dict{String,Any}, new_data::Dict{String,Any})
    InfrastructureModels.update_data!(data, new_data)
end


""
function apply_func(data::Dict{String,Any}, key::String, func)
    if haskey(data, key)
        data[key] = func(data[key])
    end
end

"Transforms network data into per-unit"
function make_per_unit(data::Dict{String,Any})
    if !haskey(data, "per_unit") || data["per_unit"] == false
        data["per_unit"] = true
        mva_base = data["baseMVA"]
        if data["multinetwork"] == true
            for (i,nw_data) in data["nw"]
                _make_per_unit(nw_data, mva_base)
            end
        else
            _make_per_unit(data, mva_base)
        end
    end
end

function _make_per_unit(data::Dict{String,Any}, mva_base::Real)
    rescale      = x -> x/mva_base
    rescale_dual = x -> x*mva_base

    if haskey(data, "bus")
        for (i, bus) in data["bus"]
            apply_func(bus, "va", deg2rad)

            apply_func(bus, "lam_kcl_r", rescale_dual)
            apply_func(bus, "lam_kcl_i", rescale_dual)
        end
    end

    if haskey(data, "load")
        for (i, load) in data["load"]
            apply_func(load, "pd", rescale)
            apply_func(load, "qd", rescale)
        end
    end

    if haskey(data, "shunt")
        for (i, shunt) in data["shunt"]
            apply_func(shunt, "gs", rescale)
            apply_func(shunt, "bs", rescale)
        end
    end

    branches = []
    if haskey(data, "branch")
        append!(branches, values(data["branch"]))
    end
    dclines =[]
    if haskey(data, "dcline")
        append!(dclines, values(data["dcline"]))
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

        apply_func(branch, "pf", rescale)
        apply_func(branch, "pt", rescale)
        apply_func(branch, "qf", rescale)
        apply_func(branch, "qt", rescale)

        apply_func(branch, "mu_sm_fr", rescale_dual)
        apply_func(branch, "mu_sm_to", rescale_dual)
    end

    for dcline in dclines
        apply_func(dcline, "loss0", rescale)
        apply_func(dcline, "pf", rescale)
        apply_func(dcline, "pt", rescale)
        apply_func(dcline, "qf", rescale)
        apply_func(dcline, "qt", rescale)
        apply_func(dcline, "pmaxt", rescale)
        apply_func(dcline, "pmint", rescale)
        apply_func(dcline, "pmaxf", rescale)
        apply_func(dcline, "pminf", rescale)
        apply_func(dcline, "qmaxt", rescale)
        apply_func(dcline, "qmint", rescale)
        apply_func(dcline, "qmaxf", rescale)
        apply_func(dcline, "qminf", rescale)

        if "model" in keys(dcline) && "cost" in keys(dcline)
            if dcline["model"] == 1
                for i in 1:2:length(dcline["cost"])
                    dcline["cost"][i] = dcline["cost"][i]/mva_base
                end
            elseif dcline["model"] == 2
                degree = length(dcline["cost"])
                for (i, item) in enumerate(dcline["cost"])
                    dcline["cost"][i] = item*mva_base^(degree-i)
                end
            else
                warn(LOGGER, "Skipping dcline cost model of type $(dcline["model"]) in per unit transformation")
            end
        end
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
                if gen["model"] == 1
                    for i in 1:2:length(gen["cost"])
                        gen["cost"][i] = gen["cost"][i]/mva_base
                    end
                elseif gen["model"] == 2
                    degree = length(gen["cost"])
                    for (i, item) in enumerate(gen["cost"])
                        gen["cost"][i] = item*mva_base^(degree-i)
                    end
                else
                    warn(LOGGER, "Skipping generator cost model of type $(gen["model"]) in per unit transformation")
                end
            end
        end
    end

end


"Transforms network data into mixed-units (inverse of per-unit)"
function make_mixed_units(data::Dict{String,Any})
    if haskey(data, "per_unit") && data["per_unit"] == true
        data["per_unit"] = false
        mva_base = data["baseMVA"]
        if data["multinetwork"]
            for (i,nw_data) in data["nw"]
                _make_mixed_units(nw_data, mva_base)
            end
        else
             _make_mixed_units(data, mva_base)
        end
    end
end

function _make_mixed_units(data::Dict{String,Any}, mva_base::Real)
    rescale      = x -> x*mva_base
    rescale_dual = x -> x/mva_base

    if haskey(data, "bus")
        for (i, bus) in data["bus"]
            apply_func(bus, "va", rad2deg)

            apply_func(bus, "lam_kcl_r", rescale_dual)
            apply_func(bus, "lam_kcl_i", rescale_dual)
        end
    end

    if haskey(data, "load")
        for (i, load) in data["load"]
            apply_func(load, "pd", rescale)
            apply_func(load, "qd", rescale)
        end
    end

    if haskey(data, "shunt")
        for (i, shunt) in data["shunt"]
            apply_func(shunt, "gs", rescale)
            apply_func(shunt, "bs", rescale)
        end
    end

    branches = []
    if haskey(data, "branch")
        append!(branches, values(data["branch"]))
    end

    dclines =[]
    if haskey(data, "dcline")
        append!(dclines, values(data["dcline"]))
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

        apply_func(branch, "pf", rescale)
        apply_func(branch, "pt", rescale)
        apply_func(branch, "qf", rescale)
        apply_func(branch, "qt", rescale)

        apply_func(branch, "mu_sm_fr", rescale_dual)
        apply_func(branch, "mu_sm_to", rescale_dual)
    end

    for dcline in dclines
        apply_func(dcline, "loss0", rescale)
        apply_func(dcline, "pf", rescale)
        apply_func(dcline, "pt", rescale)
        apply_func(dcline, "qf", rescale)
        apply_func(dcline, "qt", rescale)
        apply_func(dcline, "pmaxt", rescale)
        apply_func(dcline, "pmint", rescale)
        apply_func(dcline, "pmaxf", rescale)
        apply_func(dcline, "pminf", rescale)
        apply_func(dcline, "qmaxt", rescale)
        apply_func(dcline, "qmint", rescale)
        apply_func(dcline, "qmaxf", rescale)
        apply_func(dcline, "qminf", rescale)

        if "model" in keys(dcline) && "cost" in keys(dcline)
            if dcline["model"] == 1
                for i in 1:2:length(dcline["cost"])
                    dcline["cost"][i] = dcline["cost"][i]*mva_base
                end
            elseif dcline["model"] == 2
                degree = length(dcline["cost"])
                for (i, item) in enumerate(dcline["cost"])
                    dcline["cost"][i] = item/mva_base^(degree-i)
                end
            else
                warn(LOGGER, "Skipping dcline cost model of type $(dcline["model"]) in mixed units transformation")
            end
        end
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
                if gen["model"] == 1
                    for i in 1:2:length(gen["cost"])
                        gen["cost"][i] = gen["cost"][i]*mva_base
                    end
                elseif gen["model"] == 2
                    degree = length(gen["cost"])
                    for (i, item) in enumerate(gen["cost"])
                        gen["cost"][i] = item/mva_base^(degree-i)
                    end
                else
                    warn(LOGGER, "Skipping generator cost model of type $(gen["model"]) in mixed units transformation")
                end
            end
        end
    end

end


"checks that phase angle differences are within 90 deg., if not tightens"
function check_voltage_angle_differences(data::Dict{String,Any}, default_pad = 1.0472)
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_voltage_angle_differences does not yet support multinetwork data")
    end

    assert("per_unit" in keys(data) && data["per_unit"])

    for (i, branch) in data["branch"]
        if branch["angmin"] <= -pi/2
            warn(LOGGER, "this code only supports angmin values in -90 deg. to 90 deg., tightening the value on branch $(branch["index"]) from $(rad2deg(branch["angmin"])) to -$(rad2deg(default_pad)) deg.")
            branch["angmin"] = -default_pad
        end
        if branch["angmax"] >= pi/2
            warn(LOGGER, "this code only supports angmax values in -90 deg. to 90 deg., tightening the value on branch $(branch["index"]) from $(rad2deg(branch["angmax"])) to $(rad2deg(default_pad)) deg.")
            branch["angmax"] = default_pad
        end
        if branch["angmin"] == 0.0 && branch["angmax"] == 0.0
            warn(LOGGER, "angmin and angmax values are 0, widening these values on branch $(branch["index"]) to +/- $(rad2deg(default_pad)) deg.")
            #branch["angmin"] = -rad2deg(default_pad)
            #branch["angmax"] = rad2deg(default_pad)
            branch["angmin"] = -default_pad
            branch["angmax"] = default_pad
        end
    end
end

"checks that each branch has a reasonable thermal rating, if not computes one"
function check_thermal_limits(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_thermal_limits does not yet support multinetwork data")
    end

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

            warn(LOGGER, "this code only supports positive rate_a values, changing the value on branch $(branch["index"]) from $(mva_base*branch["rate_a"]) to $(mva_base*new_rate)")
            branch["rate_a"] = new_rate
        end
    end
end


"checks that all parallel branches have the same orientation"
function check_branch_directions(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_branch_directions does not yet support multinetwork data")
    end

    orientations = Set()
    for (i, branch) in data["branch"]
        orientation = (branch["f_bus"], branch["t_bus"])
        orientation_rev = (branch["t_bus"], branch["f_bus"])

        if in(orientation_rev, orientations)
            warn(LOGGER, "reversing the orientation of branch $(i) $(orientation) to be consistent with other parallel branches")
            branch_orginal = copy(branch)
            branch["f_bus"] = branch_orginal["t_bus"]
            branch["t_bus"] = branch_orginal["f_bus"]
            branch["tap"] = 1/branch_orginal["tap"]
            branch["br_r"] = branch_orginal["br_r"]*branch_orginal["tap"]^2
            branch["br_x"] = branch_orginal["br_x"]*branch_orginal["tap"]^2
            branch["shift"] = -branch_orginal["shift"]
            branch["angmin"] = -branch_orginal["angmax"]
            branch["angmax"] = -branch_orginal["angmin"]
        else
            push!(orientations, orientation)
        end

    end
end


"checks that all branches connect two distinct buses"
function check_branch_loops(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_branch_loops does not yet support multinetwork data")
    end

    for (i, branch) in data["branch"]
        if branch["f_bus"] == branch["t_bus"]
            error(LOGGER, "both sides of branch $(i) connect to bus $(branch["f_bus"])")
        end
    end
end


"checks that all buses are unique and other components link to valid buses"
function check_connectivity(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_connectivity does not yet support multinetwork data")
    end

    bus_ids = Set([bus["index"] for (i,bus) in data["bus"]])
    assert(length(bus_ids) == length(data["bus"])) # if this is not true something very bad is going on

    for (i, load) in data["load"]
        if !(load["load_bus"] in bus_ids)
            error(LOGGER, "bus $(load["load_bus"]) in load $(i) is not defined")
        end
    end

    for (i, shunt) in data["shunt"]
        if !(shunt["shunt_bus"] in bus_ids)
            error(LOGGER, "bus $(shunt["shunt_bus"]) in shunt $(i) is not defined")
        end
    end

    for (i, gen) in data["gen"]
        if !(gen["gen_bus"] in bus_ids)
            error(LOGGER, "bus $(gen["gen_bus"]) in generator $(i) is not defined")
        end
    end

    for (i, branch) in data["branch"]
        if !(branch["f_bus"] in bus_ids)
            error(LOGGER, "from bus $(branch["f_bus"]) in branch $(i) is not defined")
        end

        if !(branch["t_bus"] in bus_ids)
            error(LOGGER, "to bus $(branch["t_bus"]) in branch $(i) is not defined")
        end
    end

    for (i, dcline) in data["dcline"]
        if !(dcline["f_bus"] in bus_ids)
            error(LOGGER, "from bus $(dcline["f_bus"]) in dcline $(i) is not defined")
        end

        if !(dcline["t_bus"] in bus_ids)
            error(LOGGER, "to bus $(dcline["t_bus"]) in dcline $(i) is not defined")
        end
    end
end


"""
checks that each branch has a reasonable transformer parameters

this is important because setting tap == 0.0 leads to NaN computations, which are hard to debug
"""
function check_transformer_parameters(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_transformer_parameters does not yet support multinetwork data")
    end

    assert("per_unit" in keys(data) && data["per_unit"])

    for (i, branch) in data["branch"]
        if !haskey(branch, "tap")
            warn(LOGGER, "branch found without tap value, setting a tap to 1.0")
            branch["tap"] = 1.0
        else
            if branch["tap"] <= 0.0
                warn(LOGGER, "branch found with non-posative tap value of $(branch["tap"]), setting a tap to 1.0")
                branch["tap"] = 1.0
            end
        end
        if !haskey(branch, "shift")
            warn(LOGGER, "branch found without shift value, setting a shift to 0.0")
            branch["shift"] = 0.0
        end
    end
end


"checks bus types are consistent with generator connections, if not, fixes them"
function check_bus_types(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_bus_types does not yet support multinetwork data")
    end

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
                warn(LOGGER, "no active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 1")
                bus["bus_type"] = 1
            end

            if bus_gens_count != 0 && bus["bus_type"] != 2
                warn(LOGGER, "active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 2")
                bus["bus_type"] = 2
            end

        end
    end
end


"checks that parameters for dc lines are reasonable"
function check_dcline_limits(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_dcline_limits does not yet support multinetwork data")
    end

    assert("per_unit" in keys(data) && data["per_unit"])
    mva_base = data["baseMVA"]

    for (i, dcline) in data["dcline"]
        if dcline["loss0"] < 0.0
            new_rate = 0.0
            warn(LOGGER, "this code only supports positive loss0 values, changing the value on dcline $(dcline["index"]) from $(mva_base*dcline["loss0"]) to $(mva_base*new_rate)")
            dcline["loss0"] = new_rate
          end

        if dcline["loss0"] >= dcline["pmaxf"]*(1-dcline["loss1"] )+ dcline["pmaxt"]
            new_rate = 0.0
            warn(LOGGER, "this code only supports loss0 values which are consistent with the line flow bounds, changing the value on dcline $(dcline["index"]) from $(mva_base*dcline["loss0"]) to $(mva_base*new_rate)")
            dcline["loss0"] = new_rate
          end

        if dcline["loss1"] < 0.0
            new_rate = 0.0
            warn(LOGGER, "this code only supports positive loss1 values, changing the value on dcline $(dcline["index"]) from $(dcline["loss1"]) to $(new_rate)")
            dcline["loss1"] = new_rate
        end

        if dcline["loss1"] >= 1.0
            new_rate = 0.0
            warn(LOGGER, "this code only supports loss1 values < 1, changing the value on dcline $(dcline["index"]) from $(dcline["loss1"]) to $(new_rate)")
            dcline["loss1"] = new_rate
        end

        if dcline["pmint"] <0.0 && dcline["loss1"] > 0.0
            #new_rate = 0.0
            warn(LOGGER, "the dc line model is not meant to be used bi-directionally when loss1 > 0, be careful interpreting the results as the dc line losses can now be negative. change loss1 to 0 to avoid this warning")
            #dcline["loss0"] = new_rate
        end
    end
end


"throws warnings if generator and dc line voltage setpoints are not consistent with the bus voltage setpoint"
function check_voltage_setpoints(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_voltage_setpoints does not yet support multinetwork data")
    end

    for (i,gen) in data["gen"]
        bus_id = gen["gen_bus"]
        bus = data["bus"]["$(bus_id)"]
        if gen["vg"] != bus["vm"]
           warn(LOGGER, "the voltage setpoint on generator $(i) does not match the value at bus $(bus_id)")
        end
    end

    for (i, dcline) in data["dcline"]
        bus_fr_id = dcline["f_bus"]
        bus_to_id = dcline["t_bus"]

        bus_fr = data["bus"]["$(bus_fr_id)"]
        bus_to = data["bus"]["$(bus_to_id)"]

        if dcline["vf"] != bus_fr["vm"]
           warn(LOGGER, "the from bus voltage setpoint on dc line $(i) does not match the value at bus $(bus_fr_id)")
        end

        if dcline["vt"] != bus_to["vm"]
           warn(LOGGER, "the to bus voltage setpoint on dc line $(i) does not match the value at bus $(bus_to_id)")
        end
    end
end


"throws warnings if cost functions are malformed"
function check_cost_functions(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("check_cost_functions does not yet support multinetwork data")
    end

    for (i,gen) in data["gen"]
        _check_cost_functions(i,gen)
    end
    for (i, dcline) in data["dcline"]
        _check_cost_functions(i,dcline)
    end
end

function _check_cost_functions(id, comp)
    if "model" in keys(comp) && "cost" in keys(comp)
        if comp["model"] == 1
            if length(comp["cost"]) != 2*comp["ncost"]
                error("ncost of $(comp["ncost"]) not consistent with $(length(comp["cost"])) cost values")
            end
            if length(comp["cost"]) < 4
                error("cost includes $(comp["ncost"]) points, but at least two points are required")
            end
            for i in 3:2:length(comp["cost"])
                if comp["cost"][i-2] >= comp["cost"][i]
                    error("non-increasing x values in pwl cost model")
                end
            end
            if "pmin" in keys(comp) && "pmax" in keys(comp)
                pmin = comp["pmin"]
                pmax = comp["pmax"]
                for i in 3:2:length(comp["cost"])
                    if comp["cost"][i] < pmin || comp["cost"][i] > pmax
                        warn(LOGGER, "pwl x value $(comp["cost"][i]) is outside the generator bounds $(pmin)-$(pmax)")
                    end
                end
            end
        elseif comp["model"] == 2
            if length(comp["cost"]) != comp["ncost"]
                error("ncost of $(comp["ncost"]) not consistent with $(length(comp["cost"])) cost values")
            end
        else
            warn(LOGGER, "Unknown generator cost model of type $(comp["model"])")
        end
    end
end



"""
finds active network buses and branches that are not necessary for the
computation and sets their status to off.

Works on a PowerModels data dict, so that a it can be used without a GenericPowerModel object

Warning: this implementation has quadratic complexity, in the worst case
"""
function propagate_topology_status(data::Dict{String,Any})
    if data["multinetwork"]
        for (i,nw_data) in data["nw"]
            _propagate_topology_status(nw_data)
        end
    else
         _propagate_topology_status(data)
    end
end

function _propagate_topology_status(data::Dict{String,Any})
    buses = Dict(bus["bus_i"] => bus for (i,bus) in data["bus"])

    for (i,load) in data["load"]
        if load["status"] != 0 && load["pd"] == 0.0 && load["qd"] == 0.0
            info(LOGGER, "deactivating load $(load["index"]) due to zero pd and qd")
            load["status"] = 0
        end
    end

    for (i,shunt) in data["shunt"]
        if shunt["status"] != 0 && shunt["gs"] == 0.0 && shunt["bs"] == 0.0
            info(LOGGER, "deactivating shunt $(shunt["index"]) due to zero gs and bs")
            shunt["status"] = 0
        end
    end

    # compute what active components are incident to each bus
    incident_load = bus_load_lookup(data["load"], data["bus"])
    incident_active_load = Dict()
    for (i, load_list) in incident_load
        incident_active_load[i] = filter(load -> load["status"] != 0, load_list)
    end

    incident_shunt = bus_shunt_lookup(data["shunt"], data["bus"])
    incident_active_shunt = Dict()
    for (i, shunt_list) in incident_shunt
        incident_active_shunt[i] = filter(shunt -> shunt["status"] != 0, shunt_list)
    end

    incident_gen = bus_gen_lookup(data["gen"], data["bus"])
    incident_active_gen = Dict()
    for (i, gen_list) in incident_gen
        incident_active_gen[i] = filter(gen -> gen["gen_status"] != 0, gen_list)
    end

    incident_branch = Dict(bus["bus_i"] => [] for (i,bus) in data["bus"])
    for (i,branch) in data["branch"]
        push!(incident_branch[branch["f_bus"]], branch)
        push!(incident_branch[branch["t_bus"]], branch)
    end

    incident_dcline = Dict(bus["bus_i"] => [] for (i,bus) in data["bus"])
    for (i,dcline) in data["dcline"]
        push!(incident_dcline[dcline["f_bus"]], dcline)
        push!(incident_dcline[dcline["t_bus"]], dcline)
    end

    updated = true
    iteration = 0

    while updated
        while updated
            iteration += 1
            updated = false

            for (i,branch) in data["branch"]
                if branch["br_status"] != 0
                    f_bus = buses[branch["f_bus"]]
                    t_bus = buses[branch["t_bus"]]

                    if f_bus["bus_type"] == 4 || t_bus["bus_type"] == 4
                        info(LOGGER, "deactivating branch $(i):($(branch["f_bus"]),$(branch["t_bus"])) due to connecting bus status")
                        branch["br_status"] = 0
                        updated = true
                    end
                end
            end

            for (i,dcline) in data["dcline"]
                if dcline["br_status"] != 0
                    f_bus = buses[dcline["f_bus"]]
                    t_bus = buses[dcline["t_bus"]]

                    if f_bus["bus_type"] == 4 || t_bus["bus_type"] == 4
                        info(LOGGER, "deactivating dcline $(i):($(dcline["f_bus"]),$(dcline["t_bus"])) due to connecting bus status")
                        dcline["br_status"] = 0
                        updated = true
                    end
                end
            end

            for (i,bus) in buses
                if bus["bus_type"] != 4
                    if length(incident_branch[i]) + length(incident_dcline[i]) > 0
                        incident_branch_count = sum([0; [branch["br_status"] for branch in incident_branch[i]]])
                        incident_dcline_count = sum([0; [dcline["br_status"] for dcline in incident_dcline[i]]])
                        incident_active_edge = incident_branch_count + incident_dcline_count
                    else
                        incident_active_edge = 0
                    end

                    #println("bus $(i) active branch $(incident_active_edge)")
                    #println("bus $(i) active gen $(incident_active_gen)")
                    #println("bus $(i) active load $(incident_active_load)")
                    #println("bus $(i) active shunt $(incident_active_shunt)")

                    if incident_active_edge == 1 && length(incident_active_gen[i]) == 0 && length(incident_active_load[i]) == 0 && length(incident_active_shunt[i]) == 0
                        info(LOGGER, "deactivating bus $(i) due to dangling bus without generation and load")
                        bus["bus_type"] = 4
                        updated = true
                    end

                else # bus type == 4
                    for load in incident_active_load[i]
                        if load["status"] != 0
                            info(LOGGER, "deactivating load $(load["index"]) due to inactive bus $(i)")
                            load["status"] = 0
                            updated = true
                        end
                    end

                    for shunt in incident_active_shunt[i]
                        if shunt["status"] != 0
                            info(LOGGER, "deactivating shunt $(shunt["index"]) due to inactive bus $(i)")
                            shunt["status"] = 0
                            updated = true
                        end
                    end

                    for gen in incident_active_gen[i]
                        if gen["gen_status"] != 0
                            info(LOGGER, "deactivating generator $(gen["index"]) due to inactive bus $(i)")
                            gen["gen_status"] = 0
                            updated = true
                        end
                    end
                end
            end
        end

        ccs = connected_components(data)

        #println(ccs)
        #TODO set reference node for each cc

        for cc in ccs
            cc_active_loads = [0]
            cc_active_shunts = [0]
            cc_active_gens = [0]

            for i in cc
                cc_active_loads = push!(cc_active_loads, length(incident_active_load[i]))
                cc_active_shunts = push!(cc_active_shunts, length(incident_active_shunt[i]))
                cc_active_gens = push!(cc_active_gens, length(incident_active_gen[i]))
            end

            active_load_count = sum(cc_active_loads)
            active_shunt_count = sum(cc_active_shunts)
            active_gen_count = sum(cc_active_gens)

            if (active_load_count == 0 && active_shunt_count == 0) || active_gen_count == 0
                info(LOGGER, "deactivating connected component $(cc) due to isolation without generation and load")
                for i in cc
                    buses[i]["bus_type"] = 4
                end
                updated = true
            end
        end

    end

    info(LOGGER, "topology status propagation fixpoint reached in $(iteration) rounds")

    check_refrence_buses(data)
end


"""
determines the largest connected component of the network and turns everything else off
"""
function select_largest_component(data::Dict{String,Any})
    if data["multinetwork"]
        for (i,nw_data) in data["nw"]
            _select_largest_component(nw_data)
        end
    else
         _select_largest_component(data)
    end
end

function _select_largest_component(data::Dict{String,Any})
    ccs = connected_components(data)
    info(LOGGER, "found $(length(ccs)) components")

    ccs_order = sort(collect(ccs); by=length)
    largest_cc = ccs_order[end]

    info(LOGGER, "largest component has $(length(largest_cc)) buses")

    for (i,bus) in data["bus"]
        if bus["bus_type"] != 4 && !(bus["index"] in largest_cc)
            bus["bus_type"] = 4
            info(LOGGER, "deactivating bus $(i) due to small connected component")
        end
    end

    check_refrence_buses(data)
end


"""
checks that each connected components has a reference bus, if not, adds one
"""
function check_refrence_buses(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        for (i,nw_data) in data["nw"]
            _check_refrence_buses(nw_data)
        end
    else
        _check_refrence_buses(data)
    end
end


function _check_refrence_buses(data::Dict{String,Any})
    bus_lookup = Dict(bus["bus_i"] => bus for (i,bus) in data["bus"])
    bus_gen = bus_gen_lookup(data["gen"], data["bus"])

    ccs = connected_components(data)
    ccs_order = sort(collect(ccs); by=length)

    bus_to_cc = Dict()
    for (i, cc) in enumerate(ccs_order)
        for bus_i in cc
            bus_to_cc[bus_i] = i
        end
    end

    cc_gens = Dict( i => Dict() for (i, cc) in enumerate(ccs_order) )
    for (i, gen) in data["gen"]
        bus_id = gen["gen_bus"]
        if haskey(bus_to_cc, bus_id)
            cc_id = bus_to_cc[bus_id]
            cc_gens[cc_id][i] = gen
        end
    end

    for (i, cc) in enumerate(ccs_order)
        check_component_refrence_bus(cc, bus_lookup, cc_gens[i])
    end
end


"""
checks that a connected component has a reference bus, if not, adds one
"""
function check_component_refrence_bus(component_bus_ids, bus_lookup, component_gens)
    refrence_buses = Set()
    for bus_id in component_bus_ids
        bus = bus_lookup[bus_id]
        if bus["bus_type"] == 3
            push!(refrence_buses, bus_id)
        end
    end

    if length(refrence_buses) == 0
        warn(LOGGER, "no reference bus found in connected component $(component_bus_ids)")

        if length(component_gens) > 0
            big_gen = biggest_generator(component_gens)
            gen_bus = bus_lookup[big_gen["gen_bus"]]
            gen_bus["bus_type"] = 3
            warn(LOGGER, "setting bus $(gen_bus["index"]) as reference bus in connected component $(component_bus_ids), based on generator $(big_gen["index"])")
        else
            warn(LOGGER, "no generators found in connected component $(component_bus_ids), try running propagate_topology_status")
        end
    end
end


"builds a lookup list of what generators are connected to a given bus"
function bus_gen_lookup(gen_data::Dict{String,Any}, bus_data::Dict{String,Any})
    bus_gen = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,gen) in gen_data
        push!(bus_gen[gen["gen_bus"]], gen)
    end
    return bus_gen
end

"builds a lookup list of what loads are connected to a given bus"
function bus_load_lookup(load_data::Dict{String,Any}, bus_data::Dict{String,Any})
    bus_load = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,load) in load_data
        push!(bus_load[load["load_bus"]], load)
    end
    return bus_load
end

"builds a lookup list of what shunts are connected to a given bus"
function bus_shunt_lookup(shunt_data::Dict{String,Any}, bus_data::Dict{String,Any})
    bus_shunt = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,shunt) in shunt_data
        push!(bus_shunt[shunt["shunt_bus"]], shunt)
    end
    return bus_shunt
end


"""
computes the connected components of the network graph
returns a set of sets of bus ids, each set is a connected component
"""
function connected_components(data::Dict{String,Any})
    if haskey(data, "multinetwork") && data["multinetwork"]
        error("connected_components does not yet support multinetwork data")
    end

    active_bus = filter((i, bus) -> bus["bus_type"] != 4, data["bus"])
    active_bus_ids = Set{Int64}([bus["bus_i"] for (i,bus) in active_bus])
    #println(active_bus_ids)

    neighbors = Dict(i => [] for i in active_bus_ids)
    for (i,branch) in data["branch"]
        if branch["br_status"] != 0 && branch["f_bus"] in active_bus_ids && branch["t_bus"] in active_bus_ids
            push!(neighbors[branch["f_bus"]], branch["t_bus"])
            push!(neighbors[branch["t_bus"]], branch["f_bus"])
        end
    end
    for (i,dcline) in data["dcline"]
        if dcline["br_status"] != 0 && dcline["f_bus"] in active_bus_ids && dcline["t_bus"] in active_bus_ids
            push!(neighbors[dcline["f_bus"]], dcline["t_bus"])
            push!(neighbors[dcline["t_bus"]], dcline["f_bus"])
        end
    end
    #println(neighbors)

    component_lookup = Dict(i => Set{Int64}([i]) for i in active_bus_ids)
    touched = Set{Int64}()

    for i in active_bus_ids
        if !(i in touched)
            _dfs(i, neighbors, component_lookup, touched)
        end
    end

    ccs = (Set(values(component_lookup)))

    return ccs
end


"""
performs DFS on a graph
"""
function _dfs(i, neighbors, component_lookup, touched)
    push!(touched, i)
    for j in neighbors[i]
        if !(j in touched)
            new_comp = union(component_lookup[i], component_lookup[j])
            for k in new_comp
                component_lookup[k] = new_comp
            end
            _dfs(j, neighbors, component_lookup, touched)
        end
    end
end
