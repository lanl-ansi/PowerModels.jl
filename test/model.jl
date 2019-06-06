
@testset "JuMP model building" begin
    @testset "run with user provided JuMP model" begin
        m = JuMP.Model()
        x = JuMP.@variable(m, my_var >= 0, start=0.0)
        result = run_ac_opf("../test/data/matpower/case5.m", ipopt_solver, jump_model=m)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18269; atol = 1e0)
        @test m[:my_var] == x
    end

    @testset "build with user provided JuMP model" begin
        m = JuMP.Model()
        x = JuMP.@variable(m, my_var >= 0, start=0.0)
        pm = build_model("../test/data/matpower/case5.m", ACPPowerModel, PowerModels.post_opf, jump_model=m)

        @test JuMP.num_nl_constraints(pm.model) == 28
        @test JuMP.num_variables(pm.model) == 49

        @test pm.model[:my_var] == x
        @test m[:my_var] == x
    end
end



@testset "exports for usablity" begin
    @testset "with_optimizer and NLP status" begin
        result = run_opf("../test/data/matpower/case5.m", ACPPowerModel, with_optimizer(Ipopt.Optimizer, print_level=0))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test result["primal_status"] == FEASIBLE_POINT
        @test result["dual_status"] == FEASIBLE_POINT
        @test isapprox(result["objective"], 18269.1; atol = 1e0)
    end

    @testset "with_optimizer and LP status" begin
        result = run_opf("../test/data/matpower/case5.m", DCPPowerModel, with_optimizer(Cbc.Optimizer, logLevel=0))

        @test result["termination_status"] == OPTIMAL
        @test result["primal_status"] == FEASIBLE_POINT
        @test result["dual_status"] == NO_SOLUTION
        @test isapprox(result["objective"], 17613.2; atol = 1e0)
    end
end