export
    SDPWRMPowerModel, SDPWRMForm,
    SparseSDPWRMPowerModel, SparseSDPWRMForm

""
abstract type AbstractWRMForm <: AbstractConicPowerFormulation end

""
function constraint_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, c_rating_a) where T <: AbstractWRMForm
    l,i,j = f_idx
    t_idx = (l,j,i)

    w_fr = var(pm, n, c, :w, i)
    w_to = var(pm, n, c, :w, j)

    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    @constraint(pm.model, norm([2*p_fr; 2*q_fr; w_fr*c_rating_a^2-1]) <= w_fr*c_rating_a^2+1)

    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    @constraint(pm.model, norm([2*p_to; 2*q_to; w_to*c_rating_a^2-1]) <= w_to*c_rating_a^2+1)
end




""
abstract type SDPWRMForm <: AbstractWRMForm end

"""
Semi-definite relaxation of AC OPF

Originally proposed by:
```
@article{BAI2008383,
  author = "Xiaoqing Bai and Hua Wei and Katsuki Fujisawa and Yong Wang",
  title = "Semidefinite programming for optimal power flow problems",
  journal = "International Journal of Electrical Power & Energy Systems",
  volume = "30",
  number = "6",
  pages = "383 - 392",
  year = "2008",
  issn = "0142-0615",
  doi = "https://doi.org/10.1016/j.ijepes.2007.12.003",
  url = "http://www.sciencedirect.com/science/article/pii/S0142061507001378",
}
```
First paper to use "W" variables in the BIM of AC OPF:
```
@INPROCEEDINGS{6345272,
  author={S. Sojoudi and J. Lavaei},
  title={Physics of power networks makes hard optimization problems easy to solve},
  booktitle={2012 IEEE Power and Energy Society General Meeting},
  year={2012},
  month={July},
  pages={1-8},
  doi={10.1109/PESGM.2012.6345272},
  ISSN={1932-5517}
}
```
"""
const SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}

""
SDPWRMPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPWRMForm; kwargs...)


""
function constraint_voltage(pm::GenericPowerModel{T}, nw::Int, cnd::Int) where T <: SDPWRMForm
    WR = var(pm, nw, cnd)[:WR]
    WI = var(pm, nw, cnd)[:WI]

    @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)
end


""
function variable_voltage(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: SDPWRMForm
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





abstract type SparseSDPWRMForm <: SDPWRMForm end

"""
Sparsity-exploiting semidefinite relaxation of AC OPF

Proposed in:
```
@article{doi:10.1137/S1052623400366218,
author = {Fukuda, M. and Kojima, M. and Murota, K. and Nakata, K.},
title = {Exploiting Sparsity in Semidefinite Programming via Matrix Completion I: General Framework},
journal = {SIAM Journal on Optimization},
volume = {11},
number = {3},
pages = {647-674},
year = {2001},
doi = {10.1137/S1052623400366218},
URL = {https://doi.org/10.1137/S1052623400366218},
eprint = {https://doi.org/10.1137/S1052623400366218}
}
```
Original application to OPF by:
```
@ARTICLE{6064917,
author={R. A. Jabr},
title={Exploiting Sparsity in SDP Relaxations of the OPF Problem},
journal={IEEE Transactions on Power Systems},
volume={27},
number={2},
pages={1138-1139},
year={2012},
month={May}},
doi={10.1109/TPWRS.2011.2170772},
ISSN={0885-8950}
```
"""
const SparseSDPWRMPowerModel = GenericPowerModel{SparseSDPWRMForm}

""
SparseSDPWRMPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SparseSDPWRMForm; kwargs...)

struct SDconstraintDecomposition
    "Each sub-vector consists of bus IDs corresponding to a clique grouping"
    decomp::Vector{Vector{Int64}}
    "`lookup_index[bus_id] --> idx` for mapping between 1:n and bus indices"
    lookup_index::Dict
    "A chordal extension and maximal cliques are uniquely determined by a graph ordering"
    ordering::Vector{Int64}
end
import Base: ==
function ==(d1::SDconstraintDecomposition, d2::SDconstraintDecomposition)
    eq = true
    for f in fieldnames(SDconstraintDecomposition)
        eq = eq && (getfield(d1, f) == getfield(d2, f))
    end
    return eq
end

