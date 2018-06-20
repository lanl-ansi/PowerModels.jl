export MultiPhaseValue, MultiPhaseVector, MultiPhaseMatrix, phases


"a data structure for working with multiphase datasets"
abstract type MultiPhaseValue{T} end


"a data structure for working with multiphase datasets"
mutable struct MultiPhaseVector{T} <: MultiPhaseValue{T}
    values::Vector{T}
end


MultiPhaseVector(value::T, phases::Int) where T = MultiPhaseVector([value for i in 1:phases])
Base.map(f, a::MultiPhaseVector{T}) where T = MultiPhaseVector{T}(map(f, a.values))
Base.map(f, a::MultiPhaseVector{T}, b::MultiPhaseVector{T}) where T = MultiPhaseVector{T}(map(f, a.values, b.values))
phases(mpv::MultiPhaseVector) = length(mpv.values)


""
function Base.setindex!(mpv::MultiPhaseVector{T}, v::T, i::Int) where T
    mpv.values[i] = v
end


""
mutable struct MultiPhaseMatrix{T} <: MultiPhaseValue{T}
    values::Matrix{T}
end


MultiPhaseMatrix(value::T, phases::Int) where T = MultiPhaseMatrix(value*eye(phases))
Base.map(f, a::MultiPhaseMatrix{T}) where T = MultiPhaseMatrix{T}(map(f, a.values))
Base.map(f, a::MultiPhaseMatrix{T}, b::MultiPhaseMatrix{T}) where T = MultiPhaseMatrix{T}(map(f, a.values, b.values))
phases(mpv::MultiPhaseMatrix) = size(mpv.values, 1)


""
function Base.setindex!(mpv::MultiPhaseMatrix{T}, v::T, i::Int, j::Int) where T
    mpv.values[i,j] = v
end


Base.start(mpv::MultiPhaseValue) = start(mpv.values)
Base.next(mpv::MultiPhaseValue, state) = next(mpv.values, state)
Base.done(mpv::MultiPhaseValue, state) = done(mpv.values, state)

Base.length(mpv::MultiPhaseValue) = length(mpv.values)
Base.size(mpv::MultiPhaseValue, a...) = size(mpv.values, a...)
Base.getindex(mpv::MultiPhaseValue, args...) = mpv.values[args...]

Base.show(io::IO, mpv::MultiPhaseValue) = Base.show(io, mpv.values)

Base.broadcast(f::Any, a, b::MultiPhaseValue) = broadcast(f, a, b.values)
Base.broadcast(f::Any, a::MultiPhaseValue, b) = broadcast(f, a.values, b)
Base.broadcast(f::Any, a::MultiPhaseValue, b::MultiPhaseValue) = broadcast(f, a.values, b.values)

Base.:+(a::MultiPhaseVector{T}, b...) where T = MultiPhaseVector{T}(+(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:-(a::MultiPhaseVector{T}, b...) where T = MultiPhaseVector{T}(-(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:*(a::MultiPhaseVector{T}, b...) where T = MultiPhaseVector{T}(*(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:/(a::MultiPhaseVector{T}, b...) where T = MultiPhaseVector{T}(/(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:*(a::Real, b::MultiPhaseVector{T}) where T = MultiPhaseVector{T}(Base.broadcast(*, a, b.values))
Base.:/(a::Real, b::MultiPhaseVector{T}) where T = MultiPhaseVector{T}(Base.broadcast(/, a, b.values))

Base.:+(a::MultiPhaseMatrix{T}, b...) where T = MultiPhaseMatrix{T}(+(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:-(a::MultiPhaseMatrix{T}, b...) where T = MultiPhaseMatrix{T}(-(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:*(a::MultiPhaseMatrix{T}, b...) where T = MultiPhaseMatrix{T}(*(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))
Base.:/(a::MultiPhaseMatrix{T}, b...) where T = MultiPhaseMatrix{T}(/(a.values, (isa(i, MultiPhaseValue) ? i.values : i for i in [b...])...))

Base.:*(a::MultiPhaseMatrix{T}, b::MultiPhaseVector) where T = MultiPhaseVector{T}(*(a.values, b.values))
Base.:/(a::MultiPhaseMatrix{T}, b::MultiPhaseVector) where T = MultiPhaseVector{T}(*(a.values, b.values))

Base.:^(a::MultiPhaseVector{T}, b::Integer) where T = MultiPhaseVector{T}(a.values .^ b)
Base.:^(a::MultiPhaseMatrix{T}, b::Integer) where T = MultiPhaseMatrix{T}(a.values ^ b)

Base.:^(a::MultiPhaseVector{T}, b::AbstractFloat) where T = MultiPhaseVector{T}(a.values .^ b)
Base.:^(a::MultiPhaseMatrix{T}, b::AbstractFloat) where T = MultiPhaseMatrix{T}(a.values ^ b)

Base.transpose(a::MultiPhaseVector) = a.values'
Base.transpose(a::MultiPhaseMatrix{T}) where T = MultiPhaseMatrix{T}(a.values')

Base.diagm(a::MultiPhaseVector{T}) where T = MultiPhaseMatrix{T}(diagm(a.values))

Base.rad2deg(a::MultiPhaseVector{T}) where T = MultiPhaseVector{T}(map(rad2deg, a.values))
Base.rad2deg(a::MultiPhaseMatrix{T}) where T = MultiPhaseMatrix{T}(map(rad2deg, a.values))

Base.deg2rad(a::MultiPhaseVector{T}) where T = MultiPhaseVector{T}(map(deg2rad, a.values))
Base.deg2rad(a::MultiPhaseMatrix{T}) where T = MultiPhaseMatrix{T}(map(deg2rad, a.values))

JSON.lower(mpv::MultiPhaseValue) = mpv.values


"converts a MultiPhaseValue value to a string in summary"
function InfrastructureModels._value2string(mpv::MultiPhaseValue, float_precision::Int)
    a = join([InfrastructureModels._value2string(v, float_precision) for v in mpv.values], ", ")
    return "[$(a)]"
end


""
function Base.isapprox(a::MultiPhaseValue, b::MultiPhaseValue; kwargs...)
    if length(a) == length(b)
        return all( isapprox(a[i], b[i]) for i in 1:length(a); kwargs...)
    end
    return false
end


getmpv(value::Any, phase::Int) = value
getmpv(value::Any, phase_i::Int, phase_j::Int) = value
getmpv(value::MultiPhaseVector, phase::Int) = value[phase]
getmpv(value::MultiPhaseMatrix{T}, phase::Int) where T = MultiPhaseVector{T}(value[phase])
getmpv(value::MultiPhaseMatrix, phase_i::Int, phase_j::Int) = value[phase_i, phase_j]
