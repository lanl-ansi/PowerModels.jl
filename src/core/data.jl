# tools for working with a PowerModels data dict structure
import LinearAlgebra: pinv


""
function calc_branch_t(branch::Dict{String,<:Any})
    tap_ratio = branch["tap"]
    angle_shift = branch["shift"]

    tr = tap_ratio .* cos.(angle_shift)
    ti = tap_ratio .* sin.(angle_shift)

    return tr, ti
end


""
function calc_branch_y(branch::Dict{String,<:Any})
    y = pinv(branch["br_r"] + im * branch["br_x"])
    g, b = real(y), imag(y)
    return g, b
end


""
function calc_theta_delta_bounds(data::Dict{String,<:Any})
    bus_count = length(data["bus"])
    branches = [branch for branch in values(data["branch"])]
    if haskey(data, "ne_branch")
        append!(branches, values(data["ne_branch"]))
    end

    angle_min = Real[]
    angle_max = Real[]

    conductors = 1
    if haskey(data, "conductors")
        conductors = data["conductors"]
    end
    conductor_ids = 1:conductors

    for c in conductor_ids
        angle_mins = [branch["angmin"][c] for branch in branches]
        angle_maxs = [branch["angmax"][c] for branch in branches]

        sort!(angle_mins)
        sort!(angle_maxs, rev=true)

        if length(angle_mins) > 1
            # note that, this can occur when dclines are present
            angle_count = min(bus_count-1, length(branches))

            angle_min_val = sum(angle_mins[1:angle_count])
            angle_max_val = sum(angle_maxs[1:angle_count])
        else
            angle_min_val = angle_mins[1]
            angle_max_val = angle_maxs[1]
        end

        push!(angle_min, angle_min_val)
        push!(angle_max, angle_max_val)
    end

    if haskey(data, "conductors")
        amin = MultiConductorVector(angle_min)
        amax = MultiConductorVector(angle_max)
        return amin, amax
    else
        return angle_min[1], angle_max[1]
    end
end


