
@testset "export data to other file types" begin

    function test_export(filename::AbstractString, extension::AbstractString)
        source_data = parse_file(filename)

        file_tmp = "../test/data/tmp." * extension
        PowerModels.export_file(file_tmp, source_data)

        destination_data = PowerModels.parse_file(file_tmp)
        rm(file_tmp)

        @test true
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
