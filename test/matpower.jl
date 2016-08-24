@testset "test matpower parser" begin
    @testset "30-bus case" begin
        result = run_opf("../test/data/case30.m", ACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end
end

@testset "test matpower data coercion" begin
    @testset "ACP Model" begin
        result = run_opf("../test/data/case14.m", ACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 8081.5; atol = 1e0)
    end
    @testset "DC Model" begin
        result = run_opf("../test/data/case14.m", DCPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 7642.6; atol = 1e0)
    end
    @testset "QC Model" begin
        result = run_opf("../test/data/case14.m", QCWRPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 8075.1; atol = 1e0)
    end
end
