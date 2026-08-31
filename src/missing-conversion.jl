struct DataValueArrowVector{J,T<:ArrowCompat.ArrowVector{Union{J,Missing}}} <: AbstractVector{DataValue{J}}
    data::T
end

Base.size(A::DataValueArrowVector) = size(A.data)

@inline function Base.getindex(A::DataValueArrowVector{J,T}, i) where {J,T}
    @boundscheck checkbounds(A.data, i)
    @inbounds o = ArrowCompat.unsafe_isnull(A.data, i) ? DataValue{J}() : DataValue{J}(ArrowCompat.unsafe_getvalue(A.data, i))
    o    
end

@inline function Base.getindex(A::DataValueArrowVector{J,T}, i) where {J,T<:ArrowCompat.DictEncoding{Union{Missing,J}}}
    @boundscheck checkbounds(A.data, i)
    @inbounds o = ArrowCompat.unsafe_isnull(A.data, i) ? DataValue{J}() : DataValue{J}(A.data.pool[A.data.refs[i]+1])
    o    
end

Base.IndexStyle(::Type{<:DataValueArrowVector}) = IndexLinear()

Base.eltype(::Type{DataValueArrowVector{J,T}}) where {J,T} = DataValue{J}

struct MissingDataValueVector{J,T<:AbstractVector{DataValue{J}}} <: AbstractVector{Union{J,Missing}}
    data::T
end

Base.size(A::MissingDataValueVector) = size(A.data)

@inline function Base.getindex(A::MissingDataValueVector, i)
    @inbounds o = isna(A.data[i]) ? missing : get(A.data[i])
    o    
end

Base.IndexStyle(::Type{<:MissingDataValueVector}) = IndexLinear()

Base.eltype(::Type{MissingDataValueVector{J,T}}) where {J,T} = Union{J,Missing}

# Feather stores dates and times as the Arrow wire types Datestamp, Timestamp and
# TimeOfDay. Those are an implementation detail of the file layout, so unwrap them into
# the Julia types users expect rather than handing out FeatherLib internals. FeatherLib
# itself deliberately keeps the raw types -- it is a faithful low-level mirror of the file.
const ARROW_TIME_TYPES = Union{ArrowCompat.Datestamp,ArrowCompat.Timestamp,ArrowCompat.TimeOfDay}

juliatimetype(::Type{<:ArrowCompat.Datestamp}) = Dates.Date
juliatimetype(::Type{<:ArrowCompat.Timestamp}) = Dates.DateTime
juliatimetype(::Type{<:ArrowCompat.TimeOfDay}) = Dates.Time

struct TimeConversionVector{J,T<:AbstractVector} <: AbstractVector{J}
    data::T
end

Base.size(A::TimeConversionVector) = size(A.data)
Base.IndexStyle(::Type{<:TimeConversionVector}) = IndexLinear()
Base.eltype(::Type{TimeConversionVector{J,T}}) where {J,T} = J

@inline function Base.getindex(A::TimeConversionVector{J}, i) where {J}
    @inbounds v = A.data[i]
    return convert(J, v)
end

@inline function Base.getindex(A::TimeConversionVector{DataValue{J}}, i) where {J}
    @inbounds v = A.data[i]
    return isna(v) ? DataValue{J}() : DataValue{J}(convert(J, get(v)))
end

@inline function Base.getindex(A::TimeConversionVector{Union{J,Missing}}, i) where {J}
    @inbounds v = A.data[i]
    return ismissing(v) ? missing : convert(J, v)
end

# Wrap `col` so that it yields Julia date/time values, or return it untouched when it holds
# no Arrow time type. Handles the DataValue-wrapped nullable columns too.
converttimes(col::AbstractVector) = col
function converttimes(col::AbstractVector{T}) where {T<:ARROW_TIME_TYPES}
    J = juliatimetype(T)
    return TimeConversionVector{J,typeof(col)}(col)
end
function converttimes(col::AbstractVector{DataValue{T}}) where {T<:ARROW_TIME_TYPES}
    J = juliatimetype(T)
    return TimeConversionVector{DataValue{J},typeof(col)}(col)
end
# get_columns_copy_using_missing works on the raw columns, which represent nulls with
# Missing rather than DataValue.
function converttimes(col::AbstractVector{Union{T,Missing}}) where {T<:ARROW_TIME_TYPES}
    J = juliatimetype(T)
    return TimeConversionVector{Union{J,Missing},typeof(col)}(col)
end
