import LinearAlgebra: I, diagm


export MultiConductorValue, MultiConductorVector, MultiConductorMatrix, conductors

# "a data structure for working with multiconductor datasets"
abstract type MultiConductorValue{T,N} <: AbstractArray{T,N} end


"a data structure for working with multiconductor datasets"
mutable struct MultiConductorVector{T} <: MultiConductorValue{T,1}
    values::Vector{T}
end

MultiConductorVector(value::T, conductors::Int) where T = MultiConductorVector([value for i in 1:conductors])
Base.map(f, a::MultiConductorVector{T}) where T = MultiConductorVector{T}(map(f, a.values))
Base.map(f, a::MultiConductorVector{T}, b::MultiConductorVector{T}) where T = MultiConductorVector{T}(map(f, a.values, b.values))
conductors(mcv::MultiConductorVector) = length(mcv.values)

MultiConductorVector(value::Array{T,2}) where T = MultiConductorMatrix{T}(value)


""
function Base.setindex!(mcv::MultiConductorVector{T}, v::T, i::Int) where T
    mcv.values[i] = v
end



""
mutable struct MultiConductorMatrix{T} <: MultiConductorValue{T,2}
    values::Matrix{T}
end


MultiConductorMatrix(value::T, conductors::Int) where T = MultiConductorMatrix(value*Matrix{Float64}(I, conductors, conductors))
Base.map(f, a::MultiConductorMatrix{T}) where T = MultiConductorMatrix{T}(map(f, a.values))
Base.map(f, a::MultiConductorMatrix{T}, b::MultiConductorMatrix{T}) where T = MultiConductorMatrix{T}(map(f, a.values, b.values))
conductors(mcv::MultiConductorMatrix) = size(mcv.values, 1)

""
function Base.setindex!(mcv::MultiConductorMatrix{T}, v::T, i::Int, j::Int) where T
    mcv.values[i,j] = v
end

iterate(mcv::MultiConductorValue, kwargs...) = iterate(mcv.values, kwargs...)

Base.length(mcv::MultiConductorValue) = length(mcv.values)
Base.size(mcv::MultiConductorValue, a...) = size(mcv.values, a...)
Base.getindex(mcv::MultiConductorValue, args...) = mcv.values[args...]

Base.show(io::IO, mcv::MultiConductorValue) = Base.show(io, mcv.values)

Base.broadcast(f::Any, a::Any, b::MultiConductorValue) = broadcast(f, a, b.values)
Base.broadcast(f::Any, a::MultiConductorValue, b::Any) = broadcast(f, a.values, b)
Base.broadcast(f::Any, a::MultiConductorValue, b::MultiConductorValue) = broadcast(f, a.values, b.values)

Base.BroadcastStyle(::Type{<:MultiConductorVector}) = Broadcast.ArrayStyle{MultiConductorVector}()
Base.BroadcastStyle(::Type{<:MultiConductorMatrix}) = Broadcast.ArrayStyle{MultiConductorMatrix}()


function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{MultiConductorVector}}, ::Type{ElType}) where ElType
    A = find_mcv(bc)
    return MultiConductorVector(similar(Array{ElType}, axes(bc)))
end

"`A = find_mcv(As)` returns the first MultiConductorVector among the arguments."
find_mcv(bc::Base.Broadcast.Broadcasted) = find_mcv(bc.args)
find_mcv(args::Base.Broadcast.Extruded) = find_mcv(args.x)
find_mcv(args::Tuple) = find_mcv(find_mcv(args[1]), Base.tail(args))
find_mcv(x) = x
find_mcv(a::MultiConductorVector, rest) = a
find_mcv(::Any, rest) = find_mcv(rest)


function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{MultiConductorMatrix}}, ::Type{ElType}) where ElType
    A = find_mcm(bc)
    return MultiConductorMatrix(similar(Array{ElType}, axes(bc)))
end

"`A = find_mcm(As)` returns the first MultiConductorMatrix among the arguments."
find_mcm(bc::Base.Broadcast.Broadcasted) = find_mcm(bc.args)
find_mcm(args::Base.Broadcast.Extruded) = find_mcm(args.x)
find_mcm(args::Tuple) = find_mcm(find_mcm(args[1]), Base.tail(args))
find_mcm(x) = x
find_mcm(a::MultiConductorMatrix, rest) = a
find_mcm(::Any, rest) = find_mcm(rest)


