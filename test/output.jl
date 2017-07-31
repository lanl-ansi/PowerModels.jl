
@testset "test output api" begin
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", ACPPowerModel, ipopt_solver)

        @test haskey(result, "solver") == true
        @test haskey(result, "status") == true
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

@testset "test line flow output" begin
    @testset "24-bus rts case ac opf" begin
        result = run_opf("../test/data/case24.m", ACPPowerModel, ipopt_solver; setting = Dict("output" => Dict("line_flows" => true)))

        @test haskey(result, "solver") == true
        @test haskey(result, "status") == true
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

        @test isapprox(branches["2"]["pf"],  20.01; atol = 1e-1)
        @test isapprox(branches["2"]["pt"],   -19.80; atol = 1e-1)
        @test isapprox(branches["2"]["qf"],   0.55; atol = 1e-1)
        @test isapprox(branches["2"]["qt"],    -5.71; atol = 1e-1)
    end

    # A DCPPowerModel test is important because it does have variables for the reverse side of the lines
    @testset "3-bus case dc opf" begin
        result = run_opf("../test/data/case3.m", DCPPowerModel, ipopt_solver; setting = Dict("output" => Dict("line_flows" => true)))

        @test haskey(result, "solution") == true
        @test haskey(result["solution"], "branch") == true

        @test length(result["solution"]["bus"]) == 3
        @test length(result["solution"]["gen"]) == 3
        @test length(result["solution"]["branch"]) == 3
        @test length(result["solution"]["dcline"]) == 1

        branches = result["solution"]["branch"]

        @test isapprox(branches["3"]["pf"], -10.3497; atol = 1e-1)
        @test isapprox(branches["3"]["pt"],  10.3497; atol = 1e-1)
        @test isnan(branches["3"]["qf"])
        @test isnan(branches["3"]["qt"])
    end
end


# recomended by @lroald
@testset "test solution feedback" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/case3.m")
        opf_result = run_ac_opf(data, ipopt_solver)
        @test opf_result["status"] == :LocalOptimal
        @test isapprox(opf_result["objective"], 5907; atol = 1e0)
        PowerModels.make_per_unit(opf_result["solution"])

        PowerModels.update_data(data, opf_result["solution"])

        pf_result = run_ac_pf(data, ipopt_solver)
        @test pf_result["status"] == :LocalOptimal
        @test isapprox(pf_result["objective"], 0.0; atol = 1e-3)
        PowerModels.make_per_unit(pf_result["solution"])

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

end