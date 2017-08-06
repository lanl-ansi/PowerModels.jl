
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
        @test haskey(result["solution"]["nw"]["0"], "branch") == false

        @test !isnan(result["solve_time"])

        @test length(result["solution"]["nw"]["0"]["bus"]) == 24
        @test length(result["solution"]["nw"]["0"]["gen"]) == 33
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
        @test haskey(result["solution"]["nw"]["0"], "branch") == true

        @test length(result["solution"]["nw"]["0"]["bus"]) == 24
        @test length(result["solution"]["nw"]["0"]["gen"]) == 33
        @test length(result["solution"]["nw"]["0"]["branch"]) == 38

        branches = result["solution"]["nw"]["0"]["branch"]

        @test isapprox(branches["2"]["pf"],  0.2001; atol = 1e-3)
        @test isapprox(branches["2"]["pt"], -0.1980; atol = 1e-3)
        @test isapprox(branches["2"]["qf"],  0.0055; atol = 1e-3)
        @test isapprox(branches["2"]["qt"], -0.0571; atol = 1e-3)
    end

    # A DCPPowerModel test is important because it does have variables for the reverse side of the lines
    @testset "3-bus case dc opf" begin
        result = run_opf("../test/data/case3.m", DCPPowerModel, ipopt_solver; setting = Dict("output" => Dict("line_flows" => true)))

        @test haskey(result, "solution") == true
        @test haskey(result["solution"]["nw"]["0"], "branch") == true

        @test length(result["solution"]["nw"]["0"]["bus"]) == 3
        @test length(result["solution"]["nw"]["0"]["gen"]) == 3
        @test length(result["solution"]["nw"]["0"]["branch"]) == 3
        @test length(result["solution"]["nw"]["0"]["dcline"]) == 1

        branches = result["solution"]["nw"]["0"]["branch"]

        @test isapprox(branches["3"]["pf"], -0.103497; atol = 1e-3)
        @test isapprox(branches["3"]["pt"],  0.103497; atol = 1e-3)
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

        PowerModels.update_data(data, opf_result["solution"]["nw"]["0"])

        pf_result = run_ac_pf(data, ipopt_solver)
        @test pf_result["status"] == :LocalOptimal
        @test isapprox(pf_result["objective"], 0.0; atol = 1e-3)

        for (i,bus) in data["bus"]
            @test isapprox(opf_result["solution"]["nw"]["0"]["bus"][i]["va"], pf_result["solution"]["nw"]["0"]["bus"][i]["va"]; atol = 1e-3)
            @test isapprox(opf_result["solution"]["nw"]["0"]["bus"][i]["vm"], pf_result["solution"]["nw"]["0"]["bus"][i]["vm"]; atol = 1e-3)
        end

        for (i,gen) in data["gen"]
            @test isapprox(opf_result["solution"]["nw"]["0"]["gen"][i]["pg"], pf_result["solution"]["nw"]["0"]["gen"][i]["pg"]; atol = 1e-3)
            # cannot check this value solution does not appeat to be unique; verify this!
            #@test isapprox(opf_result["solution"]["nw"]["0"]["gen"][i]["qg"], pf_result["solution"]["nw"]["0"]["gen"][i]["qg"]; atol = 1e-3)
        end

        for (i,dcline) in data["dcline"]
            @test isapprox(opf_result["solution"]["nw"]["0"]["dcline"][i]["pf"], pf_result["solution"]["nw"]["0"]["dcline"][i]["pf"]; atol = 1e-3)
            @test isapprox(opf_result["solution"]["nw"]["0"]["dcline"][i]["pt"], pf_result["solution"]["nw"]["0"]["dcline"][i]["pt"]; atol = 1e-3)
        end
    end

end