@testset "test ac api" begin
    @testset "3-bus case" begin
        result = run_api_opf("../test/data/case3.json", APIACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1.3375; atol = 1e-3)
        @test isapprox(result["solution"]["bus"][1]["pd"], 147.1; atol = 1e0)
    end
    @testset "5-bus pjm case" begin
        result = run_api_opf("../test/data/case5.json", APIACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 2.6885; atol = 1e-3)
        @test isapprox(result["solution"]["bus"][4]["pd"], 1075.4; atol = 1e0)
    end
    @testset "30-bus ieee case" begin
        result = run_api_opf("../test/data/case30.json", APIACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1.6632; atol = 1e-3)
        @test isapprox(result["solution"]["bus"][2]["pd"], 36.1; atol = 1e0)
    end
end


#=
@testset "test ac sad" begin
    @testset "3-bus case" begin
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = AC_SAD, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0.3144; atol = 1e-2)
    end
    @testset "5-bus pjm case" begin
        result = run_opf_file(;file = "../test/data/case5.json", model_builder = AC_SAD, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0.02233; atol = 1e-2)
    end
    @testset "30-bus ieee case" begin
        result = run_opf_file(;file = "../test/data/case30.json", model_builder = AC_SAD, solver = IpoptSolver(tol=1e-6, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0.1537; atol = 1e-2)
    end
end
=#