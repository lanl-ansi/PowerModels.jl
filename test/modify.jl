

@testset "data modification tests" begin
    @testset "30-bus case file incremental" begin
        data = PowerModels.parse_file("../test/data/matpower/case30.m")

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)

        data["branch"]["6"]["br_status"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 195.25; atol = 1e-1)

        data["gen"]["6"]["gen_status"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 195.896; atol = 1e-1)

        data["load"]["4"]["pd"] = 0
        data["load"]["4"]["qd"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 104.428; atol = 1e-1)
    end

    @testset "30-bus case file batch" begin
        data = PowerModels.parse_file("../test/data/matpower/case30.m")

        data_delta = JSON.parse("
        {
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
            \"load\":{
                \"4\":{
                    \"pd\":0,
                    \"qd\":0
                }
            }
        }")

        PowerModels.update_data!(data, data_delta)

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 104.428; atol = 1e-1)
    end
end
