using FeatherFiles
using DataValues
using IteratorInterfaceExtensions
using TableTraits
using Test

@testset "FeatherFiles" begin

source = [(Name="John", Age=34., Children=2),
    (Name="Sally", Age=54., Children=1),
    (Name="Jim", Age=34., Children=0)]

output_filename = tempname() * ".feather"

source |> save(output_filename)

try
    sink = load(output_filename) |> IteratorInterfaceExtensions.getiterator |> collect

    @test source == sink

    featherfile = load(output_filename)

    @test IteratorInterfaceExtensions.isiterable(featherfile) == true
    @test TableTraits.supports_get_columns_copy_using_missing(featherfile) == true
    ff_as_cols = TableTraits.get_columns_copy_using_missing(featherfile)
    @test ff_as_cols == (Name=["John", "Sally", "Jim"], Age=[34., 54., 34.], Children=[2,1,0])
finally
    GC.gc()
    GC.gc()
    # rm(output_filename)
end

source2 = [(Name=DataValue("John"), Age=DataValue(34.), Children=DataValue{Int}()),
    (Name=DataValue("Sally"), Age=DataValue{Float64}(), Children=DataValue(1)),
    (Name=DataValue{String}(), Age=DataValue(34.), Children=DataValue(0))]

output_filename2 = tempname() * ".feather"

source2 |> save(output_filename2)

try
    sink2 = load(output_filename2) |> IteratorInterfaceExtensions.getiterator |> collect

    @test source2 == sink2

    featherfile = load(output_filename2)
    @test IteratorInterfaceExtensions.isiterable(featherfile) == true
    @test TableTraits.supports_get_columns_copy_using_missing(featherfile) == true
    ff_as_cols = TableTraits.get_columns_copy_using_missing(featherfile)
    @test isequal(ff_as_cols, (Name=["John", "Sally", missing], Age=[34., missing, 34.], Children=[missing,1,0]))
finally
    GC.gc()
    GC.gc()
    # rm(output_filename2)
end

ar = load(output_filename2)

@test sprint((stream,data)->show(stream, "text/html", data), ar) == "<table><thead><tr><th>Name</th><th>Age</th><th>Children</th></tr></thead><tbody><tr><td>&quot;John&quot;</td><td>34.0</td><td>#NA</td></tr><tr><td>&quot;Sally&quot;</td><td>#NA</td><td>1</td></tr><tr><td>#NA</td><td>34.0</td><td>0</td></tr></tbody></table>"
@test sprint((stream,data)->show(stream, "application/vnd.dataresource+json", data), ar) == "{\"schema\":{\"fields\":[{\"name\":\"Name\",\"type\":\"string\"},{\"name\":\"Age\",\"type\":\"number\"},{\"name\":\"Children\",\"type\":\"integer\"}]},\"data\":[{\"Name\":\"John\",\"Age\":34.0,\"Children\":null},{\"Name\":\"Sally\",\"Age\":null,\"Children\":1},{\"Name\":null,\"Age\":34.0,\"Children\":0}]}"
@test sprint(show, ar) == "3x3 Feather file\nName    │ Age  │ Children\n────────┼──────┼─────────\n\"John\"  │ 34.0 │ #NA     \n\"Sally\" │ #NA  │ 1       \n#NA     │ 34.0 │ 0       "
@test showable("text/html", ar) == true
@test showable("application/vnd.dataresource+json", ar) == true

end
