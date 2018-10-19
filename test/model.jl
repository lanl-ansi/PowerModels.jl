
@testset "JuMP model building" begin
    @testset "run with user provided JuMP model" begin
        m = Model()
        x = @variable(m, my_var >= 0)
        result = run_ac_opf("../test/data/matpower/case5.m", ipopt_solver, jump_model=m)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 18269; atol = 1e0)
        @test m[:my_var] == x
    end

    @testset "build with user provided JuMP model" begin
        m = Model()
        x = @variable(m, my_var >= 0)
        pm = build_generic_model("../test/data/matpower/case5.m", ACPPowerModel, PowerModels.post_opf, jump_model=m)

        @test MathProgBase.numlinconstr(pm.model) == 13
        @test MathProgBase.numquadconstr(pm.model) == 24
        @test MathProgBase.numconstr(pm.model) - MathProgBase.numlinconstr(pm.model) - MathProgBase.numquadconstr(pm.model) == 28
        @test MathProgBase.numvar(pm.model) == 49

        @test pm.model[:my_var] == x
        @test m[:my_var] == x
    end
end
