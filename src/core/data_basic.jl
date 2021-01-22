# tools for working with the "basic" versions of PowerModels data dict

"""
given a powermodels data dict produces a new data dict that conforms to the
following basic network model requirements.
- no dclines
- no switches
- no inactive components
- all components are numbered from 1-to-n
- generation cost functions are quadratic
- all branches have explicit thermal limit values
"""
function make_basic_network(data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        Memento.error(_LOGGER, "make_basic_network does not support multinetwork data")
    end

    data = deepcopy(data)

    # ensure that components connected in inactive buses are also inactive
    propagate_topology_status!(data)

    # remove switches by merging buses
    resolve_swithces!(data)

    # switch resolution can result in new parallel branches
    correct_branch_directions!(data)

    # equivalence parallel lines?
    #merge_parallel_branches!(data)

    # set remaining unsupported components as inactive
    dcline_status_key = pm_component_status["dcline"]
    dcline_inactive_status = pm_component_status_inactive["dcline"]
    for (i,dcline) in data["dcline"]
        dcline[dcline_status_key] = dcline_inactive_status
    end

    # remove inactive components
    for (comp_key, status_key) in pm_component_status
        comp_count = length(data[comp_key])
        status_inactive = pm_component_status_inactive[comp_key]
        data[comp_key] = filter_inactive_components(data[comp_key], status_key=status_key, status_inactive_value=status_inactive)
        if length(data[comp_key]) < comp_count
            Memento.info(_LOGGER, "removed $(comp_count - length(data[comp_key])) inactive $(comp_key) components")
        end
    end

    # re-number non-bus component ids
    for comp_key in keys(pm_component_status)
        if comp_key != "bus"
            data[comp_key] = renumber_components(data[comp_key])
        end
    end

    # renumber bus ids
    bus_ordered = sort([bus for (i,bus) in data["bus"]], by=(x) -> x["index"])

    bus_id_map = Dict{Int,Int}()
    for (i,bus) in enumerate(bus_ordered)
        bus_id_map[bus["index"]] = i
    end
    update_bus_ids!(data, bus_id_map)


    # TODO transform PWL costs into linear costs

    standardize_cost_terms!(data, order=2)

    calc_thermal_limits!(data)

    data["basic_network"] = true

    return data
end


#=
"""
given a network data dict, replaces parallel branches with an equivalent single
branch.
assumes that all parallel branches have a consistent orientation
"""
function merge_parallel_branches!(data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _merge_parallel_branches!(nw_data)
        end
    else
         _merge_parallel_branches!(data)
    end
end

""
function _merge_parallel_branches!(data::Dict{String,<:Any})
    # assumes parallel branches have a consistent orientation
    branch_sets = Dict()

    for (i,branch) in data["branch"]
        bus_pair = (fr=branch["f_bus"], to=branch["t_bus"])
        if !haskey(branch_sets, bus_pair)
            branch_sets[bus_pair] = []
        end
        push!(branch_sets[bus_pair], branch)
    end

    merged = false
    branch_list = []
    for (bp, branches) in branch_sets
        if length(branches) > 1
            branch_ids = [branch["index"] for branch in branches]
            Memento.info(_LOGGER, "merging parallel branches $(join(branch_ids, ","))")

            branch_new = copy(branches[1])

            branch_new["g_to"] = sum(branch["g_to"] for branch in branches)
            branch_new["b_to"] = sum(branch["b_to"] for branch in branches)
            branch_new["g_fr"] = sum(branch["g_fr"] for branch in branches)
            branch_new["b_fr"] = sum(branch["b_fr"] for branch in branches)

            z_total = 1/sum(1/(branch["br_r"] + branch["br_x"]im) for branch in branches)
            #t_total = sum((branch["tap"]*cos(branch["shift"]) + branch["tap"]*sin(branch["shift"])im) for branch in branches)

            println([(branch["br_r"] + branch["br_x"]im) for branch in branches])
            #println([(branch["tap"]*cos(branch["shift"]) + branch["tap"]*sin(branch["shift"])im) for branch in branches])
            println(z_total)
            #println(t_total)

            #push!(branch_list, branch_new)
        else
            push!(branch_list, branches[1])
        end
    end

    #data["branch"] = Dict{String,Any}("$(branch["index"])" => branch for branch in branch_list)
end
=#


"""
given a component dict returns a new dict where inactive components have been
removed.
"""
function filter_inactive_components(comp_dict::Dict{String,<:Any}; status_key="status", status_inactive_value=0)
    filtered_dict = Dict{String,Any}()

    for (i,comp) in comp_dict
        if comp[status_key] != status_inactive_value
            filtered_dict[i] = comp
        end
    end

    return filtered_dict
end

"""
given a component dict returns a new dict where components have been renumbered
from 1-to-n ordered by the increasing values of the orginal component id.
"""
function renumber_components(comp_dict::Dict{String,<:Any})
    renumbered_dict = Dict{String,Any}()

    comp_ordered = sort([comp for (i,comp) in comp_dict], by=(x) -> x["index"])

    for (i,comp) in enumerate(comp_ordered)
        comp = deepcopy(comp)
        comp["index"] = i
        renumbered_dict["$i"] = comp
    end

    return renumbered_dict
end




"""
given a network data dict and a mapping of current-bus-ids to new-bus-ids
modifies the data dict to reflect the proposed new bus ids.
"""
function update_bus_ids!(data::Dict{String,<:Any}, bus_id_map::Dict{Int,Int}; injective=true)
    if _IM.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _update_bus_ids!(nw_data, bus_id_map; injective=injective)
        end
    else
         _update_bus_ids!(data, bus_id_map; injective=injective)
    end
end


function _update_bus_ids!(data::Dict{String,<:Any}, bus_id_map::Dict{Int,Int}; injective=true)
    # verify bus id map is injective
    if injective
        new_bus_ids = Set{Int}()
        for (i,bus) in data["bus"]
            new_id = get(bus_id_map, bus["index"], bus["index"])
            if !(new_id in new_bus_ids)
                push!(new_bus_ids, new_id)
            else
                Memento.error(_LOGGER, "bus id mapping given to update_bus_ids has an id clash on new bus id $(new_id)")
            end
        end
    end


    # start renumbering process
    renumbered_bus_dict = Dict{String,Any}()

    for (i,bus) in data["bus"]
        new_id = get(bus_id_map, bus["index"], bus["index"])
        bus["index"] = new_id
        bus["bus_i"] = new_id
        renumbered_bus_dict["$new_id"] = bus
    end

    data["bus"] = renumbered_bus_dict


    # update bus numbering in dependent components
    for (i, load) in data["load"]
        load["load_bus"] = get(bus_id_map, load["load_bus"], load["load_bus"])
    end

    for (i, shunt) in data["shunt"]
        shunt["shunt_bus"] = get(bus_id_map, shunt["shunt_bus"], shunt["shunt_bus"])
    end

    for (i, gen) in data["gen"]
        gen["gen_bus"] = get(bus_id_map, gen["gen_bus"], gen["gen_bus"])
    end

    for (i, strg) in data["storage"]
        strg["storage_bus"] = get(bus_id_map, strg["storage_bus"], strg["storage_bus"])
    end


    for (i, switch) in data["switch"]
        switch["f_bus"] = get(bus_id_map, switch["f_bus"], switch["f_bus"])
        switch["t_bus"] = get(bus_id_map, switch["t_bus"], switch["t_bus"])
    end

    branches = []
    if haskey(data, "branch")
        append!(branches, values(data["branch"]))
    end

    if haskey(data, "ne_branch")
        append!(branches, values(data["ne_branch"]))
    end

    for branch in branches
        branch["f_bus"] = get(bus_id_map, branch["f_bus"], branch["f_bus"])
        branch["t_bus"] = get(bus_id_map, branch["t_bus"], branch["t_bus"])
    end

    for (i, dcline) in data["dcline"]
        dcline["f_bus"] = get(bus_id_map, dcline["f_bus"], dcline["f_bus"])
        dcline["t_bus"] = get(bus_id_map, dcline["t_bus"], dcline["t_bus"])
    end
end



"""
given a network data dict merges buses that are connected by closed switches
converting the dataset into a pure bus-branch model.
"""
function resolve_swithces!(data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        for (i,nw_data) in data["nw"]
            _resolve_swithces!(nw_data)
        end
    else
         _resolve_swithces!(data)
    end
end

""
function _resolve_swithces!(data::Dict{String,<:Any})
    if length(data["switch"]) <= 0
        return
    end

    bus_sets = Dict{Int,Set{Int}}()

    switch_status_key = pm_component_status["switch"]
    switch_status_value = pm_component_status_inactive["switch"]

    for (i,switch) in data["switch"]
        if switch[switch_status_key] != switch_status_value && switch["state"] == 1
            if !haskey(bus_sets, switch["f_bus"])
                bus_sets[switch["f_bus"]] = Set{Int}([switch["f_bus"]])
            end
            if !haskey(bus_sets, switch["t_bus"])
                bus_sets[switch["t_bus"]] = Set{Int}([switch["t_bus"]])
            end

            merged_set = Set{Int}([bus_sets[switch["f_bus"]]..., bus_sets[switch["t_bus"]]...])
            bus_sets[switch["f_bus"]] = merged_set
            bus_sets[switch["t_bus"]] = merged_set
        end
    end

    bus_id_map = Dict{Int,Int}()
    for bus_set in Set(values(bus_sets))
        bus_min = minimum(bus_set)
        Memento.info(_LOGGER, "merging buses $(join(bus_set, ",")) in to bus $(bus_min) based on switch status")
        for i in bus_set
            if i != bus_min
                bus_id_map[i] = bus_min
            end
        end
    end

    update_bus_ids!(data, bus_id_map, injective=false)

    for (i, branch) in data["branch"]
        if branch["f_bus"] == branch["t_bus"]
            Memento.warn(_LOGGER, "switch removal resulted in both sides of branch $(i) connect to bus $(branch["f_bus"]), deactivating branch")
            branch[pm_component_status["branch"]] = pm_component_status_inactive["branch"]
        end
    end

    for (i, dcline) in data["dcline"]
        if dcline["f_bus"] == dcline["t_bus"]
            Memento.warn(_LOGGER, "switch removal resulted in both sides of dcline $(i) connect to bus $(branch["f_bus"]), deactivating dcline")
            branch[pm_component_status["dcline"]] = pm_component_status_inactive["dcline"]
        end
    end

    Memento.info(_LOGGER, "removed $(length(data["switch"])) switch components")
    data["switch"] = Dict{String,Any}()
end


