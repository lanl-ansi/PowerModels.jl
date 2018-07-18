export
    SDPDecompPowerModel, SDPDecompForm

""
abstract type AbstractWRMForm <: AbstractConicPowerFormulation end

""
abstract type SDPDecompForm <: AbstractWRMForm end

""
const SDPDecompPowerModel = GenericPowerModel{SDPDecompForm}

""
SDPDecompPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPDecompForm; kwargs...)

"""
    adj = adjacency_matrix(pm, nw)
Return a sparse adjacency matrix.
"""
function adjacency_matrix(pm::GenericPowerModel, nw::Int=pm.cnw)
    bus_ids = ids(pm, nw, :bus)
    buspairs = ref(pm, nw, :buspairs)

    nb = length(bus_ids)
    nl = length(buspairs)

    reindex = Dict([(bi, i) for (i, bi) in enumerate(bus_ids)])
    f = [reindex[bp[1]] for bp in keys(buspairs)]
    t = [reindex[bp[2]] for bp in keys(buspairs)]

    return sparse([f;t], [t;f], ones(2nl), nb, nb)
end

"""
    cadj = chordal_extension(pm, nw)
Return an adjacency matrix corresponding
to a chordal extension of the power grid graph.
"""
function chordal_extension(pm::GenericPowerModel, nw::Int=pm.cnw)
    adj = adjacency_matrix(pm, nw)
    nb = size(adj, 1)
    diag_el = sum(adj, 1)[:]
    W = Hermitian(adj + spdiagm(diag_el, 0))

    F = cholfact(W)
    L, p = sparse(F[:L]), invperm(F[:p])
    Rchol = L - spdiagm(diag(L), 0)
    f_idx, t_idx, V = findnz(Rchol)
    cadj = sparse([f_idx;t_idx], [t_idx;f_idx], ones(2*length(f_idx)), nb, nb)
    cadj = cadj[p, p] # revert to original bus ordering (invert cholfact permutation)
    return cadj
end

"""
    peo = mcs(A)
Maximum cardinality search for graph adjacency matrix A.
Returns a perfect elimination ordering.
"""
function mcs(A)
    n = size(A, 1)
    w = zeros(Int, n)
    peo = zeros(Int, n)
    unnumbered = collect(1:n)

    for i = n:-1:1
        z = unnumbered[indmax(w[unnumbered])]
        filter!(x -> x != z, unnumbered)
        peo[i] = z

        Nz = find(A[:, z])
        for y in intersect(Nz, unnumbered)
            w[y] += 1
        end
    end
    return peo
end

"""
    mc = maximal_cliques(cadj, peo)
Given a chordal graph adjacency matrix and perfect elimination
ordering, return the set of maximal cliques.
"""
function maximal_cliques(cadj::SparseMatrixCSC{Float64,Int64}, peo::Vector{Int})
    nb = size(cadj, 1)

    # use peo to obtain one clique for each vertex
    cliques = Vector(nb)
    for (i, v) in enumerate(peo)
        Nv = find(cadj[:, v])
        cliques[i] = union(v, intersect(Nv, peo[i+1:end]))
    end

    # now remove cliques that are strict subsets of other cliques
    mc = Vector()
    for c1 in cliques
        # declare clique maximal if it is a subset only of itself
        if sum([issubset(c1, c2) for c2 in cliques]) == 1
            push!(mc, c1)
        end
    end
    # sort node labels within each clique
    mc = [sort(c) for c in mc]
    return mc
end
maximal_cliques(cadj::SparseMatrixCSC{Float64,Int64}) = maximal_cliques(cadj, mcs(cadj))

function constraint_voltage(pm::GenericPowerModel{SDPDecompForm}, nw::Int, cnd::Int)
    cadj = chordal_extension(pm)
    mc = maximal_cliques(cadj)

    # `partition` is a list of lists that partitions the set of nodes,
    # must consist of combinations of maximal cliques of a chordal extension
    # of the power grid graph
    partition = mc

    WR = var(pm, nw, cnd)[:WR]
    WI = var(pm, nw, cnd)[:WI]

    for group in partition
        WRgroup = WR[group, group]
        WIgroup = WI[group, group]
        @SDconstraint(pm.model, [WRgroup WIgroup; -WIgroup WRgroup] >= 0)
    end
end
