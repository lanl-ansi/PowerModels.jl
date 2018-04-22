# Test cases for PTI RAW file parser

@testset "test .raw file parser" begin
    @testset "Check PTI exception handling" begin
        setlevel!(getlogger(PowerModels), "warn")

        @test_nowarn PowerModels.parse_pti("../test/data/pti/parser_test_a.raw")
        @test_warn(getlogger(PowerModels),
                   "The PSS(R)E parser is partially implimented, and currently only supports buses, loads, shunts, generators, branches, and transformers",
                   PowerModels.parse_file("../test/data/pti/frankenstein_00.raw"))
        @test_throws(getlogger(PowerModels),
                     ErrorException,
                     PowerModels.parse_pti("../test/data/pti/parser_test_b.raw"))
        @test_warn(getlogger(PowerModels),
                   "Version 32 of PTI format is unsupported, parser may not function correctly.",
                   PowerModels.parse_pti("../test/data/pti/parser_test_c.raw"))
        @test_throws(getlogger(PowerModels), ErrorException, PowerModels.parse_pti("../test/data/pti/parser_test_d.raw"))
        @test_warn(getlogger(PowerModels), "GNE DEVICE parsing is not supported.", PowerModels.parse_pti("../test/data/pti/parser_test_h.raw"))

        setlevel!(getlogger(PowerModels), "error")
    end

    @testset "4-bus frankenstein file" begin
        data_dict = PowerModels.parse_pti("../test/data/pti/frankenstein_00.raw")
        @test isa(data_dict, Dict)

        @test length(data_dict["CASE IDENTIFICATION"]) == 1
        @test length(data_dict["CASE IDENTIFICATION"][1]) == 9

        @test length(data_dict["BUS"]) == 4
        for item in data_dict["BUS"]
            @test length(item) == 13
        end

        @test length(data_dict["LOAD"]) == 2
        for item in data_dict["LOAD"]
            @test length(item) == 13
        end

        @test length(data_dict["FIXED SHUNT"]) == 1
        @test length(data_dict["FIXED SHUNT"][1]) == 5

        @test length(data_dict["GENERATOR"]) == 3
        for item in data_dict["GENERATOR"]
            @test length(item) == 28
        end

        @test length(data_dict["TRANSFORMER"]) == 1
        @test length(data_dict["TRANSFORMER"][1]) == 43

        @test length(data_dict["AREA INTERCHANGE"]) == 1
        @test length(data_dict["AREA INTERCHANGE"][1]) == 5

        @test length(data_dict["ZONE"]) == 1
        @test length(data_dict["ZONE"][1]) == 2

        @test length(data_dict["OWNER"]) == 1
        @test length(data_dict["OWNER"][1]) == 2
    end

    @testset "20-bus frankenstein file" begin
        data_dict = PowerModels.parse_pti("../test/data/pti/frankenstein_20.raw")
        @test isa(data_dict, Dict)

        @test length(data_dict["BRANCH"]) == 2
        for item in data_dict["BRANCH"]
            @test length(item) == 24
        end

        @test length(data_dict["TRANSFORMER"][2]) == 83

        @test length(data_dict["SWITCHED SHUNT"]) == 2
        @test length(data_dict["SWITCHED SHUNT"][1]) == 16
        @test length(data_dict["SWITCHED SHUNT"][2]) == 12
    end

    @testset "70-bus frankenstein file" begin
        data_dict = PowerModels.parse_pti("../test/data/pti/frankenstein_70.raw")
        @test isa(data_dict, Dict)

        @test length(data_dict["TWO-TERMINAL DC"]) == 1
        @test length(data_dict["TWO-TERMINAL DC"][1]) == 46

        @test length(data_dict["VOLTAGE SOURCE CONVERTER"]) == 1
        @test length(data_dict["VOLTAGE SOURCE CONVERTER"][1]) == 12
        @test length(data_dict["VOLTAGE SOURCE CONVERTER"][1]["CONVERTER BUSES"]) == 2
        for item in data_dict["VOLTAGE SOURCE CONVERTER"][1]["CONVERTER BUSES"]
            @test length(item) == 15
        end

        @test length(data_dict["IMPEDANCE CORRECTION"]) == 2
        @test length(data_dict["IMPEDANCE CORRECTION"][1]) == 23
        @test length(data_dict["IMPEDANCE CORRECTION"][2]) == 15

        @test length(data_dict["MULTI-TERMINAL DC"]) == 1
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 11

        @test length(data_dict["MULTI-TERMINAL DC"][1]["CONV"]) == 3
        for item in data_dict["MULTI-TERMINAL DC"][1]["CONV"]
            @test length(item) == 16
        end

        @test length(data_dict["MULTI-TERMINAL DC"][1]["DCBS"]) == 3
        for item in data_dict["MULTI-TERMINAL DC"][1]["DCBS"]
            @test length(item) == 8
        end

        @test length(data_dict["MULTI-TERMINAL DC"][1]["DCLN"]) == 3
        for item in data_dict["MULTI-TERMINAL DC"][1]["DCLN"]
            @test length(item) == 6
        end

        @test length(data_dict["FACTS CONTROL DEVICE"]) == 2
        for item in data_dict["FACTS CONTROL DEVICE"]
            @test length(item) == 19
        end

        data_dict = PowerModels.parse_pti("../test/data/pti/parser_test_e.raw")
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 10

        data_dict = PowerModels.parse_pti("../test/data/pti/parser_test_f.raw")
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 9

        data_dict = PowerModels.parse_pti("../test/data/pti/parser_test_g.raw")
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 8

    end

    @testset "0-bus case file" begin
        @test_throws(getlogger(PowerModels), ArgumentError, PowerModels.parse_pti("../test/data/pti/case0.raw"))
    end

    @testset "73-bus case file" begin
        data_dict = PowerModels.parse_pti("../test/data/pti/case73.raw")
        @test isa(data_dict, Dict)

        @test length(data_dict["BUS"]) == 73
        for item in data_dict["BUS"]
            @test length(item) == 13
        end

        @test length(data_dict["LOAD"]) == 51
        for item in data_dict["LOAD"]
            @test length(item) == 13
        end

        @test length(data_dict["GENERATOR"]) == 99
        for item in data_dict["GENERATOR"]
            @test length(item) == 28
        end

        @test length(data_dict["BRANCH"]) == 105
        for item in data_dict["BRANCH"]
            @test length(item) == 24
        end

        @test length(data_dict["TRANSFORMER"]) == 15
        for item in data_dict["TRANSFORMER"]
            @test length(item) == 43
        end

        @test length(data_dict["AREA INTERCHANGE"]) == 3
        @test length(data_dict["ZONE"]) == 3
        @test length(data_dict["OWNER"]) == 1

        @test length(data_dict["SWITCHED SHUNT"]) == 3
        for item in data_dict["SWITCHED SHUNT"]
            @test length(item) == 12
        end
    end
end