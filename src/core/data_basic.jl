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
- phase shift on all transformers is set to 0.0
- bus shunts have 0.0 conductance values
users requiring any of the features listed above for their analysis should use 
the non-basic PowerModels routines.
"""
function make_basic_network(data::Dict{String,<:Any})
    if _IM.ismultiinfrastructure(data)
        Memento.error(_LOGGER, "make_basic_network does not support multiinfrastructure data")
    end

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

    # set conductance to zero on all shunts
    for (i,shunt) in data["shunt"]
        if !isapprox(shunt["gs"], 0.0)
            Memento.warn(_LOGGER, "setting conductance on shunt $(i) from $(shunt["gs"]) to 0.0")
            shunt["gs"] = 0.0
        end
    end

    # ensure that branch components always have a rate_a value
    calc_thermal_limits!(data)

    # set phase shift to zero on all branches
    for (i,branch) in data["branch"]
        if !isapprox(branch["shift"], 0.0)
            Memento.warn(_LOGGER, "setting phase shift on branch $(i) from $(branch["shift"]) to 0.0")
            branch["shift"] = 0.0
        end
    end

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
        data[comp_key] = _filter_inactive_components(data[comp_key], status_key=status_key, status_inactive_value=status_inactive)
        if length(data[comp_key]) < comp_count
            Memento.info(_LOGGER, "removed $(comp_count - length(data[comp_key])) inactive $(comp_key) components")
        end
    end

    # re-number non-bus component ids
    for comp_key in keys(pm_component_status)
        if comp_key != "bus"
            data[comp_key] = _renumber_components(data[comp_key])
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
given a component dict returns a new dict where inactive components have been
removed.
"""
function _filter_inactive_components(comp_dict::Dict{String,<:Any}; status_key="status", status_inactive_value=0)
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
function _renumber_components(comp_dict::Dict{String,<:Any})
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
given a basic network data dict, returns a complex valued vector of bus voltage
values in rectangular coordinates as they appear in the network data.
"""
function calc_basic_bus_voltage(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_bus_voltage requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    b = [bus for (i,bus) in data["bus"] if bus["bus_type"] != 4]
    bus_ordered = sort(b, by=(x) -> x["index"])

    return [bus["vm"]*cos(bus["va"]) + bus["vm"]*sin(bus["va"])im for bus in bus_ordered]
end

"""
given a basic network data dict, returns a complex valued vector of bus power
injections as they appear in the network data.
"""
function calc_basic_bus_injection(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_bus_injection requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    bi_dict = calc_bus_injection(data)
    bi_vect = [bi_dict[1][i] + bi_dict[2][i]im for i in 1:length(data["bus"])]

    return bi_vect
end

"""
given a basic network data dict, returns a complex valued vector of branch
series impedances.
"""
function calc_basic_branch_series_impedance(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_branch_series_impedance requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    b = [branch for (i,branch) in data["branch"] if branch["br_status"] != 0]
    branch_ordered = sort(b, by=(x) -> x["index"])

    return [branch["br_r"] + branch["br_x"]im for branch in branch_ordered]
end


"""
given a basic network data dict, returns a sparse integer valued incidence
matrix with one row for each branch and one column for each bus in the network.
In each branch row a +1 is used to indicate the _from_ bus and -1 is used to
indicate _to_ bus.
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
        push!(I, i); push!(J, branch["f_bus"]); push!(V,  1)
        push!(I, i); push!(J, branch["t_bus"]); push!(V, -1)
    end

    return sparse(I,J,V)
end

"""
given a basic network data dict, returns a sparse complex valued admittance
matrix with one row and column for each bus in the network.
"""
function calc_basic_admittance_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_admittance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    return calc_admittance_matrix(data).matrix
end


"""
given a basic network data dict, returns a sparse real valued susceptance
matrix with one row and column for each bus in the network.
This susceptance matrix reflects the imaginary part of an admittance
matrix that only considers the branch series impedance.
"""
function calc_basic_susceptance_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_susceptance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    return calc_susceptance_matrix(data).matrix
end