""
function calc_max_cost_index(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        max_index = 0
        for (i,nw_data) in data["nw"]
            nw_max_index = _calc_max_cost_index(nw_data)
            max_index = max(max_index, nw_max_index)
        end
        return max_index
    else
        return _calc_max_cost_index(data)
    end
end


""
function _calc_max_cost_index(data::Dict{String,<:Any})
    max_index = 0

    for (i,gen) in data["gen"]
        if haskey(gen, "model")
            if gen["model"] == 2
                if haskey(gen, "cost")
                    max_index = max(max_index, length(gen["cost"]))
                end
            else
                Memento.warn(_LOGGER, "skipping cost generator $(i) cost model in calc_cost_order, only model 2 is supported.")
            end
        end
    end

    for (i,dcline) in data["dcline"]
        if haskey(dcline, "model")
            if dcline["model"] == 2
                if haskey(dcline, "cost")
                    max_index = max(max_index, length(dcline["cost"]))
                end
            else
                Memento.warn(_LOGGER, "skipping cost dcline $(i) cost model in calc_cost_order, only model 2 is supported.")
            end
        end
    end

    return max_index
end


"prints the text summary for a data file or dictionary to stdout"
function print_summary(obj::Union{String, Dict{String,<:Any}}; kwargs...)
    summary(stdout, obj; kwargs...)
end


"prints the text summary for a data file to IO"
function summary(io::IO, file::String; kwargs...)
    data = parse_file(file)
    summary(io, data; kwargs...)
    return data
end


const _pm_component_types_order = Dict(
    "bus" => 1.0, "load" => 2.0, "shunt" => 3.0, "gen" => 4.0, "storage" => 5.0,
    "branch" => 6.0, "dcline" => 7.0
)

const _pm_component_parameter_order = Dict(
    "bus_i" => 1.0, "load_bus" => 2.0, "shunt_bus" => 3.0, "gen_bus" => 4.0,
    "storage_bus" => 5.0, "f_bus" => 6.0, "t_bus" => 7.0,

    "bus_name" => 9.1, "base_kv" => 9.2, "bus_type" => 9.3,

    "vm" => 10.0, "va" => 11.0,
    "pd" => 20.0, "qd" => 21.0,
    "gs" => 30.0, "bs" => 31.0,
    "pg" => 40.0, "qg" => 41.0, "vg" => 42.0, "mbase" => 43.0,
    "energy" => 44.0,
    "br_r" => 50.0, "br_x" => 51.0, "g_fr" => 52.0, "b_fr" => 53.0,
    "g_to" => 54.0, "b_to" => 55.0, "tap" => 56.0, "shift" => 57.0,
    "vf" => 58.1, "pf" => 58.2, "qf" => 58.3,
    "vt" => 58.4, "pt" => 58.5, "qt" => 58.6,
    "loss0" => 58.7, "loss1" => 59.8,

    "vmin" => 60.0, "vmax" => 61.0,
    "pmin" => 62.0, "pmax" => 63.0,
    "qmin" => 64.0, "qmax" => 65.0,
    "rate_a" => 66.0, "rate_b" => 67.0, "rate_c" => 68.0,
    "pminf" => 69.0, "pmaxf" => 70.0, "qminf" => 71.0, "qmaxf" => 72.0,
    "pmint" => 73.0, "pmaxt" => 74.0, "qmint" => 75.0, "qmaxt" => 76.0,
    "energy_rating" => 77.01, "charge_rating" => 77.02,
    "discharge_rating" => 77.03, "charge_efficiency" => 77.04,
    "discharge_efficiency" => 77.05, "thermal_rating" => 77.06,
    "qmin" => 77.07, "qmax" => 77.08, "qmin" => 77.09, "qmax" => 77.10,
    "r" => 77.11, "x" => 77.12, "standby_loss" => 77.13,

    "status" => 80.0, "gen_status" => 81.0, "br_status" => 82.0,

    "model" => 90.0, "ncost" => 91.0, "cost" => 92.0, "startup" => 93.0, "shutdown" => 94.0
)

const _pm_component_status_parameters = Set(["status", "gen_status", "br_status"])


"prints the text summary for a data dictionary to IO"
function summary(io::IO, data::Dict{String,<:Any}; kwargs...)
    InfrastructureModels.summary(io, data;
        component_types_order = _pm_component_types_order,
        component_parameter_order = _pm_component_parameter_order,
        component_status_parameters = _pm_component_status_parameters,
        kwargs...)
end


component_table(data::Dict{String,<:Any}, component::String, args...) = InfrastructureModels.component_table(data, component, args...)


"recursively applies new_data to data, overwriting information"
function update_data!(data::Dict{String,<:Any}, new_data::Dict{String,<:Any})
    if haskey(data, "conductors") && haskey(new_data, "conductors")
        if data["conductors"] != new_data["conductors"]
            Memento.error(_LOGGER, "update_data requires datasets with the same number of conductors")
        end
    else
        if (haskey(data, "conductors") && !haskey(new_data, "conductors")) || (!haskey(data, "conductors") && haskey(new_data, "conductors"))
            Memento.warn(_LOGGER, "running update_data with missing onductors fields, conductors may be incorrect")
        end
    end
    InfrastructureModels.update_data!(data, new_data)
end


"""
Turns in given single network data in multinetwork data with a `count`
replicate of the given network.  Note that this function performs a deepcopy
of the network data.  Significant multinetwork space savings can often be
achieved by building application specific methods of building multinetwork
with minimal data replication.
"""
function replicate(sn_data::Dict{String,<:Any}, count::Int; global_keys::Set{String}=Set{String}())
    pm_global_keys = Set(["baseMVA", "per_unit"])
    return InfrastructureModels.replicate(sn_data, count, global_keys=union(global_keys, pm_global_keys))
end


""
function _apply_func!(data::Dict{String,<:Any}, key::String, func)
    if haskey(data, key)
        if isa(data[key], MultiConductorVector)
            data[key] = MultiConductorVector([func(v) for v in data[key]])
        else
            data[key] = func(data[key])
        end
    end
end


"Transforms network data into per-unit"
function make_per_unit!(data::Dict{String,<:Any})
    if !haskey(data, "per_unit") || data["per_unit"] == false
        data["per_unit"] = true
        mva_base = data["baseMVA"]
        if InfrastructureModels.ismultinetwork(data)
            for (i,nw_data) in data["nw"]
                _make_per_unit!(nw_data, mva_base)
            end
        else
            _make_per_unit!(data, mva_base)
        end
    end
end


""
function _make_per_unit!(data::Dict{String,<:Any}, mva_base::Real)
    # to be consistent with matpower's opf.flow_lim= 'I' with current magnitude
    # limit defined in MVA at 1 p.u. voltage
    ka_base = mva_base

    rescale        = x -> x/mva_base
    rescale_dual   = x -> x*mva_base
    rescale_ampere = x -> x/ka_base


    if haskey(data, "bus")
        for (i, bus) in data["bus"]
            _apply_func!(bus, "va", deg2rad)

            _apply_func!(bus, "lam_kcl_r", rescale_dual)
            _apply_func!(bus, "lam_kcl_i", rescale_dual)
        end
    end

    if haskey(data, "load")
        for (i, load) in data["load"]
            _apply_func!(load, "pd", rescale)
            _apply_func!(load, "qd", rescale)
        end
    end

    if haskey(data, "shunt")
        for (i, shunt) in data["shunt"]
            _apply_func!(shunt, "gs", rescale)
            _apply_func!(shunt, "bs", rescale)
        end
    end

    if haskey(data, "gen")
        for (i, gen) in data["gen"]
            _apply_func!(gen, "pg", rescale)
            _apply_func!(gen, "qg", rescale)

            _apply_func!(gen, "pmax", rescale)
            _apply_func!(gen, "pmin", rescale)

            _apply_func!(gen, "qmax", rescale)
            _apply_func!(gen, "qmin", rescale)

            _rescale_cost_model!(gen, mva_base)
        end
    end

    if haskey(data, "storage")
        for (i, strg) in data["storage"]
            _apply_func!(strg, "energy", rescale)
            _apply_func!(strg, "energy_rating", rescale)
            _apply_func!(strg, "charge_rating", rescale)
            _apply_func!(strg, "discharge_rating", rescale)
            _apply_func!(strg, "thermal_rating", rescale)
            _apply_func!(strg, "current_rating", rescale)
            _apply_func!(strg, "qmin", rescale)
            _apply_func!(strg, "qmax", rescale)
            _apply_func!(strg, "standby_loss", rescale)
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
        _apply_func!(branch, "rate_a", rescale)
        _apply_func!(branch, "rate_b", rescale)
        _apply_func!(branch, "rate_c", rescale)

        _apply_func!(branch, "c_rating_a", rescale_ampere)
        _apply_func!(branch, "c_rating_b", rescale_ampere)
        _apply_func!(branch, "c_rating_c", rescale_ampere)

        _apply_func!(branch, "shift", deg2rad)
        _apply_func!(branch, "angmax", deg2rad)
        _apply_func!(branch, "angmin", deg2rad)

        _apply_func!(branch, "pf", rescale)
        _apply_func!(branch, "pt", rescale)
        _apply_func!(branch, "qf", rescale)
        _apply_func!(branch, "qt", rescale)

        _apply_func!(branch, "mu_sm_fr", rescale_dual)
        _apply_func!(branch, "mu_sm_to", rescale_dual)
    end

    if haskey(data, "dcline")
        for (i, dcline) in data["dcline"]
            _apply_func!(dcline, "loss0", rescale)
            _apply_func!(dcline, "pf", rescale)
            _apply_func!(dcline, "pt", rescale)
            _apply_func!(dcline, "qf", rescale)
            _apply_func!(dcline, "qt", rescale)
            _apply_func!(dcline, "pmaxt", rescale)
            _apply_func!(dcline, "pmint", rescale)
            _apply_func!(dcline, "pmaxf", rescale)
            _apply_func!(dcline, "pminf", rescale)
            _apply_func!(dcline, "qmaxt", rescale)
            _apply_func!(dcline, "qmint", rescale)
            _apply_func!(dcline, "qmaxf", rescale)
            _apply_func!(dcline, "qminf", rescale)

            _rescale_cost_model!(dcline, mva_base)
        end
    end

end


"Transforms network data into mixed-units (inverse of per-unit)"
function make_mixed_units!(data::Dict{String,<:Any})
    if haskey(data, "per_unit") && data["per_unit"] == true
        data["per_unit"] = false
        mva_base = data["baseMVA"]
        if InfrastructureModels.ismultinetwork(data)
            for (i,nw_data) in data["nw"]
                _make_mixed_units!(nw_data, mva_base)
            end
        else
             _make_mixed_units!(data, mva_base)
        end
    end
end


""
function _make_mixed_units!(data::Dict{String,<:Any}, mva_base::Real)
    # to be consistent with matpower's opf.flow_lim= 'I' with current magnitude
    # limit defined in MVA at 1 p.u. voltage
    ka_base = mva_base

    rescale        = x -> x*mva_base
    rescale_dual   = x -> x/mva_base
    rescale_ampere = x -> x*ka_base

    if haskey(data, "bus")
        for (i, bus) in data["bus"]
            _apply_func!(bus, "va", rad2deg)

            _apply_func!(bus, "lam_kcl_r", rescale_dual)
            _apply_func!(bus, "lam_kcl_i", rescale_dual)
        end
    end

    if haskey(data, "load")
        for (i, load) in data["load"]
            _apply_func!(load, "pd", rescale)
            _apply_func!(load, "qd", rescale)
        end
    end

    if haskey(data, "shunt")
        for (i, shunt) in data["shunt"]
            _apply_func!(shunt, "gs", rescale)
            _apply_func!(shunt, "bs", rescale)
        end
    end

    if haskey(data, "gen")
        for (i, gen) in data["gen"]
            _apply_func!(gen, "pg", rescale)
            _apply_func!(gen, "qg", rescale)

            _apply_func!(gen, "pmax", rescale)
            _apply_func!(gen, "pmin", rescale)

            _apply_func!(gen, "qmax", rescale)
            _apply_func!(gen, "qmin", rescale)

            _rescale_cost_model!(gen, 1.0/mva_base)
        end
    end

    if haskey(data, "storage")
        for (i, strg) in data["storage"]
            _apply_func!(strg, "energy", rescale)
            _apply_func!(strg, "energy_rating", rescale)
            _apply_func!(strg, "charge_rating", rescale)
            _apply_func!(strg, "discharge_rating", rescale)
            _apply_func!(strg, "thermal_rating", rescale)
            _apply_func!(strg, "current_rating", rescale)
            _apply_func!(strg, "qmin", rescale)
            _apply_func!(strg, "qmax", rescale)
            _apply_func!(strg, "standby_loss", rescale)
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
        _apply_func!(branch, "rate_a", rescale)
        _apply_func!(branch, "rate_b", rescale)
        _apply_func!(branch, "rate_c", rescale)

        _apply_func!(branch, "c_rating_a", rescale_ampere)
        _apply_func!(branch, "c_rating_b", rescale_ampere)
        _apply_func!(branch, "c_rating_c", rescale_ampere)

        _apply_func!(branch, "shift", rad2deg)
        _apply_func!(branch, "angmax", rad2deg)
        _apply_func!(branch, "angmin", rad2deg)

        _apply_func!(branch, "pf", rescale)
        _apply_func!(branch, "pt", rescale)
        _apply_func!(branch, "qf", rescale)
        _apply_func!(branch, "qt", rescale)

        _apply_func!(branch, "mu_sm_fr", rescale_dual)
        _apply_func!(branch, "mu_sm_to", rescale_dual)
    end

    if haskey(data, "dcline")
        for (i,dcline) in data["dcline"]
            _apply_func!(dcline, "loss0", rescale)
            _apply_func!(dcline, "pf", rescale)
            _apply_func!(dcline, "pt", rescale)
            _apply_func!(dcline, "qf", rescale)
            _apply_func!(dcline, "qt", rescale)
            _apply_func!(dcline, "pmaxt", rescale)
            _apply_func!(dcline, "pmint", rescale)
            _apply_func!(dcline, "pmaxf", rescale)
            _apply_func!(dcline, "pminf", rescale)
            _apply_func!(dcline, "qmaxt", rescale)
            _apply_func!(dcline, "qmint", rescale)
            _apply_func!(dcline, "qmaxf", rescale)
            _apply_func!(dcline, "qminf", rescale)

            _rescale_cost_model!(dcline, 1.0/mva_base)
        end
    end

end


""
function _rescale_cost_model!(comp::Dict{String,<:Any}, scale::Real)
    if "model" in keys(comp) && "cost" in keys(comp)
        if comp["model"] == 1
            for i in 1:2:length(comp["cost"])
                comp["cost"][i] = comp["cost"][i]/scale
            end
        elseif comp["model"] == 2
            degree = length(comp["cost"])
            for (i, item) in enumerate(comp["cost"])
                comp["cost"][i] = item*(scale^(degree-i))
            end
        else
            Memento.warn(_LOGGER, "Skipping cost model of type $(comp["model"]) in per unit transformation")
        end
    end
end



"computes the generator cost from given network data"
function calc_gen_cost(data::Dict{String,<:Any})
    @assert("per_unit" in keys(data) && data["per_unit"])
    @assert(!haskey(data, "conductors"))

    if InfrastructureModels.ismultinetwork(data)
        nw_costs = Dict{String,Any}()
        for (i,nw_data) in data["nw"]
            nw_costs[i] = _calc_gen_cost(nw_data)
        end
        return sum(nw_cost for (i,nw_cost) in nw_costs)
    else
        return _calc_gen_cost(data)
    end
end

function _calc_gen_cost(data::Dict{String,<:Any})
    cost = 0.0
    for (i,gen) in data["gen"]
        if gen["gen_status"] == 1
            if haskey(gen, "model")
                if gen["model"] == 1
                    cost += _calc_cost_pwl(gen, "pg")
                elseif gen["model"] == 2
                    cost += _calc_cost_polynomial(gen, "pg")
                else
                    Memento.warn(_LOGGER, "generator $(i) has an unknown cost model $(gen["model"])")
                end
            else
                Memento.warn(_LOGGER, "generator $(i) does not have a cost model")
            end
        end
    end
    return cost
end


"computes the dcline cost from given network data"
function calc_dcline_cost(data::Dict{String,<:Any})
    @assert("per_unit" in keys(data) && data["per_unit"])
    @assert(!haskey(data, "conductors"))

    if InfrastructureModels.ismultinetwork(data)
        nw_costs = Dict{String,Any}()
        for (i,nw_data) in data["nw"]
            nw_costs[i] = _calc_dcline_cost(nw_data)
        end
        return sum(nw_cost for (i,nw_cost) in nw_costs)
    else
        return _calc_dcline_cost(data)
    end
end

function _calc_dcline_cost(data::Dict{String,<:Any})
    cost = 0.0
    for (i,dcline) in data["dcline"]
        if dcline["br_status"] == 1
            if haskey(dcline, "model")
                if dcline["model"] == 1
                    cost += _calc_cost_pwl(dcline, "pf")
                elseif dcline["model"] == 2
                    cost += _calc_cost_polynomial(dcline, "pf")
                else
                    Memento.warn(_LOGGER, "dcline $(i) has an unknown cost model $(dcline["model"])")
                end
            else
                Memento.warn(_LOGGER, "dcline $(i) does not have a cost model")
            end
        end
    end
    return cost
end



"""
compute lines in m and b from from pwl cost models data is a list of components.

Can be run on data or ref data structures
"""
function calc_cost_pwl_lines(comp_dict::Dict)
    lines = Dict()
    for (i,comp) in comp_dict
        lines[i] = _calc_comp_lines(comp)
    end
    return lines
end


"""
compute lines in m and b from from pwl cost models
"""
function _calc_comp_lines(component::Dict{String,<:Any})
    @assert component["model"] == 1
    points = component["cost"]

    line_data = []
    for i in 3:2:length(points)
        x1 = points[i-2]
        y1 = points[i-1]
        x2 = points[i-0]
        y2 = points[i+1]

        m = (y2 - y1)/(x2 - x1)
        b = y1 - m * x1

        push!(line_data, (slope=m, intercept=b))
    end

    for i in 2:length(line_data)
        if line_data[i-1].slope > line_data[i].slope
            Memento.error(_LOGGER, "non-convex pwl function found in points $(component["cost"])\nlines: $(line_data)")
        end
    end

    return line_data
end


function _calc_cost_pwl(component::Dict{String,<:Any}, setpoint_id)
    comp_lines = _calc_comp_lines(component)

    setpoint = component[setpoint_id]
    cost = -Inf
    for line in comp_lines
        cost = max(cost, line.slope*setpoint + line.intercept)
    end

    return cost
end


function _calc_cost_polynomial(component::Dict{String,<:Any}, setpoint_id)
    cost_terms_rev = reverse(component["cost"])

    setpoint = component[setpoint_id]

    if length(cost_terms_rev) == 0
        cost = 0.0
    elseif length(cost_terms_rev) == 1
        cost = cost_terms_rev[1]
    elseif length(cost_terms_rev) == 2
        cost = cost_terms_rev[1] + cost_terms_rev[2]*setpoint
    else
        cost_terms_rev_high = cost_terms_rev[3:end]
        cost = cost_terms_rev[1] + cost_terms_rev[2]*setpoint + sum( v*setpoint^(d+1) for (d,v) in enumerate(cost_terms_rev_high) )
    end

    return cost
end



"assumes a vaild ac solution is included in the data and computes the branch flow values"
function calc_branch_flow_ac(data::Dict{String,<:Any})
    @assert("per_unit" in keys(data) && data["per_unit"])
    @assert(!haskey(data, "conductors"))

    if InfrastructureModels.ismultinetwork(data)
        nws = Dict{String,Any}()
        for (i,nw_data) in data["nw"]
            nws[i] = _calc_branch_flow_ac(nw_data)
        end
        return Dict{String,Any}(
            "nw" => nws,
            "per_unit" => data["per_unit"],
            "baseMVA" => data["baseMVA"]
        )
    else
        flows = _calc_branch_flow_ac(data)
        flows["per_unit"] = data["per_unit"]
        flows["baseMVA"] = data["baseMVA"]
        return flows
    end
end


"helper function for calc_branch_flow_ac"
function _calc_branch_flow_ac(data::Dict{String,<:Any})
    vm = Dict(bus["index"] => bus["vm"] for (i,bus) in data["bus"])
    va = Dict(bus["index"] => bus["va"] for (i,bus) in data["bus"])

    flows = Dict{String,Any}()
    for (i,branch) in data["branch"]
        if branch["br_status"] != 0
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]

            g, b = calc_branch_y(branch)
            tr, ti = calc_branch_t(branch)
            g_fr = branch["g_fr"]
            b_fr = branch["b_fr"]
            g_to = branch["g_to"]
            b_to = branch["b_to"]

            tm = branch["tap"]

            vm_fr = vm[f_bus]
            vm_to = vm[t_bus]
            va_fr = va[f_bus]
            va_to = va[t_bus]

            p_fr =  (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))
            q_fr = -(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))

            p_to =  (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))
            q_to = -(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))
        else
            p_fr = NaN
            q_fr = NaN

            p_to = NaN
            q_to = NaN
        end

        flows[i] = Dict(
            "pf" => p_fr,
            "qf" => q_fr,
            "pt" => p_to,
            "qt" => q_to
        )
    end

    return Dict{String,Any}("branch" => flows)
