@testitem "FeatherFiles" begin
    using DataValues
    using IteratorInterfaceExtensions
    using TableTraits
    using QueryTables

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
        # This rm stays commented out, and close! does not change that. The culprit is the
        # lazy getiterator call above: its rows read straight through the memory mapping,
        # so nothing may release it while the iterator is alive, and afterwards only the
        # GC can. It is the mapping from *that* call, not from
        # get_columns_copy_using_missing, that still holds the file on Windows.
        # The deterministic half is covered by the dedicated testitem
        # "get_columns_copy_using_missing releases the file" below, which does rm without
        # a GC.
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

@testitem "Missing Conversion" begin
    using DataValues
    using FeatherLib.ArrowCompat: NullablePrimitive, DictEncoding

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

@testitem "Date and time columns" begin
    using Dates
    using DataValues
    using IteratorInterfaceExtensions
    using TableTraits
    using FeatherLib: featherwrite

    # Feather stores these as the Arrow wire types Datestamp, Timestamp and TimeOfDay.
    # Users should never see those: FeatherLib deliberately hands them out as-is, and
    # FeatherFiles is the layer that unwraps them.
    filename = tempname() * ".feather"
    featherwrite(filename,
                 Any[[Date(2020, 1, 2), Date(2021, 3, 4)],
                     [DateTime(2020, 1, 2, 3, 4, 5), DateTime(2021, 3, 4, 5, 6, 7)],
                     [Time(1, 2, 3), Time(4, 5, 6)],
                     [1, 2]],
                 [:d, :dt, :t, :n])

    rows = collect(IteratorInterfaceExtensions.getiterator(load(filename)))
    @test typeof(rows[1].d) == Date
    @test rows[1].d == Date(2020, 1, 2)
    @test typeof(rows[1].dt) == DateTime
    @test rows[1].dt == DateTime(2020, 1, 2, 3, 4, 5)
    @test typeof(rows[1].t) == Time
    @test rows[1].t == Time(1, 2, 3)
    @test typeof(rows[1].n) == Int64      # non-temporal columns untouched

    cols = TableTraits.get_columns_copy_using_missing(load(filename))
    @test eltype(cols.d) == Date
    @test cols.d == [Date(2020, 1, 2), Date(2021, 3, 4)]
    @test eltype(cols.dt) == DateTime
    @test eltype(cols.t) == Time

    GC.gc(); GC.gc()
    rm(filename)
end

@testitem "Nullable date columns" begin
    using Dates
    using DataValues
    using IteratorInterfaceExtensions
    using TableTraits
    using FeatherLib: featherwrite

    filename = tempname() * ".feather"
    featherwrite(filename, Any[Union{Date,Missing}[Date(2020, 1, 2), missing, Date(2021, 3, 4)]], [:d])

    # Julia does not order Union members predictably: for Union{Datestamp,Missing} the
    # non-Missing half is `.a`, so the old `col_eltype.b <: Missing` test silently skipped
    # these columns and they came back unwrapped.
    rows = collect(IteratorInterfaceExtensions.getiterator(load(filename)))
    @test typeof(rows[1].d) == DataValue{Date}
    @test get(rows[1].d) == Date(2020, 1, 2)
    @test isna(rows[2].d)

    cols = TableTraits.get_columns_copy_using_missing(load(filename))
    @test eltype(cols.d) == Union{Date,Missing}
    @test isequal(cols.d, [Date(2020, 1, 2), missing, Date(2021, 3, 4)])

    GC.gc(); GC.gc()
    rm(filename)
end

@testitem "get_columns_copy_using_missing releases the file" begin
    using TableTraits

    # Every column is copied out, so the ResultSet is closed before returning and the
    # file is immediately deletable -- no GC needed, which matters on Windows.
    filename = tempname() * ".feather"
    [(a=1, b=2), (a=3, b=4)] |> save(filename)

    TableTraits.get_columns_copy_using_missing(load(filename))

    @test (rm(filename); !isfile(filename))
end
