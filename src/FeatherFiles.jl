module FeatherFiles

using FeatherLib, IteratorInterfaceExtensions, TableTraits, TableTraitsUtils,
    DataValues, NamedTuples, Arrow, Missings
import IterableTables, FileIO

struct FeatherFile
    filename::String
end

function load(f::FileIO.File{FileIO.format"Feather"})
    return FeatherFile(f.filename)
end

IteratorInterfaceExtensions.isiterable(x::FeatherFile) = true
TableTraits.isiterabletable(x::FeatherFile) = true
TableTraits.supports_get_columns_view(x::FeatherFile) = true

function IteratorInterfaceExtensions.getiterator(file::FeatherFile)
    rs = featherread(file.filename)

    it = create_tableiterator(rs.columns, rs.names)

    return it
end

function get_columns_view(file::FeatherFile)
    rs = featherread(file.filename)

    T = eval(:(@NT($(Symbol.(rs.names)...)))){typeof.(rs.columns)...}

    return T(rs.columns)
end

function save(f::FileIO.File{FileIO.format"Feather"}, data)
    isiterabletable(data) || error("Can't write this data to a Feather file.")

    columns, colnames = create_columns_from_iterabletable(data)

    featherwrite(f.filename, columns, colnames)
end

end # module
