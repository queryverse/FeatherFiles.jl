module FeatherFiles

using FeatherLib, IteratorInterfaceExtensions, TableTraits, TableTraitsUtils,
    DataValues, FileIO, TableShowUtils, Dates
using FeatherLib: ArrowCompat
import IterableTables

export load, save, File, @format_str

include("missing-conversion.jl")

struct FeatherFile
    filename::String
end

# Displaying a file should not leave it memory mapped. Unlike getiterator, which hands the
# iterator to the caller, the show methods consume every row they need and return, so the
# ResultSet they opened can be closed straight away -- otherwise merely displaying a
# feather file keeps it locked against deletion on Windows until the GC runs.
function withtable(f, source::FeatherFile)
    rs = read_converted(source.filename)
    try
        return f(create_tableiterator(rs.columns, rs.names))
    finally
        close!(rs)
    end
end

function Base.show(io::IO, source::FeatherFile)
    withtable(it -> TableShowUtils.printtable(io, it, "Feather file"), source)
end

function Base.show(io::IO, ::MIME"text/html", source::FeatherFile)
    withtable(it -> TableShowUtils.printHTMLtable(io, it), source)
end

Base.showable(::MIME"text/html", source::FeatherFile) = true

function Base.show(io::IO, ::MIME"application/vnd.dataresource+json", source::FeatherFile)
    withtable(it -> TableShowUtils.printdataresource(io, it), source)
end

Base.showable(::MIME"application/vnd.dataresource+json", source::FeatherFile) = true

function fileio_load(f::FileIO.File{FileIO.format"Feather"})
    return FeatherFile(f.filename)
end

IteratorInterfaceExtensions.isiterable(x::FeatherFile) = true
TableTraits.isiterabletable(x::FeatherFile) = true
# TableTraits.supports_get_columns_view(x::FeatherFile) = true
TableTraits.supports_get_columns_copy_using_missing(x::FeatherFile) = true

# Read a feather file and put its columns into the form the Queryverse surface expects:
# nullable columns as DataValue, and the Arrow date/time wire types as Date/DateTime/Time.
function read_converted(filename::AbstractString)
    rs = featherread(filename)

    for i=1:length(rs.columns)
        col_eltype = eltype(rs.columns[i])
        # Julia does not order the members of a Union predictably, so pick the
        # non-Missing half by name rather than assuming it is the second field. It is
        # `.a` for Union{Datestamp,Missing}, which is why date columns were previously
        # left unwrapped.
        if isa(col_eltype, Union) && Missing <: col_eltype
            J = Base.nonmissingtype(col_eltype)
            T = DataValueArrowVector{J,typeof(rs.columns[i])}
            rs.columns[i] = T(rs.columns[i])
        end
        rs.columns[i] = converttimes(rs.columns[i])
    end

    return rs
end

function IteratorInterfaceExtensions.getiterator(file::FeatherFile)
    rs = read_converted(file.filename)

    # No close! here: the columns are read lazily, so the iterator needs the file to stay
    # mapped for as long as it is alive. Callers who want the file released should use
    # get_columns_copy_using_missing, which copies and then closes.
    return create_tableiterator(rs.columns, rs.names)
end

# function TableTraits.get_columns_view(file::FeatherFile)
#     rs = featherread(file.filename)

#     for i=1:length(rs.columns)
#         col_eltype = eltype(rs.columns[i])
#         if isa(col_eltype, Union) && col_eltype.b <: Missing
#             T = DataValueArrowVector{col_eltype.a,typeof(rs.columns[i])}
#             rs.columns[i] = T(rs.columns[i])
#         end
#     end

#     T = eval(:(@NT($(Symbol.(rs.names)...)))){typeof.(rs.columns)...}

#     return T(rs.columns...)
# end

function TableTraits.get_columns_copy_using_missing(file::FeatherFile)
    rs = featherread(file.filename)
    try
        columns = [converttimes(c) for c in rs.columns]
        return NamedTuple{(Symbol.(rs.names)...,)}(((convert(Vector{eltype(c)}, c) for c in columns)...,))
    finally
        # Every column has been copied out, so the mapping can go. Without this the file
        # stays locked against deletion on Windows until the ResultSet is collected.
        close!(rs)
    end
end

function fileio_save(f::FileIO.File{FileIO.format"Feather"}, data)
    isiterabletable(data) || error("Can't write this data to a Feather file.")

    columns, colnames = create_columns_from_iterabletable(data)

    columns = Any[c for c in columns]

    for i=1:length(columns)
        if eltype(columns[i]) <: DataValue
            T = MissingDataValueVector{eltype(eltype(columns[i])),typeof(columns[i])}
            columns[i] = T(columns[i])
        end
    end

    featherwrite(f.filename, columns, colnames)
end

end # module
