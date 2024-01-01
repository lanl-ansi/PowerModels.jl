###############################################################################
# Data Structures and Functions for working with a network Admittance Matrix
###############################################################################

"""
Stores data related to an Admittance Matrix.  Work with both complex
(i.e. Y) and real-valued (e.g. B) valued admittance matrices.  Only supports
sparse matrices.

* `idx_to_bus` - a mapping from 1-to-n bus idx values to data model bus ids
* `bus_to_idx` - a mapping from data model bus ids to 1-to-n bus idx values
* `matrix` - the sparse admittance matrix values
"""
struct AdmittanceMatrix{T}
    idx_to_bus::Vector{Int}
    bus_to_idx::Dict{Int,Int}
    matrix::SparseArrays.SparseMatrixCSC{T,Int}
end

Base.show(io::IO, x::AdmittanceMatrix{<:Number}) = print(io, "AdmittanceMatrix($(length(x.idx_to_bus)) buses, $(length(nonzeros(x.matrix))) entries)")


"data should be a PowerModels network data model; only supports networks with exactly one reference bus"
function calc_admittance_matrix(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_admittance_matrix does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_admittance_matrix does not support data with switches")
    end

    #TODO check single connected component

    buses = [x.second for x in data["bus"] if (x.second[pm_component_status["bus"]] != pm_component_status_inactive["bus"])]
    sort!(buses, by=x->x["index"])

    idx_to_bus = [x["index"] for x in buses]
    bus_to_idx = Dict(x["index"] => i for (i,x) in enumerate(buses))

    I = Int[]
    J = Int[]
    V = Complex{Float64}[]

    for (i,branch) in data["branch"]
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        if branch[pm_component_status["branch"]] != pm_component_status_inactive["branch"] && haskey(bus_to_idx, f_bus) && haskey(bus_to_idx, t_bus)
            f_bus = bus_to_idx[f_bus]
            t_bus = bus_to_idx[t_bus]
            y = inv(branch["br_r"] + branch["br_x"]im)
            tr, ti = calc_branch_t(branch)
            t = tr + ti*im
            lc_fr = branch["g_fr"] + branch["b_fr"]im
            lc_to = branch["g_to"] + branch["b_to"]im
            push!(I, f_bus); push!(J, t_bus); push!(V, -y/conj(t))
            push!(I, t_bus); push!(J, f_bus); push!(V, -(y/t))
            push!(I, f_bus); push!(J, f_bus); push!(V, (y + lc_fr)/abs2(t))
            push!(I, t_bus); push!(J, t_bus); push!(V, (y + lc_to))
        end
    end

    for (i,shunt) in data["shunt"]
        shunt_bus = shunt["shunt_bus"]
        if shunt[pm_component_status["shunt"]] != pm_component_status_inactive["shunt"] && haskey(bus_to_idx, shunt_bus)
            bus = bus_to_idx[shunt_bus]

            ys = shunt["gs"] + shunt["bs"]im

            push!(I, bus); push!(J, bus); push!(V, ys)
        end
    end

    m = sparse(I,J,V)

    return AdmittanceMatrix(idx_to_bus, bus_to_idx, m)
end


"data should be a PowerModels network data model; only supports networks with exactly one refrence bus"
function calc_susceptance_matrix(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with switches")
    end

    #TODO check single connected component

    buses = [x.second for x in data["bus"] if (x.second[pm_component_status["bus"]] != pm_component_status_inactive["bus"])]
    sort!(buses, by=x->x["index"])

    idx_to_bus = [x["index"] for x in buses]
    bus_type = [x["bus_type"] for x in buses]
    bus_to_idx = Dict(x["index"] => i for (i,x) in enumerate(buses))

    I = Int[]
    J = Int[]
    V = Float64[]

    for (i,branch) in data["branch"]
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        if branch[pm_component_status["branch"]] != pm_component_status_inactive["branch"] && haskey(bus_to_idx, f_bus) && haskey(bus_to_idx, t_bus)
            f_bus = bus_to_idx[f_bus]
            t_bus = bus_to_idx[t_bus]
            b_val = imag(inv(branch["br_r"] + branch["br_x"]im))
            push!(I, f_bus); push!(J, t_bus); push!(V, -b_val)
            push!(I, t_bus); push!(J, f_bus); push!(V, -b_val)
            push!(I, f_bus); push!(J, f_bus); push!(V,  b_val)
            push!(I, t_bus); push!(J, t_bus); push!(V,  b_val)
        end
    end

    m = sparse(I,J,V)

    return AdmittanceMatrix(idx_to_bus, bus_to_idx, m)
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


"""
    calc_susceptance_matrix_inv(data)

Compute the inverse of the network's susceptance matrix.

Note: `data`` should be a PowerModels network data model; only supports networks with exactly one refrence bus.

While the susceptance matrix is sparse, its inverse it typically quite dense.
This implementation first computes a sparse factorization, then recovers the (dense)
    matrix inverse via backward substitution. This is more efficient
    than directly computing a dense inverse with `LinearAlgebra.inv`.
"""
function calc_susceptance_matrix_inv(data::Dict{String,<:Any})
    #TODO check single connected component
    sm = calc_susceptance_matrix(data)
    S  = sm.matrix
    num_buses = length(sm.idx_to_bus)  # this avoids inactive buses
    
    ref_bus = reference_bus(data)
    ref_idx = sm.bus_to_idx[ref_bus["index"]]
    if !(ref_idx > 0 && ref_idx <= num_buses)
        Memento.error(_LOGGER, "invalid ref_idx in calc_susceptance_matrix_inv")
    end
    S[ref_idx, :] .= 0.0
    S[:, ref_idx] .= 0.0
    S[ref_idx, ref_idx] = 1.0
    
    F = LinearAlgebra.ldlt(Symmetric(S); check=false)
    if !LinearAlgebra.issuccess(F)
        Memento.error(_LOGGER, "Failed factorization in calc_susceptance_matrix_inv")
    end
    M = F \ Matrix(1.0I, num_buses, num_buses)
    M[ref_idx, :] .= 0.0  # zero-out the row of the slack bus
    
    return AdmittanceMatrixInverse(sm.idx_to_bus, sm.bus_to_idx, ref_idx, M)
end

"calculates the inverse of the susceptance matrix"
function calc_admittance_matrix_inv(am::AdmittanceMatrix, ref_idx::Int)
    num_buses = length(am.idx_to_bus)

    if !(ref_idx > 0 && ref_idx <= num_buses)
        Memento.error(_LOGGER, "invalid ref_idx in calc_admittance_matrix_inv")
    end

    M = Matrix(am.matrix)

    nonref_buses = Int[i for i in 1:num_buses if i != ref_idx]
    am_inv = zeros(Float64, num_buses, num_buses)
    am_inv[nonref_buses, nonref_buses] = inv(M[nonref_buses, nonref_buses])

    return AdmittanceMatrixInverse(am.idx_to_bus, am.bus_to_idx, ref_idx, am_inv)
end


"""
extracts a mapping from bus injections to voltage angles from the inverse of an admittance matrix.
refrence bus is defined as part of the given AdmittanceMatrixInverse.
"""
function injection_factors_va(am_inv::AdmittanceMatrixInverse{T}, bus_id::Int)::Dict{Int,T} where T
    if !haskey(am_inv.bus_to_idx, bus_id)
        return Dict{Int,T}()
    end

    bus_idx = am_inv.bus_to_idx[bus_id]

    injection_factors = Dict(
        am_inv.idx_to_bus[i] => am_inv.matrix[bus_idx,i]
        for i in 1:length(am_inv.idx_to_bus) if !isapprox(am_inv.matrix[bus_idx,i], 0.0)
    )

    return injection_factors
end


"""
computes a mapping from bus injections to voltage angles implicitly by solving a system of linear equations.
an explicit refrence bus id required.
"""
function injection_factors_va(am::AdmittanceMatrix{T}, ref_bus::Int, bus_id::Int)::Dict{Int,T} where T
    # !haskey(am.bus_to_idx, bus_id) occurs when the bus is inactive
    if ref_bus == bus_id || !haskey(am.bus_to_idx, bus_id)
        return Dict{Int,T}()
    end

    ref_idx = am.bus_to_idx[ref_bus]
    bus_idx = am.bus_to_idx[bus_id]

    # need to remap the indexes to omit the ref_bus id
    # a reverse lookup is also required
    idx2_to_idx1 = Int[]
    for i in 1:length(am.idx_to_bus)
        if i != ref_idx
            push!(idx2_to_idx1, i)
        end
    end
    idx1_to_idx2 = Dict(v => i for (i,v) in enumerate(idx2_to_idx1))

    # rebuild the sparse version of the AdmittanceMatrix without the reference bus
    I = Int[]
    J = Int[]
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
computes the power injection of each bus in the network, with a focus on the
needs of Power Flow solvers.

excludes voltage-dependent components (e.g. shunts), these should be addressed
as needed by the calling functions.  note that voltage dependent components are
resolved during an AC Power Flow solve and are not static.

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
            p_delta = bvals["pg"] - bvals["ps"] - bvals["pd"]
            q_delta = bvals["qg"] - bvals["qs"] - bvals["qd"]
        else
            p_delta = NaN
            q_delta = NaN
        end

        p_deltas[bus["index"]] = p_delta
        q_deltas[bus["index"]] = q_delta
    end

    return (p_deltas, q_deltas)
end

"an active power only variant of `calc_bus_injection`"
calc_bus_injection_active(data::Dict{String,<:Any}) = calc_bus_injection(data)[1]


"""
solves a DC power flow, assumes a single slack power variable at the given refrence bus
"""
function solve_theta(am::AdmittanceMatrix, ref_idx::Int, bus_injection::Vector{Float64})
    # TODO can copy be avoided?  @view?
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

    theta = -m \ bi

    return theta
end