end



"assumes a vaild dc solution is included in the data and computes the branch flow values"
function calc_branch_flow_dc(data::Dict{String,<:Any})
    @assert("per_unit" in keys(data) && data["per_unit"])
    @assert(!haskey(data, "conductors"))

    if InfrastructureModels.ismultinetwork(data)
        nws = Dict{String,Any}()
        for (i,nw_data) in data["nw"]
            nws[i] = _calc_branch_flow_dc(nw_data)
        end
        return Dict{String,Any}(
            "nw" => nws,
            "per_unit" => data["per_unit"],
            "baseMVA" => data["baseMVA"]
        )
    else
        flows = _calc_branch_flow_dc(data)
        flows["per_unit"] = data["per_unit"]
        flows["baseMVA"] = data["baseMVA"]
        return flows
    end
end


"helper function for calc_branch_flow_dc"
function _calc_branch_flow_dc(data::Dict{String,<:Any})
    vm = Dict(bus["index"] => bus["vm"] for (i,bus) in data["bus"])
    va = Dict(bus["index"] => bus["va"] for (i,bus) in data["bus"])

    flows = Dict{String,Any}()
    for (i,branch) in data["branch"]
        if branch["br_status"] != 0
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]

            g, b = calc_branch_y(branch)

            p_fr = -b*(va[f_bus] - va[t_bus])
        else
            p_fr = NaN
        end

        flows[i] = Dict(
            "pf" =>  p_fr,
            "qf" =>  NaN,
            "pt" => -p_fr,
            "qt" =>  NaN
        )
    end

    return Dict{String,Any}("branch" => flows)
end




"assumes a vaild solution is included in the data and computes the power balance at each bus"
function calc_power_balance(data::Dict{String,<:Any})
    @assert("per_unit" in keys(data) && data["per_unit"]) # may not be strictly required
    @assert(!haskey(data, "conductors"))

    if InfrastructureModels.ismultinetwork(data)
        nws = Dict{String,Any}()
        for (i,nw_data) in data["nw"]
            nws[i] = _calc_power_balance(nw_data)
        end
        return Dict{String,Any}(
            "nw" => nws,
            "per_unit" => data["per_unit"],
            "baseMVA" => data["baseMVA"]
        )
    else
        flows = _calc_power_balance(data)
        flows["per_unit"] = data["per_unit"]
        flows["baseMVA"] = data["baseMVA"]
        return flows
    end
end