# Vectors
Base.:+(a::MultiConductorVector) = MultiConductorVector(+(a.values))
Base.:+(a::MultiConductorVector, b::Union{Array,Number}) = MultiConductorVector(+(a.values, b))
Base.:+(a::Union{Array,Number}, b::MultiConductorVector) = MultiConductorVector(+(a, b.values))
Base.:+(a::MultiConductorVector, b::MultiConductorVector) = MultiConductorVector(+(a.values, b.values))

Base.:-(a::MultiConductorVector) = MultiConductorVector(-(a.values))
Base.:-(a::MultiConductorVector, b::Union{Array,Number}) = MultiConductorVector(-(a.values, b))
Base.:-(a::Union{Array,Number}, b::MultiConductorVector) = MultiConductorVector(-(a, b.values))
Base.:-(a::MultiConductorVector, b::MultiConductorVector) = MultiConductorVector(-(a.values, b.values))

Base.:*(a::Number, b::MultiConductorVector) = MultiConductorVector(*(a, b.values))
Base.:*(a::MultiConductorVector, b::Number) = MultiConductorVector(*(a.values, b))
Base.:*(a::Array, b::MultiConductorVector) = MultiConductorVector(Base.broadcast(*, a, b.values))
Base.:*(a::MultiConductorVector, b::Array) = MultiConductorVector(Base.broadcast(*, a.values, b))
Base.:*(a::MultiConductorVector, b::MultiConductorVector) = MultiConductorVector(Base.broadcast(*, a.values, b.values))

Base.:/(a::MultiConductorVector, b::Number) = MultiConductorVector(/(a.values, b))
Base.:/(a::Union{Array,Number}, b::MultiConductorVector) = MultiConductorVector(Base.broadcast(/, a, b.values))
Base.:/(a::MultiConductorVector, b::MultiConductorVector) = MultiConductorVector(Base.broadcast(/, a.values, b.values))

Base.:*(a::MultiConductorVector, b::LinearAlgebra.Adjoint) = MultiConductorMatrix(Base.broadcast(*, a.values, b))
Base.:*(a::LinearAlgebra.Adjoint, b::MultiConductorVector) = MultiConductorMatrix(Base.broadcast(*, a, b.values))


# Matrices
Base.:+(a::MultiConductorMatrix) = MultiConductorMatrix(+(a.values))
Base.:+(a::MultiConductorMatrix, b::Union{Array,Number}) = MultiConductorMatrix(+(a.values, b))
Base.:+(a::Union{Array,Number}, b::MultiConductorMatrix) = MultiConductorMatrix(+(a, b.values))
Base.:+(a::MultiConductorMatrix, b::MultiConductorMatrix) = MultiConductorMatrix(+(a.values, b.values))

Base.:-(a::MultiConductorMatrix) = MultiConductorMatrix(-(a.values))
Base.:-(a::MultiConductorMatrix, b::Union{Array,Number}) = MultiConductorMatrix(-(a.values, b))
Base.:-(a::Union{Array,Number}, b::MultiConductorMatrix) = MultiConductorMatrix(-(a, b.values))
Base.:-(a::MultiConductorMatrix, b::MultiConductorMatrix) = MultiConductorMatrix(-(a.values, b.values))

Base.:*(a::MultiConductorMatrix, b::Number) = MultiConductorMatrix(*(a.values, b))
Base.:*(a::Number, b::MultiConductorMatrix) = MultiConductorMatrix(*(a, b.values))
Base.:*(a::MultiConductorMatrix, b::Array) = MultiConductorMatrix(*(a.values, b))
Base.:*(a::Array, b::MultiConductorMatrix) = MultiConductorMatrix(*(a, b.values))
Base.:*(a::MultiConductorMatrix, b::MultiConductorMatrix) = MultiConductorMatrix(*(a.values, b.values))

Base.:/(a::MultiConductorMatrix, b::Union{Array,Number}) = MultiConductorMatrix(/(a.values, b))
Base.:/(a::Union{Array,Number}, b::MultiConductorMatrix) = MultiConductorMatrix(/(a, b.values))
Base.:/(a::MultiConductorMatrix, b::MultiConductorMatrix) = MultiConductorMatrix(/(a.values, b.values))

