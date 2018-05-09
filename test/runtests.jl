using FileIO
using TableTraits
using FeatherFiles
using NamedTuples
using DataValues
using Base.Test

@testset "FeatherFiles" begin

source = [@NT(Name="John", Age=34., Children=2),
    @NT(Name="Sally", Age=54., Children=1),
    @NT(Name="Jim", Age=34., Children=0)]

output_filename = tempname() * ".feather"

source |> save(output_filename)

try
    sink = load(output_filename) |> IteratorInterfaceExtensions.getiterator |> collect

    @test source == sink

    featherfile = load(output_filename)

    @test isiterable(featherfile) == true
finally
    gc()
    gc()
    # rm(output_filename)
end

source2 = [@NT(Name=DataValue("John"), Age=DataValue(34.), Children=DataValue{Int}()),
    @NT(Name=DataValue("Sally"), Age=DataValue{Float64}(), Children=DataValue(1)),
    @NT(Name=DataValue{String}(), Age=DataValue(34.), Children=DataValue(0))]

source2 = [@NT(Age=DataValue(34.), Children=DataValue{Int}()),
    @NT(Age=DataValue{Float64}(), Children=DataValue(1)),
    @NT(Age=DataValue(34.), Children=DataValue(0))]


output_filename2 = tempname() * ".feather"

source2 |> save(output_filename2)

try
    sink2 = load(output_filename2) |> IteratorInterfaceExtensions.getiterator |> collect

    @test source2 == sink2
finally
    gc()
    gc()
    # rm(output_filename2)
end

end
