using FileIO
using TableTraits
using FeatherFiles
using IterableTables
using DataFrames
using Base.Test

@testset "FeatherFiles" begin

df = DataFrame(Name=["John", "Sally", "Jim"], Age=[34.,54.,23],Children=[2,1,0])

output_filename = tempname() * ".feather"

df |> save(output_filename)

try
    df2 = load(output_filename) |> DataFrame

    @test df == df2

    featherfile = load(output_filename)

    @test isiterable(featherfile) == true
finally
    gc()
    rm(output_filename)
end

end
