@testset "test matpower parser" begin
    @testset "30-bus case file" begin
        result = solve_opf("../test/data/matpower/case30.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_file)" begin
        data = PowerModels.parse_file("../test/data/matpower/case30.m")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_matpower; matlab_data)" begin
        matlab_data = Dict{String, Any}()
        matlab_data["mpc.bus"::String] = [
            [1, 3, 0.0, 0.0, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [2, 2, 21.7, 12.7, 0, 0.0, 1, 1, 0, 135, 1, 1.1, 0.95],
            [3, 1, 2.4, 1.2, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [4, 1, 7.6, 1.6, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [5, 1, 0.0, 0.0, 0, 0.19, 1, 1, 0, 135, 1, 1.05, 0.95],
            [6, 1, 0.0, 0.0, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [7, 1, 22.8, 10.9, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [8, 1, 30.0, 30.0, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [9, 1, 0.0, 0.0, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [10, 1, 5.8, 2.0, 0, 0.0, 3, 1, 0, 135, 1, 1.05, 0.95],
            [11, 1, 0.0, 0.0, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [12, 1, 11.2, 7.5, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [13, 2, 0.0, 0.0, 0, 0.0, 2, 1, 0, 135, 1, 1.1, 0.95],
            [14, 1, 6.2, 1.6, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [15, 1, 8.2, 2.5, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [16, 1, 3.5, 1.8, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [17, 1, 9.0, 5.8, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [18, 1, 3.2, 0.9, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [19, 1, 9.5, 3.4, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [20, 1, 2.2, 0.7, 0, 0.0, 2, 1, 0, 135, 1, 1.05, 0.95],
            [21, 1, 17.5, 11.2, 0, 0.0, 3, 1, 0, 135, 1, 1.05, 0.95],
            [22, 2, 0.0, 0.0, 0, 0.0, 3, 1, 0, 135, 1, 1.1, 0.95],
            [23, 2, 3.2, 1.6, 0, 0.0, 2, 1, 0, 135, 1, 1.1, 0.95],
            [24, 1, 8.7, 6.7, 0, 0.04, 3, 1, 0, 135, 1, 1.05, 0.95],
            [25, 1, 0.0, 0.0, 0, 0.0, 3, 1, 0, 135, 1, 1.05, 0.95],
            [26, 1, 3.5, 2.3, 0, 0.0, 3, 1, 0, 135, 1, 1.05, 0.95],
            [27, 2, 0.0, 0.0, 0, 0.0, 3, 1, 0, 135, 1, 1.1, 0.95],
            [28, 1, 0.0, 0.0, 0, 0.0, 1, 1, 0, 135, 1, 1.05, 0.95],
            [29, 1, 2.4, 0.9, 0, 0.0, 3, 1, 0, 135, 1, 1.05, 0.95],
            [30, 1, 10.6, 1.9, 0, 0.0, 3, 1, 0, 135, 1, 1.05, 0.95]
        ]
        matlab_data["mpc.version"::String] = "2"
        matlab_data["mpc.baseMVA"::String] = 100
        matlab_data["mpc.gencost"::String] = [
            [2, 0, 0, 3, 0.02, 2.0, 0],
            [2, 0, 0, 3, 0.0175, 1.75, 0],
            [2, 0, 0, 3, 0.0625, 1.0, 0],
            [2, 0, 0, 3, 0.00834, 3.25, 0],
            [2, 0, 0, 3, 0.025, 3.0, 0],
            [2, 0, 0, 3, 0.025, 3.0, 0]
        ]
        matlab_data["mpc.gen"::String] = [
            [1, 23.54, 0, 150.0, -20, 1, 100, 1, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [2, 60.97, 0, 60.0, -20, 1, 100, 1, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [22, 21.59, 0, 62.5, -15, 1, 100, 1, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [27, 26.91, 0, 48.7, -15, 1, 100, 1, 55, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 19.2, 0, 40.0, -10, 1, 100, 1, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [13, 37.0, 0, 44.7, -15, 1, 100, 1, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        ]
        matlab_data["mpc.branch"::String] = [
            [1, 2, 0.02, 0.06, 0.03, 130, 130, 130, 0, 0, 1, -360, 360],
            [1, 3, 0.05, 0.19, 0.02, 130, 130, 130, 0, 0, 1, -360, 360],
            [2, 4, 0.06, 0.17, 0.02, 65, 65, 65, 0, 0, 1, -360, 360],
            [3, 4, 0.01, 0.04, 0.0, 130, 130, 130, 0, 0, 1, -360, 360],
            [2, 5, 0.05, 0.2, 0.02, 130, 130, 130, 0, 0, 1, -360, 360],
            [2, 6, 0.06, 0.18, 0.02, 65, 65, 65, 0, 0, 1, -360, 360],
            [4, 6, 0.01, 0.04, 0.0, 90, 90, 90, 0, 0, 1, -360, 360],
            [5, 7, 0.05, 0.12, 0.01, 70, 70, 70, 0, 0, 1, -360, 360],
            [6, 7, 0.03, 0.08, 0.01, 130, 130, 130, 0, 0, 1, -360, 360],
            [6, 8, 0.01, 0.04, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [6, 9, 0.0, 0.21, 0.0, 65, 65, 65, 0, 0, 1, -360, 360],
            [6, 10, 0.0, 0.56, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [9, 11, 0.0, 0.21, 0.0, 65, 65, 65, 0, 0, 1, -360, 360],
            [9, 10, 0.0, 0.11, 0.0, 65, 65, 65, 0, 0, 1, -360, 360],
            [4, 12, 0.0, 0.26, 0.0, 65, 65, 65, 0, 0, 1, -360, 360],
            [12, 13, 0.0, 0.14, 0.0, 65, 65, 65, 0, 0, 1, -360, 360],
            [12, 14, 0.12, 0.26, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [12, 15, 0.07, 0.13, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [12, 16, 0.09, 0.2, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [14, 15, 0.22, 0.2, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [16, 17, 0.08, 0.19, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [15, 18, 0.11, 0.22, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [18, 19, 0.06, 0.13, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [19, 20, 0.03, 0.07, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [10, 20, 0.09, 0.21, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [10, 17, 0.03, 0.08, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [10, 21, 0.03, 0.07, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [10, 22, 0.07, 0.15, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [21, 22, 0.01, 0.02, 0.0, 32, 32, 32, 0, 0, 1, -360, 360],
            [15, 23, 0.1, 0.2, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [22, 24, 0.12, 0.18, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [23, 24, 0.13, 0.27, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [24, 25, 0.19, 0.33, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [25, 26, 0.25, 0.38, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [25, 27, 0.11, 0.21, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [28, 27, 0.0, 0.4, 0.0, 65, 65, 65, 0, 0, 1, -360, 360],
            [27, 29, 0.22, 0.42, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [27, 30, 0.32, 0.6, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [29, 30, 0.24, 0.45, 0.0, 16, 16, 16, 0, 0, 1, -360, 360],
            [8, 28, 0.06, 0.2, 0.02, 32, 32, 32, 0, 0, 1, -360, 360],
            [6, 28, 0.02, 0.06, 0.01, 32, 32, 32, 0, 0, 1, -360, 360]
        ]
        func_name = "case30"
        colnames = Dict{String, Any}()
        data = PowerModels.parse_matpower(matlab_data, func_name=func_name, colnames=colnames, validate=true)

        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_matpower; path string)" begin
        data = PowerModels.parse_matpower("../test/data/matpower/case30.m")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_matpower; iostream)" begin
        open("../test/data/matpower/case30.m") do f
            data = PowerModels.parse_matpower(f)
            @test isa(JSON.json(data), String)

            result = solve_opf(data, ACPPowerModel, nlp_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 204.96; atol = 1e-1)
        end
    end

    @testset "14-bus case file with bus names" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        @test data["bus"]["1"]["name"] == "Bus 1     HV"
        @test isa(JSON.json(data), String)
    end

    @testset "5-bus case file with pwl cost functions" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")
        @test data["gen"]["1"]["model"] == 1
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus case file with hvdc lines" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")
        @test length(data["dcline"]) > 0
        @test isa(JSON.json(data), String)
    end

    @testset "2-bus case file with spaces" begin
        result = solve_pf("../test/data/matpower/case2.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0.0; atol = 1e-1)
    end

    @testset "5-bus source ids" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_strg.m")
        @test data["bus"]["1"]["source_id"] == ["bus", 1]
        @test data["gen"]["1"]["source_id"] == ["gen", 1]
        @test data["load"]["1"]["source_id"] == ["bus", 2]
        @test data["branch"]["1"]["source_id"] == ["branch", 1]
        @test data["storage"]["1"]["source_id"] == ["storage", 1]
    end
end


@testset "test matpower data coercion" begin
    @testset "ACP Model" begin
        result = solve_opf("../test/data/matpower/case14.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8081.5; atol = 1e0)
        #@test result["status"] = bus_name
    end
    @testset "DC Model" begin
        result = solve_opf("../test/data/matpower/case14.m", DCPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 7642.6; atol = 1e0)
    end
    @testset "QC Model" begin
        result = solve_opf("../test/data/matpower/case14.m", QCRMPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8075.1; atol = 1e0)
    end
end


@testset "test matpower extentions parser" begin
    @testset "3-bus extended constants" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test data["const_int"] == 123
        @test data["const_float"] == 4.56
        @test data["const_str"] == "a string"
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended matrix" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas")
        @test data["areas"]["1"]["col_1"] == 1
        @test data["areas"]["1"]["col_2"] == 1
        @test data["areas"]["2"]["col_1"] == 2
        @test data["areas"]["2"]["col_2"] == 3
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended named matrix" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named")
        @test data["areas_named"]["1"]["area"] == 4
        @test data["areas_named"]["1"]["refbus"] == 5
        @test data["areas_named"]["2"]["area"] == 5
        @test data["areas_named"]["2"]["refbus"] == 6
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended predefined matrix" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named")
        @test data["branch"]["1"]["rate_i"] == 50.2
        @test data["branch"]["1"]["rate_p"] == 45
        @test data["branch"]["2"]["rate_i"] == 36
        @test data["branch"]["2"]["rate_p"] == 60.1
        @test data["branch"]["3"]["rate_i"] == 12
        @test data["branch"]["3"]["rate_p"] == 30
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended matrix from cell" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_cells")
        @test data["areas_cells"]["1"]["col_1"] == "Area 1"
        @test data["areas_cells"]["1"]["col_2"] == 123
        @test data["areas_cells"]["1"]["col_4"] == "Slack \\\"Bus\\\" 1"
        @test data["areas_cells"]["1"]["col_5"] == 1.23
        @test data["areas_cells"]["2"]["col_1"] == "Area 2"
        @test data["areas_cells"]["2"]["col_2"] == 456
        @test data["areas_cells"]["2"]["col_4"] == "Slack Bus 3"
        @test data["areas_cells"]["2"]["col_5"] == 4.56
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended named matrix from cell" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named_cells")
        @test data["areas_named_cells"]["1"]["area_name"] == "Area 1"
        @test data["areas_named_cells"]["1"]["area"] == 123
        @test data["areas_named_cells"]["1"]["area2"] == 987
        @test data["areas_named_cells"]["1"]["refbus_name"] == "Slack Bus 1"
        @test data["areas_named_cells"]["1"]["refbus"] == 1.23
        @test data["areas_named_cells"]["2"]["area_name"] == "Area 2"
        @test data["areas_named_cells"]["2"]["area"] == 456
        @test data["areas_named_cells"]["2"]["area2"] == 987
        @test data["areas_named_cells"]["2"]["refbus_name"] == "Slack Bus 3"
        @test data["areas_named_cells"]["2"]["refbus"] == 4.56
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended predefined matrix from cell" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named")
        @test data["branch"]["1"]["name"] == "Branch 1"
        @test data["branch"]["1"]["number_id"] == 123
        @test data["branch"]["2"]["name"] == "Branch 2"
        @test data["branch"]["2"]["number_id"] == 456
        @test data["branch"]["3"]["name"] == "Branch 3"
        @test data["branch"]["3"]["number_id"] == 789
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus tnep case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")

        @test haskey(data, "ne_branch")
        @test data["ne_branch"]["1"]["f_bus"] == 2
        @test data["ne_branch"]["1"]["construction_cost"] == 1
        @test isa(JSON.json(data), String)
    end

    @testset "`build_ref` for 3-bus tnep case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        ref = PowerModels.build_ref(data)

        @assert !PowerModels.InfrastructureModels.ismultinetwork(data)
        ref_nw = ref[:it][pm_it_sym][:nw][0]

        @test haskey(data, "name")
        @test haskey(ref_nw, :name)
        @test data["name"] == ref_nw[:name]
    end
end

@testset "test idempotent matpower export" begin

    function test_mp_idempotent(filename::AbstractString, parse_file::Function)
        source_data = parse_file(filename)

        io = PipeBuffer()
        PowerModels.export_matpower(io, source_data)
        destination_data = PowerModels.parse_matpower(io)

        @test InfrastructureModels.compare_dict(source_data, destination_data)
    end

    @testset "test frankenstein_00" begin
        file = "../test/data/matpower/frankenstein_00.m"
        test_mp_idempotent(file, PowerModels.parse_file)
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case14" begin
        file = "../test/data/matpower/case14.m"
        test_mp_idempotent(file, PowerModels.parse_file)
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case2" begin
        file = "../test/data/matpower/case2.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case24" begin
        file = "../test/data/matpower/case24.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case3_tnep" begin
        file = "../test/data/matpower/case3_tnep.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case30" begin
        file = "../test/data/matpower/case30.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 asym" begin
        file = "../test/data/matpower/case5_asym.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 gap" begin
        file = "../test/data/matpower/case5_gap.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 strg" begin
        file = "../test/data/matpower/case5_strg.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    # currently not idempotent due to pwl function simplification
    #@testset "test case5 pwlc" begin
    #    file = "../test/data/matpower/case5_pwlc.m"
    #    test_mp_idempotent(file, PowerModels.parse_matpower)
    #end

    # line reversal, with line charging is not invertable
    #@testset "test case5" begin
    #    file = "../test/data/matpower/case5.m"
    #    test_mp_idempotent(file, PowerModels.parse_matpower)
    #end

    @testset "test case6" begin
        file = "../test/data/matpower/case6.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case3" begin
        file = "../test/data/matpower/case3.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 dc" begin
        file = "../test/data/matpower/case5_dc.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 tnep" begin
        file = "../test/data/matpower/case5_tnep.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case7 tplgy" begin
        file = "../test/data/matpower/case7_tplgy.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end
end


function test_mp_export(filename::AbstractString)
    source_data = PowerModels.parse_file(filename)
    test_mp_export(source_data)
end

function test_mp_export(data::Dict{String,<:Any})
    io = PipeBuffer()
    PowerModels.export_matpower(io, data)
    destination_data = PowerModels.parse_matpower(io)
    @test true
end


@testset "test matpower export to file" begin
    file_case = "../test/data/matpower/case5_gap.m"
    file_tmp = "../test/data/tmp.m"
    case_base = PowerModels.parse_file(file_case)

    export_matpower(file_tmp, case_base)

    case_tmp = PowerModels.parse_file(file_tmp)
    rm(file_tmp)

    @test InfrastructureModels.compare_dict(case_base, case_tmp)
end


@testset "test pti to matpower" begin
    # special string name edge case
    #@testset "test case3" begin
    #    file = "../test/data/pti/case3.raw"
    #    test_mp_export(file, PowerModels.parse_psse)
    #end

    @testset "test case5" begin
        file = "../test/data/pti/case5.raw"
        test_mp_export(file)
    end

    @testset "test case14" begin
        file = "../test/data/pti/case14.raw"
        test_mp_export(file)
    end

    @testset "test case24" begin
        file = "../test/data/pti/case24.raw"
        test_mp_export(file)
    end

end


@testset "test matpower export robustness" begin

    @testset "test adhoc data" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_strg.m")

        data["foo"] = [1.2, 3.4, 5.6]
        data["bar"] = Dict(1 => "a", 2 => "b", 3 => "c")

        data["adhoc_comp"] = Dict(
            "a" => Dict("val" => 1.2, "active" => false),
            "b" => Dict("val" => 3.4),
            "c" => Dict("val" => 5.6, "active" => true),
            "d" => Dict("val" => 1.1 + 2.3im),
        )

        data["adhoc_comp_2"] = Dict(
            3 => Dict("val" => 1.2),
            2 => Dict("val" => 3.4),
            1 => Dict("val" => 5.6)
        )

        data["bus"]["1"]["complex"] = 1 + 2im

        test_mp_export(data)
    end

end

