

@testset "test ac opf" begin
    @testset "3-bus case" begin
        result = run_ac_opf("../test/data/case3.json", IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5812; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.json", ACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
end


@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = run_dc_opf("../test/data/case3.json", IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5695; atol = 1e0)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/case24.json", DCPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
end


@testset "test soc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.json", SOCWRPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5735.9; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.json", SOCWRPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70831; atol = 1e0)
    end
end


@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.json", QCWRPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5742.0; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.json", QCWRPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 77049; atol = 1e0)
    end
end


@testset "test sdp opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.json", SDPWRMPowerModel, SCSSolver(max_iters=1000000, verbose=0))

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5788.7; atol = 1e0)
    end
    # TODO replace this with smaller case, way too slow for unit testing
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/case24.json", SDPWRMPowerModel, SCSSolver(max_iters=1000000, verbose=0))

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end




