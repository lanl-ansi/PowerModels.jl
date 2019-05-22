
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
        @test haskey(result["solution"], "branch") == false

        @test !isnan(result["solve_time"])

        @test length(result["solution"]["bus"]) == 24
        @test length(result["solution"]["gen"]) == 33
    end
end

@testset "test branch flow output" begin
    @testset "24-bus rts case ac opf" begin
        result = run_opf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)))

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
        result = run_opf("../test/data/matpower/case3.m", DCPPowerModel, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)))

        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true

        @test length(result["solution"]["bus"]) == 3
        @test length(result["solution"]["gen"]) == 3
        @test length(result["solution"]["branch"]) == 3
        @test length(result["solution"]["dcline"]) == 1

        branches = result["solution"]["branch"]

        @test isapprox(branches["3"]["pf"], -0.103497; atol = 1e-3)
        @test isapprox(branches["3"]["pt"],  0.103497; atol = 1e-3)
        @test isnan(branches["3"]["qf"])
        @test isnan(branches["3"]["qt"])
    end
end


@testset "test dual value output" begin
    settings = Dict("output" => Dict("duals" => true))
    result = run_dc_opf("../test/data/matpower/case14.m", ipopt_solver, setting = settings)

    PowerModels.make_mixed_units!(result["solution"])
    @testset "14 bus - kcl duals" begin
        for (i, bus) in result["solution"]["bus"]
            @test haskey(bus, "lam_kcl_r")
            @test haskey(bus, "lam_kcl_i")
            @test isapprox(bus["lam_kcl_r"], -39.02; atol = 1e-2) # Expected result for case14
            @test isnan(bus["lam_kcl_i"])
        end
    end

    @testset "14 bus - thermal limit duals" begin
        for (i, branch) in result["solution"]["branch"]
            @test haskey(branch, "mu_sm_fr")
            @test haskey(branch, "mu_sm_to")
            @test isapprox(branch["mu_sm_fr"], 0.0; atol = 1e-2)
            @test isnan(branch["mu_sm_to"])
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
            @test isnan(branch["mu_sm_to"])
        end
    end
end


# recomended by @lroald
@testset "test solution feedback" begin

    function solution_feedback(case, ac_opf_obj)
        data = PowerModels.parse_file(case)
        opf_result = run_ac_opf(data, ipopt_solver)
        @test opf_result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(opf_result["objective"], ac_opf_obj; atol = 1e0)

        PowerModels.update_data!(data, opf_result["solution"])

        pf_result = run_ac_pf(data, ipopt_solver)
        @test pf_result["termination_status"] == MOI.LOCALLY_SOLVED
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
