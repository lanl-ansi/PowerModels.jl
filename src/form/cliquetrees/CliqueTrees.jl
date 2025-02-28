module CliqueTrees

using Base: oneto, @propagate_inbounds
using SparseArrays

const AbstractScalar{T} = AbstractArray{T,0}
const Scalar{T} = Array{T,0}
const MAX_ITEMS_PRINTED = 5

export permutation, MCS

include("./abstract_linked_lists.jl")
include("./doubly_linked_lists.jl")
include("./elimination_algorithms.jl")

end
