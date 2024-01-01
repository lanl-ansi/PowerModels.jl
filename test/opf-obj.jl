### Tests for OPF objective variants ###

@testset "linear objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [1400.0, 1.0]
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = []

    @testset "jump model objective type" begin
        pm = instantiate_model(data, ACPPowerModel, build_opf)
        @test isa(JuMP.objective_function(pm.model), JuMP.AffExpr)
    end

    @testset "nlp solver" begin
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5420.3; atol = 1e0)
    end

    @testset "conic solver" begin
        result = solve_opf(data, SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 3095.88; atol = 1e0)
    end

    @testset "lp solver" begin
        result = solve_dc_opf(data, milp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 4679.05; atol = 1e0)
    end
end

@testset "quadratic objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [1.0, 1400.0, 1.0]
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = []

    @testset "jump model objective type" begin
        pm = instantiate_model(data, ACPPowerModel, build_opf)
        @test isa(JuMP.objective_function(pm.model), JuMP.QuadExpr)
    end

    @testset "nlp solver" begin
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5420.46; atol = 1e0)
    end

    @testset "conic solver" begin
        result = solve_opf(data, SOCWRConicPowerModel, sdp_solver)

        # ALMOST_OPTIMAL only required for Julia 1.0 on Linux
        @test result["termination_status"] == OPTIMAL || result["termination_status"] == ALMOST_OPTIMAL
        # 5e0 only required for Julia 1.6 on Linux
        @test isapprox(result["objective"], 3096.04; atol = 5e0)
    end
end

@testset "nlp objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = []
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = [10.0, 100.0, 300.0, 1400.0, 1.0]

    @testset "jump model objective type" begin
        pm = instantiate_model(data, ACPPowerModel, build_opf)

        @test JuMP.objective_function(pm.model) == JuMP.AffExpr(0.0)
        # would be good to add a test like this one in a future version where the NL expression can be accessed with a public API
        #@test isa(JuMP._nlp_objective_function(pm.model), JuMP.MOI.Nonlinear.Expression)
    end

    @testset "opf objective" begin
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 19005.9; atol = 1e0)
    end

    @testset "opb objective" begin
        result = solve_opb(data, SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18911.70; atol = 1e0)
    end

end

@testset "pwl objective" begin
    data = PowerModels.parse_file("data/matpower/case5_pwlc.m")

    @testset "opf objective" begin
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42905; atol = 1e0)
    end

    @testset "opb objective" begin
        result = solve_opb(data, SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42575; atol = 1e0)
    end

end


@testset "dcline objectives" begin
    data = PowerModels.parse_file("data/matpower/case5_dc.m")

    @testset "nlp objective" begin
        data["dcline"]["1"]["cost"] = [100.0, 300.0, 4000.0, 1.0]
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18160.3; atol = 1e0)
    end

    @testset "qp objective" begin
        data["dcline"]["1"]["cost"] = [1.0, 4000.0, 1.0]
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18157.2; atol = 1e0)
    end

    @testset "linear objective" begin
        data["dcline"]["1"]["cost"] = [4000.0, 1.0]
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18157.2; atol = 1e0)
    end

    @testset "constant objective" begin
        data["dcline"]["1"]["cost"] = [1.0]
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17757.2; atol = 1e0)
    end

    @testset "empty objective" begin
        data["dcline"]["1"]["cost"] = []
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17756.2; atol = 1e0)
    end

    @testset "pwl objective" begin
        data = PowerModels.parse_file("data/matpower/case5_pwlc.m")

        data["dcline"]["1"]["model"] = 1
        data["dcline"]["1"]["ncost"] = 4
        data["dcline"]["1"]["cost"] = [0.0, 10.0, 20.0, 15.0, 100.0, 50.0, 150.0, 800.0]
        result = solve_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 42915; atol = 1e0)
    end
end
