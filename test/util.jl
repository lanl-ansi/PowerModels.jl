
@testset "obbt with trilinear convex hull relaxation" begin
    @testset "3-bus case" begin
        result_ac = run_ac_opf("../test/data/matpower/case3.m", ipopt_solver);
        upper_bound = result_ac["objective"]

        data, stats = run_obbt_opf("../test/data/matpower/case3.m", ipopt_solver, model_constructor=QCWRTriPowerModel);
        @test isapprox(stats["final_relaxation_objective"], 5901.96; atol=1e0)
        @test isnan(stats["final_rel_gap_from_ub"])
        @test stats["iteration_count"] == 5

        data, stats = run_obbt_opf("../test/data/matpower/case3.m", ipopt_solver, 
            model_constructor = QCWRTriPowerModel,
            upper_bound = upper_bound, 
            upper_bound_constraint = true, 
            rel_gap_tol = 1e-3);
        @test isapprox(stats["final_rel_gap_from_ub"], 0; atol=1e0)
        @test stats["iteration_count"] == 2
        @test isapprox(stats["vm_range_final"], 0.0793; atol=1e0)

    end
end

@testset "obbt with qc relaxation" begin
    @testset "3-bus case" begin
        result_ac = run_ac_opf("../test/data/matpower/case3.m", ipopt_solver);
        upper_bound = result_ac["objective"]

        data, stats = run_obbt_opf("../test/data/matpower/case3.m", ipopt_solver, model_constructor=QCWRPowerModel);
        @test isapprox(stats["final_relaxation_objective"], 5900.04; atol=1e0)
        @test isnan(stats["final_rel_gap_from_ub"])
        @test stats["iteration_count"] == 5

        data, stats = run_obbt_opf("../test/data/matpower/case3.m", ipopt_solver, 
            model_constructor = QCWRPowerModel,
            upper_bound = upper_bound, 
            upper_bound_constraint = true, 
            rel_gap_tol = 1e-3);
        @test isapprox(stats["final_rel_gap_from_ub"], 0; atol=1e0)
        @test stats["iteration_count"] == 2
        @test isapprox(stats["vm_range_final"], 0.148; atol=1e0)
    
    end

end