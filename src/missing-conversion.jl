struct DataValueArrowVector{J}
    data::Arrow.ArrowVector{Union{J,Missing}}
end

Base.size(A::DataValueArrowVector) = size(A.data)

@inline function Base.getindex(A::DataValueArrowVector{Union{J,Missing}}) where J
    @boundscheck checkbounds(A, i)
    @inbounds o = Arrow.unsafe_isnull(A, i) ? DataValue{J}() : DataValue{J}(unsafe_getvalue(A, i))
    o    
end

Base.IndexStyle(::Type{<:DataValueArrowVector}) = IndexLinear()

Base.eltype(::Type{DataValueArrowVector{J}}) where J = DataValue{J}