Base.:*(a::MultiConductorMatrix, b::MultiConductorVector) = MultiConductorVector(*(a.values, b.values))

Base.:/(a::MultiConductorMatrix, b::LinearAlgebra.Adjoint) = MultiConductorVector(squeeze(/(a.values, b), 2))

Base.:^(a::MultiConductorVector, b::Complex) = MultiConductorVector(Base.broadcast(^, a.values, b))
Base.:^(a::MultiConductorVector, b::Integer) = MultiConductorVector(Base.broadcast(^, a.values, b))
Base.:^(a::MultiConductorVector, b::AbstractFloat) = MultiConductorVector(Base.broadcast(^, a.values, b))
Base.:^(a::MultiConductorMatrix, b::Complex) = MultiConductorMatrix(a.values ^ b)
Base.:^(a::MultiConductorMatrix, b::Integer) = MultiConductorMatrix(a.values ^ b)
Base.:^(a::MultiConductorMatrix, b::AbstractFloat) = MultiConductorMatrix(a.values ^ b)


LinearAlgebra.inv(a::MultiConductorMatrix) = MultiConductorMatrix(inv(a.values))
LinearAlgebra.pinv(a::MultiConductorMatrix) = MultiConductorMatrix(pinv(a.values))

Base.real(a::MultiConductorVector) = MultiConductorVector(real(a.values))
Base.real(a::MultiConductorMatrix) = MultiConductorMatrix(real(a.values))
Base.imag(a::MultiConductorVector) = MultiConductorVector(imag(a.values))
Base.imag(a::MultiConductorMatrix) = MultiConductorMatrix(imag(a.values))

LinearAlgebra.transpose(a::MultiConductorVector) = a.values'
LinearAlgebra.transpose(a::MultiConductorMatrix) = MultiConductorMatrix(a.values')

LinearAlgebra.diag(a::MultiConductorMatrix) = MultiConductorVector(diag(a.values))
LinearAlgebra.diagm(p::Pair{<:Integer, MultiConductorVector{S}}) where S = MultiConductorMatrix(diagm(p.first => p.second.values))

Base.rad2deg(a::MultiConductorVector) = MultiConductorVector(map(rad2deg, a.values))
Base.rad2deg(a::MultiConductorMatrix) = MultiConductorMatrix(map(rad2deg, a.values))

Base.deg2rad(a::MultiConductorVector) = MultiConductorVector(map(deg2rad, a.values))
Base.deg2rad(a::MultiConductorMatrix) = MultiConductorMatrix(map(deg2rad, a.values))

JSON.lower(mcv::PowerModels.MultiConductorValue) = Dict("values"=>mcv.values, "type"=>string(typeof(mcv)))
function JSON.show_json(io::JSON.StructuralContext, s::JSON.CommonSerialization, p::PowerModels.MultiConductorValue)
    a = Dict("values"=>p.values, "type"=>string(typeof(p)))
    JSON.begin_object(io)
    for kv in a
        JSON.show_pair(io, s, kv)
    end
    JSON.end_object(io)
end

"converts a MultiConductorValue value to a string in summary"
function InfrastructureModels._value2string(mcv::MultiConductorValue, float_precision::Int)
    a = join([InfrastructureModels._value2string(v, float_precision) for v in mcv.values], ", ")
    return "[$(a)]"
end


""
function Base.isapprox(a::MultiConductorValue, b::MultiConductorValue; kwargs...)
    if length(a) == length(b)
        return all( isapprox(a[i], b[i]; kwargs...) for i in 1:length(a))
    end
    return false
end


getmcv(value::Any, conductor::Int) = value
getmcv(value::Any, conductor_i::Int, conductor_j::Int) = value
getmcv(value::MultiConductorVector, conductor::Int) = value[conductor]
getmcv(value::MultiConductorMatrix{T}, conductor::Int) where T = MultiConductorVector{T}(value[conductor])
getmcv(value::MultiConductorMatrix, conductor_i::Int, conductor_j::Int) = value[conductor_i, conductor_j]