"helper function for calc_power_balance"
function _calc_power_balance(data::Dict{String,<:Any})
    bus_values = Dict(bus["index"] => Dict{String,Float64}() for (i,bus) in data["bus"])
    for (i,bus) in data["bus"]
        bvals = bus_values[bus["index"]]
        bvals["vm"] = bus["vm"]

        bvals["pd"] = 0.0
        bvals["qd"] = 0.0

        bvals["gs"] = 0.0
        bvals["bs"] = 0.0

        bvals["ps"] = 0.0
        bvals["qs"] = 0.0

        bvals["pg"] = 0.0
        bvals["qg"] = 0.0

        bvals["p"] = 0.0
        bvals["q"] = 0.0

        bvals["p_dc"] = 0.0
        bvals["q_dc"] = 0.0
    end

    for (i,load) in data["load"]
        if load["status"] != 0
            bvals = bus_values[load["load_bus"]]
            bvals["pd"] += load["pd"]
            bvals["qd"] += load["qd"]
        end
    end

    for (i,shunt) in data["shunt"]
        if shunt["status"] != 0
            bvals = bus_values[shunt["shunt_bus"]]
            bvals["gs"] += shunt["gs"]
            bvals["bs"] += shunt["bs"]
        end
    end

    for (i,storage) in data["storage"]
        if storage["status"] != 0
            bvals = bus_values[storage["storage_bus"]]
            bvals["ps"] += storage["ps"]
            bvals["qs"] += storage["qs"]
        end
    end

    for (i,gen) in data["gen"]
        if gen["gen_status"] != 0
            bvals = bus_values[gen["gen_bus"]]
            bvals["pg"] += gen["pg"]
            bvals["qg"] += gen["qg"]
        end
    end

    for (i,branch) in data["branch"]
        if branch["br_status"] != 0
            bus_fr = branch["f_bus"]
            bvals_fr = bus_values[bus_fr]
            bvals_fr["p"] += branch["pf"]
            bvals_fr["q"] += branch["qf"]

            bus_to = branch["t_bus"]
            bvals_to = bus_values[bus_to]
            bvals_to["p"] += branch["pt"]
            bvals_to["q"] += branch["qt"]
        end
    end

    for (i,dcline) in data["dcline"]
        if dcline["br_status"] != 0
            bus_fr = dcline["f_bus"]
            bvals_fr = bus_values[bus_fr]
            bvals_fr["p_dc"] += dcline["pf"]
            bvals_fr["q_dc"] += dcline["qf"]

            bus_to = dcline["t_bus"]
            bvals_to = bus_values[bus_to]
            bvals_to["p_dc"] += dcline["pt"]
            bvals_to["q_dc"] += dcline["qt"]
        end
    end

    deltas = Dict{String,Any}()
    for (i,bus) in data["bus"]
        if bus["bus_type"] != 4
            bvals = bus_values[bus["index"]]
            p_delta = bvals["p"] + bvals["p_dc"] - bvals["pg"] + bvals["ps"] + bvals["pd"] + bvals["gs"]*(bvals["vm"]^2)
            q_delta = bvals["q"] + bvals["q_dc"] - bvals["qg"] + bvals["qs"] + bvals["qd"] - bvals["bs"]*(bvals["vm"]^2)
        else
            p_delta = NaN
            q_delta = NaN
        end

        deltas[i] = Dict(
            "p_delta" => p_delta,
            "q_delta" => q_delta,
        )
    end

    return Dict{String,Any}("bus" => deltas)
end







