@testset "test matpower parser" begin
    @testset "30-bus case" begin
        result = run_opf_file(;file = "../test/data/case30.m", model_builder = AC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end
end