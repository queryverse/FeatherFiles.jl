module FeatherFiles

using Feather, IterableTables, DataValues, DataTables
import FileIO

struct FeatherFile
    filename::String
end

function load(f::FileIO.File{FileIO.format"Feather"})
    return FeatherFile(f.filename)
end

IterableTables.isiterable(x::FeatherFile) = true
IterableTables.isiterabletable(x::FeatherFile) = true

function IterableTables.getiterator(file::FeatherFile)
    dt = Feather.read(file.filename, DataTable)

    it = getiterator(dt)

    return it
end

function save(f::FileIO.File{FileIO.format"Feather"}, data)
    isiterabletable(data) || error("Can't write this data to a Feather file.")

    it = getiterator(data)

    ds = IterableTables.get_datastreams_source(it)
    try
        Feather.write(f.filename, ds)
    finally
        Data.close!(ds)
    end
end


end # module