"""
given a basic network data dict, returns a sparse real valued branch susceptance
matrix with one row for each branch and one column for each bus in the network.
Multiplying the branch susceptance matrix by bus phase angels yields a vector
active power flow values for each branch.
"""
function calc_basic_branch_susceptance_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_branch_susceptance_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    I = Int64[]
    J = Int64[]
    V = Float64[]

    b = [branch for (i,branch) in data["branch"] if branch["br_status"] != 0]
    branch_ordered = sort(b, by=(x) -> x["index"])
    for (i,branch) in enumerate(branch_ordered)
        g,b = calc_branch_y(branch)
        push!(I, i); push!(J, branch["f_bus"]); push!(V,  b)
        push!(I, i); push!(J, branch["t_bus"]); push!(V, -b)
    end

    return sparse(I,J,V)
end

"""
given a basic network data dict, computes real valued vector of bus voltage
phase angles by solving a dc power flow.
"""
function compute_basic_dc_pf(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "compute_basic_dc_pf requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    num_bus = length(data["bus"])
    ref_bus_id = reference_bus(data)["index"]

    bi = real(calc_basic_bus_injection(data))

    sm = calc_basic_susceptance_matrix(data)

    for i in 1:num_bus
        if i == ref_bus_id
            # TODO improve scaling of this value
            sm[i,i] = 1.0
        else
            if !iszero(sm[ref_bus_id,i])
                sm[ref_bus_id,i] = 0.0
            end
        end
    end
    bi[ref_bus_id] = 0.0

    theta = -sm \ bi

    return theta
end



"""
given a basic network data dict, returns a real valued ptdf matrix with one
row for each branch and one column for each bus in the network.
Multiplying the ptdf matrix by bus injection values yields a vector
active power flow values on each branch.
"""
function calc_basic_ptdf_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_ptdf_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    num_bus = length(data["bus"])
    num_branch = length(data["branch"])

    b_inv = calc_susceptance_matrix_inv(data).matrix

    ptdf = zeros(num_branch, num_bus)
    for (i,branch) in data["branch"]
        branch_idx = branch["index"]
        bus_fr = branch["f_bus"]
        bus_to = branch["t_bus"]
        g,b = calc_branch_y(branch)
        for n in 1:num_bus
            ptdf[branch_idx, n] = b*(b_inv[bus_fr, n] - b_inv[bus_to, n])
        end
    end

    return ptdf
end

"""
given a basic network data dict and a branch index returns a row of the ptdf
matrix reflecting that branch.
"""
function calc_basic_ptdf_row(data::Dict{String,<:Any}, branch_index::Int)
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_ptdf_row requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end

    if branch_index < 1 || branch_index > length(data["branch"])
        Memento.error(_LOGGER, "branch index of $(branch_index) is out of bounds, valid values are $(1)-$(length(data["branch"]))")
    end
    branch = data["branch"]["$(branch_index)"]
    g,b = calc_branch_y(branch)

    num_bus = length(data["bus"])

    ref_bus = reference_bus(data)
    am = calc_susceptance_matrix(data)

    if_fr = injection_factors_va(am, ref_bus["index"], branch["f_bus"])
    if_to = injection_factors_va(am, ref_bus["index"], branch["t_bus"])

    ptdf_column = zeros(num_bus)
    for n in 1:num_bus
        ptdf_column[n] = b*(get(if_fr, n, 0.0) - get(if_to, n, 0.0))
    end

    return ptdf_column
end


#=
TODO needs to be updated to new admittance matrix convention

"""
given a basic network data dict, returns a sparse real valued Jacobian matrix
of the ac power flow problem.  The power variables are ordered by p and then q
while voltage values are ordered by voltage angle and then voltage magnitude.
"""
function calc_basic_jacobian_matrix(data::Dict{String,<:Any})
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "calc_basic_jacobian_matrix requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
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

    return J
end
=#

