###############################################################################
# Data Structures and Functions for working with a network Admittance Matrix
###############################################################################

"""
Stores metadata related to an Admittance Matirx

Designed to work with both complex (i.e. Y) and real-valued (e.g. b) valued
admittance matirices.

Typically the matrix will be sparse, but supports dense matricies as well.
"""
struct AdmittanceMatrix{T}
    idx_to_bus::Vector{Int}
    bus_to_idx::Dict{Int,Int}
    matrix::T
    # TODO should this include a RHS?
end

# Generic Case (e.g. with Dense Array Case)
Base.show(io::IO, x::AdmittanceMatrix{<:Any}) = print(io, "AdmittanceMatrix($(length(x.idx_to_bus)) buses, $(length(x.matrix)) entries)")

# Typical Sparse Array Case
Base.show(io::IO, x::AdmittanceMatrix{<:SparseArrays.AbstractSparseMatrix}) = print(io, "AdmittanceMatrix($(length(x.idx_to_bus)) buses, $(length(nonzeros(x.matrix))) entries)")



"""
Stores metadata related to an PTDF Matirx

Designed to work with the inverse of both complex (i.e. Y) and real-valued (e.g. b) valued
admittance matirices.

Typically the matrix will be dense.
"""
struct PowerTransferDistributionFactors{T}
    idx_to_bus::Vector{Int}
    bus_to_idx::Dict{Int,Int}
    matrix::T
    # TODO should this include a RHS?
end

# Generic Case (e.g. with Dense Array Case)
Base.show(io::IO, x::PowerTransferDistributionFactors{<:Any}) = print(io, "PowerTransferDistributionFactors($(length(x.idx_to_bus)) buses, $(length(x.matrix)) entries)")




"data should be a PowerModels network data model"
function calc_susceptance_matrix(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with switches")
    end

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

    return AdmittanceMatrix(idx_to_bus, bus_to_idx, m)
end


"note, data should be a PowerModels network data model"
calc_ptdf_matrix(data::Dict{String,<:Any}) = calc_ptdf_matrix(calc_susceptance_matrix(data))

"calculates a PTDF matrix"
function calc_ptdf_matrix(am::AdmittanceMatrix)
    m = Matrix(am.matrix)
    ptdf = pinv(m)
    #println(ptdf)
    return PowerTransferDistributionFactors(am.idx_to_bus, am.bus_to_idx, ptdf)
end

function injection_factors(ptdf::PowerTransferDistributionFactors, bus_id::Int)
    bus_idx = ptdf.bus_to_idx[bus_id]

    injection_factors = Dict(
        ptdf.idx_to_bus[i] => ptdf.matrix[bus_idx,i]
        for i in 1:length(ptdf.idx_to_bus)
    )

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

    ref_bus = [bus["index"] for (i,bus) in data["bus"] if bus["bus_type"] == 3]

    if length(ref_bus) != 1
        Memento.error(_LOGGER, "exactly one refrence bus is required when solving a dc power flow, given $(length(ref_bus))")
    end
    ref_bus = ref_bus[1]
    #println(ref_bus)

    sm = calc_susceptance_matrix(data)
    bi = calc_bus_injection_active(data)

    bi_idx = [bi[bus_id] for bus_id in sm.idx_to_bus]
    theta_idx = solve_theta(sm, bi_idx, sm.bus_to_idx[ref_bus])

    bus_assignment= Dict{String,Any}()
    for (i,bus) in data["bus"]
        va = NaN
        if haskey(sm.bus_to_idx, bus["index"])
            va = theta_idx[sm.bus_to_idx[bus["index"]]]
        end
        bus_assignment[i] = Dict("va" => va)
    end

    return Dict("bus" => bus_assignment)
end


"""
solves a DC power flow
"""
function solve_theta(am::AdmittanceMatrix, bus_injection::Vector{Float64}, ref_idx::Int)
    #println(am.matrix)
    #println(bus_injection)

    m = deepcopy(am.matrix)
    bi = deepcopy(bus_injection)

    for i in 1:length(am.idx_to_bus)
        if i == ref_idx
            # TODO improve scaling of this value
            m[i,i] = 1.0
        else
            if !iszero(m[ref_idx,i])
                m[ref_idx,i] = 0.0
            end
        end
    end
    bi[ref_idx] = 0.0

    #println(m)
    #println(bi)

    theta = m \ -bi

    return theta
end