""
function check_conductors(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _check_conductors(nw_data)
        end
    else
        _check_conductors(data)
    end
end


""
function _check_conductors(data::Dict{String,<:Any})
    if haskey(data, "conductors") && data["conductors"] < 1
        Memento.error(_LOGGER, "conductor values must be positive integers, given $(data["conductors"])")
    end
end


"checks that voltage angle differences are within 90 deg., if not tightens"
function correct_voltage_angle_differences!(data::Dict{String,<:Any}, default_pad = 1.0472)
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_voltage_angle_differences! does not yet support multinetwork data")
    end

    @assert("per_unit" in keys(data) && data["per_unit"])
    default_pad_deg = round(rad2deg(default_pad), digits=2)

    modified = Set{Int}()

    for c in 1:get(data, "conductors", 1)
        cnd_str = haskey(data, "conductors") ? ", conductor $(c)" : ""
        for (i, branch) in data["branch"]
            angmin = branch["angmin"][c]
            angmax = branch["angmax"][c]

            if angmin <= -pi/2
                Memento.warn(_LOGGER, "this code only supports angmin values in -90 deg. to 90 deg., tightening the value on branch $i$(cnd_str) from $(rad2deg(angmin)) to -$(default_pad_deg) deg.")
                if haskey(data, "conductors")
                    branch["angmin"][c] = -default_pad
                else
                    branch["angmin"] = -default_pad
                end
                push!(modified, branch["index"])
            end

            if angmax >= pi/2
                Memento.warn(_LOGGER, "this code only supports angmax values in -90 deg. to 90 deg., tightening the value on branch $i$(cnd_str) from $(rad2deg(angmax)) to $(default_pad_deg) deg.")
                if haskey(data, "conductors")
                    branch["angmax"][c] = default_pad
                else
                    branch["angmax"] = default_pad
                end
                push!(modified, branch["index"])
            end

            if angmin == 0.0 && angmax == 0.0
                Memento.warn(_LOGGER, "angmin and angmax values are 0, widening these values on branch $i$(cnd_str) to +/- $(default_pad_deg) deg.")
                if haskey(data, "conductors")
                    branch["angmin"][c] = -default_pad
                    branch["angmax"][c] =  default_pad
                else
                    branch["angmin"] = -default_pad
                    branch["angmax"] =  default_pad
                end
                push!(modified, branch["index"])
            end
        end
    end

    return modified
end


"checks that each branch has a reasonable thermal rating-a, if not computes one"
function correct_thermal_limits!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_thermal_limits! does not yet support multinetwork data")
    end

    @assert("per_unit" in keys(data) && data["per_unit"])
    mva_base = data["baseMVA"]

    modified = Set{Int}()

    branches = [branch for branch in values(data["branch"])]
    if haskey(data, "ne_branch")
        append!(branches, values(data["ne_branch"]))
    end

    for branch in branches
        if !haskey(branch, "rate_a")
            if haskey(data, "conductors")
                branch["rate_a"] = MultiConductorVector(0.0, data["conductors"])
            else
                branch["rate_a"] = 0.0
            end
        end

        for c in 1:get(data, "conductors", 1)
            cnd_str = haskey(data, "conductors") ? ", conductor $(c)" : ""
            if branch["rate_a"][c] <= 0.0
                theta_max = max(abs(branch["angmin"][c]), abs(branch["angmax"][c]))

                r = branch["br_r"]
                x = branch["br_x"]
                z = r + im * x
                y = pinv(z)
                y_mag = abs.(y[c,c])

                fr_vmax = data["bus"][string(branch["f_bus"])]["vmax"][c]
                to_vmax = data["bus"][string(branch["t_bus"])]["vmax"][c]
                m_vmax = max(fr_vmax, to_vmax)

                c_max = sqrt(fr_vmax^2 + to_vmax^2 - 2*fr_vmax*to_vmax*cos(theta_max))

                new_rate = y_mag*m_vmax*c_max

                if haskey(branch, "c_rating_a") && branch["c_rating_a"][c] > 0.0
                    new_rate = min(new_rate, branch["c_rating_a"][c]*m_vmax)
                end

                Memento.warn(_LOGGER, "this code only supports positive rate_a values, changing the value on branch $(branch["index"])$(cnd_str) to $(round(mva_base*new_rate, digits=4))")

                if haskey(data, "conductors")
                    branch["rate_a"][c] = new_rate
                else
                    branch["rate_a"] = new_rate
                end

                push!(modified, branch["index"])
            end
        end
    end

    return modified
end


"checks that each branch has a reasonable current rating-a, if not computes one"
function correct_current_limits!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_current_limits! does not yet support multinetwork data")
    end

    @assert("per_unit" in keys(data) && data["per_unit"])
    mva_base = data["baseMVA"]

    modified = Set{Int}()

    branches = [branch for branch in values(data["branch"])]
    if haskey(data, "ne_branch")
        append!(branches, values(data["ne_branch"]))
    end

    for branch in branches

        if !haskey(branch, "c_rating_a")
            if haskey(data, "conductors")
                branch["c_rating_a"] = MultiConductorVector(0.0, data["conductors"])
            else
                branch["c_rating_a"] = 0.0
            end
        end

        for c in 1:get(data, "conductors", 1)
            cnd_str = haskey(data, "conductors") ? ", conductor $(c)" : ""
            if branch["c_rating_a"][c] <= 0.0
                theta_max = max(abs(branch["angmin"][c]), abs(branch["angmax"][c]))

                r = branch["br_r"]
                x = branch["br_x"]
                z = r + im * x
                y = pinv(z)
                y_mag = abs.(y[c,c])

                fr_vmax = data["bus"][string(branch["f_bus"])]["vmax"][c]
                to_vmax = data["bus"][string(branch["t_bus"])]["vmax"][c]
                m_vmax = max(fr_vmax, to_vmax)

                new_c_rating = y_mag*sqrt(fr_vmax^2 + to_vmax^2 - 2*fr_vmax*to_vmax*cos(theta_max))

                if haskey(branch, "rate_a") && branch["rate_a"][c] > 0.0
                    fr_vmin = data["bus"][string(branch["f_bus"])]["vmin"][c]
                    to_vmin = data["bus"][string(branch["t_bus"])]["vmin"][c]
                    vm_min = min(fr_vmin, to_vmin)

                    new_c_rating = min(new_c_rating, branch["rate_a"]/vm_min)
                end

                Memento.warn(_LOGGER, "this code only supports positive c_rating_a values, changing the value on branch $(branch["index"])$(cnd_str) to $(mva_base*new_c_rating)")
                if haskey(data, "conductors")
                    branch["c_rating_a"][c] = new_c_rating
                else
                    branch["c_rating_a"] = new_c_rating
                end

                push!(modified, branch["index"])
            end
        end
    end

    return modified
end


"checks that all parallel branches have the same orientation"
function correct_branch_directions!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_branch_directions! does not yet support multinetwork data")
    end

    modified = Set{Int}()

    orientations = Set()
    for (i, branch) in data["branch"]
        orientation = (branch["f_bus"], branch["t_bus"])
        orientation_rev = (branch["t_bus"], branch["f_bus"])

        if in(orientation_rev, orientations)
            Memento.warn(_LOGGER, "reversing the orientation of branch $(i) $(orientation) to be consistent with other parallel branches")
            branch_orginal = copy(branch)
            branch["f_bus"] = branch_orginal["t_bus"]
            branch["t_bus"] = branch_orginal["f_bus"]
            branch["g_to"] = branch_orginal["g_fr"] .* branch_orginal["tap"]'.^2
            branch["b_to"] = branch_orginal["b_fr"] .* branch_orginal["tap"]'.^2
            branch["g_fr"] = branch_orginal["g_to"] ./ branch_orginal["tap"]'.^2
            branch["b_fr"] = branch_orginal["b_to"] ./ branch_orginal["tap"]'.^2
            branch["tap"] = 1 ./ branch_orginal["tap"]
            branch["br_r"] = branch_orginal["br_r"] .* branch_orginal["tap"]'.^2
            branch["br_x"] = branch_orginal["br_x"] .* branch_orginal["tap"]'.^2
            branch["shift"] = -branch_orginal["shift"]
            branch["angmin"] = -branch_orginal["angmax"]
            branch["angmax"] = -branch_orginal["angmin"]

            push!(modified, branch["index"])
        else
            push!(orientations, orientation)
        end

    end

    return modified
end


"checks that all branches connect two distinct buses"
function check_branch_loops(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "check_branch_loops does not yet support multinetwork data")
    end

    for (i, branch) in data["branch"]
        if branch["f_bus"] == branch["t_bus"]
            Memento.error(_LOGGER, "both sides of branch $(i) connect to bus $(branch["f_bus"])")
        end
    end
end


"checks that all buses are unique and other components link to valid buses"
function check_connectivity(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "check_connectivity does not yet support multinetwork data")
    end

    bus_ids = Set(bus["index"] for (i,bus) in data["bus"])
    @assert(length(bus_ids) == length(data["bus"])) # if this is not true something very bad is going on

    for (i, load) in data["load"]
        if !(load["load_bus"] in bus_ids)
            Memento.error(_LOGGER, "bus $(load["load_bus"]) in load $(i) is not defined")
        end
    end

    for (i, shunt) in data["shunt"]
        if !(shunt["shunt_bus"] in bus_ids)
            Memento.error(_LOGGER, "bus $(shunt["shunt_bus"]) in shunt $(i) is not defined")
        end
    end

    for (i, gen) in data["gen"]
        if !(gen["gen_bus"] in bus_ids)
            Memento.error(_LOGGER, "bus $(gen["gen_bus"]) in generator $(i) is not defined")
        end
    end

    for (i, strg) in data["storage"]
        if !(strg["storage_bus"] in bus_ids)
            Memento.error(_LOGGER, "bus $(strg["storage_bus"]) in storage unit $(i) is not defined")
        end
    end

    for (i, branch) in data["branch"]
        if !(branch["f_bus"] in bus_ids)
            Memento.error(_LOGGER, "from bus $(branch["f_bus"]) in branch $(i) is not defined")
        end

        if !(branch["t_bus"] in bus_ids)
            Memento.error(_LOGGER, "to bus $(branch["t_bus"]) in branch $(i) is not defined")
        end
    end

    for (i, dcline) in data["dcline"]
        if !(dcline["f_bus"] in bus_ids)
            Memento.error(_LOGGER, "from bus $(dcline["f_bus"]) in dcline $(i) is not defined")
        end

        if !(dcline["t_bus"] in bus_ids)
            Memento.error(_LOGGER, "to bus $(dcline["t_bus"]) in dcline $(i) is not defined")
        end
    end
end


"checks that active components are not connected to inactive buses, otherwise prints warnings"
function check_status(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "check_status does not yet support multinetwork data")
    end

    active_bus_ids = Set(bus["index"] for (i,bus) in data["bus"] if bus["bus_type"] != 4)

    for (i, load) in data["load"]
        if load["status"] != 0 && !(load["load_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active load $(i) is connected to inactive bus $(load["load_bus"])")
        end
    end

    for (i, shunt) in data["shunt"]
        if shunt["status"] != 0 && !(shunt["shunt_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active shunt $(i) is connected to inactive bus $(shunt["shunt_bus"])")
        end
    end

    for (i, gen) in data["gen"]
        if gen["gen_status"] != 0 && !(gen["gen_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active generator $(i) is connected to inactive bus $(gen["gen_bus"])")
        end
    end

    for (i, strg) in data["storage"]
        if strg["status"] != 0 && !(strg["storage_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active storage unit $(i) is connected to inactive bus $(strg["storage_bus"])")
        end
    end

    for (i, branch) in data["branch"]
        if branch["br_status"] != 0 && !(branch["f_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active branch $(i) is connected to inactive bus $(branch["f_bus"])")
        end

        if branch["br_status"] != 0 && !(branch["t_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active branch $(i) is connected to inactive bus $(branch["t_bus"])")
        end
    end

    for (i, dcline) in data["dcline"]
        if dcline["br_status"] != 0 && !(dcline["f_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active dcline $(i) is connected to inactive bus $(dcline["f_bus"])")
        end

        if dcline["br_status"] != 0 && !(dcline["t_bus"] in active_bus_ids)
            Memento.warn(_LOGGER, "active dcline $(i) is connected to inactive bus $(dcline["t_bus"])")
        end
    end
end


"checks that contains at least one refrence bus"
function check_reference_bus(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "check_reference_bus does not yet support multinetwork data")
    end

    ref_buses = Dict{String,Any}()
    for (k,v) in data["bus"]
        if v["bus_type"] == 3
            ref_buses[k] = v
        end
    end

    if length(ref_buses) == 0
            if length(data["gen"]) > 0
            big_gen = _biggest_generator(data["gen"])
            gen_bus = big_gen["gen_bus"]
            ref_bus = data["bus"]["$(gen_bus)"]
            ref_bus["bus_type"] = 3
            Memento.warn(_LOGGER, "no reference bus found, setting bus $(gen_bus) as reference based on generator $(big_gen["index"])")
        else
            (bus_item, state) = Base.iterate(data["bus"])
            bus_item.second["bus_type"] = 3
            Memento.warn(_LOGGER, "no reference bus found, setting bus $(bus_item.second["index"]) as reference")
        end
    end
end


"find the largest active generator in the network"
function _biggest_generator(gens)
    biggest_gen = nothing
    biggest_value = -Inf
    for (k,gen) in gens
        pmax = maximum(gen["pmax"])
        if pmax > biggest_value
            biggest_gen = gen
            biggest_value = pmax
        end
    end
    @assert(biggest_gen != nothing)
    return biggest_gen
end


"""
checks that each branch has a reasonable transformer parameters

this is important because setting tap == 0.0 leads to NaN computations, which are hard to debug
"""
function correct_transformer_parameters!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_transformer_parameters! does not yet support multinetwork data")
    end

    @assert("per_unit" in keys(data) && data["per_unit"])

    modified = Set{Int}()

    for (i, branch) in data["branch"]
        if !haskey(branch, "tap")
            Memento.warn(_LOGGER, "branch found without tap value, setting a tap to 1.0")
            if haskey(data, "conductors")
                branch["tap"] = MultiConductorVector{Float64}(ones(data["conductors"]))
            else
                branch["tap"] = 1.0
            end
            push!(modified, branch["index"])
        else
            for c in 1:get(data, "conductors", 1)
                cnd_str = haskey(data, "conductors") ? " on conductor $(c)" : ""
                if branch["tap"][c] <= 0.0
                    Memento.warn(_LOGGER, "branch found with non-positive tap value of $(branch["tap"][c]), setting a tap to 1.0$(cnd_str)")
                    if haskey(data, "conductors")
                        branch["tap"][c] = 1.0
                    else
                        branch["tap"] = 1.0
                    end
                    push!(modified, branch["index"])
                end
            end
        end
        if !haskey(branch, "shift")
            Memento.warn(_LOGGER, "branch found without shift value, setting a shift to 0.0")
            if haskey(data, "conductors")
                branch["shift"] = MultiConductorVector{Float64}(zeros(data["conductors"]))
            else
                branch["shift"] = 0.0
            end
            push!(modified, branch["index"])
        end
    end

    return modified
end


"""
checks that each storage unit has a reasonable parameters
"""
function check_storage_parameters(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "check_storage_parameters does not yet support multinetwork data")
    end

    for (i, strg) in data["storage"]
        if strg["energy"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive energy level $(strg["energy"])")
        end
        if strg["energy_rating"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive energy rating $(strg["energy_rating"])")
        end
        if strg["charge_rating"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive charge rating $(strg["energy_rating"])")
        end
        if strg["discharge_rating"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive discharge rating $(strg["energy_rating"])")
        end
        if strg["standby_loss"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive standby losses $(strg["standby_loss"])")
        end

        for c in 1:get(data, "conductors", 1)
            if strg["r"][c] < 0.0
                Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive resistance $(strg["r"][c])")
            end
            if strg["x"][c] < 0.0
                Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive reactance $(strg["x"][c])")
            end
            if haskey(strg, "thermal_rating") && strg["thermal_rating"][c] < 0.0
                Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive thermal rating $(strg["thermal_rating"][c])")
            end
            if haskey(strg, "current_rating") && strg["current_rating"][c] < 0.0
                Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive current rating $(strg["thermal_rating"][c])")
            end
            if !isapprox(strg["x"][c], 0.0, atol=1e-6, rtol=1e-6)
                Memento.warn(_LOGGER, "storage unit $(strg["index"]) has a non-zero reactance $(strg["x"][c]), which is currently ignored")
            end
        end

        if strg["charge_efficiency"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive charge efficiency of $(strg["charge_efficiency"])")
        end
        if strg["charge_efficiency"] <= 0.0 || strg["charge_efficiency"] > 1.0
            Memento.warn(_LOGGER, "storage unit $(strg["index"]) charge efficiency of $(strg["charge_efficiency"]) is out of the valid range (0.0. 1.0]")
        end
        if strg["discharge_efficiency"] < 0.0
            Memento.error(_LOGGER, "storage unit $(strg["index"]) has a non-positive discharge efficiency of $(strg["discharge_efficiency"])")
        end
        if strg["discharge_efficiency"] <= 0.0 || strg["discharge_efficiency"] > 1.0
            Memento.warn(_LOGGER, "storage unit $(strg["index"]) discharge efficiency of $(strg["discharge_efficiency"]) is out of the valid range (0.0. 1.0]")
        end

        if strg["standby_loss"] > 0.0 && strg["energy"] <= 0.0
            Memento.warn(_LOGGER, "storage unit $(strg["index"]) has standby losses but zero initial energy.  This can lead to model infeasiblity.")
        end
    end

end


"checks bus types are consistent with generator connections, if not, fixes them"
function correct_bus_types!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_bus_types! does not yet support multinetwork data")
    end

    modified = Set{Int}()

    bus_gens = Dict((i, []) for (i,bus) in data["bus"])

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
                Memento.warn(_LOGGER, "no active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 1")
                bus["bus_type"] = 1
                push!(modified, bus["index"])
            end

            if bus_gens_count != 0 && bus["bus_type"] != 2
                Memento.warn(_LOGGER, "active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 2")
                bus["bus_type"] = 2
                push!(modified, bus["index"])
            end

        end
    end

    return modified
end


"checks that parameters for dc lines are reasonable"
function correct_dcline_limits!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_dcline_limits! does not yet support multinetwork data")
    end

    @assert("per_unit" in keys(data) && data["per_unit"])
    mva_base = data["baseMVA"]

    modified = Set{Int}()

    for c in 1:get(data, "conductors", 1)
        cnd_str = haskey(data, "conductors") ? ", conductor $(c)" : ""
        for (i, dcline) in data["dcline"]
            if dcline["loss0"][c] < 0.0
                new_rate = 0.0
                Memento.warn(_LOGGER, "this code only supports positive loss0 values, changing the value on dcline $(dcline["index"])$(cnd_str) from $(mva_base*dcline["loss0"][c]) to $(mva_base*new_rate)")
                if haskey(data, "conductors")
                    dcline["loss0"][c] = new_rate
                else
                    dcline["loss0"] = new_rate
                end
                push!(modified, dcline["index"])
            end

            if dcline["loss0"][c] >= dcline["pmaxf"][c]*(1-dcline["loss1"][c] )+ dcline["pmaxt"][c]
                new_rate = 0.0
                Memento.warn(_LOGGER, "this code only supports loss0 values which are consistent with the line flow bounds, changing the value on dcline $(dcline["index"])$(cnd_str) from $(mva_base*dcline["loss0"][c]) to $(mva_base*new_rate)")
                if haskey(data, "conductors")
                    dcline["loss0"][c] = new_rate
                else
                    dcline["loss0"] = new_rate
                end
                push!(modified, dcline["index"])
            end

            if dcline["loss1"][c] < 0.0
                new_rate = 0.0
                Memento.warn(_LOGGER, "this code only supports positive loss1 values, changing the value on dcline $(dcline["index"])$(cnd_str) from $(dcline["loss1"][c]) to $(new_rate)")
                if haskey(data, "conductors")
                    dcline["loss1"][c] = new_rate
                else
                    dcline["loss1"] = new_rate
                end
                push!(modified, dcline["index"])
            end

            if dcline["loss1"][c] >= 1.0
                new_rate = 0.0
                Memento.warn(_LOGGER, "this code only supports loss1 values < 1, changing the value on dcline $(dcline["index"])$(cnd_str) from $(dcline["loss1"][c]) to $(new_rate)")
                if haskey(data, "conductors")
                    dcline["loss1"][c] = new_rate
                else
                    dcline["loss1"] = new_rate
                end
                push!(modified, dcline["index"])
            end

            if dcline["pmint"][c] <0.0 && dcline["loss1"][c] > 0.0
                #new_rate = 0.0
                Memento.warn(_LOGGER, "the dc line model is not meant to be used bi-directionally when loss1 > 0, be careful interpreting the results as the dc line losses can now be negative. change loss1 to 0 to avoid this warning")
                #dcline["loss0"] = new_rate
            end
        end
    end

    return modified
end


"throws warnings if generator and dc line voltage setpoints are not consistent with the bus voltage setpoint"
function check_voltage_setpoints(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "check_voltage_setpoints does not yet support multinetwork data")
    end

    for c in 1:get(data, "conductors", 1)
        cnd_str = haskey(data, "conductors") ? "conductor $(c) " : ""
        for (i,gen) in data["gen"]
            bus_id = gen["gen_bus"]
            bus = data["bus"]["$(bus_id)"]
            if gen["vg"][c] != bus["vm"][c]
                Memento.warn(_LOGGER, "the $(cnd_str)voltage setpoint on generator $(i) does not match the value at bus $(bus_id)")
            end
        end

        for (i, dcline) in data["dcline"]
            bus_fr_id = dcline["f_bus"]
            bus_to_id = dcline["t_bus"]

            bus_fr = data["bus"]["$(bus_fr_id)"]
            bus_to = data["bus"]["$(bus_to_id)"]

            if dcline["vf"][c] != bus_fr["vm"][c]
                Memento.warn(_LOGGER, "the $(cnd_str)from bus voltage setpoint on dc line $(i) does not match the value at bus $(bus_fr_id)")
            end

            if dcline["vt"][c] != bus_to["vm"][c]
                Memento.warn(_LOGGER, "the $(cnd_str)to bus voltage setpoint on dc line $(i) does not match the value at bus $(bus_to_id)")
            end
        end
    end
end



"throws warnings if cost functions are malformed"
function correct_cost_functions!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "correct_cost_functions! does not yet support multinetwork data")
    end

    modified_gen = Set{Int}()
    for (i,gen) in data["gen"]
        if _correct_cost_function!(i, gen, "generator")
            push!(modified_gen, gen["index"])
        end
    end

    modified_dcline = Set{Int}()
    for (i, dcline) in data["dcline"]
        if _correct_cost_function!(i, dcline, "dcline")
            push!(modified_dcline, dcline["index"])
        end
    end

    return (modified_gen, modified_dcline)
end


""
function _correct_cost_function!(id, comp, type_name)
    #println(comp)
    modified = false

    if "model" in keys(comp) && "cost" in keys(comp)
        if comp["model"] == 1
            if length(comp["cost"]) != 2*comp["ncost"]
                Memento.error(_LOGGER, "ncost of $(comp["ncost"]) not consistent with $(length(comp["cost"])) cost values on $(type_name) $(id)")
            end
            if length(comp["cost"]) < 4
                Memento.error(_LOGGER, "cost includes $(comp["ncost"]) points, but at least two points are required on $(type_name) $(id)")
            end

            modified = _remove_pwl_cost_duplicates!(id, comp, type_name)

            for i in 3:2:length(comp["cost"])
                if comp["cost"][i-2] >= comp["cost"][i]
                    Memento.error(_LOGGER, "non-increasing x values in pwl cost model on $(type_name) $(id)")
                end
            end
            if "pmin" in keys(comp) && "pmax" in keys(comp)
                pmin = sum(comp["pmin"]) # sum supports multi-conductor case
                pmax = sum(comp["pmax"])
                for i in 3:2:length(comp["cost"])
                    if comp["cost"][i] < pmin || comp["cost"][i] > pmax
                        Memento.warn(_LOGGER, "pwl x value $(comp["cost"][i]) is outside the bounds $(pmin)-$(pmax) on $(type_name) $(id)")
                    end
                end
            end
            modified |= _simplify_pwl_cost!(id, comp, type_name)
        elseif comp["model"] == 2
            if length(comp["cost"]) != comp["ncost"]
                Memento.error(_LOGGER, "ncost of $(comp["ncost"]) not consistent with $(length(comp["cost"])) cost values on $(type_name) $(id)")
            end
        else
            Memento.warn(_LOGGER, "Unknown cost model of type $(comp["model"]) on $(type_name) $(id)")
        end
    end

    return modified
end


"checks that each point in the a pwl function is unqiue, simplifies the function if duplicates appear"
function _remove_pwl_cost_duplicates!(id, comp, type_name, tolerance = 1e-2)
    @assert comp["model"] == 1

    unique_costs = Float64[comp["cost"][1], comp["cost"][2]]
    for i in 3:2:length(comp["cost"])
        x1 = unique_costs[end-1]
        y1 = unique_costs[end]
        x2 = comp["cost"][i+0]
        y2 = comp["cost"][i+1]
        if !(isapprox(x1, x2) && isapprox(y1, y2))
            push!(unique_costs, x2)
            push!(unique_costs, y2)
        end
    end

    if length(unique_costs) < length(comp["cost"])
        Memento.warn(_LOGGER, "removing duplicate points from pwl cost on $(type_name) $(id), $(comp["cost"]) -> $(unique_costs)")
        comp["cost"] = unique_costs
        comp["ncost"] = length(unique_costs)/2
        return true
    end
    return false
end


"checks the slope of each segment in a pwl function, simplifies the function if the slope changes is below a tolerance"
function _simplify_pwl_cost!(id, comp, type_name, tolerance = 1e-2)
    @assert comp["model"] == 1

    slopes = Float64[]
    smpl_cost = Float64[]
    prev_slope = nothing

    x2, y2 = 0.0, 0.0

    for i in 3:2:length(comp["cost"])
        x1 = comp["cost"][i-2]
        y1 = comp["cost"][i-1]
        x2 = comp["cost"][i-0]
        y2 = comp["cost"][i+1]

        m = (y2 - y1)/(x2 - x1)

        if prev_slope == nothing || (abs(prev_slope - m) > tolerance)
            push!(smpl_cost, x1)
            push!(smpl_cost, y1)
            prev_slope = m
        end

        push!(slopes, m)
    end

    push!(smpl_cost, x2)
    push!(smpl_cost, y2)

    if length(smpl_cost) < length(comp["cost"])
        Memento.warn(_LOGGER, "simplifying pwl cost on $(type_name) $(id), $(comp["cost"]) -> $(smpl_cost)")
        comp["cost"] = smpl_cost
        comp["ncost"] = length(smpl_cost)/2
        return true
    end
    return false
end


"trims zeros from higher order cost terms"
function simplify_cost_terms!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        networks = data["nw"]
    else
        networks = [("0", data)]
    end

    modified_gen = Set{Int}()
    modified_dcline = Set{Int}()

    for (i, network) in networks
        if haskey(network, "gen")
            for (i, gen) in network["gen"]
                if haskey(gen, "model") && gen["model"] == 2
                    ncost = length(gen["cost"])
                    for j in 1:ncost
                        if gen["cost"][1] == 0.0
                            gen["cost"] = gen["cost"][2:end]
                        else
                            break
                        end
                    end
                    if length(gen["cost"]) != ncost
                        gen["ncost"] = length(gen["cost"])
                        Memento.info(_LOGGER, "removing $(ncost - gen["ncost"]) cost terms from generator $(i): $(gen["cost"])")
                        push!(modified_gen, gen["index"])
                    end
                end
            end
        end

        if haskey(network, "dcline")
            for (i, dcline) in network["dcline"]
                if haskey(dcline, "model") && dcline["model"] == 2
                    ncost = length(dcline["cost"])
                    for j in 1:ncost
                        if dcline["cost"][1] == 0.0
                            dcline["cost"] = dcline["cost"][2:end]
                        else
                            break
                        end
                    end
                    if length(dcline["cost"]) != ncost
                        dcline["ncost"] = length(dcline["cost"])
                        Memento.info(_LOGGER, "removing $(ncost - dcline["ncost"]) cost terms from dcline $(i): $(dcline["cost"])")
                        push!(modified_dcline, dcline["index"])
                    end
                end
            end
        end
    end

    return (modified_gen, modified_dcline)
end


"ensures all polynomial costs functions have the same number of terms"
function standardize_cost_terms!(data::Dict{String,<:Any}; order=-1)
    comp_max_order = 1

    if InfrastructureModels.ismultinetwork(data)
        networks = data["nw"]
    else
        networks = [("0", data)]
    end

    for (i, network) in networks
        if haskey(network, "gen")
            for (i, gen) in network["gen"]
                if haskey(gen, "model") && gen["model"] == 2
                    max_nonzero_index = 1
                    for i in 1:length(gen["cost"])
                        max_nonzero_index = i
                        if gen["cost"][i] != 0.0
                            break
                        end
                    end

                    max_oder = length(gen["cost"]) - max_nonzero_index + 1

                    comp_max_order = max(comp_max_order, max_oder)
                end
            end
        end

        if haskey(network, "dcline")
            for (i, dcline) in network["dcline"]
                if haskey(dcline, "model") && dcline["model"] == 2
                    max_nonzero_index = 1
                    for i in 1:length(dcline["cost"])
                        max_nonzero_index = i
                        if dcline["cost"][i] != 0.0
                            break
                        end
                    end

                    max_oder = length(dcline["cost"]) - max_nonzero_index + 1

                    comp_max_order = max(comp_max_order, max_oder)
                end
            end
        end

    end

    if comp_max_order <= order+1
        comp_max_order = order+1
    else
        if order != -1 # if not the default
            Memento.warn(_LOGGER, "a standard cost order of $(order) was requested but the given data requires an order of at least $(comp_max_order-1)")
        end
    end

    for (i, network) in networks
        if haskey(network, "gen")
            _standardize_cost_terms!(network["gen"], comp_max_order, "generator")
        end
        if haskey(network, "dcline")
            _standardize_cost_terms!(network["dcline"], comp_max_order, "dcline")
        end
    end

end


"ensures all polynomial costs functions have at exactly comp_order terms"
function _standardize_cost_terms!(components::Dict{String,<:Any}, comp_order::Int, cost_comp_name::String)
    modified = Set{Int}()
    for (i, comp) in components
        if haskey(comp, "model") && comp["model"] == 2 && length(comp["cost"]) != comp_order
            std_cost = [0.0 for i in 1:comp_order]
            current_cost = reverse(comp["cost"])
            #println("gen cost: $(comp["cost"])")
            for i in 1:min(comp_order, length(current_cost))
                std_cost[i] = current_cost[i]
            end
            comp["cost"] = reverse(std_cost)
            comp["ncost"] = comp_order
            #println("std gen cost: $(comp["cost"])")

            Memento.warn(_LOGGER, "Updated $(cost_comp_name) $(comp["index"]) cost function with order $(length(current_cost)) to a function of order $(comp_order): $(comp["cost"])")
            push!(modified, comp["index"])
        end
    end
    return modified
end





"""
finds active network buses and branches that are not necessary for the
computation and sets their status to off.

Works on a PowerModels data dict, so that a it can be used without a GenericPowerModel object

Warning: this implementation has quadratic complexity, in the worst case
"""
function propagate_topology_status!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _propagate_topology_status!(nw_data)
        end
    else
         _propagate_topology_status!(data)
    end
end


""
function _propagate_topology_status!(data::Dict{String,<:Any})
    buses = Dict(bus["bus_i"] => bus for (i,bus) in data["bus"])

    for (i,load) in data["load"]
        if load["status"] != 0 && all(load["pd"] .== 0.0) && all(load["qd"] .== 0.0)
            Memento.info(_LOGGER, "deactivating load $(load["index"]) due to zero pd and qd")
            load["status"] = 0
        end
    end

    for (i,shunt) in data["shunt"]
        if shunt["status"] != 0 && all(shunt["gs"] .== 0.0) && all(shunt["bs"] .== 0.0)
            Memento.info(_LOGGER, "deactivating shunt $(shunt["index"]) due to zero gs and bs")
            shunt["status"] = 0
        end
    end

    # compute what active components are incident to each bus
    incident_load = bus_load_lookup(data["load"], data["bus"])
    incident_active_load = Dict()
    for (i, load_list) in incident_load
        incident_active_load[i] = [load for load in load_list if load["status"] != 0]
        #incident_active_load[i] = filter(load -> load["status"] != 0, load_list)
    end

    incident_shunt = bus_shunt_lookup(data["shunt"], data["bus"])
    incident_active_shunt = Dict()
    for (i, shunt_list) in incident_shunt
        incident_active_shunt[i] = [shunt for shunt in shunt_list if shunt["status"] != 0]
        #incident_active_shunt[i] = filter(shunt -> shunt["status"] != 0, shunt_list)
    end

    incident_gen = bus_gen_lookup(data["gen"], data["bus"])
    incident_active_gen = Dict()
    for (i, gen_list) in incident_gen
        incident_active_gen[i] = [gen for gen in gen_list if gen["gen_status"] != 0]
        #incident_active_gen[i] = filter(gen -> gen["gen_status"] != 0, gen_list)
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
                        Memento.info(_LOGGER, "deactivating branch $(i):($(branch["f_bus"]),$(branch["t_bus"])) due to connecting bus status")
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
                        Memento.info(_LOGGER, "deactivating dcline $(i):($(dcline["f_bus"]),$(dcline["t_bus"])) due to connecting bus status")
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
                        Memento.info(_LOGGER, "deactivating bus $(i) due to dangling bus without generation and load")
                        bus["bus_type"] = 4
                        updated = true
                    end

                else # bus type == 4
                    for load in incident_active_load[i]
                        if load["status"] != 0
                            Memento.info(_LOGGER, "deactivating load $(load["index"]) due to inactive bus $(i)")
                            load["status"] = 0
                            updated = true
                        end
                    end

                    for shunt in incident_active_shunt[i]
                        if shunt["status"] != 0
                            Memento.info(_LOGGER, "deactivating shunt $(shunt["index"]) due to inactive bus $(i)")
                            shunt["status"] = 0
                            updated = true
                        end
                    end

                    for gen in incident_active_gen[i]
                        if gen["gen_status"] != 0
                            Memento.info(_LOGGER, "deactivating generator $(gen["index"]) due to inactive bus $(i)")
                            gen["gen_status"] = 0
                            updated = true
                        end
                    end
                end
            end
        end

        ccs = calc_connected_components(data)

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
                Memento.info(_LOGGER, "deactivating connected component $(cc) due to isolation without generation and load")
                for i in cc
                    buses[i]["bus_type"] = 4
                end
                updated = true
            end
        end

    end

    Memento.info(_LOGGER, "topology status propagation fixpoint reached in $(iteration) rounds")

    correct_reference_buses!(data)
end


"""
determines the largest connected component of the network and turns everything else off
"""
function select_largest_component!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _select_largest_component!(nw_data)
        end
    else
         _select_largest_component!(data)
    end
end


""
function _select_largest_component!(data::Dict{String,<:Any})
    ccs = calc_connected_components(data)
    Memento.info(_LOGGER, "found $(length(ccs)) components")

    ccs_order = sort(collect(ccs); by=length)
    largest_cc = ccs_order[end]

    Memento.info(_LOGGER, "largest component has $(length(largest_cc)) buses")

    for (i,bus) in data["bus"]
        if bus["bus_type"] != 4 && !(bus["index"] in largest_cc)
            bus["bus_type"] = 4
            Memento.info(_LOGGER, "deactivating bus $(i) due to small connected component")
        end
    end

    correct_reference_buses!(data)
end


"""
checks that each connected components has a reference bus, if not, adds one
"""
function correct_reference_buses!(data::Dict{String,<:Any})
    if InfrastructureModels.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _correct_reference_buses!(nw_data)
        end
    else
        _correct_reference_buses!(data)
    end
end


""
function _correct_reference_buses!(data::Dict{String,<:Any})
    bus_lookup = Dict(bus["bus_i"] => bus for (i,bus) in data["bus"])
    bus_gen = bus_gen_lookup(data["gen"], data["bus"])

    ccs = calc_connected_components(data)
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
        correct_component_refrence_bus!(cc, bus_lookup, cc_gens[i])
    end
end


"""
checks that a connected component has a reference bus, if not, adds one
"""
function correct_component_refrence_bus!(component_bus_ids, bus_lookup, component_gens)
    refrence_buses = Set()
    for bus_id in component_bus_ids
        bus = bus_lookup[bus_id]
        if bus["bus_type"] == 3
            push!(refrence_buses, bus_id)
        end
    end

    if length(refrence_buses) == 0
        Memento.warn(_LOGGER, "no reference bus found in connected component $(component_bus_ids)")

        if length(component_gens) > 0
            big_gen = _biggest_generator(component_gens)
            gen_bus = bus_lookup[big_gen["gen_bus"]]
            gen_bus["bus_type"] = 3
            Memento.warn(_LOGGER, "setting bus $(gen_bus["index"]) as reference bus in connected component $(component_bus_ids), based on generator $(big_gen["index"])")
        else
            Memento.warn(_LOGGER, "no generators found in connected component $(component_bus_ids), try running propagate_topology_status!(")
        end
    end
end


"builds a lookup list of what generators are connected to a given bus"
function bus_gen_lookup(gen_data::Dict{String,<:Any}, bus_data::Dict{String,<:Any})
    bus_gen = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,gen) in gen_data
        push!(bus_gen[gen["gen_bus"]], gen)
    end
    return bus_gen
end


"builds a lookup list of what loads are connected to a given bus"
function bus_load_lookup(load_data::Dict{String,<:Any}, bus_data::Dict{String,<:Any})
    bus_load = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,load) in load_data
        push!(bus_load[load["load_bus"]], load)
    end
    return bus_load
end


"builds a lookup list of what shunts are connected to a given bus"
function bus_shunt_lookup(shunt_data::Dict{String,<:Any}, bus_data::Dict{String,<:Any})
    bus_shunt = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,shunt) in shunt_data
        push!(bus_shunt[shunt["shunt_bus"]], shunt)
    end
    return bus_shunt
end


"builds a lookup list of what storage is connected to a given bus"
function bus_storage_lookup(storage_data::Dict{String,<:Any}, bus_data::Dict{String,<:Any})
    bus_storage = Dict(bus["bus_i"] => [] for (i,bus) in bus_data)
    for (i,storage) in storage_data
        push!(bus_storage[storage["shunt_bus"]], storage)
    end
    return bus_storage
end


"""
computes the connected components of the network graph
returns a set of sets of bus ids, each set is a connected component
"""
function calc_connected_components(data::Dict{String,<:Any}; edges=["branch", "dcline"])
    if InfrastructureModels.ismultinetwork(data)
        Memento.error(_LOGGER, "connected_components does not yet support multinetwork data")
    end

    active_bus = Dict(x for x in data["bus"] if x.second["bus_type"] != 4)
    active_bus_ids = Set{Int64}([bus["bus_i"] for (i,bus) in active_bus])

    neighbors = Dict(i => [] for i in active_bus_ids)
    for line_type in edges
        for line in values(get(data, line_type, Dict()))
            if get(line, "br_status", 1) != 0 && line["f_bus"] in active_bus_ids && line["t_bus"] in active_bus_ids
                push!(neighbors[line["f_bus"]], line["t_bus"])
                push!(neighbors[line["t_bus"]], line["f_bus"])
            end
        end
    end

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


"Transforms single-conductor network data into multi-conductor data"
function make_multiconductor!(data::Dict{String,<:Any}, conductors::Int)
    if InfrastructureModels.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _make_multiconductor!(nw_data, conductors)
        end
    else
         _make_multiconductor!(data, conductors)
    end
end


"feild names that should not be multi-conductor values"
const _conductorless = Set(["index", "bus_i", "bus_type", "status", "gen_status",
    "br_status", "gen_bus", "load_bus", "shunt_bus", "storage_bus", "f_bus", "t_bus",
    "transformer", "area", "zone", "base_kv", "energy", "energy_rating", "charge_rating",
    "discharge_rating", "charge_efficiency", "discharge_efficiency", "standby_loss",
    "model", "ncost", "cost", "startup", "shutdown", "name", "source_id", "active_phases"])

"feild names that should become multi-conductor matrix not arrays"
const _conductor_matrix = Set(["br_r", "br_x"])


""
function _make_multiconductor!(data::Dict{String,<:Any}, conductors::Real)
    if haskey(data, "conductors")
        Memento.warn(_LOGGER, "skipping network that is already multiconductor")
        return
    end

    data["conductors"] = conductors

    for (key, item) in data
        if isa(item, Dict{String,Any})
            for (item_id, item_data) in item
                if isa(item_data, Dict{String,Any})
                    item_ref_data = Dict{String,Any}()
                    for (param, value) in item_data
                        if param in _conductorless
                            item_ref_data[param] = value
                        else
                            if param in _conductor_matrix
                                item_ref_data[param] = MultiConductorMatrix(value, conductors)
                            else
                                item_ref_data[param] = MultiConductorVector(value, conductors)
                            end
                        end
                    end
                    item[item_id] = item_ref_data
                end
            end
        else
            #root non-dict items
        end
    end
end
