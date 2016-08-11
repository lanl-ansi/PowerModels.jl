

@testset "test ac opf" begin
    @testset "3-bus case" begin
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = AC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5812; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf_file(;file = "../test/data/case24.json", model_builder = AC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
end


@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = DC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5695; atol = 1e0)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf_file(;file = "../test/data/case24.json", model_builder = DC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
end


@testset "test soc opf" begin
    @testset "3-bus case" begin
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = SOC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5735.9; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf_file(;file = "../test/data/case24.json", model_builder = SOC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70831; atol = 1e0)
    end
end


@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = QC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5742.0; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf_file(;file = "../test/data/case24.json", model_builder = QC_OPF, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 77049; atol = 1e0)
    end
end


@testset "test SDP opf" begin
    @testset "3-bus case" begin
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = SDP_OPF, solver = SCSSolver(max_iters=1000000, verbose=0))

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5788.7; atol = 1e0)
    end
    # TODO replace this with smaller case, way too slow for regression testing
    #@testset "24-bus rts case" begin
    #    result = run_opf_file(;file = "../test/data/case24.json", model_builder = SDP_OPF, solver = SCSSolver(max_iters=1000000, verbose=0))
    #
    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end




