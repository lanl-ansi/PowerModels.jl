"""
    EliminationAlgorithm

A graph elimination algorithm. The options are

| type             | name                                         | time     | space    |
|:---------------- |:-------------------------------------------- |:-------- |:-------- |
| [`MCS`](@ref)    | maximum cardinality search                   | O(m + n) | O(n)     |
"""
abstract type EliminationAlgorithm end

"""
    MCS <: EliminationAlgorithm

    MCS()

The maximum cardinality search algorithm.

### Reference

Tarjan, Robert E., and Mihalis Yannakakis. "Simple linear-time algorithms to test chordality of graphs, test acyclicity of hypergraphs, and selectively reduce acyclic hypergraphs." *SIAM Journal on Computing* 13.3 (1984): 566-579.
"""
struct MCS <: EliminationAlgorithm end

function permutation(matrix, alg::MCS)
    index, card = mcs(matrix)
    return invperm(index), index
end

"""
    mcs(matrix[, clique::AbstractVector])

Perform a maximum cardinality search, optionally specifying a clique to be ordered last.
Returns the inverse permutation.
"""
function mcs(matrix::SparseMatrixCSC{<:Any, V}) where V
    mcs(matrix, oneto(zero(V)))
end

# Simple Linear-Time Algorithms to Test Chordality of BipartiteGraphs, Test Acyclicity of Hypergraphs, and Selectively Reduce Acyclic Hypergraphs
# Tarjan and Yannakakis
# Maximum Cardinality Search
#
# Construct a fill-reducing permutation of a graph.
# The complexity is O(m + n), where m = |E| and n = |V|.
function mcs(matrix::SparseMatrixCSC{<:Any, V}, clique::AbstractVector) where {V}
    n = convert(V, size(matrix, 2))

    # construct disjoint sets data structure
    head = zeros(V, n + one(V))
    prev = Vector{V}(undef, n + one(V))
    next = Vector{V}(undef, n + one(V))

    function set(i)
        @inbounds DoublyLinkedList(view(head, i), prev, next)
    end

    # run algorithm
    alpha = Vector{V}(undef, n)
    card = ones(V, n)
    prepend!(set(one(V)), oneto(n))

    j = one(V)
    k = convert(V, lastindex(clique))

    @inbounds for i in reverse(oneto(n))
        v = zero(V)

        if k in eachindex(clique)
            v = convert(V, clique[k])
            k -= one(V)
            delete!(set(j), v)
        else
            v = popfirst!(set(j))
        end

        alpha[v] = i
        card[v] = one(V) - card[v]

        for w in @view rowvals(matrix)[nzrange(matrix, v)]
            if card[w] >= one(V)
                delete!(set(card[w]), w)
                card[w] += one(V)
                pushfirst!(set(card[w]), w)
            end
        end

        j += one(V)

        while j >= one(V) && isempty(set(j))
            j -= one(V)
        end
    end

    return alpha, card
end