function variable_voltage(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded=true) where T <: SparseSDPWRMForm

    if haskey(pm.ext, :SDconstraintDecomposition)
        decomp = pm.ext[:SDconstraintDecomposition]
        groups = decomp.decomp
        lookup_index = decomp.lookup_index
        lookup_bus_index = map(reverse, lookup_index)
    else
        cadj, lookup_index, ordering = chordal_extension(pm)
        groups = maximal_cliques(cadj)
        lookup_bus_index = map(reverse, lookup_index)
        groups = [[lookup_bus_index[gi] for gi in g] for g in groups]
        pm.ext[:SDconstraintDecomposition] = SDconstraintDecomposition(groups, lookup_index, ordering)
    end

    voltage_product_groups =
        var(pm, nw, cnd)[:voltage_product_groups] =
        Vector{Dict{Symbol, Array{JuMP.Variable, 2}}}(length(groups))

    for (gidx, group) in enumerate(groups)
        n = length(group)
        voltage_product_groups[gidx] = Dict()
        voltage_product_groups[gidx][:WR] =
            var(pm, nw, cnd)[:voltage_product_groups][gidx][:WR] =
            @variable(pm.model, [1:n, 1:n], Symmetric,
                basename="$(nw)_$(cnd)_$(gidx)_WR")

        voltage_product_groups[gidx][:WI] =
            var(pm, nw, cnd)[:voltage_product_groups][gidx][:WI] =
            @variable(pm.model, [1:n, 1:n],
                basename="$(nw)_$(cnd)_$(gidx)_WI")
    end

    # voltage product bounds
    visited_buses = []
    visited_buspairs = []
    var(pm, nw, cnd)[:w] = Dict{Int,Any}()
    var(pm, nw, cnd)[:wr] = Dict{Tuple{Int,Int},Any}()
    var(pm, nw, cnd)[:wi] = Dict{Tuple{Int,Int},Any}()
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)
    for (gidx, voltage_product_group) in enumerate(voltage_product_groups)
        WR, WI = voltage_product_group[:WR], voltage_product_group[:WI]
        group = groups[gidx]
        ng = length(group)

        # diagonal bounds
        for (group_idx, bus_id) in enumerate(group)
            # group_idx indexes into group
            # bus_id indexes into ref(pm, nw, :bus)
            bus = ref(pm, nw, :bus, bus_id)

            wr_ii = WR[group_idx, group_idx]

            if bounded
                setupperbound(wr_ii, (bus["vmax"][cnd])^2)
                setlowerbound(wr_ii, (bus["vmin"][cnd])^2)
            else
                setlowerbound(wr_ii, 0)
            end

            # for non-semidefinite constraints
            if !(bus_id in visited_buses)
                push!(visited_buses, bus_id)
                var(pm, nw, cnd, :w)[bus_id] = wr_ii
            end
        end

        # off-diagonal bounds
        offdiag_indices = [(i, j) for i in 1:ng, j in 1:ng if i != j]
        for (i, j) in offdiag_indices
            i_bus, j_bus = group[i], group[j]
            if (i_bus, j_bus) in ids(pm, nw, :buspairs)
                if bounded
                    setupperbound(WR[i, j], wr_max[i_bus, j_bus])
                    setlowerbound(WR[i, j], wr_min[i_bus, j_bus])

                    setupperbound(WI[i, j], wi_max[i_bus, j_bus])
                    setlowerbound(WI[i, j], wi_min[i_bus, j_bus])
                end

                # for non-semidefinite constraints
                if !((i_bus, j_bus) in visited_buspairs)
                    push!(visited_buspairs, (i_bus, j_bus))
                    var(pm, nw, cnd, :wr)[(i_bus, j_bus)] = WR[i, j]
                    var(pm, nw, cnd, :wi)[(i_bus, j_bus)] = WI[i, j]
                end
            end
        end
    end
end


