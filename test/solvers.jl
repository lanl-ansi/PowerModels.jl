

@testset "test solver builders" begin
    # NOTE these tests should only include the subset of solvers used in unit testing

    @testset "ipopt solver" begin
        solver = build_solver(IPOPT_SOLVER)
        @test length(solver.options) == 2
    end

    @testset "scs solver" begin
        solver = build_solver(SCS_SOLVER)
        @test length(solver.options) == 1
    end
end


@testset "test solver builders settings" begin

    @testset "default value overide" begin
        solver = build_solver(IPOPT_SOLVER, tol=1.0)
        @test length(solver.options) == 2
        @test solver.options[1][2] == 1.0
    end

    @testset "default extra values" begin
        solver = build_solver(IPOPT_SOLVER, param="bloop")
        @test length(solver.options) == 3
        @test solver.options[1][1] == :param
        @test solver.options[1][2] == "bloop"
    end

    @testset "load from file" begin
        solver = build_solver_file("../test/data/ipopt.json")
        @test length(solver.options) == 2
    end
end


