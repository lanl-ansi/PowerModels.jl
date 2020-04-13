@testset "test native dc pf solver" begin
    # degenerate due to no slack bus
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     result = run_dc_pf(data, ipopt_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_dc_pf(data, ipopt_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = run_dc_pf(data, ipopt_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    # compute_dc_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     result = run_dc_pf(data, ipopt_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = run_dc_pf(data, ipopt_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
end


@testset "test native ac pf solver" begin
    # requires dc line support in ac solver
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     result = run_dc_pf(data, ipopt_solver)
    #     native = compute_dc_pf(data)

    #     @test result["termination_status"] == LOCALLY_SOLVED

    #     bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
    #     bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

    #     bus_pg_nls = bus_gen_values(data, native, "pg")
    #     bus_qg_nls = bus_gen_values(data, native, "qg")

    #     for (i,bus) in data["bus"]
    #         @test isapprox(result["solution"]["bus"][i]["va"], native["bus"][i]["va"]; atol = 1e-7)
    #         @test isapprox(result["solution"]["bus"][i]["vm"], native["bus"][i]["vm"]; atol = 1e-7)

    #         @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-7)
    #         @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-7)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_ac_pf(data, ipopt_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native) >= 3

        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native, "pg")
        bus_qg_nls = bus_gen_values(data, native, "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-7)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-7)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = run_ac_pf(data, ipopt_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native) >= 3

        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native, "pg")
        bus_qg_nls = bus_gen_values(data, native, "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-7)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-7)
        end
    end
    # compute_ac_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     result = run_ac_pf(data, ipopt_solver)
    #     native = compute_ac_pf(data)

    #     @test result["termination_status"] == LOCALLY_SOLVED

    #     bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
    #     bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

    #     bus_pg_nls = bus_gen_values(data, native, "pg")
    #     bus_qg_nls = bus_gen_values(data, native, "qg")

    #     for (i,bus) in data["bus"]
    #         @test isapprox(result["solution"]["bus"][i]["va"], native["bus"][i]["va"]; atol = 1e-7)
    #         @test isapprox(result["solution"]["bus"][i]["vm"], native["bus"][i]["vm"]; atol = 1e-7)

    #         @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-7)
    #         @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-7)
    #     end
    # end
    @testset "14-bus case, vm fixed non-1.0 value" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        result = run_ac_pf(data, ipopt_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native) >= 3

        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native, "pg")
        bus_qg_nls = bus_gen_values(data, native, "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-7)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-7)
        end
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = run_ac_pf(data, ipopt_solver)
        native = compute_ac_pf(data)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test length(native) >= 3


        bus_pg_nlp = bus_gen_values(data, result["solution"], "pg")
        bus_qg_nlp = bus_gen_values(data, result["solution"], "qg")

        bus_pg_nls = bus_gen_values(data, native, "pg")
        bus_qg_nls = bus_gen_values(data, native, "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], native["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], native["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_nlp[i], bus_pg_nls[i]; atol = 1e-7)
            @test isapprox(bus_qg_nlp[i], bus_qg_nls[i]; atol = 1e-7)
        end
    end
end


@testset "test native ac pf solver, in-place" begin
    # requires dc line support in ac solver
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     native = compute_ac_pf(data)
    #     compute_ac_pf!(data)

    #     @test length(native) >= 3

    #     for (i,bus) in native["bus"]
    #         @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
    #         @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
    #     end
    #     for (i,gen) in native["gen"]
    #         @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-7)
    #         @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-7)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native) >= 3

        for (i,bus) in native["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-7)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-7)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native) >= 3

        for (i,bus) in native["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-7)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-7)
        end
    end
    # compute_ac_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     native = compute_ac_pf(data)
    #     compute_ac_pf!(data)

    #     @test length(native) >= 3

    #     for (i,bus) in native["bus"]
    #         @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
    #         @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
    #     end
    #     for (i,gen) in native["gen"]
    #         @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-7)
    #         @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-7)
    #     end
    # end
    @testset "14-bus case, vm fixed non-1.0 value" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native) >= 3

        for (i,bus) in native["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-7)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-7)
        end
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        native = compute_ac_pf(data)
        compute_ac_pf!(data)

        @test length(native) >= 3

        for (i,bus) in native["bus"]
            @test isapprox(data["bus"][i]["va"], bus["va"]; atol = 1e-7)
            @test isapprox(data["bus"][i]["vm"], bus["vm"]; atol = 1e-7)
        end
        for (i,gen) in native["gen"]
            @test isapprox(data["gen"][i]["pg"], gen["pg"]; atol = 1e-7)
            @test isapprox(data["gen"][i]["qg"], gen["qg"]; atol = 1e-7)
        end
    end
end


@testset "test warm-start ac pf solvers" begin
    @testset "24-bus rts case, jump warm-start" begin
        # TODO extract number of iterations and test there is a reduction
        # Ipopt log can be used for manual verification, for now
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = run_ac_pf(data, ipopt_solver)
        #result = run_ac_pf(data, JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6))
        @test result["termination_status"] == LOCALLY_SOLVED

        update_data!(data, result["solution"])
        set_ac_pf_start_values!(data)

        result_ws = run_ac_pf(data, ipopt_solver)
        #result_ws = run_ac_pf(data, JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6))
        @test result_ws["termination_status"] == LOCALLY_SOLVED

        bus_pg_ini = bus_gen_values(data, result["solution"], "pg")
        bus_qg_ini = bus_gen_values(data, result["solution"], "qg")

        bus_pg_ws = bus_gen_values(data, result_ws["solution"], "pg")
        bus_qg_ws = bus_gen_values(data, result_ws["solution"], "qg")

        for (i,bus) in data["bus"]
            @test isapprox(result["solution"]["bus"][i]["va"], result_ws["solution"]["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(result["solution"]["bus"][i]["vm"], result_ws["solution"]["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_ini[i], bus_pg_ws[i]; atol = 1e-7)
            @test isapprox(bus_qg_ini[i], bus_qg_ws[i]; atol = 1e-7)
        end
    end

    @testset "24-bus rts case, native warm-start" begin
        # TODO extract number of iterations and test there is a reduction
        # show_trace can be used for manual verification, for now
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        solution = compute_ac_pf(data)
        #solution = compute_ac_pf(data, show_trace=true)
        @test length(solution) >= 3

        update_data!(data, solution)
        set_ac_pf_start_values!(data)

        solution_ws = compute_ac_pf(data)
        #solution_ws = compute_ac_pf(data, show_trace=true)
        @test length(solution_ws) >= 3

        bus_pg_ini = bus_gen_values(data, solution, "pg")
        bus_qg_ini = bus_gen_values(data, solution, "qg")

        bus_pg_ws = bus_gen_values(data, solution_ws, "pg")
        bus_qg_ws = bus_gen_values(data, solution_ws, "qg")

        for (i,bus) in data["bus"]
            @test isapprox(solution["bus"][i]["va"], solution_ws["bus"][i]["va"]; atol = 1e-7)
            @test isapprox(solution["bus"][i]["vm"], solution_ws["bus"][i]["vm"]; atol = 1e-7)

            @test isapprox(bus_pg_ini[i], bus_pg_ws[i]; atol = 1e-7)
            @test isapprox(bus_qg_ini[i], bus_qg_ws[i]; atol = 1e-7)
        end
    end
end

