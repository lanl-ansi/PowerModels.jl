
@testset "code snippets from docs" begin
    @testset "DATA.md - The Network Data Dictionary" begin
        network_data = PowerModels.parse_file("$(Pkg.dir("PowerModels"))/test/data/case14.m")

        @test length(network_data["bus"]) == 14
        @test length(network_data["branch"]) == 20
    end

    @testset "README.md - Modifying Network Data" begin
        network_data = PowerModels.parse_file("$(Pkg.dir("PowerModels"))/test/data/case3.m")

        result = run_opf(network_data, ACPPowerModel, IpoptSolver(print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5812.64; atol = 1e0)

        network_data["bus"][3]["pd"] = 0.0
        network_data["bus"][3]["qd"] = 0.0

        result = run_opf(network_data, ACPPowerModel, IpoptSolver(print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 2933.85; atol = 1e0)
    end
end

