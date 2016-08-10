
@testset "test output api" begin
    @testset "24-bus rts case" begin
        result = run_opf_file(; file = "../test/data/case24.json")

        @test haskey(result, "solver") == true
        @test haskey(result, "status") == true
        @test haskey(result, "objective") == true
        @test haskey(result, "objective_lb") == true
        @test haskey(result, "solve_time") == true
        @test haskey(result, "machine") == true
        @test haskey(result, "data") == true
        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == false
        
        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33
        
    end
end

@testset "test line flow output" begin
    @testset "24-bus rts case opf" begin
        result = run_power_model_file("../test/data/case24.json", AC_OPF, build_solver(IPOPT_SOLVER), Dict("output" => Dict("line_flows" => true)))

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
        
    end
end