# tools for working with the "basic" versions of PowerModels data dict

"""
given a powermodels data dict produces a new data dict that conforms to the
following basic network model requirements.
- no dclines
- no switches
- no inactive components
- all components are numbered from 1-to-n
- the network forms a single connected component
- there exactly one phase angle reference bus
- generation cost functions are quadratic
- all branches have explicit thermal limits
"""
function make_basic_network(data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        Memento.error(_LOGGER, "make_basic_network does not support multinetwork data")
    end

    # make a copy of data so that modifications do not change the input data
    data = deepcopy(data)

    # TODO transform PWL costs into linear costs
    for (i,gen) in data["gen"]
        if get(gen, "cost_model", 2) != 2
            Memento.error(_LOGGER, "make_basic_network only supports network data with polynomial cost functions, generator $(i) has a piecewise linear cost function")
        end
    end
    standardize_cost_terms!(data, order=2)

    # ensure that branch components always have a rate_a value
    calc_thermal_limits!(data)

    # ensure single connected component
    select_largest_component!(data)

    # ensure that components connected in inactive buses are also inactive
    propagate_topology_status!(data)

    # ensure there is exactly one reference bus
    ref_buses = Set{Int}()
    for (i,bus) in data["bus"]
        if bus["bus_type"] == 3
            push!(ref_buses, bus["index"])
        end
    end
    if length(ref_buses) > 1
        Memento.warn(_LOGGER, "network data specifies $(length(ref_buses)) reference buses")
        for ref_bus_id in ref_buses
            data["bus"]["$(ref_bus_id)"]["bus_type"] = 2
        end
        ref_buses = Set{Int}()
    end
    if length(ref_buses) == 0
        gen = _biggest_generator(data["gen"])
        @assert length(gen) > 0
        gen_bus = gen["gen_bus"]
        ref_bus = data["bus"]["$(gen_bus)"]
        ref_bus["bus_type"] = 3
        Memento.warn(_LOGGER, "setting bus $(gen_bus) as reference based on generator $(gen["index"])")
    end

    # remove switches by merging buses
    resolve_swithces!(data)

    # switch resolution can result in new parallel branches
    correct_branch_directions!(data)

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

    data["basic_network"] = true

    return data
end

"""
given a basic network data dict, returns a sparse incidence matrix
"""
function calc_basic_incidence_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_incidence_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    I = Int64[]
    J = Int64[]
    V = Int64[]

    b = [branch for (i,branch) in data["branch"] if branch["br_status"] != 0]
    branch_ordered = sort(b, by=(x) -> x["index"])
    for (i,branch) in enumerate(branch_ordered)
        push!(I, branch["f_bus"]); push!(J, i); push!(V, 1)
        push!(I, branch["t_bus"]); push!(J, i); push!(V, 1)
    end

    return sparse(I,J,V)
end

"""
given a basic network data dict, returns a sparse admittance matrix
"""
function calc_basic_admittance_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_admittance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    am = calc_admittance_matrix(data)

    # conj can be removed once #734 is resolved
    return conj.(am.matrix)
end

"""
given a basic network data dict, returns a sparse susceptance matrix
"""
function calc_basic_susceptance_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_susceptance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    am = calc_susceptance_matrix(data)

    # -1.0 can be removed once #734 is resolved
    return -1.0*am.matrix
end


"""
given a basic network data dict, returns a ptdf matrix
"""
function calc_basic_ptdf_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_susceptance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    num_bus = length(data["bus"])
    num_branch = length(data["branch"])

    b_inv = calc_susceptance_matrix_inv(data).matrix

    ptdf = zeros(num_bus, num_branch)
    for (i,branch) in data["branch"]
        branch_idx = branch["index"]
        bus_fr = branch["f_bus"]
        bus_to = branch["t_bus"]
        for n in 1:num_bus
            ptdf[n, branch_idx] = b_inv[bus_fr, n] - b_inv[bus_to, n]
        end
    end

    return ptdf
end

"""
given a basic network data dict and a branch index returns a column of the ptdf
matrix for that column.
"""
function calc_basic_ptdf_column(data::Dict{String,<:Any}, branch_index::Int)
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_susceptance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    if branch_index < 1 || branch_index > length(data["branch"])
        Memento.error(_LOGGER, "branch index of $(branch_index) is out of bounds, valid values are $(1)-$(length(data["branch"]))")
    end
    branch = data["branch"]["$(branch_index)"]

    num_bus = length(data["bus"])
    num_branch = length(data["branch"])

    am = calc_susceptance_matrix(data)

    if_fr = injection_factors_va(am, branch["f_bus"])
    if_to = injection_factors_va(am, branch["t_bus"])

    ptdf_column = zeros(num_bus)
    for n in 1:num_bus
        ptdf_column[n] = get(if_fr, n, 0.0) - get(if_to, n, 0.0)
    end

    return ptdf_column
end


"""
given a basic network data dict, returns the Jacobian matrix of the ac power
flow problem.  Power variables are ordered by p and then q while voltage
values are ordered by voltage angle and then voltage magnitude.
"""
function calc_basic_jacobian_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_susceptance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    num_bus = length(data["bus"])

    vm = [bus["vm"] for (i,bus) in data["bus"]]
    va = [bus["va"] for (i,bus) in data["bus"]]
    am = calc_admittance_matrix(data)


    neighbors = [Set{Int}([i]) for i in 1:num_bus]
    I, J, V = findnz(am.matrix)
    for nz in eachindex(V)
        push!(neighbors[I[nz]], J[nz])
        push!(neighbors[J[nz]], I[nz])
    end


    J0_I = Int64[]
    J0_J = Int64[]
    J0_V = Float64[]

    for i in 1:num_bus
        f_i_r = i
        f_i_i = i + num_bus

        for j in neighbors[i]
            x_j_fst = j + num_bus
            x_j_snd = j

            push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            push!(J0_I, f_i_r); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
            push!(J0_I, f_i_i); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            push!(J0_I, f_i_i); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
        end
    end

    J = sparse(J0_I, J0_J, J0_V)


    for i in 1:num_bus
        f_i_r = i
        f_i_i = i + num_bus

        for j in neighbors[i]
            x_j_fst = j + num_bus
            x_j_snd = j

            bus_type = data["bus"]["$(j)"]["bus_type"]
            if bus_type == 1
                if i == j
                    y_ii = am.matrix[i,i]
                    J[f_i_r, x_j_fst] = 2*real(y_ii)*vm[i] +            sum( real(am.matrix[i,k]) * vm[k] *  cos(va[i] - va[k]) - imag(am.matrix[i,k]) * vm[k] * sin(va[i] - va[k]) for k in neighbors[i] if k != i)
                    J[f_i_r, x_j_snd] =                         vm[i] * sum( real(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) - imag(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)

                    J[f_i_i, x_j_fst] = 2*imag(y_ii)*vm[i] +            sum( imag(am.matrix[i,k]) * vm[k] *  cos(va[i] - va[k]) + real(am.matrix[i,k]) * vm[k] * sin(va[i] - va[k]) for k in neighbors[i] if k != i)
                    J[f_i_i, x_j_snd] =                         vm[i] * sum( imag(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) + real(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)
                else
                    y_ij = am.matrix[i,j]
                    J[f_i_r, x_j_fst] =         vm[i] * (real(y_ij) * cos(va[i] - va[j]) - imag(y_ij) *  sin(va[i] - va[j]))
                    J[f_i_r, x_j_snd] = vm[i] * vm[j] * (real(y_ij) * sin(va[i] - va[j]) - imag(y_ij) * -cos(va[i] - va[j]))

                    J[f_i_i, x_j_fst] =         vm[i] * (imag(y_ij) * cos(va[i] - va[j]) + real(y_ij) *  sin(va[i] - va[j]))
                    J[f_i_i, x_j_snd] = vm[i] * vm[j] * (imag(y_ij) * sin(va[i] - va[j]) + real(y_ij) * -cos(va[i] - va[j]))
                end
            elseif bus_type == 2
                if i == j
                    J[f_i_r, x_j_fst] = 0.0
                    J[f_i_i, x_j_fst] = 1.0

                    y_ii = am.matrix[i,i]
                    J[f_i_r, x_j_snd] =   vm[i] * sum( real(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) - imag(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)
                    J[f_i_i, x_j_snd] =   vm[i] * sum( imag(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) + real(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)
                else
                    J[f_i_r, x_j_fst] = 0.0
                    J[f_i_i, x_j_fst] = 0.0

                    y_ij = am.matrix[i,j]
                    J[f_i_r, x_j_snd] = vm[i] * vm[j] * (real(y_ij) * sin(va[i] - va[j]) - imag(y_ij) * -cos(va[i] - va[j]))
                    J[f_i_i, x_j_snd] = vm[i] * vm[j] * (imag(y_ij) * sin(va[i] - va[j]) + real(y_ij) * -cos(va[i] - va[j]))
                end
            elseif bus_type == 3
                if i == j
                    J[f_i_r, x_j_fst] = 1.0
                    J[f_i_r, x_j_snd] = 0.0
                    J[f_i_i, x_j_fst] = 0.0
                    J[f_i_i, x_j_snd] = 1.0
                end
            else
                @assert false
            end
        end
    end


    # J0_I = Int64[]
    # J0_J = Int64[]
    # J0_V = String[]

    # for i in 1:num_bus
    #     f_i_r = i
    #     f_i_i = i + num_bus

    #     for j in neighbors[i]
    #         x_j_fst = j + num_bus
    #         x_j_snd = j

    #         push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, "")
    #         push!(J0_I, f_i_r); push!(J0_J, x_j_snd); push!(J0_V, "")
    #         push!(J0_I, f_i_i); push!(J0_J, x_j_fst); push!(J0_V, "")
    #         push!(J0_I, f_i_i); push!(J0_J, x_j_snd); push!(J0_V, "")
    #     end
    # end

    # J = sparse(J0_I, J0_J, J0_V)


    # for i in 1:num_bus
    #     f_i_r = i
    #     f_i_i = i + num_bus

    #     for j in neighbors[i]
    #         x_j_fst = j + num_bus
    #         x_j_snd = j

    #         bus_type = data["bus"]["$(j)"]["bus_type"]
    #         if bus_type == 1
    #             if i == j
    #                 y_ii = am.matrix[i,i]
    #                 J[f_i_r, x_j_fst] = "P/vm" #2*real(y_ii)*vm[i] +            sum( real(am.matrix[i,k]) * vm[k] *  cos(va[i] - va[k]) - imag(am.matrix[i,k]) * vm[k] * sin(va[i] - va[k]) for k in neighbors[i] if k != i)
    #                 J[f_i_r, x_j_snd] = "P/va" #                       vm[i] * sum( real(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) - imag(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)

    #                 J[f_i_i, x_j_fst] = "Q/vm" #2*imag(y_ii)*vm[i] +            sum( imag(am.matrix[i,k]) * vm[k] *  cos(va[i] - va[k]) + real(am.matrix[i,k]) * vm[k] * sin(va[i] - va[k]) for k in neighbors[i] if k != i)
    #                 J[f_i_i, x_j_snd] = "Q/va" #                       vm[i] * sum( imag(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) + real(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)
    #             else
    #                 y_ij = am.matrix[i,j]
    #                 J[f_i_r, x_j_fst] = "P/vm" #        vm[i] * (real(y_ij) * cos(va[i] - va[j]) - imag(y_ij) *  sin(va[i] - va[j]))
    #                 J[f_i_r, x_j_snd] = "P/va" #vm[i] * vm[j] * (real(y_ij) * sin(va[i] - va[j]) - imag(y_ij) * -cos(va[i] - va[j]))

    #                 J[f_i_i, x_j_fst] = "Q/vm" #        vm[i] * (imag(y_ij) * cos(va[i] - va[j]) + real(y_ij) *  sin(va[i] - va[j]))
    #                 J[f_i_i, x_j_snd] = "Q/va" #vm[i] * vm[j] * (imag(y_ij) * sin(va[i] - va[j]) + real(y_ij) * -cos(va[i] - va[j]))
    #             end
    #         elseif bus_type == 2
    #             if i == j
    #                 J[f_i_r, x_j_fst] = "P/vm"  #0.0
    #                 J[f_i_i, x_j_fst] = "Q/vm"  #1.0

    #                 y_ii = am.matrix[i,i]
    #                 J[f_i_r, x_j_snd] = "P/va"  #  vm[i] * sum( real(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) - imag(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)
    #                 J[f_i_i, x_j_snd] = "Q/va"  #  vm[i] * sum( imag(am.matrix[i,k]) * vm[k] * -sin(va[i] - va[k]) + real(am.matrix[i,k]) * vm[k] * cos(va[i] - va[k]) for k in neighbors[i] if k != i)
    #             else
    #                 J[f_i_r, x_j_fst] = "P/vm"  #0.0
    #                 J[f_i_i, x_j_fst] = "Q/vm"  #0.0

    #                 y_ij = am.matrix[i,j]
    #                 J[f_i_r, x_j_snd] = "P/va"  #vm[i] * vm[j] * (real(y_ij) * sin(va[i] - va[j]) - imag(y_ij) * -cos(va[i] - va[j]))
    #                 J[f_i_i, x_j_snd] = "Q/va"  #vm[i] * vm[j] * (imag(y_ij) * sin(va[i] - va[j]) + real(y_ij) * -cos(va[i] - va[j]))
    #             end
    #         elseif bus_type == 3
    #             if i == j
    #                 J[f_i_r, x_j_fst] = "P/vm" #1.0
    #                 J[f_i_r, x_j_snd] = "P/va" #0.0
    #                 J[f_i_i, x_j_fst] = "Q/vm" #0.0
    #                 J[f_i_i, x_j_snd] = "Q/va" #1.0
    #             end
    #         else
    #             @assert false
    #         end
    #     end
    # end

    return J
end


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
        Memento.info(_LOGGER, "merged buses $(join(bus_set, ",")) in to bus $(bus_min) based on switch status")
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


