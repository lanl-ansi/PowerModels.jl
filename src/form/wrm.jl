export
    SDPWRMPowerModel, SDPWRMForm, SDPDecompPowerModel, SDPDecompForm,
    SDPDecompMergePowerModel, SDPDecompMergeForm

""
abstract type AbstractWRMForm <: AbstractConicPowerFormulation end

""
abstract type SDPWRMForm <: AbstractWRMForm end

""
abstract type SDPDecompForm <: AbstractWRMForm end

""
abstract type SDPDecompMergeForm <: AbstractWRMForm end

""
const SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}

""
const SDPDecompPowerModel = GenericPowerModel{SDPDecompForm}

""
const SDPDecompMergePowerModel = GenericPowerModel{SDPDecompMergeForm}

""
SDPWRMPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPWRMForm; kwargs...)

SDPDecompPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPDecompForm; kwargs...)

SDPDecompMergePowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPDecompMergeForm; kwargs...)

""
function variable_voltage(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: AbstractWRMForm
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)
    bus_ids = ids(pm, nw, :bus)

    w_index = 1:length(bus_ids)
    lookup_w_index = Dict([(bi,i) for (i,bi) in enumerate(bus_ids)])

    WR = var(pm, nw, cnd)[:WR] = @variable(pm.model,
        [1:length(bus_ids), 1:length(bus_ids)], Symmetric, basename="$(nw)_$(cnd)_WR"
    )
    WI = var(pm, nw, cnd)[:WI] = @variable(pm.model,
        [1:length(bus_ids), 1:length(bus_ids)], basename="$(nw)_$(cnd)_WI"
    )

    # bounds on diagonal
    for (i, bus) in ref(pm, nw, :bus)
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        if bounded
            setlowerbound(wr_ii, (bus["vmin"][cnd])^2)
            setupperbound(wr_ii, (bus["vmax"][cnd])^2)

            #this breaks SCS on the 3 bus exmple
            #setlowerbound(wi_ii, 0)
            #setupperbound(wi_ii, 0)
        else
             setlowerbound(wr_ii, 0)
        end
    end

    # bounds on off-diagonal
    for (i,j) in ids(pm, nw, :buspairs)
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        if bounded
            setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
            setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

            setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
            setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
        end
    end

    var(pm, nw, cnd)[:w] = Dict{Int,Any}()
    for (i, bus) in ref(pm, nw, :bus)
        w_idx = lookup_w_index[i]
        var(pm, nw, cnd, :w)[i] = WR[w_idx,w_idx]
    end

    var(pm, nw, cnd)[:wr] = Dict{Tuple{Int,Int},Any}()
    var(pm, nw, cnd)[:wi] = Dict{Tuple{Int,Int},Any}()
    for (i,j) in ids(pm, nw, :buspairs)
        w_fr_index = lookup_w_index[i]
        w_to_index = lookup_w_index[j]

        var(pm, nw, cnd, :wr)[(i,j)] = WR[w_fr_index, w_to_index]
        var(pm, nw, cnd, :wi)[(i,j)] = WI[w_fr_index, w_to_index]
    end

end


""
function constraint_voltage(pm::GenericPowerModel{T}, nw::Int, cnd::Int) where T <: AbstractWRMForm
    WR = var(pm, nw, cnd)[:WR]
    WI = var(pm, nw, cnd)[:WI]

    @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in ids(pm, nw, :buspairs)
    #    InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
end

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

"""
    A = overlap_graph(groups)
Return adjacency matrix for overlap graph associated with `groups`.
I.e. if `A[i, j] = k`, then `groups[i]` and `groups[j]` share `k` elements.
"""
function overlap_graph(groups)
    n = length(groups)
    I = Vector{Int}()
    J = Vector{Int}()
    V = Vector{Int}()
    for (i, gi) in enumerate(groups)
        for (j, gj) in enumerate(groups)
            if gi != gj
                overlap = length(intersect(gi, gj))
                if overlap > 0
                    push!(I, i)
                    push!(J, j)
                    push!(V, overlap)
                end
            end
        end
    end
    return sparse(I, J, V, n, n)
end

