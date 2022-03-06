@testset "test native dc pf solver" begin
    # degenerate due to no slack bus
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     result = run_dc_pf(data, nlp_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["solution"]["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_dc_pf(data, nlp_solver)
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
        result = run_dc_pf(data, nlp_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["solution"]["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    @testset "5-bus multiple slack gens case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        result = run_dc_pf(data, nlp_solver)
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
    #     result = run_dc_pf(data, nlp_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["solution"]["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = run_dc_pf(data, nlp_solver)
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
    #     result = run_dc_pf(data, nlp_solver)
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
        result = run_ac_pf(data, nlp_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED

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
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = run_ac_pf(data, nlp_solver)
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
        result = run_ac_pf(data, nlp_solver)
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
    #     result = run_ac_pf(data, nlp_solver)
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
        result = run_ac_pf(data, nlp_solver)
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
        result = run_ac_pf(data, nlp_solver)
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
        result = run_ac_pf(data, nlp_solver)
        #result = run_ac_pf(data, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6))
        @test result["termination_status"] == LOCALLY_SOLVED

        update_data!(data, result["solution"])
        set_ac_pf_start_values!(data)

        result_ws = run_ac_pf(data, nlp_solver)
        #result_ws = run_ac_pf(data, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6))
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
        # TODO extract number of iterations and test there is a reduction
        # show_trace can be used for manual verification, for now
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        solution = compute_ac_pf(data)
        #solution = compute_ac_pf(data, show_trace=true)
        @test length(solution) >= 3

        update_data!(data, solution["solution"])
        set_ac_pf_start_values!(data)

        solution_ws = compute_ac_pf(data)
        #solution_ws = compute_ac_pf(data, show_trace=true)
        @test length(solution_ws["solution"]) >= 3

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
    @testset "5-bus case, finite_differencing" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_ac_pf(data, nlp_solver)
        native = compute_ac_pf("../test/data/matpower/case5.m", finite_differencing=true)

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
    @testset "5-bus case, flat_start" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_ac_pf(data, nlp_solver)
        native = compute_ac_pf("../test/data/matpower/case5.m", flat_start=true)

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
    @testset "5-bus case, in-place and nsolve method parameter" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        native = compute_ac_pf("../test/data/matpower/case5.m", method=:newton)
        compute_ac_pf!(data, method=:newton)

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

