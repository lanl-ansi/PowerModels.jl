###############################################################################
# Data Structures and Functions for working with a network Admittance Matrix
###############################################################################

"""
Stores metadata related to an Admittance Matirx

Designed to work with both complex (i.e. Y) and real-valued (e.g. b) valued
admittance matrices.

Typically the matrix will be sparse, but supports dense matricies as well.
"""
struct AdmittanceMatrix{T}
    idx_to_bus::Vector{Int}
    bus_to_idx::Dict{Int,Int}
    ref_idx::Int
    matrix::SparseArrays.SparseMatrixCSC{T,Int}
end

Base.show(io::IO, x::AdmittanceMatrix{<:Number}) = print(io, "AdmittanceMatrix($(length(x.idx_to_bus)) buses, $(length(nonzeros(x.matrix))) entries)")


"data should be a PowerModels network data model; only supports networks with exactly one refrence bus"
function calc_susceptance_matrix(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with switches")
    end

    #TODO check single connected component

    # NOTE currently exactly one refrence bus is required
    ref_bus = reference_bus(data)

    buses = [x.second for x in data["bus"] if (x.second[pm_component_status["bus"]] != pm_component_status_inactive["bus"])]
    sort!(buses, by=x->x["index"])

    idx_to_bus = [x["index"] for x in buses]
    bus_to_idx = Dict(x["index"] => i for (i,x) in enumerate(buses))
    #println(idx_to_bus)
    #println(bus_to_idx)

    I = Int64[]
    J = Int64[]
    V = Float64[]

    for (i,branch) in data["branch"]
        if branch[pm_component_status["branch"]] != pm_component_status_inactive["branch"]
            f_bus = bus_to_idx[branch["f_bus"]]
            t_bus = bus_to_idx[branch["t_bus"]]
            b_val = -branch["br_x"]/(branch["br_x"]^2+branch["br_r"]^2)
            push!(I, f_bus); push!(J, t_bus); push!(V,  b_val)
            push!(I, t_bus); push!(J, f_bus); push!(V,  b_val)
            push!(I, f_bus); push!(J, f_bus); push!(V, -b_val)
            push!(I, t_bus); push!(J, t_bus); push!(V, -b_val)
        end
    end

    m = sparse(I,J,V)
    #println(m)

    return AdmittanceMatrix(idx_to_bus, bus_to_idx, bus_to_idx[ref_bus["index"]], m)
end


"""
Stores metadata related to an inverse of an Matirx

Designed to work with the inverse of both complex (i.e. Y) and real-valued (e.g. b) valued
admittance matrices.

Typically the matrix will be dense.
"""
struct AdmittanceMatrixInverse{T}
    idx_to_bus::Vector{Int}
    bus_to_idx::Dict{Int,Int}
    ref_idx::Int
    matrix::Matrix{T}
end

Base.show(io::IO, x::AdmittanceMatrixInverse{<:Number}) = print(io, "AdmittanceMatrixInverse($(length(x.idx_to_bus)) buses, $(length(x.matrix)) entries)")


"note, data should be a PowerModels network data model; only supports networks with exactly one refrence bus"
function calc_susceptance_matrix_inv(data::Dict{String,<:Any})
    #TODO check single connected component

    sm = calc_susceptance_matrix(data)
    sm_inv = calc_admittance_matrix_inv(sm)

    return sm_inv
end

"calculates the inverse of the susceptance matrix"
function calc_admittance_matrix_inv(am::AdmittanceMatrix)
    M = Matrix(am.matrix)

    num_buses = length(am.idx_to_bus)
    nonref_buses = Int64[i for i in 1:num_buses if i != am.ref_idx]
    am_inv = zeros(Float64, num_buses, num_buses)
    am_inv[nonref_buses, nonref_buses] = inv(M[nonref_buses, nonref_buses])

    return AdmittanceMatrixInverse(am.idx_to_bus, am.bus_to_idx, am.ref_idx, am_inv)
end


"extracts a mapping from bus injections to voltage angles from the inverse of an admittance matrix."
function injection_factors_va(am_inv::AdmittanceMatrixInverse{T}, bus_id::Int)::Dict{Int,T} where T
    bus_idx = am_inv.bus_to_idx[bus_id]

    injection_factors = Dict(
        am_inv.idx_to_bus[i] => am_inv.matrix[bus_idx,i]
        for i in 1:length(am_inv.idx_to_bus) if !isapprox(am_inv.matrix[bus_idx,i], 0.0)
    )

    return injection_factors
end


"computes a mapping from bus injections to voltage angles implicitly by solving a system of linear equations."
function injection_factors_va(am::AdmittanceMatrix{T}, bus_id::Int; ref_bus::Int=typemin(Int))::Dict{Int,T} where T
    # this row is all zeros, an empty Dict is also a reasonable option

    if ref_bus == typemin(Int)
        ref_bus = am.idx_to_bus[am.ref_idx]
    end

    if ref_bus == bus_id
        return Dict{Int,T}()
    end

    ref_idx = am.bus_to_idx[ref_bus]
    bus_idx = am.bus_to_idx[bus_id]

    # need to remap the indexes to omit the ref_bus id
    # a reverse lookup is also required
    idx2_to_idx1 = Int64[]
    for i in 1:length(am.idx_to_bus)
        if i != ref_idx
            push!(idx2_to_idx1, i)
        end
    end
    idx1_to_idx2 = Dict(v => i for (i,v) in enumerate(idx2_to_idx1))

    # rebuild the sparse version of the AdmittanceMatrix without the reference bus
    I = Int64[]
    J = Int64[]
    V = Float64[]

    I_src, J_src, V_src = findnz(am.matrix)
    for k in 1:length(V_src)
        if I_src[k] != ref_idx && J_src[k] != ref_idx
            push!(I, idx1_to_idx2[I_src[k]])
            push!(J, idx1_to_idx2[J_src[k]])
            push!(V, V_src[k])
        end
    end
    M = sparse(I,J,V)

    # a vector to select which bus injection factors to compute
    va_vect = zeros(Float64, length(idx2_to_idx1))
    va_vect[idx1_to_idx2[bus_idx]] = 1.0

    if_vect = M \ va_vect

    # map injection factors back to original bus ids
    injection_factors = Dict(am.idx_to_bus[idx2_to_idx1[i]] => v for (i,v) in enumerate(if_vect) if !isapprox(v, 0.0))

    return injection_factors
end


"""
computes the power injection of each bus in the network

data should be a PowerModels network data model
"""
function calc_bus_injection(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_bus_injection does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_bus_injection does not support data with switches")
    end

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

    p_deltas = Dict{Int,Float64}()
    q_deltas = Dict{Int,Float64}()
    for (i,bus) in data["bus"]
        if bus["bus_type"] != 4
            bvals = bus_values[bus["index"]]
            p_delta = - bvals["pg"] + bvals["ps"] + bvals["pd"] + bvals["gs"]*(bvals["vm"]^2)
            q_delta = - bvals["qg"] + bvals["qs"] + bvals["qd"] - bvals["bs"]*(bvals["vm"]^2)
        else
            p_delta = NaN
            q_delta = NaN
        end

        p_deltas[bus["index"]] = p_delta
        q_deltas[bus["index"]] = q_delta
    end

    return (p_deltas, q_deltas)
end

calc_bus_injection_active(data::Dict{String,<:Any}) = calc_bus_injection(data)[1]


"""
computes a dc power flow based on the susceptance matrix of the network data
"""
function solve_dc_pf(data::Dict{String,<:Any})
    #TODO check single connected component

    sm = calc_susceptance_matrix(data)
    bi = calc_bus_injection_active(data)

    bi_idx = [bi[bus_id] for bus_id in sm.idx_to_bus]
    theta_idx = solve_theta(sm, bi_idx)

    bus_assignment= Dict{String,Any}()
    for (i,bus) in data["bus"]
        va = NaN
        if haskey(sm.bus_to_idx, bus["index"])
            va = theta_idx[sm.bus_to_idx[bus["index"]]]
        end
        bus_assignment[i] = Dict("va" => va)
    end

    return Dict("per_unit" => data["per_unit"], "bus" => bus_assignment)
end


"""
solves a DC power flow, assumes a single slack power variable at the refrence bus
"""
function solve_theta(am::AdmittanceMatrix, bus_injection::Vector{Float64})
    #println(am.matrix)
    #println(bus_injection)

    m = deepcopy(am.matrix)
    bi = deepcopy(bus_injection)

    for i in 1:length(am.idx_to_bus)
        if i == am.ref_idx
            # TODO improve scaling of this value
            m[i,i] = 1.0
        else
            if !iszero(m[am.ref_idx,i])
                m[am.ref_idx,i] = 0.0
            end
        end
    end
    bi[am.ref_idx] = 0.0

    theta = m \ -bi

    return theta
end
