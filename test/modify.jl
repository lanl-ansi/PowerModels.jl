

@testset "data modification tests" begin
    @testset "30-bus case file incremental" begin
        data = PowerModels.parse_file("../test/data/case30.m")

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 204.96; atol = 1e-1)

        data["base"]["branch"]["6"]["br_status"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 195.25; atol = 1e-1)

        data["base"]["gen"]["6"]["gen_status"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 195.896; atol = 1e-1)

        data["base"]["bus"]["5"]["pd"] = 0
        data["base"]["bus"]["5"]["qd"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 104.428; atol = 1e-1)
    end

    @testset "30-bus case file batch" begin
        data = PowerModels.parse_file("../test/data/case30.m")

        data_delta = JSON.parse("
        {
            \"base\":{
                \"branch\":{
                    \"6\":{
                        \"br_status\":0
                    }
                },
                \"gen\":{
                    \"6\":{
                        \"gen_status\":0
                    }
                },
                \"bus\":{
                    \"5\":{
                        \"pd\":0,
                        \"qd\":0
                    }
                }
            }
        }")

        PowerModels.update_data(data, data_delta)

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 104.428; atol = 1e-1)
    end
end