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

end
