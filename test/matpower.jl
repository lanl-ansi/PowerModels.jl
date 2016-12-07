@testset "test matpower parser" begin
    @testset "30-bus case file" begin
        result = run_opf("../test/data/case30.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data" begin
        data = PowerModels.parse_file("../test/data/case30.m")
        result = run_opf(data, ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "14-bus case file with names" begin
        data = PowerModels.parse_file("../test/data/case14.m")
        @test data["bus"][1]["bus_name"] == "Bus 1     HV"
    end

    @testset "2-bus case file with spaces" begin
        result = run_opf("../test/data/case2.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 184.70; atol = 1e-1)
    end
end

@testset "test matpower data coercion" begin
    @testset "ACP Model" begin
        result = run_opf("../test/data/case14.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 8081.5; atol = 1e0)
        #@test result["status"] = bus_name
    end
    @testset "DC Model" begin
        result = run_opf("../test/data/case14.m", DCPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 7642.6; atol = 1e0)
    end
    @testset "QC Model" begin
        result = run_opf("../test/data/case14.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 8075.1; atol = 1e0)
    end
end

@testset "test matpower extentions parser" begin
    @testset "3-bus extended constants" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test data["const_int"] == 123
        @test data["const_float"] == 4.56
        @test data["const_str"] == "a string"
    end

    @testset "3-bus extended matrix" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test haskey(data, "areas")
        @test data["areas"][1]["col_1"] == 1
        @test data["areas"][1]["col_2"] == 1
        @test data["areas"][2]["col_1"] == 2
        @test data["areas"][2]["col_2"] == 3
    end

    @testset "3-bus extended named matrix" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test haskey(data, "areas_named")
        @test data["areas_named"][1]["area"] == 4
        @test data["areas_named"][1]["refbus"] == 5
        @test data["areas_named"][2]["area"] == 5
        @test data["areas_named"][2]["refbus"] == 6
    end

    @testset "3-bus extended predefined matrix" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test haskey(data, "areas_named")
        @test data["branch"][1]["rate_i"] == 50.2
        @test data["branch"][1]["rate_p"] == 45
        @test data["branch"][2]["rate_i"] == 36
        @test data["branch"][2]["rate_p"] == 60.1
        @test data["branch"][3]["rate_i"] == 12
        @test data["branch"][3]["rate_p"] == 30
    end


    @testset "3-bus extended matrix from cell" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test haskey(data, "areas_cells")
        @test data["areas_cells"][1]["col_1"] == "Area 1"
        @test data["areas_cells"][1]["col_2"] == 123
        @test data["areas_cells"][1]["col_4"] == "Slack 'Bus' 1"
        @test data["areas_cells"][1]["col_5"] == 1.23
        @test data["areas_cells"][2]["col_1"] == "Area 2"
        @test data["areas_cells"][2]["col_2"] == 456
        @test data["areas_cells"][2]["col_4"] == "Slack Bus 3"
        @test data["areas_cells"][2]["col_5"] == 4.56
    end

    @testset "3-bus extended named matrix from cell" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test haskey(data, "areas_named_cells")
        @test data["areas_named_cells"][1]["area_name"] == "Area 1"
        @test data["areas_named_cells"][1]["area"] == 123
        @test data["areas_named_cells"][1]["area2"] == 987
        @test data["areas_named_cells"][1]["refbus_name"] == "Slack Bus 1"
        @test data["areas_named_cells"][1]["refbus"] == 1.23
        @test data["areas_named_cells"][2]["area_name"] == "Area 2"
        @test data["areas_named_cells"][2]["area"] == 456
        @test data["areas_named_cells"][2]["area2"] == 987
        @test data["areas_named_cells"][2]["refbus_name"] == "Slack Bus 3"
        @test data["areas_named_cells"][2]["refbus"] == 4.56
    end

    @testset "3-bus extended predefined matrix from cell" begin
        data = PowerModels.parse_file("../test/data/case3.m")

        @test haskey(data, "areas_named")
        @test data["branch"][1]["name"] == "Branch 1"
        @test data["branch"][1]["number_id"] == 123
        @test data["branch"][2]["name"] == "Branch 2"
        @test data["branch"][2]["number_id"] == 456
        @test data["branch"][3]["name"] == "Branch 3"
        @test data["branch"][3]["number_id"] == 789
    end
end