"""
    T = prim(A, minweight=false)
Return minimum spanning tree adjacency matrix, given adjacency matrix.
If minweight == false, return the *maximum* weight spanning tree.

Convention: start with node 1.
"""
function prim(A, minweight=false)
    n = size(A, 1)
    candidate_edges = []
    unvisited = collect(1:n)
    next_node = 1 # convention
    T = spzeros(n, n)

    while length(unvisited) > 1
        current_node = next_node
        filter!(node -> node != current_node, unvisited)

        neighbors = intersect(find(A[:, current_node]), unvisited)
        current_node_edges = [(current_node, i) for i in neighbors]
        append!(candidate_edges, current_node_edges)
        filter!(edge -> length(intersect(edge, unvisited)) == 1, candidate_edges)
        weights = [A[edge...] for edge in candidate_edges]
        next_edge = minweight ? candidate_edges[indmin(weights)] : candidate_edges[indmax(weights)]
        filter!(edge -> edge != next_edge, candidate_edges)
        T[next_edge...] = minweight ? minimum(weights) : maximum(weights)
        next_node = intersect(next_edge, unvisited)[1]
    end
    return T
end

"""
    ps = problem_size(groups)
Returns the sum of variables and linking constraints corresponding to the
semidefinite constraint decomposition given by `groups`. This function is
not necessary for the operation of clique merge, since `merge_cost`
computes the change in problem size for a proposed group merge.
"""
function problem_size(groups)
    nvars(n::Integer) = n*(2*n + 1)
    A = prim(overlap_graph(groups))
    return sum(nvars.(Int64.(nonzeros(A)))) + sum(nvars.(length.(groups)))
end

function merge_cost(groups, i, k)
    nvars(n::Integer) = n*(2*n + 1)
    nvars(g::Vector) = nvars(length(g))

    gi, gk = groups[i], groups[k]
    overlap = intersect(gi, gk)
    gnew = union(gi, gk)
    return nvars(gnew) - nvars(gi) - nvars(gk) - nvars(overlap)
end

function merge_groups!(groups, i, k)
    gi, gk = groups[i], groups[k]
    filter!(g -> g != gi && g != gk, groups)
    push!(groups, union(gi, gk))
end

"""
    merged_groups = greedy_merge(groups)
Greedily merge groups belonging to `groups`. Merge costs are computed by the function
`merge_cost`, which accepts `groups` and two group indices, and returns the change
in objective value associated with merging the two groups.

This function assumes that merge costs grow with increasing overlap between groups.
"""
function greedy_merge(groups::Vector{Vector{Int64}}, merge_cost::Function=merge_cost)
    merged_groups = copy(groups)

    delta = -1
    while delta < 0
        T = prim(overlap_graph(merged_groups))
        potential_merges = [ind2sub(T, idx) for idx in find(T)]
        length(potential_merges) == 0 && break
        merge_costs = [merge_cost(merged_groups, merge...) for merge in potential_merges]
        delta, merge_idx = findmin(merge_costs)
        delta == 0 && break
        i, k = potential_merges[merge_idx]
        merge_groups!(merged_groups, i, k)
    end
    return merged_groups
end

function constraint_voltage(pm::GenericPowerModel{SDPDecompForm}, nw::Int, cnd::Int)
    if haskey(pm.ext, :clique_grouping)
        clique_grouping = pm.ext[:clique_grouping]
    else
        cadj = chordal_extension(pm)
        clique_grouping = maximal_cliques(cadj)
    end

    WR = var(pm, nw, cnd)[:WR]
    WI = var(pm, nw, cnd)[:WI]

    for group in clique_grouping
        WRgroup = WR[group, group]
        WIgroup = WI[group, group]
        @SDconstraint(pm.model, [WRgroup WIgroup; -WIgroup WRgroup] >= 0)
    end
end

function constraint_voltage(pm::GenericPowerModel{SDPDecompMergeForm}, nw::Int, cnd::Int)
    WR = var(pm, nw, cnd)[:WR]
    WI = var(pm, nw, cnd)[:WI]

    cadj = chordal_extension(pm)
    cliques = maximal_cliques(cadj)
    clique_grouping = greedy_merge(cliques)
    for group in clique_grouping
        WRgroup = WR[group, group]
        WIgroup = WI[group, group]
        @SDconstraint(pm.model, [WRgroup WIgroup; -WIgroup WRgroup] >= 0)
    end
end
