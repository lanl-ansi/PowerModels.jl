# Test cases for PTI RAW file parser

TESTLOG = Memento.getlogger(PowerModels)

@testset "test .raw file parser" begin
    @testset "Check PTI exception handling" begin
        Memento.setlevel!(TESTLOG, "warn")

        @test_nowarn PowerModels.parse_pti("../test/data/pti/parser_test_a.raw")
        # @test_throws(TESTLOG, ErrorException, PowerModels.parse_pti("../test/data/pti/parser_test_b.raw"))
        @test_warn(TESTLOG, "Version 32 of PTI format is unsupported, parser may not function correctly.",
                   PowerModels.parse_pti("../test/data/pti/parser_test_c.raw"))
        @test_warn(TESTLOG, "At line 4, new section started with '0', but additional non-comment data is present. Pattern '^\\s*0\\s*[/]*.*' is reserved for section start/end.",
                    PowerModels.parse_pti("../test/data/pti/parser_test_c.raw"))
        @test_throws(TESTLOG, ErrorException, PowerModels.parse_pti("../test/data/pti/parser_test_d.raw"))
        @test_warn(TESTLOG, "GNE DEVICE parsing is not supported.", PowerModels.parse_pti("../test/data/pti/parser_test_h.raw"))
        @test_throws(TESTLOG, ErrorException, PowerModels.parse_pti("../test/data/pti/parser_test_j.raw"))

        Memento.setlevel!(TESTLOG, "error")
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
            @test length(item) == 14
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

    @testset "20-bus frankenstein file (parse_file)" begin
        data_dict = PowerModels.parse_pti("../test/data/pti/frankenstein_20.raw")
        @test isa(data_dict, Dict)

        @test length(data_dict["BRANCH"]) == 2
        for item in data_dict["BRANCH"]
            @test length(item) == 24
        end

        @test length(data_dict["TRANSFORMER"][2]) == 83

        @test length(data_dict["SWITCHED SHUNT"]) == 2
        @test length(data_dict["SWITCHED SHUNT"][1]) == 26
        @test length(data_dict["SWITCHED SHUNT"][2]) == 26
    end

    @testset "20-bus frankenstein file (parse_pti)" begin
        data_dict = PowerModels.parse_pti("../test/data/pti/frankenstein_20.raw")
        @test isa(data_dict, Dict)

        @test length(data_dict["BRANCH"]) == 2
        for item in data_dict["BRANCH"]
            @test length(item) == 24
        end

        @test length(data_dict["TRANSFORMER"][2]) == 83

        @test length(data_dict["SWITCHED SHUNT"]) == 2
        @test length(data_dict["SWITCHED SHUNT"][1]) == 26
        @test length(data_dict["SWITCHED SHUNT"][2]) == 26
    end

    @testset "20-bus frankenstein file (parse_pti; iostream)" begin
        data_dict = open("../test/data/pti/frankenstein_20.raw") do f
            PowerModels.parse_pti(f)
        end
        @test isa(data_dict, Dict)

        @test length(data_dict["BRANCH"]) == 2
        for item in data_dict["BRANCH"]
            @test length(item) == 24
        end

        @test length(data_dict["TRANSFORMER"][2]) == 83

        @test length(data_dict["SWITCHED SHUNT"]) == 2
        @test length(data_dict["SWITCHED SHUNT"][1]) == 26
        @test length(data_dict["SWITCHED SHUNT"][2]) == 26
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
        @test length(data_dict["IMPEDANCE CORRECTION"][2]) == 23

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
            @test length(item) == 21
        end

        data_dict = PowerModels.parse_pti("../test/data/pti/parser_test_e.raw")
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 10

        data_dict = PowerModels.parse_pti("../test/data/pti/parser_test_f.raw")
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 9

        data_dict = PowerModels.parse_pti("../test/data/pti/parser_test_g.raw")
        @test length(data_dict["MULTI-TERMINAL DC"][1]) == 8

    end

    @testset "0-bus case file" begin
        @test_throws(TESTLOG, ErrorException, PowerModels.parse_pti("../test/data/pti/case0.raw"))
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
            @test length(item) == 14
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
            @test length(item) == 26
        end
    end

    @testset "reserved characters in comments" begin
        pti = PowerModels.parse_pti("../test/data/pti/parser_test_a.raw")
        @test pti["CASE IDENTIFICATION"][1]["Comment_Line_1"] == "0"
        @test pti["CASE IDENTIFICATION"][1]["Comment_Line_2"] == "Q"
        @test length(pti["BUS"]) == 2
    end

    @testset "default values in PTI files" begin
        pti = Dict{String,Array}("CASE IDENTIFICATION" => [Dict{String,Any}("IC" => 0, "SBASE" => 100.0, "REV" => 33, "XFRRAT" => 0, "NXFRAT" => 0, "BASFRQ" => 60, "Comment_Line_1" => "default values test", "Comment_Line_2" => "", "NAME" => "parser_test_defaults")],
                                 "BUS" => [Dict{String,Any}("I" => 1, "NAME" => "            ", "BASKV" => 0.0, "IDE" => 1, "AREA" => 1, "ZONE" => 1, "OWNER" => 1, "VM" => 1.0, "VA" => 0.0, "NVHI" => 1.1, "NVLO" => 0.9, "EVHI" => 1.1, "EVLO" => 0.9)],
                                 "LOAD" => [Dict{String,Any}("I" => 1, "ID" => 1, "STATUS" => 1, "AREA" => 1, "ZONE" => 1, "PL" => 0.0, "QL" => 0.0, "IP" => 0.0, "IQ" => 0.0, "YP" => 0.0, "YQ" => 0.0, "OWNER" => 1, "SCALE" => 1, "INTRPT" => 0)],
                                 "FIXED SHUNT" => [Dict{String,Any}("I" => 1, "ID" => 1, "STATUS" => 1, "GL" => 0.0, "BL" => 0.0)],
                                 "GENERATOR" => [Dict{String,Any}("I" => 1, "ID" => 1, "PG" => 0.0, "QG" => 0.0, "QT" => 9999.0, "QB" => -9999.0, "VS" => 1.0, "IREG" => 0, "MBASE" => 100.0, "ZR" => 0.0, "ZX" => 1.0, "RT" => 0.0, "XT" => 0.0, "GTAP" => 1.0, "STAT" => 1, "RMPCT" => 100.0, "PT" => 9999.0, "PB" => -9999.0, "O1" => 1, "F1" => 1.0, "O2" => 0, "F2" => 1.0, "O3" => 0, "F3" => 1.0, "O4" => 0, "F4" => 1.0, "WMOD" => 0, "WPF" => 1.0)],
                                 "BRANCH" => [Dict{String,Any}("I" => 1, "J" => 2, "CKT" => 1, "R" => 0.1, "X" => 0.1, "B" => 0.0, "RATEA" => 0.0, "RATEB" => 0.0, "RATEC" => 0.0, "GI" => 0.0, "BI" => 0.0, "BJ" => 0.0, "GJ" => 0.0, "ST" => 1, "MET" => 1, "LEN" => 0.0, "O1" => 1, "F1" => 1.0, "O2" => 0, "F2" => 1.0, "O3" => 0, "F3" => 1.0, "O4" => 0, "F4" => 1.0)],
                                 "TRANSFORMER" => [Dict{String,Any}()],
                                 "AREA INTERCHANGE" => [Dict{String,Any}("I" => 1, "ISW" => 0, "PDES" => 0.0, "PTOL" => 10.0, "ARNAME" => "            ")],
                                 "TWO-TERMINAL DC" => [Dict{String,Any}()],
                                 "VOLTAGE SOURCE CONVERTER" => [Dict{String,Any}()],
                                 "IMPEDANCE CORRECTION" => [Dict{String,Any}("I" => 1, "T1" => 0.0, "F1" => 0.0, "T2" => 0.0, "F2" => 0.0, "T3" => 0.0, "F3" => 0.0, "T4" => 0.0, "F4" => 0.0, "T5" => 0.0, "F5" => 0.0, "T6" => 0.0, "F6" => 0.0, "T7" => 0.0, "F7" => 0.0, "T8" => 0.0, "F8" => 0.0, "T9" => 0.0, "F9" => 0.0, "T10" => 0.0, "F10" => 0.0, "T11" => 0.0, "F11" => 0.0)],
                                 "MULTI-TERMINAL DC" => [Dict{String,Any}("NAME" => "MULTI-TERM", "NCONV" => 1, "NDCBS" => 1, "NDCLN" => 1, "MDC" => 0, "VCONV"  => 1, "VCMOD" => 0.0, "VCONVN" => 0,
                                                                          "CONV" => [Dict{String,Any}("IB" => 2, "N" => 1, "ANGMX" => 9.0, "ANGMN" => 5.0, "RC" => 1.0, "XC" => 1.0, "EBAS" => 1.0, "TR" => 1.0, "TAP" => 1.0, "TPMX" => 1.5, "TPMN" => 0.51, "TSTP" => 0.00625, "SETVL" => 1, "DCPF" => 1, "MARG" => 0.0, "CNVCOD" => 1)],
                                                                          "DCBS" => [Dict{String,Any}("IDC" => 3, "IB" => 0, "AREA" => 1, "ZONE" => 1, "DCNAME" => "            ", "IDC2" => 0, "RGRND" => 0.0, "OWNER" => 1)],
                                                                          "DCLN" => [Dict{String,Any}("IDC" => 1, "JDC" => 2, "DCCKT" => 1, "MET" => 1, "RDC" => 1.0, "LDC" => 1.0)])],
                                 "MULTI-SECTION LINE" => [Dict{String,Any}("I" => 1, "J" => 2, "ID" => "&1", "MET" => 1, "DUM1" => 1, "DUM2" => "", "DUM3" => "", "DUM4" => "", "DUM5" => "", "DUM6" => "", "DUM7" => "", "DUM8" => "", "DUM9" => "")],
                                 "ZONE" => [Dict{String,Any}("I" => 1, "ZONAME" => "            ")],
                                 "INTER-AREA TRANSFER" => [Dict{String,Any}("ARFROM" => 1, "ARTO" => 2, "TRID" => 1, "PTRAN" => 0.0)],
                                 "OWNER" => [Dict{String,Any}("I" => 1, "OWNAME" => "            ")],
                                 "FACTS CONTROL DEVICE" => [Dict{String,Any}("NAME" => "FACTS", "I" => 1, "J" => 0, "MODE" => 1, "PDES" => 0.0, "QDES" => 0.0, "VSET" => 1.0, "SHMX" => 9999.0, "TRMX" => 9999.0, "VTMN" => 0.9, "VTMX" => 1.1, "VSMX" => 1.0, "IMX" => 0.0, "LINX" => 0.05, "RMPCT" => 100.0, "OWNER" => 1, "SET1" => 0.0, "SET2" => 0.0, "VSREF" => 0, "REMOT" => 0, "MNAME" => "")],
                                 "SWITCHED SHUNT" => [Dict{String,Any}("I" => 1, "MODSW" => 1, "ADJM" => 0, "STAT" => 1, "VSWHI" => 1.0, "VSWLO" => 1.0, "SWREM" => 0, "RMPCT" => 100.0, "RMIDNT" => "", "BINIT" => 0.0, "N1" => 0.0, "B1" => 0.0, "N2" => 0.0, "B2" => 0.0, "N3" => 0.0, "B3" => 0.0, "N4" => 0.0, "B4" => 0.0, "N5" => 0.0, "B5" => 0.0, "N6" => 0.0, "B6" => 0.0, "N7" => 0.0, "B7" => 0.0, "N8" => 0.0, "B8" => 0.0)])

        parsed_pti = PowerModels.parse_pti("../test/data/pti/parser_test_defaults.raw")

        # @test parsed_pti == pti
    end
end
