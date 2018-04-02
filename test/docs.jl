

@testset "code snippets from docs" begin
    @testset "DATA.md - The Network Data Dictionary" begin
        network_data = PowerModels.parse_file("../test/data/matpower/case14.m")

        @test length(network_data["bus"]) == 14
        @test length(network_data["branch"]) == 20
    end

    @testset "README.md - Modifying Network Data" begin
        network_data = PowerModels.parse_file("../test/data/matpower/case3.m")

        result = run_opf(network_data, ACPPowerModel, IpoptSolver(print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5906.88; atol = 1e0)

        network_data["load"]["3"]["pd"] = 0.0
        network_data["load"]["3"]["qd"] = 0.0

        result = run_opf(network_data, ACPPowerModel, IpoptSolver(print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 2937.16; atol = 1e0)
    end

    @testset "README.md - JuMP Model Inspection" begin
        pm = build_generic_model("../test/data/matpower/case3.m", ACPPowerModel, PowerModels.post_opf)

        #pretty print the model to the terminal
        #print(pm.model)

        @test MathProgBase.numlinconstr(pm.model) == 8
        @test MathProgBase.numquadconstr(pm.model) == 12
        @test MathProgBase.numconstr(pm.model) - MathProgBase.numlinconstr(pm.model) - MathProgBase.numquadconstr(pm.model) == 12
        @test MathProgBase.numvar(pm.model) == 28

        result = solve_generic_model(pm, IpoptSolver(print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5906.88; atol = 1e0)
    end
end
