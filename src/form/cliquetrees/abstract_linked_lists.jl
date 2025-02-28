abstract type AbstractLinkedList{I<:Integer} end

function Base.show(io::IO, ::MIME"text/plain", list::L) where {L<:AbstractLinkedList}
    println(io, "$L:")

    for (i, v) in enumerate(take(list, MAX_ITEMS_PRINTED + 1))
        if i <= MAX_ITEMS_PRINTED
            println(io, " $v")
        else
            println(io, " ⋮")
        end
    end
end

function Base.empty!(list::AbstractLinkedList{I}) where {I}
    list.head[] = zero(I)
    return list
end

function Base.isempty(list::AbstractLinkedList)
    return iszero(list.head[])
end

#######################
# Iteration Interface #
#######################

function Base.iterate(list::AbstractLinkedList{I}, i::I=list.head[]) where {I}
    if !iszero(i)
        @inbounds (i, list.next[i])
    end
end

function Base.IteratorSize(::Type{<:AbstractLinkedList})
    return Base.SizeUnknown()
end

function Base.eltype(::Type{<:AbstractLinkedList{I}}) where {I}
    return I
end
