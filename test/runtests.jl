using FeatherFiles
using DataValues
using IteratorInterfaceExtensions
using TableTraits
using Test
using Arrow
using QueryTables

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
    @test TableTraits.isiterabletable(featherfile) == true
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

source3 = DataTable(a=[1,2,NA], b=[3,4,5])

output_filename3 = tempname() * ".feather"

source3 |> save(output_filename3)

ar = load(output_filename3)

@test sprint(show, ar) == "3x2 Feather file\na   │ b\n────┼──\n1   │ 3\n2   │ 4\n#NA │ 5"

end

@testset "Missing Conversion" begin

v1 = FeatherFiles.DataValueArrowVector(NullablePrimitive([2.0, missing, 5.0, 7.0]))
@test getindex(v1, 3) == DataValue{Float64}(5.0)
@test getindex(v1, 2) == DataValue{Float64}()
@test size(v1) == size(v1.data)
@test IndexStyle(v1) == IndexLinear()

v2 = FeatherFiles.DataValueArrowVector(DictEncoding(["fire", "walk", "with", missing, "me"]))
@test getindex(v2, 1) == DataValue{String}("fire")
@test getindex(v2, 4) == DataValue{String}()
@test IndexStyle(v2) == IndexLinear()

v3 = FeatherFiles.MissingDataValueVector([DataValue{Int64}(), DataValue{Int64}(18), DataValue{Int64}(54)])
@test getindex(v3, 2) == 18
@test getindex(v3, 1) === missing
@test IndexStyle(v3) == IndexLinear()

end