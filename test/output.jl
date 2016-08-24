
@testset "test output api" begin
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.json", ACPPowerModel, IpoptSolver(tol=1e-6, print_level=0))

        @test haskey(result, "solver") == true
        @test haskey(result, "status") == true
        @test haskey(result, "objective") == true
        @test haskey(result, "objective_lb") == true
        @test haskey(result, "solve_time") == true
        @test haskey(result, "machine") == true
        @test haskey(result, "data") == true
        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == false
        
        @test !isnan(result["solve_time"])

        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33
    end
end

@testset "test line flow output" begin
    @testset "24-bus rts case ac opf" begin
        result = run_opf("../test/data/case24.json", ACPPowerModel, IpoptSolver(tol=1e-6, print_level=0); setting = Dict("output" => Dict("line_flows" => true)))

        @test haskey(result, "solver") == true
        @test haskey(result, "status") == true
        @test haskey(result, "objective") == true
        @test haskey(result, "objective_lb") == true
        @test haskey(result, "solve_time") == true
        @test haskey(result, "machine") == true
        @test haskey(result, "data") == true
        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true
        
        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33
        @test length(result["solution"]["branch"]) == 38

        branches = result["solution"]["branch"]

        @test isapprox(branches[2]["p_from"],  20.01; atol = 1e-1)
        @test isapprox(branches[2]["p_to"],   -19.80; atol = 1e-1)
        @test isapprox(branches[2]["q_from"],   0.55; atol = 1e-1)
        @test isapprox(branches[2]["q_to"],    -5.71; atol = 1e-1)
    end

    # A DCPPowerModel test is important because it does have variables for the reverse side of the lines
    @testset "3-bus case dc opf" begin
        result = run_opf("../test/data/case3.json", DCPPowerModel, IpoptSolver(tol=1e-6, print_level=0); setting = Dict("output" => Dict("line_flows" => true)))

        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true
        
        @test length(result["solution"]["bus"]) == 3
        @test length(result["solution"]["gen"]) == 3
        @test length(result["solution"]["branch"]) == 3

        branches = result["solution"]["branch"]

        @test isapprox(branches[3]["p_from"], -10.34; atol = 1e-1)
        @test isapprox(branches[3]["p_to"],    10.34; atol = 1e-1)
        @test isnan(branches[3]["q_from"])
        @test isnan(branches[3]["q_to"])
    end
end