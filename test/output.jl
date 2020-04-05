
@testset "test output api" begin
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver)

        @test haskey(result, "optimizer") == true
        @test haskey(result, "termination_status") == true
        @test haskey(result, "primal_status") == true
        @test haskey(result, "dual_status") == true
        @test haskey(result, "objective") == true
        @test haskey(result, "objective_lb") == true
        @test haskey(result, "solve_time") == true
        @test haskey(result, "machine") == true
        @test haskey(result, "data") == true
        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true

        @test !isnan(result["solve_time"])

        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33
    end

    @testset "infeasible case" begin
        # make sure code does not crash when ResultCount == 0
        # change objective to linear so the case can load into cbc
        data = parse_file("../test/data/matpower/case24.m")
        for (i,gen) in data["gen"]
            if gen["ncost"] > 2
                gen["ncost"] = 2
                gen["cost"] = gen["cost"][length(gen["cost"])-1:end]
            end
        end
        result = run_opf(data, DCPPowerModel, cbc_solver)

        @test haskey(result, "optimizer")
        @test haskey(result, "termination_status")
        @test haskey(result, "primal_status")
        @test haskey(result, "dual_status")
        @test haskey(result, "solve_time")
        @test haskey(result, "solution")
        @test !isnan(result["solve_time"])
        @test length(result["solution"]) == 0
    end
end

@testset "test branch flow output" begin
    @testset "24-bus rts case ac opf" begin
        result = run_opf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver)

        @test haskey(result, "optimizer") == true
        @test haskey(result, "termination_status") == true
        @test haskey(result, "primal_status") == true
        @test haskey(result, "dual_status") == true
        @test haskey(result, "objective") == true
        @test haskey(result, "objective_lb") == true
        @test haskey(result, "solve_time") == true
        @test haskey(result, "machine") == true
        @test haskey(result, "data") == true
        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true

        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33
        @test length(result["solution"]["branch"]) == 38

        branches = result["solution"]["branch"]

        @test isapprox(branches["2"]["pf"],  0.2001; atol = 1e-3)
        @test isapprox(branches["2"]["pt"], -0.1980; atol = 1e-3)
        @test isapprox(branches["2"]["qf"],  0.0055; atol = 1e-3)
        @test isapprox(branches["2"]["qt"], -0.0571; atol = 1e-3)
    end

    # A DCPPowerModel test is important because it does have variables for the reverse side of the branchs
    @testset "3-bus case dc opf" begin
        result = run_opf("../test/data/matpower/case3.m", DCPPowerModel, ipopt_solver)

        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true

        @test length(result["solution"]["bus"]) == 3
        @test length(result["solution"]["gen"]) == 3
        @test length(result["solution"]["branch"]) == 3
        @test length(result["solution"]["dcline"]) == 1

        branches = result["solution"]["branch"]

        @test isapprox(branches["3"]["pf"], -0.103497; atol = 1e-3)
        @test isapprox(branches["3"]["pt"],  0.103497; atol = 1e-3)
        #@test isnan(branches["3"]["qf"])
        #@test isnan(branches["3"]["qt"])
    end

    @testset "24-bus rts case ac pf" begin
        result = run_pf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver)

        @test haskey(result, "optimizer") == true
        @test haskey(result, "termination_status") == true
        @test haskey(result, "primal_status") == true
        @test haskey(result, "dual_status") == true
        @test haskey(result, "objective") == true
        @test haskey(result, "objective_lb") == true
        @test haskey(result, "solve_time") == true
        @test haskey(result, "machine") == true
        @test haskey(result, "data") == true
        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "bus") == true
        @test haskey(result["solution"], "branch") == false

        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33

        bus = result["solution"]["bus"]

        @test isapprox(bus["1"]["vm"],  1.03116; atol = 1e-3)
        @test isapprox(bus["1"]["va"], -0.13525; atol = 1e-3)
        @test isapprox(bus["2"]["vm"],  1.02794; atol = 1e-3)
        @test isapprox(bus["2"]["va"], -0.13480; atol = 1e-3)
    end

    # A DCPPowerModel test is important because it does have variables for the reverse side of the branchs
    @testset "3-bus case dc pf" begin
        result = run_pf("../test/data/matpower/case3.m", DCPPowerModel, ipopt_solver)

        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == false

        @test length(result["solution"]["bus"]) == 3
        @test length(result["solution"]["gen"]) == 3
        @test length(result["solution"]["dcline"]) == 1

        bus = result["solution"]["bus"]

        @test isapprox(bus["3"]["vm"],  1.0; atol = 1e-3)
        @test isapprox(bus["3"]["va"], -0.28291; atol = 1e-3)
        #@test isnan(branches["3"]["qf"])
        #@test isnan(branches["3"]["qt"])
    end
