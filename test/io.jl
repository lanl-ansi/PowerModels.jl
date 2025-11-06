
@testset "export data to other file types" begin

    function test_export(filename::AbstractString, extension::AbstractString)
        source_data = parse_file(filename)

        dir = mktempdir()
        file_tmp = joinpath(dir, "tmp.$extension")
        PowerModels.export_file(file_tmp, source_data)

        # Test ::String method
        destination_data_file = PowerModels.parse_file(file_tmp)
        # Test ::IO method
        destination_data_io = open(file_tmp, "r") do io
            return PowerModels.parse_file(io; filetype = extension)
        end
        @test destination_data_file == destination_data_io
        return
    end

    @testset "test case30.m" begin
        file = "../test/data/matpower/case30.m"
        test_export(file, "raw")
        test_export(file, "json")
    end

        @testset "test case5.m" begin
        file = "../test/data/matpower/case5.m"
        test_export(file, "raw")
        test_export(file, "json")
    end

    @testset "test case14.m" begin
        file = "../test/data/matpower/case14.m"
        test_export(file, "raw")
        test_export(file, "json")
    end

    @testset "test case24.m" begin
        file = "../test/data/matpower/case24.m"
        test_export(file, "raw")
        test_export(file, "json")
    end

    @testset "test case30.m" begin
        file = "../test/data/matpower/case30.m"
        test_export(file, "raw")
        test_export(file, "json")
    end

    @testset "test case5_dc.m" begin
        file = "../test/data/matpower/case5_dc.m"
        test_export(file, "raw")
        test_export(file, "json")
    end

    @testset "test case30.raw" begin
        file = "../test/data/pti/case30.raw"
        test_export(file, "m")
        test_export(file, "json")
    end

    @testset "test case73.raw" begin
        file = "../test/data/pti/case73.raw"
        test_export(file, "m")
        test_export(file, "json")
    end

    @testset "test frankenstein_00_2.raw" begin
        file = "../test/data/pti/frankenstein_00_2.raw"
        test_export(file, "m")
        test_export(file, "json")
    end

    @testset "test frankenstein_20.raw" begin
        file = "../test/data/pti/frankenstein_20.raw"
        test_export(file, "m")
        test_export(file, "json")
    end
end
