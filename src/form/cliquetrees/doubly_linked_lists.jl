# A doubly linked list of distinct natural numbers.
struct DoublyLinkedList{
    I,Init<:AbstractScalar{I},Prev<:AbstractVector{I},Next<:AbstractVector{I}
} <: AbstractLinkedList{I}
    head::Init
    prev::Prev
    next::Next
end

function DoublyLinkedList{I}(n::Integer) where {I}
    head = fill(zero(I))
    prev = Vector{I}(undef, n)
    next = Vector{I}(undef, n)
    return DoublyLinkedList(head, prev, next)
end

function DoublyLinkedList{I}(vector::AbstractVector) where {I}
    list = DoublyLinkedList{I}(length(vector))
    return prepend!(list, vector)
end

function DoublyLinkedList(vector::AbstractVector{I}) where {I}
    return DoublyLinkedList{I}(vector)
end

@propagate_inbounds function Base.pushfirst!(list::DoublyLinkedList, i::Integer)
    @boundscheck checkbounds(list.prev, i)
    @boundscheck checkbounds(list.next, i)

    @inbounds begin
        n = list.next[i] = list.head[]
        list.head[] = i
        list.prev[i] = 0

        if !iszero(n)
            list.prev[n] = i
        end
    end

    return list
end

@propagate_inbounds function Base.popfirst!(list::DoublyLinkedList)
    i = list.head[]
    @boundscheck checkbounds(list.next, i)

    @inbounds begin
        n = list.head[] = list.next[i]

        if !iszero(n)
            list.prev[n] = 0
        end
    end

    return i
end

@propagate_inbounds function Base.delete!(list::DoublyLinkedList, i::Integer)
    @boundscheck checkbounds(list.prev, i)
    @boundscheck checkbounds(list.next, i)

    @inbounds begin
        p = list.prev[i]
        n = list.next[i]

        if !iszero(p)
            list.next[p] = n
        else
            list.head[] = n
        end

        if !iszero(n)
            list.prev[n] = p
        end
    end

    return list
end

function Base.prepend!(list::DoublyLinkedList, vector::AbstractVector)
    @views list.next[vector[begin:(end - 1)]] = vector[(begin + 1):end]
    @views list.prev[vector[(begin + 1):end]] = vector[begin:(end - 1)]

    if !isempty(vector)
        list.next[vector[end]] = list.head[]
        list.prev[vector[begin]] = 0
        list.head[] = vector[begin]
    end

    return list
end
