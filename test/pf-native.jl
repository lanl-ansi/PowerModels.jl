@testset "test native dc pf solver" begin
    # degenerate due to no slack bus
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     result = solve_dc_pf(data, nlp_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["solution"]["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = solve_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        @test length(native) >= 5
        @test native["objective"] == 0.0
        @test native["termination_status"]
        @test haskey(native, "solution")
        @test length(native["solution"]) >= 2

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = solve_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    @testset "5-bus multiple slack gens case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        result = solve_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            if bus["bus_type"] != pm_component_status_inactive["bus"]
                opt_val = result["solution"]["bus"][i]["va"]
                lin_val = native["solution"]["bus"][i]["va"]
                @test isapprox(opt_val, lin_val; atol = 1e-10)
            end
        end
    end
    # compute_dc_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     result = solve_dc_pf(data, nlp_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["solution"]["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = solve_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
end


# updated pg/qg tolerance to 1e-6 on 04/21/2021 to fix cross platform stability

@testset "test native ac pf solver" begin
    # requires dc line support in ac solver
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     result = solve_dc_pf(data, nlp_solver)
    #     native = compute_dc_pf(data)

    #     @test result["termination_status"] == LOCALLY_SOLVED

    #     bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
    #     bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

    #     bus_pg_nls = bus_gen_values(data, native, "pg")
    #     bus_qg_nls = bus_gen_values(data, native, "qg")

    #     for (i,bus) in data["bus"]
    #         @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
    #         @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

    #         @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
    #         @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf(data)

        # compat for Julia v1.6 on windows (01/19/24)
        if result["termination_status"] == LOCALLY_SOLVED
            @test length(native) >= 5
            @test native["objective"] == 0.0
            @test native["termination_status"]
            @test haskey(native, "solution")
            @test length(native["solution"]) >= 3

            bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
            bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

            bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
            bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

            for (i,bus) in data["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

                @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
                @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
            end
        else
            @test result["termination_status"] == NUMERICAL_ERROR
        end

    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native["solution"]) >= 3

        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
        bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
        end
    end
    @testset "5-bus multiple slack gens case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native["solution"]) >= 3

        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
        bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

        for (i,bus) in data["bus"]
            if bus["bus_type"] != pm_component_status_inactive["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

                @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
                @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
            end
        end
    end

    # compute_ac_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     result = solve_ac_pf(data, nlp_solver)
    #     native = compute_ac_pf(data)

    #     @test result["termination_status"] == LOCALLY_SOLVED

    #     bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
    #     bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

    #     bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
    #     bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

    #     for (i,bus) in data["bus"]
    #         @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
    #         @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

    #         @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
    #         @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
    #     end
    # end
    @testset "14-bus case, vm fixed non-1.0 value" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native["solution"]) >= 3

        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
        bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
        end
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native["solution"]) >= 3


        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
        bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
        end
    end
end


@testset "test native ac pf solver, in-place" begin
    # requires dc line support in ac solver
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     native = compute_ac_pf(data)
    #     compute_ac_pf!(data)

    #     @test length(native["solution"]) >= 3

    #     for (i,bus) in native["solution"]["bus"]
    #         @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
    #         @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
    #     end
    #     for (i,gen) in native["solution"]["gen"]
    #         @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
    #         @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i,bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i,bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
        end
    end
    @testset "5-bus non-zero slack va case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i,bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
        end
    end
    # compute_ac_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     native = compute_ac_pf(data)
    #     compute_ac_pf!(data)

    #     @test length(native["solution"]) >= 3

    #     for (i,bus) in native["solution"]["bus"]
    #         @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
    #         @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
    #     end
    #     for (i,gen) in native["solution"]["gen"]
    #         @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
    #         @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
    #     end
    # end
    @testset "14-bus case, vm fixed non-1.0 value" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i,bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
        end
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i,bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
        end
    end
end


@testset "test warm-start ac pf solvers" begin
    @testset "24-bus rts case, jump warm-start" begin
        # TODO extract number of iterations and test there is a reduction
        # Ipopt log can be used for manual verification, for now
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = solve_ac_pf(data, nlp_solver)
        #result = solve_ac_pf(data, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6))
        @test result["termination_status"] == LOCALLY_SOLVED

        update_data!(data, result["solution"])
        set_ac_pf_start_values!(data)

        result_ws = solve_ac_pf(data, nlp_solver)
        #result_ws = solve_ac_pf(data, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6))
        @test result_ws["termination_status"] == LOCALLY_SOLVED

        bus_pg_ini = bus_gen_values(data, result["solution"], "pg")
        bus_qg_ini = bus_gen_values(data, result["solution"], "qg")

        bus_pg_ws = bus_gen_values(data, result_ws["solution"], "pg")
        bus_qg_ws = bus_gen_values(data, result_ws["solution"], "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], result_ws["solution"]["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], result_ws["solution"]["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_ini[i], bus_pg_ws[i]; atol = 1e-6)
            @test isapprox(bus_qg_ini[i], bus_qg_ws[i]; atol = 1e-6)
        end
    end

    @testset "24-bus rts case, native warm-start" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        solution = compute_ac_pf(data)
        @test length(solution) >= 3
        @test solution["iterations"] > 0

        update_data!(data, solution["solution"])
        set_ac_pf_start_values!(data)

        solution_ws = compute_ac_pf(data)
        @test length(solution_ws["solution"]) >= 3

        # warm-starting from a solution should reduce the iteration count
        @test solution_ws["iterations"] < solution["iterations"]

        bus_pg_ini = bus_gen_values(data, solution["solution"], "pg")
        bus_qg_ini = bus_gen_values(data, solution["solution"], "qg")

        bus_pg_ws = bus_gen_values(data, solution_ws["solution"], "pg")
        bus_qg_ws = bus_gen_values(data, solution_ws["solution"], "qg")

        for (i,bus) in data["bus"]
            @test isapprox(solution["solution"]["bus"][i]["va"], solution_ws["solution"]["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(solution["solution"]["bus"][i]["vm"], solution_ws["solution"]["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_ini[i], bus_pg_ws[i]; atol = 1e-6)
            @test isapprox(bus_qg_ini[i], bus_qg_ws[i]; atol = 1e-6)
        end
    end
end


@testset "test native ac pf solver options" begin
    @testset "5-bus case, flat_start" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf("../test/data/matpower/case5.m", flat_start=true)

        # compat for Julia v1.6 on windows (01/19/24)
        if result["termination_status"] == LOCALLY_SOLVED
            @test length(native["solution"]) >= 3

            bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
            bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

            bus_pg_nls = bus_gen_values(data, native["solution"], "pg")
            bus_qg_nls = bus_gen_values(data, native["solution"], "qg")

            for (i,bus) in data["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)

                @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-6)
                @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-6)
            end
        else
            @test result["termination_status"] == NUMERICAL_ERROR
        end
    end
    @testset "5-bus case, in-place and solver parameter" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        native = compute_ac_pf("../test/data/matpower/case5.m", solver=NativeNewton())
        compute_ac_pf!(data, solver=NativeNewton())

        @test length(native["solution"]) >= 3

        for (i,bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-6)
        end
    end
    @testset "5-bus case, NativeNewton options" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf("../test/data/matpower/case5.m", solver=NativeNewton(abstol=1e-10, linesearch=false, maxstep=100.0))

        # compat for Julia v1.6 on windows (01/19/24)
        if result["termination_status"] == LOCALLY_SOLVED
            @test length(native["solution"]) >= 3

            for (i,bus) in data["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol = 1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol = 1e-7)
            end
        else
            @test result["termination_status"] == NUMERICAL_ERROR
        end
    end
    @testset "5-bus case, iteration limit" begin
        native = compute_ac_pf("../test/data/matpower/case5.m", solver=NativeNewton(maxiters=1), flat_start=true)
        @test native["termination_status"] == false
        @test native["iterations"] == 1
        @test !haskey(native["solution"], "bus")

        _test_warn("did not converge") do
            compute_ac_pf("../test/data/matpower/case5.m", solver=NativeNewton(maxiters=1), flat_start=true)
        end
    end
    @testset "5-bus case, unknown solver type" begin
        @test_throws ErrorException compute_ac_pf("../test/data/matpower/case5.m", solver="newton")
    end
    @testset "5-bus case, direct solver interface" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        pf_data = PowerModels.instantiate_pf_data(data)
        sys = build_pf_system(pf_data)
        sol = PowerModels._solve_nl(sys, NativeNewton())

        @test sol isa PowerFlowSolution
        @test sol.converged
        @test sol.iterations > 0
        @test sol.residual_norm <= 1e-8
        @test length(sol.x) == 2*length(data["bus"])
    end
    @testset "test_issue_938" begin
        filename = joinpath(@__DIR__, "data/json/issue_938.json")
        data = PowerModels.parse_file(filename)
        native = PowerModels.compute_ac_pf(data)
        @test native["termination_status"]
    end
end

