
@testset "code snippets from docs" begin
    @testset "DATA.md - The Network Data Dictionary" begin
        network_data = PowerModels.parse_file("../test/data/matpower/case14.m")

        @test length(network_data["bus"]) == 14
        @test length(network_data["branch"]) == 20
    end

    @testset "README.md - Modifying Network Data" begin
        network_data = PowerModels.parse_file("../test/data/matpower/case3.m")

        result = run_opf(network_data, ACPPowerModel, JuMP.with_optimizer(Ipopt.Optimizer, print_level=0))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5906.88; atol = 1e0)

        network_data["load"]["3"]["pd"] = 0.0
        network_data["load"]["3"]["qd"] = 0.0

        result = run_opf(network_data, ACPPowerModel, JuMP.with_optimizer(Ipopt.Optimizer, print_level=0))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2937.16; atol = 1e0)
    end

    @testset "README.md - JuMP Model Inspection" begin
        pm = build_model("../test/data/matpower/case3.m", ACPPowerModel, PowerModels.post_opf)

        #pretty print the model to the terminal
        #print(pm.model)

        @test JuMP.num_nl_constraints(pm.model) == 12
        @test JuMP.num_variables(pm.model) == 28

        result = optimize_model!(pm, JuMP.with_optimizer(Ipopt.Optimizer, print_level=0))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5906.88; atol = 1e0)
    end
end