end


@testset "test dual value output" begin
    settings = Dict("output" => Dict("duals" => true))
    data = PowerModels.parse_file("../test/data/matpower/case14.m")
    calc_thermal_limits!(data)
    result = run_dc_opf(data, ipopt_solver, setting = settings)

    PowerModels.make_mixed_units!(result["solution"])
    @testset "14 bus - kcl duals" begin
        for (i, bus) in result["solution"]["bus"]
            @test haskey(bus, "lam_kcl_r")
            @test isapprox(bus["lam_kcl_r"], -39.02; atol = 1e-2) # Expected result for case14
        end
    end

    @testset "14 bus - thermal limit duals" begin
        for (i, branch) in result["solution"]["branch"]
            @test haskey(branch, "mu_sm_fr")
            @test haskey(branch, "mu_sm_to")
            @test isapprox(branch["mu_sm_fr"], 0.0; atol = 1e-2)
            @test isapprox(branch["mu_sm_to"], 0.0; atol = 1e-2)
        end
    end


    result = run_dc_opf("../test/data/matpower/case5.m", ipopt_solver, setting = settings)

    PowerModels.make_mixed_units!(result["solution"])
    @testset "5 bus - kcl duals" begin
        for (i, bus) in result["solution"]["bus"]
            @test bus["lam_kcl_r"] <= -9.00
            @test bus["lam_kcl_r"] >= -45.00
        end
    end

    @testset "5 bus - thermal limit duals" begin
        for (i, branch) in result["solution"]["branch"]
            if i != "7"
                @test isapprox(branch["mu_sm_fr"], 0.0; atol = 1e-2)
            else
                @test isapprox(branch["mu_sm_fr"], 54.70; atol = 1e-2)
            end
            @test isapprox(branch["mu_sm_to"], 0.0; atol = 1e-2)
        end
    end


    result = run_opf("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver, setting = settings)
    @testset "5 bus - kcl duals soc qp" begin
        for (i, bus) in result["solution"]["bus"]
            @test bus["lam_kcl_r"] <= -2900.00
            @test bus["lam_kcl_r"] >= -3100.00
            @test bus["lam_kcl_i"] <=  0.001
            @test bus["lam_kcl_i"] >= -5.000
        end
    end

    result = run_opf("../test/data/matpower/case5.m", SOCWRConicPowerModel, scs_solver, setting = settings)
    @testset "5 bus - kcl duals soc conic" begin
        for (i, bus) in result["solution"]["bus"]
            @test bus["lam_kcl_r"] <= -2900.00
            @test bus["lam_kcl_r"] >= -3100.00
            @test bus["lam_kcl_i"] <=  0.1
            @test bus["lam_kcl_i"] >= -5.000
        end
    end

    result = run_opf("../test/data/matpower/case5.m", ACPPowerModel, ipopt_solver, setting = settings)
    @testset "5 bus - kcl duals acp" begin
        for (i, bus) in result["solution"]["bus"]
            @test bus["lam_kcl_r"] <= -1000.00
            @test bus["lam_kcl_r"] >= -3600.00
            @test bus["lam_kcl_i"] <=   0.01
            @test bus["lam_kcl_i"] >= -42.00
        end
    end

    result = run_opf("../test/data/matpower/case5.m", ACRPowerModel, ipopt_solver, setting = settings)
    @testset "5 bus - kcl duals acr" begin
        for (i, bus) in result["solution"]["bus"]
            @test bus["lam_kcl_r"] <= -1000.00
            @test bus["lam_kcl_r"] >= -3600.00
            @test bus["lam_kcl_i"] <=   0.01
            @test bus["lam_kcl_i"] >= -42.00
        end
    end

    result = run_opf("../test/data/matpower/case5.m", ACTPowerModel, ipopt_solver, setting = settings)
    @testset "5 bus - kcl duals act" begin
        for (i, bus) in result["solution"]["bus"]
            @test bus["lam_kcl_r"] <= -1000.00
            @test bus["lam_kcl_r"] >= -3600.00
            @test bus["lam_kcl_i"] <=   0.01
            @test bus["lam_kcl_i"] >= -42.00
        end
    end

end


@testset "test solution builder inconsistent status" begin
    # test case where generator status is 1 but the gen_bus status is 0
    data = parse_file("../test/data/matpower/case5.m")
    data["bus"]["4"]["bus_type"] = 4
    result = run_ac_opf(data, ipopt_solver)

    @test result["termination_status"] == LOCALLY_SOLVED
    @test isapprox(result["objective"], 10128.6; atol = 1e0)
end


@testset "test solution processors" begin
    @testset "sol_vr_to_vp" begin
        result = run_opf("../test/data/matpower/case5.m", ACRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        for (i,bus) in result["solution"]["bus"]
            if haskey(bus, "vr") && haskey(bus, "vi")
                @test haskey(bus, "vm") && haskey(bus, "va")
            end
        end
    end

    @testset "sol_w_to_vm" begin
        result = run_opf("../test/data/matpower/case5.m", SOCWRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        for (i,bus) in result["solution"]["bus"]
            if haskey(bus, "w")
                @test haskey(bus, "vm")
            end
        end
    end

    @testset "sol_phi_to_vm" begin
        result = run_opf("../test/data/matpower/case5.m", LPACCPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        for (i,bus) in result["solution"]["bus"]
            if haskey(bus, "phi")
                @test haskey(bus, "vm")
            end
        end
    end
end


# recommended by @lroald
@testset "test solution feedback" begin

    function solution_feedback(case, ac_opf_obj)
        data = PowerModels.parse_file(case)
        opf_result = run_ac_opf(data, ipopt_solver)
        @test opf_result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(opf_result["objective"], ac_opf_obj; atol = 1e0)

        PowerModels.update_data!(data, opf_result["solution"])

        pf_result = run_ac_pf(data, ipopt_solver)
        @test pf_result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(pf_result["objective"], 0.0; atol = 1e-3)

        for (i,bus) in data["bus"]
            @test isapprox(opf_result["solution"]["bus"][i]["va"], pf_result["solution"]["bus"][i]["va"]; atol = 1e-3)
            @test isapprox(opf_result["solution"]["bus"][i]["vm"], pf_result["solution"]["bus"][i]["vm"]; atol = 1e-3)
        end

        for (i,gen) in data["gen"]
            @test isapprox(opf_result["solution"]["gen"][i]["pg"], pf_result["solution"]["gen"][i]["pg"]; atol = 1e-3)
            # cannot check this value solution does not appeat to be unique; verify this!
            #@test isapprox(opf_result["solution"]["gen"][i]["qg"], pf_result["solution"]["gen"][i]["qg"]; atol = 1e-3)
        end

        for (i,dcline) in data["dcline"]
            @test isapprox(opf_result["solution"]["dcline"][i]["pf"], pf_result["solution"]["dcline"][i]["pf"]; atol = 1e-3)
            @test isapprox(opf_result["solution"]["dcline"][i]["pt"], pf_result["solution"]["dcline"][i]["pt"]; atol = 1e-3)
        end
    end

    @testset "3-bus case" begin
        solution_feedback("../test/data/matpower/case3.m", 5907)
    end

    @testset "5-bus asymmetric case" begin
        solution_feedback("../test/data/matpower/case5_asym.m", 17551)
    end

    @testset "5-bus with dcline costs" begin
        solution_feedback("../test/data/matpower/case5_dc.m", 18156.2)
    end

end
