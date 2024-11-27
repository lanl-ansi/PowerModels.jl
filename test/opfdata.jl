@testset "test opfdata parser" begin
    @testset "example 1 opf data case 30 (parse_file)" begin
        data = PowerModels.parse_file("../test/data/opfdata/example_1.json")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 6935.242110031468; atol = 1e0)
    end
end