function constraint_voltage(pm::GenericPowerModel{T}, nw::Int, cnd::Int) where T <: SparseSDPWRMForm
    pair_matrix(group) = [(i, j) for i in group, j in group]

    decomp = pm.ext[:SDconstraintDecomposition]
    groups = decomp.decomp
    voltage_product_groups = var(pm, nw, cnd)[:voltage_product_groups]

    # semidefinite constraint for each group in clique grouping
    for (gidx, voltage_product_group) in enumerate(voltage_product_groups)
        group = groups[gidx]
        ng = length(group)
        WR = voltage_product_group[:WR]
        WI = voltage_product_group[:WI]

        # Lower-dimensional SOC constraint equiv. to SDP for 2-vertex
        # clique
        if ng == 2
            wr_ii = WR[1, 1]
            wr_jj = WR[2, 2]
            wr_ij = WR[1, 2]
            wi_ij = WI[1, 2]
            wi_ji = WI[2, 1]

            # standard SOC form (Mosek doesn't like rotated form)
            @constraint(pm.model, (wr_ii + wr_jj) >= norm([(wr_ii - wr_jj); 2*wr_ij; 2*wi_ij]))
            @constraint(pm.model, wi_ij == -wi_ji)
        else
            @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)
        end
    end

    # linking constraints
    tree = prim(overlap_graph(groups))
    overlapping_pairs = [ind2sub(tree, i) for i in find(tree)]
    for (i, j) in overlapping_pairs
        gi, gj = groups[i], groups[j]
        var_i, var_j = voltage_product_groups[i], voltage_product_groups[j]

        Gi, Gj = pair_matrix(gi), pair_matrix(gj)
        overlap_i, overlap_j = overlap_indices(Gi, Gj)
        indices = zip(overlap_i, overlap_j)
        for (idx_i, idx_j) in indices
            @constraint(pm.model, var_i[:WR][idx_i] == var_j[:WR][idx_j])
            @constraint(pm.model, var_i[:WI][idx_i] == var_j[:WI][idx_j])
        end
    end
end


"""
    adj, lookup_index = adjacency_matrix(pm, nw)
Return:
- a sparse adjacency matrix
- `lookup_index` s.t. `lookup_index[bus_id]` returns the integer index
of the bus with `bus_id` in the adjacency matrix.
"""
function adjacency_matrix(pm::GenericPowerModel, nw::Int=pm.cnw)
    bus_ids = ids(pm, nw, :bus)
    buspairs = ref(pm, nw, :buspairs)

    nb = length(bus_ids)
    nl = length(buspairs)

    lookup_index = Dict([(bi, i) for (i, bi) in enumerate(bus_ids)])
    f = [lookup_index[bp[1]] for bp in keys(buspairs)]
    t = [lookup_index[bp[2]] for bp in keys(buspairs)]

    return sparse([f;t], [t;f], trues(2nl), nb, nb), lookup_index
end


"""
    cadj, lookup_index, ordering = chordal_extension(pm, nw)
Return:
- a sparse adjacency matrix corresponding to a chordal extension
of the power grid graph.
- `lookup_index` s.t. `lookup_index[bus_id]` returns the integer index
of the bus with `bus_id` in the adjacency matrix.
- the graph ordering that may be used to reconstruct the chordal extension
"""
function chordal_extension(pm::GenericPowerModel, nw::Int=pm.cnw)
    adj, lookup_index = adjacency_matrix(pm, nw)
    nb = size(adj, 1)
    diag_el = sum(adj, 1)[:]
    W = Hermitian(adj + spdiagm(diag_el, 0))

    F = cholfact(W)
    L, p = sparse(F[:L]), F[:p]
    q = invperm(p)
    Rchol = L - spdiagm(diag(L), 0)
    f_idx, t_idx, V = findnz(Rchol)
    cadj = sparse([f_idx;t_idx], [t_idx;f_idx], trues(2*length(f_idx)), nb, nb)
    cadj = cadj[q, q] # revert to original bus ordering (invert cholfact permutation)
    return cadj, lookup_index, p
end


"""
    mc = maximal_cliques(cadj, peo)
Given a chordal graph adjacency matrix and perfect elimination
ordering, return the set of maximal cliques.
"""
function maximal_cliques(cadj::SparseMatrixCSC, peo::Vector{Int})
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
maximal_cliques(cadj::SparseMatrixCSC) = maximal_cliques(cadj, mcs(cadj))

"""
    peo = mcs(A)
Maximum cardinality search for graph adjacency matrix A.
Returns a perfect elimination ordering for chordal graphs.
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
    T = spzeros(Int64, n, n)

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


function filter_flipped_pairs!(pairs)
    for (i, j) in pairs
        if i != j && (j, i) in pairs
            filter!(x -> x != (j, i), pairs)
        end
    end
end


"""
    idx_a, idx_b = overlap_indices(A, B)
Given two arrays (sizes need not match) that share some values, return:

- linear index of shared values in A
- linear index of shared values in B

Thus, A[idx_a] == B[idx_b].
"""
function overlap_indices(A::Array, B::Array, symmetric=true)
    overlap = intersect(A, B)
    symmetric && filter_flipped_pairs!(overlap)
    idx_a = [findfirst(A, o) for o in overlap]
    idx_b = [findfirst(B, o) for o in overlap]
    return idx_a, idx_b
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
