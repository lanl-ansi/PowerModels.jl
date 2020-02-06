
@testset "obbt with trilinear convex hull relaxation" begin
    @testset "3-bus case" begin
        result_ac = run_ac_opf("../test/data/matpower/case3.m", ipopt_solver);
        upper_bound = result_ac["objective"]

        data, stats = run_obbt_opf!("../test/data/matpower/case3.m", ipopt_solver, model_type=QCLSPowerModel);
        @test isapprox(stats["final_relaxation_objective"], 5901.96; atol=1e0)
        @test isnan(stats["final_rel_gap_from_ub"])
        @test stats["iteration_count"] == 5

        data, stats = run_obbt_opf!("../test/data/matpower/case3.m", ipopt_solver, 
            model_type = QCLSPowerModel,
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

        data, stats = run_obbt_opf!("../test/data/matpower/case3.m", ipopt_solver, model_type=QCRMPowerModel);
        @test isapprox(stats["final_relaxation_objective"], 5900.04; atol=1e0)
        @test isnan(stats["final_rel_gap_from_ub"])
        @test stats["iteration_count"] == 5

        data, stats = run_obbt_opf!("../test/data/matpower/case3.m", ipopt_solver, 
            model_type = QCRMPowerModel,
            upper_bound = upper_bound, 
            upper_bound_constraint = true, 
            rel_gap_tol = 1e-3);
        @test isapprox(stats["final_rel_gap_from_ub"], 0; atol=1e0)
        @test stats["iteration_count"] == 2
        @test isapprox(stats["vm_range_final"], 0.148; atol=1e0)
    end

    @testset "3-bus linear case" begin
        # tests with linear objective function
        data = PowerModels.parse_file("../test/data/matpower/case3.m")
        data["gen"]["1"]["cost"] = data["gen"]["1"]["cost"][2:3]
        data["gen"]["2"]["cost"] = data["gen"]["2"]["cost"][2:3]

        result_ac = run_ac_opf(data, ipopt_solver);
        upper_bound = result_ac["objective"]

        data, stats = run_obbt_opf!(data, ipopt_solver,
            model_type=QCRMPowerModel,
            upper_bound = upper_bound,
            upper_bound_constraint = true);
        @test isapprox(stats["final_relaxation_objective"], 982.216; atol=1e0)
        @test isapprox(stats["final_rel_gap_from_ub"], 0.0; atol=1e-2)
        @test stats["iteration_count"] == 4
    end
end


@testset "opf with flow cuts" begin
    @testset "ac 5-bus case" begin
        result_base = run_opf("../test/data/matpower/case5.m", ACPPowerModel, ipopt_solver)
        result_cuts = run_opf_flow_cuts("../test/data/matpower/case5.m", ACPPowerModel, ipopt_solver)

        @test result_base["termination_status"] == LOCALLY_SOLVED
        @test result_cuts["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,bus) in result_base["solution"]["bus"]
            @test isapprox(result_base["solution"]["bus"][i]["vm"], result_cuts["solution"]["bus"][i]["vm"]; atol = 1e-7)
            @test isapprox(result_base["solution"]["bus"][i]["va"], result_cuts["solution"]["bus"][i]["va"]; atol = 1e-7)
        end
    end
    @testset "ac 14-bus case" begin
        result_base = run_opf("../test/data/matpower/case14.m", ACPPowerModel, ipopt_solver)
        result_cuts = run_opf_flow_cuts("../test/data/matpower/case14.m", ACPPowerModel, ipopt_solver)

        @test result_base["termination_status"] == LOCALLY_SOLVED
        @test result_cuts["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,bus) in result_base["solution"]["bus"]
            @test isapprox(result_base["solution"]["bus"][i]["vm"], result_cuts["solution"]["bus"][i]["vm"]; atol = 1e-8)
            @test isapprox(result_base["solution"]["bus"][i]["va"], result_cuts["solution"]["bus"][i]["va"]; atol = 1e-8)
        end
    end

    @testset "soc 5-bus case" begin
        result_base = run_opf("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver)
        result_cuts = run_opf_flow_cuts("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver)

        @test result_base["termination_status"] == LOCALLY_SOLVED
        @test result_cuts["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,bus) in result_base["solution"]["bus"]
            @test isapprox(result_base["solution"]["bus"][i]["w"], result_cuts["solution"]["bus"][i]["w"]; atol = 1e-5)
        end
    end
    @testset "soc 14-bus case" begin
        result_base = run_opf("../test/data/matpower/case14.m", SOCWRPowerModel, ipopt_solver)
        result_cuts = run_opf_flow_cuts("../test/data/matpower/case14.m", SOCWRPowerModel, ipopt_solver)

        @test result_base["termination_status"] == LOCALLY_SOLVED
        @test result_cuts["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,bus) in result_base["solution"]["bus"]
            @test isapprox(result_base["solution"]["bus"][i]["w"], result_cuts["solution"]["bus"][i]["w"]; atol = 1e-5)
        end
    end

    @testset "dc 5-bus case" begin
        result_base = run_opf("../test/data/matpower/case5.m", DCPPowerModel, cbc_solver)
        result_cuts = run_opf_flow_cuts("../test/data/matpower/case5.m", DCPPowerModel, cbc_solver)

        @test result_base["termination_status"] == OPTIMAL
        @test result_cuts["termination_status"] == OPTIMAL
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,bus) in result_base["solution"]["bus"]
            @test isapprox(result_base["solution"]["bus"][i]["va"], result_cuts["solution"]["bus"][i]["va"]; atol = 1e-8)
        end
    end
    @testset "dc 14-bus case" begin
        result_base = run_opf("../test/data/matpower/case14.m", DCPPowerModel, ipopt_solver)
        result_cuts = run_opf_flow_cuts("../test/data/matpower/case14.m", DCPPowerModel, ipopt_solver)

        @test result_base["termination_status"] == LOCALLY_SOLVED
        @test result_cuts["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,bus) in result_base["solution"]["bus"]
            @test isapprox(result_base["solution"]["bus"][i]["va"], result_cuts["solution"]["bus"][i]["va"]; atol = 1e-8)
        end
    end
end


@testset "ptdf opf with flow cuts" begin
    @testset "dc 5-bus case" begin
        result_base = run_opf("../test/data/matpower/case5.m", DCPPowerModel, cbc_solver)
        result_cuts = run_opf_ptdf_flow_cuts("../test/data/matpower/case5.m", cbc_solver)

        @test result_base["termination_status"] == OPTIMAL
        @test result_cuts["termination_status"] == OPTIMAL
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,gen) in result_base["solution"]["gen"]
            @test isapprox(result_base["solution"]["gen"][i]["pg"], result_cuts["solution"]["gen"][i]["pg"]; atol = 1e-8)
        end
    end
    @testset "dc 14-bus case" begin
        result_base = run_opf("../test/data/matpower/case14.m", DCPPowerModel, ipopt_solver)
        result_cuts = run_opf_ptdf_flow_cuts("../test/data/matpower/case14.m", ipopt_solver)

        @test result_base["termination_status"] == LOCALLY_SOLVED
        @test result_cuts["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result_base["objective"], result_cuts["objective"])
        for (i,gen) in result_base["solution"]["gen"]
            @test isapprox(result_base["solution"]["gen"][i]["pg"], result_cuts["solution"]["gen"][i]["pg"]; atol = 1e-8)
        end
    end
end



