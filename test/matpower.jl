@testset "test matpower parser" begin
    @testset "30-bus case" begin
        result = run_opf("../test/data/case30.m", ACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end
end