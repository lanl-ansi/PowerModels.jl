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

        for (i, bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol=1e-10)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = solve_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        for (i, bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol=1e-10)
        end
    end
    @testset "5-bus multiple slack gens case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        result = solve_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        for (i, bus) in data["bus"]
            if bus["bus_type"] != pm_component_status_inactive["bus"]
                opt_val = result["solution"]["bus"][i]["va"]
                lin_val = native["solution"]["bus"][i]["va"]
                @test isapprox(opt_val, lin_val; atol=1e-10)
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

        for (i, bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol=1e-10)
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

            for (i, bus) in data["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)

                @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol=1e-6)
                @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol=1e-6)
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

        for (i, bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol=1e-6)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol=1e-6)
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

        for (i, bus) in data["bus"]
            if bus["bus_type"] != pm_component_status_inactive["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)

                @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol=1e-6)
                @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol=1e-6)
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

        for (i, bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol=1e-6)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol=1e-6)
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

        for (i, bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol=1e-6)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol=1e-6)
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

        for (i, bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol=1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol=1e-7)
        end
        for (i, gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol=1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol=1e-6)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i, bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol=1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol=1e-7)
        end
        for (i, gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol=1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol=1e-6)
        end
    end
    @testset "5-bus non-zero slack va case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i, bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol=1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol=1e-7)
        end
        for (i, gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol=1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol=1e-6)
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

        for (i, bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol=1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol=1e-7)
        end
        for (i, gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol=1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol=1e-6)
        end
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native["solution"]) >= 3

        for (i, bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol=1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol=1e-7)
        end
        for (i, gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol=1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol=1e-6)
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

        for (i, bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], result_ws["solution"]["bus"][i]["va"]; atol=1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], result_ws["solution"]["bus"][i]["vm"]; atol=1e-7)

            @test isapprox(bus_pg_ini[i], bus_pg_ws[i]; atol=1e-6)
            @test isapprox(bus_qg_ini[i], bus_qg_ws[i]; atol=1e-6)
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

        for (i, bus) in data["bus"]
            @test isapprox(solution["solution"]["bus"][i]["va"], solution_ws["solution"]["bus"][i]["va"]; atol=1e-7)
            @test isapprox(solution["solution"]["bus"][i]["vm"], solution_ws["solution"]["bus"][i]["vm"]; atol=1e-7)

            @test isapprox(bus_pg_ini[i], bus_pg_ws[i]; atol=1e-6)
            @test isapprox(bus_qg_ini[i], bus_qg_ws[i]; atol=1e-6)
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

            for (i, bus) in data["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)

                @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol=1e-6)
                @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol=1e-6)
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

        for (i, bus) in native["solution"]["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol=1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol=1e-7)
        end
        for (i, gen) in native["solution"]["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol=1e-6)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol=1e-6)
        end
    end
    @testset "5-bus case, NativeNewton options" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = solve_ac_pf(data, nlp_solver)
        native = compute_ac_pf("../test/data/matpower/case5.m", solver=NativeNewton(abstol=1e-10, linesearch=false, maxstep=100.0))

        # compat for Julia v1.6 on windows (01/19/24)
        if result["termination_status"] == LOCALLY_SOLVED
            @test length(native["solution"]) >= 3

            for (i, bus) in data["bus"]
                @test isapprox(result["solution"]["bus"][i]["va"], native["solution"]["bus"][i]["va"]; atol=1e-7)
                @test isapprox(result["solution"]["bus"][i]["vm"], native["solution"]["bus"][i]["vm"]; atol=1e-7)
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
    @testset "solver interface, singular jacobian" begin
        # linear system with a singular jacobian
        f!(F, x, p) = (F[1]=x[1] + x[2]; F[2]=x[1] + x[2] - 1.0)
        j!(J, x, p) = (J[1, 1]=1.0; J[1, 2]=1.0; J[2, 1]=1.0; J[2, 2]=1.0)
        jac = SparseArrays.sparse([1, 1, 2, 2], [1, 2, 1, 2], zeros(4))
        sys = PowerFlowSystem(f!, j!, [0.0, 0.0], Float64[], jac)

        sol = PowerModels._solve_nl(sys, NativeNewton())
        @test !sol.converged
        @test sol.iterations == 0
    end
    @testset "solver interface, line search backtracking" begin
        # overshoot recovered by step cap and the line search
        f!(F, x, p) = (F[1] = atan(x[1]))
        j!(J, x, p) = (J[1, 1] = 1.0 / (1.0 + x[1]^2))
        jac = SparseArrays.sparse([1], [1], [0.0])
        sys = PowerFlowSystem(f!, j!, [3.0], Float64[], jac)

        sol = PowerModels._solve_nl(sys, NativeNewton())
        @test sol.converged
        @test sol.residual_norm <= 1e-8
        @test isapprox(sol.x[1], 0.0; atol=1e-8)
    end
    @testset "solver interface, stalled line search" begin
        # deliberately wrong jacobian so the line search never finds a decrease
        f!(F, x, p) = (F[1] = x[1])
        j!(J, x, p) = (J[1, 1] = -1.0)
        jac = SparseArrays.sparse([1], [1], [0.0])
        sys = PowerFlowSystem(f!, j!, [1.0], Float64[], jac)

        sol = PowerModels._solve_nl(sys, NativeNewton(maxiters=2))
        @test !sol.converged
        @test sol.iterations == 2
    end
    @testset "5-bus case, in-place iteration limit" begin
        _test_warn("did not converge") do
            data = PowerModels.parse_file("../test/data/matpower/case5.m")
            compute_ac_pf!(data, solver=NativeNewton(maxiters=1), flat_start=true)
        end
    end
    @testset "5-bus case, slack generator power splitting" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        reference = compute_ac_pf(deepcopy(data))
        pg_total = reference["solution"]["gen"]["4"]["pg"]

        # for test coverage: each generator exercises one branch of _assign_pg!
        slack_gen = data["gen"]["4"]
        slack_gen["pmin"] = -0.1
        slack_gen["pmax"] = -0.05
        slack_gen["qmin"] = -2.0
        slack_gen["qmax"] = 2.0
        for (i, pmin, pmax, status) in [(10, 0.5, 1.0, 1), (11, -10.0, 10.0, 1), (12, -10.0, 10.0, 1), (13, -10.0, 10.0, 0)]
            gen = deepcopy(slack_gen)
            gen["index"] = i
            gen["pmin"] = pmin
            gen["pmax"] = pmax
            gen["gen_status"] = status
            gen["pg"] = 0.0
            gen["qg"] = 0.0
            data["gen"]["$(i)"] = gen
        end

        native = compute_ac_pf(data)
        @test native["termination_status"]

        sol_gen = native["solution"]["gen"]
        @test isapprox(sol_gen["4"]["pg"], 0.0; atol=1e-8)
        @test isapprox(sol_gen["10"]["pg"], 0.5; atol=1e-8)
        @test isapprox(sol_gen["11"]["pg"], pg_total - 0.5; atol=1e-6)
        @test isapprox(sol_gen["12"]["pg"], 0.0; atol=1e-8)
        @test !haskey(sol_gen, "13")
    end
    @testset "test_issue_938" begin
        filename = joinpath(@__DIR__, "data/json/issue_938.json")
        data = PowerModels.parse_file(filename)
        native = PowerModels.compute_ac_pf(data)
        @test native["termination_status"]
    end
end

