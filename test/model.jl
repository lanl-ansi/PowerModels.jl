
@testset "JuMP model building" begin
    @testset "run with user provided JuMP model" begin
        m = JuMP.Model()
        x = JuMP.@variable(m, my_var >= 0, start=0.0)
        result = solve_ac_opf("../test/data/matpower/case5.m", nlp_solver, jump_model=m)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18269; atol = 1e0)
        @test m[:my_var] == x
    end

    @testset "build with user provided JuMP model" begin
        m = JuMP.Model()
        x = JuMP.@variable(m, my_var >= 0, start=0.0)
        pm = instantiate_model("../test/data/matpower/case5.m", ACPPowerModel, PowerModels.build_opf, jump_model=m)

        @test JuMP.num_nonlinear_constraints(pm.model) == 0
        @test JuMP.num_constraints(pm.model, JuMP.NonlinearExpr, JuMP.MOI.EqualTo{Float64}) == 28
        @test JuMP.num_variables(pm.model) == 49

        @test pm.model[:my_var] == x
        @test m[:my_var] == x
    end

    @testset "run with user provided JuMP model in direct mode" begin
        m = JuMP.direct_model(HiGHS.Optimizer())
        JuMP.set_optimizer_attribute(m, "output_flag", false)
        result = solve_dc_opf("../test/data/matpower/case5.m", milp_solver, jump_model=m)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 17613; atol = 1e0)
    end
end



@testset "exports for usablity" begin
    @testset "optimizer_with_attributes and NLP status" begin
        result = solve_opf("../test/data/matpower/case5.m", ACPPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test result["primal_status"] == FEASIBLE_POINT
        @test result["dual_status"] == FEASIBLE_POINT
        @test isapprox(result["objective"], 18269.1; atol = 1e0)
    end

    @testset "optimizer_with_attributes and LP status" begin
        result = solve_opf("../test/data/matpower/case5.m", DCPPowerModel, optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false))

        @test result["termination_status"] == OPTIMAL
        @test result["primal_status"] == FEASIBLE_POINT
        @test result["dual_status"] == FEASIBLE_POINT
        @test isapprox(result["objective"], 17613.2; atol = 1e0)
    end
end



@testset "relax integrality" begin
    @testset "relax OTS model" begin
        result = solve_ots("../test/data/matpower/case5.m", DCPPowerModel, nlp_solver, relax_integrality=true)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)

        br_status_total = sum(branch["br_status"] for (i,branch) in result["solution"]["branch"])
        @test (br_status_total >= 5.100)
    end

    @testset "relax TNEP model" begin
        result = solve_tnep("../test/data/matpower/case5_tnep.m", SOCWRPowerModel, nlp_solver, relax_integrality=true)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0.1236; atol = 1e-2)
    end
end

