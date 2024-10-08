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
            [1, 3, 0.0, 0.0, 0.0, 0.0, 1, 1.06, -0.0, 132.0, 1, 1.06, 0.94],
            [2, 2, 21.7, 12.7, 0.0, 0.0, 1, 1.03591, -4.11149, 132.0, 1, 1.06, 0.94],
            [3, 1, 2.4, 1.2, 0.0, 0.0, 1, 1.01502, -6.85372, 132.0, 1, 1.06, 0.94],
            [4, 1, 7.6, 1.6, 0.0, 0.0, 1, 1.00446, -8.44574, 132.0, 1, 1.06, 0.94],
            [5, 2, 94.2, 19.0, 0.0, 0.0, 1, 0.99748, -13.13219, 132.0, 1, 1.06, 0.94],
            [6, 1, 0.0, 0.0, 0.0, 0.0, 1, 1.0017, -10.15671, 132.0, 1, 1.06, 0.94],
            [7, 1, 22.8, 10.9, 0.0, 0.0, 1, 0.99208, -11.91706, 132.0, 1, 1.06, 0.94],
            [8, 2, 30.0, 30.0, 0.0, 0.0, 1, 1.00241, -10.93461, 132.0, 1, 1.06, 0.94],
            [9, 1, 0.0, 0.0, 0.0, 0.0, 1, 1.03671, -13.26615, 1.0, 1, 1.06, 0.94],
            [10, 1, 5.8, 2.0, 0.0, 19.0, 1, 1.0322, -14.8973, 33.0, 1, 1.06, 0.94],
            [11, 2, 0.0, 0.0, 0.0, 0.0, 1, 1.06, -13.26615, 11.0, 1, 1.06, 0.94],
            [12, 1, 11.2, 7.5, 0.0, 0.0, 1, 1.04625, -14.18878, 33.0, 1, 1.06, 0.94],
            [13, 2, 0.0, 0.0, 0.0, 0.0, 1, 1.06, -14.18878, 11.0, 1, 1.06, 0.94],
            [14, 1, 6.2, 1.6, 0.0, 0.0, 1, 1.03103, -15.09457, 33.0, 1, 1.06, 0.94],
            [15, 1, 8.2, 2.5, 0.0, 0.0, 1, 1.02621, -15.17834, 33.0, 1, 1.06, 0.94],
            [16, 1, 3.5, 1.8, 0.0, 0.0, 1, 1.03259, -14.7532, 33.0, 1, 1.06, 0.94],
            [17, 1, 9.0, 5.8, 0.0, 0.0, 1, 1.02726, -15.07475, 33.0, 1, 1.06, 0.94],
            [18, 1, 3.2, 0.9, 0.0, 0.0, 1, 1.01602, -15.79032, 33.0, 1, 1.06, 0.94],
            [19, 1, 9.5, 3.4, 0.0, 0.0, 1, 1.01317, -15.95831, 33.0, 1, 1.06, 0.94],
            [20, 1, 2.2, 0.7, 0.0, 0.0, 1, 1.01714, -15.75153, 33.0, 1, 1.06, 0.94],
            [21, 1, 17.5, 11.2, 0.0, 0.0, 1, 1.01982, -15.35269, 33.0, 1, 1.06, 0.94],
            [22, 1, 0.0, 0.0, 0.0, 0.0, 1, 1.02041, -15.3386, 33.0, 1, 1.06, 0.94],
            [23, 1, 3.2, 1.6, 0.0, 0.0, 1, 1.01532, -15.564, 33.0, 1, 1.06, 0.94],
            [24, 1, 8.7, 6.7, 0.0, 4.3, 1, 1.0093, -15.72597, 33.0, 1, 1.06, 0.94],
            [25, 1, 0.0, 0.0, 0.0, 0.0, 1, 1.00621, -15.29138, 33.0, 1, 1.06, 0.94],
            [26, 1, 3.5, 2.3, 0.0, 0.0, 1, 0.98833, -15.72053, 33.0, 1, 1.06, 0.94],
            [27, 1, 0.0, 0.0, 0.0, 0.0, 1, 1.01294, -14.75624, 33.0, 1, 1.06, 0.94],
            [28, 1, 0.0, 0.0, 0.0, 0.0, 1, 0.99824, -10.79567, 132.0, 1, 1.06, 0.94],
            [29, 1, 2.4, 0.9, 0.0, 0.0, 1, 0.99288, -16.01182, 33.0, 1, 1.06, 0.94],
            [30, 1, 10.6, 1.9, 0.0, 0.0, 1, 0.98128, -16.91371, 33.0, 1, 1.06, 0.94]
        ]
        matlab_data["mpc.version"::String] = "2"
        matlab_data["mpc.baseMVA"::String] = 100
        matlab_data["mpc.gencost"::String] = [
            [2, 0.0, 0.0, 3, 0.0, 0.521378, 0.0],
            [2, 0.0, 0.0, 3, 0.0, 1.135166, 0.0],
            [2, 0.0, 0.0, 3, 0.0, 0.0, 0.0],
            [2, 0.0, 0.0, 3, 0.0, 0.0, 0.0],
            [2, 0.0, 0.0, 3, 0.0, 0.0, 0.0],
            [2, 0.0, 0.0, 3, 0.0, 0.0, 0.0]
        ]
        matlab_data["mpc.gen"::String] = [
            [1, 218.839, 9.372, 10.0, 0.0, 1.06, 100.0, 1, 784, 0.0],
            [2, 80.05, 24.589, 50.0, -40.0, 1.03591, 100.0, 1, 100, 0.0],
            [5, 0.0, 32.487, 40.0, -40.0, 0.99748, 100.0, 1, 0, 0.0],
            [8, 0.0, 40.0, 40.0, -10.0, 1.00241, 100.0, 1, 0, 0.0],
            [11, 0.0, 11.87, 24.0, -6.0, 1.06, 100.0, 1, 0, 0.0],
            [13, 0.0, 10.414, 24.0, -6.0, 1.06, 100.0, 1, 0, 0.0]
        ]
        matlab_data["mpc.branch"::String] = [
            [1, 2, 0.0192, 0.0575, 0.0528, 138, 138, 138, 0.0, 0.0, 1, -30.0, 30.0],
            [1, 3, 0.0452, 0.1652, 0.0408, 152, 152, 152, 0.0, 0.0, 1, -30.0, 30.0],
            [2, 4, 0.057, 0.1737, 0.0368, 139, 139, 139, 0.0, 0.0, 1, -30.0, 30.0],
            [3, 4, 0.0132, 0.0379, 0.0084, 135, 135, 135, 0.0, 0.0, 1, -30.0, 30.0],
            [2, 5, 0.0472, 0.1983, 0.0418, 144, 144, 144, 0.0, 0.0, 1, -30.0, 30.0],
            [2, 6, 0.0581, 0.1763, 0.0374, 139, 139, 139, 0.0, 0.0, 1, -30.0, 30.0],
            [4, 6, 0.0119, 0.0414, 0.009, 148, 148, 148, 0.0, 0.0, 1, -30.0, 30.0],
            [5, 7, 0.046, 0.116, 0.0204, 127, 127, 127, 0.0, 0.0, 1, -30.0, 30.0],
            [6, 7, 0.0267, 0.082, 0.017, 140, 140, 140, 0.0, 0.0, 1, -30.0, 30.0],
            [6, 8, 0.012, 0.042, 0.009, 148, 148, 148, 0.0, 0.0, 1, -30.0, 30.0],
            [6, 9, 0.0, 0.208, 0.0, 142, 142, 142, 0.978, 0.0, 1, -30.0, 30.0],
            [6, 10, 0.0, 0.556, 0.0, 53, 53, 53, 0.969, 0.0, 1, -30.0, 30.0],
            [9, 11, 0.0, 0.208, 0.0, 142, 142, 142, 0.0, 0.0, 1, -30.0, 30.0],
            [9, 10, 0.0, 0.11, 0.0, 267, 267, 267, 0.0, 0.0, 1, -30.0, 30.0],
            [4, 12, 0.0, 0.256, 0.0, 115, 115, 115, 0.932, 0.0, 1, -30.0, 30.0],
            [12, 13, 0.0, 0.14, 0.0, 210, 210, 210, 0.0, 0.0, 1, -30.0, 30.0],
            [12, 14, 0.1231, 0.2559, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [12, 15, 0.0662, 0.1304, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [12, 16, 0.0945, 0.1987, 0.0, 30, 30, 30, 0.0, 0.0, 1, -30.0, 30.0],
            [14, 15, 0.221, 0.1997, 0.0, 20, 20, 20, 0.0, 0.0, 1, -30.0, 30.0],
            [16, 17, 0.0524, 0.1923, 0.0, 38, 38, 38, 0.0, 0.0, 1, -30.0, 30.0],
            [15, 18, 0.1073, 0.2185, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [18, 19, 0.0639, 0.1292, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [19, 20, 0.034, 0.068, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [10, 20, 0.0936, 0.209, 0.0, 30, 30, 30, 0.0, 0.0, 1, -30.0, 30.0],
            [10, 17, 0.0324, 0.0845, 0.0, 33, 33, 33, 0.0, 0.0, 1, -30.0, 30.0],
            [10, 21, 0.0348, 0.0749, 0.0, 30, 30, 30, 0.0, 0.0, 1, -30.0, 30.0],
            [10, 22, 0.0727, 0.1499, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [21, 22, 0.0116, 0.0236, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [15, 23, 0.1, 0.202, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [22, 24, 0.115, 0.179, 0.0, 26, 26, 26, 0.0, 0.0, 1, -30.0, 30.0],
            [23, 24, 0.132, 0.27, 0.0, 29, 29, 29, 0.0, 0.0, 1, -30.0, 30.0],
            [24, 25, 0.1885, 0.3292, 0.0, 27, 27, 27, 0.0, 0.0, 1, -30.0, 30.0],
            [25, 26, 0.2544, 0.38, 0.0, 25, 25, 25, 0.0, 0.0, 1, -30.0, 30.0],
            [25, 27, 0.1093, 0.2087, 0.0, 28, 28, 28, 0.0, 0.0, 1, -30.0, 30.0],
            [28, 27, 0.0, 0.396, 0.0, 75, 75, 75, 0.968, 0.0, 1, -30.0, 30.0],
            [27, 29, 0.2198, 0.4153, 0.0, 28, 28, 28, 0.0, 0.0, 1, -30.0, 30.0],
            [27, 30, 0.3202, 0.6027, 0.0, 28, 28, 28, 0.0, 0.0, 1, -30.0, 30.0],
            [29, 30, 0.2399, 0.4533, 0.0, 28, 28, 28, 0.0, 0.0, 1, -30.0, 30.0],
            [8, 28, 0.0636, 0.2, 0.0428, 140, 140, 140, 0.0, 0.0, 1, -30.0, 30.0],
            [6, 28, 0.0169, 0.0599, 0.013, 149, 149, 149, 0.0, 0.0, 1, -30.0, 30.0]
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

