### Tests for OPF objective variants ###

@testset "linear objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [1400.0, 1.0]
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = []

    @testset "nlp solver" begin
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5420.3; atol = 1e0)
    end

    @testset "conic solver" begin
        result = run_opf(data, SOCWRConicPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 3095.88; atol = 1e0)
    end

    @testset "lp solver" begin
        result = run_dc_opf(data, milp_solver)

        @test result["termination_status"] == OPTIMAL
        # @test isapprox(result["objective"], 4679.05; atol = 1e0)  # Problem upstream with JuMP.SecondOrderCone or JuMP.RotatedSecondOrderCone?
    end
end

@testset "quadratic objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [1.0, 1400.0, 1.0]
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = []

    @testset "nlp solver" begin
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5420.46; atol = 1e0)
    end

    @testset "conic solver" begin
        result = run_opf(data, SOCWRConicPowerModel, sdp_solver)

        # ALMOST_OPTIMAL only required for Julia 1.0 on Linux
        @test result["termination_status"] == OPTIMAL || result["termination_status"] == ALMOST_OPTIMAL
        # 5e0 only required for Julia 1.6 on Linux
        @test isapprox(result["objective"], 3096.04; atol = 5e0)
    end
end

@testset "nlp objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [100.0, 300.0, 1400.0, 1.0] # cubic (JuMP NL)
    # data["gen"]["2"]["cost"] # piece-wise linear
    # data["gen"]["3"]["cost"] # linear
    data["gen"]["4"]["cost"] = [1.0] # constant
    data["gen"]["5"]["cost"] = [] # zero

    data["gen"]["2"]["model"] = 1
    data["gen"]["2"]["ncost"] = 4
    data["gen"]["2"]["cost"] = [22.0,1122.0, 33.0,1417.0, 44.0,1742.0, 55.0,2075.0]

    @testset "opf objective" begin
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 4141.59; atol = 1e0)
    end

    @testset "opb objective" begin
        result = run_opb(data, SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1027.40; atol = 1e0)
    end

end


@testset "dcline objectives" begin
    data = PowerModels.parse_file("data/matpower/case5_dc.m")

    @testset "nlp objective" begin
        data["dcline"]["1"]["cost"] = [100.0, 300.0, 4000.0, 1.0]
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18160.3; atol = 1e0)
    end

    @testset "qp objective" begin
        data["dcline"]["1"]["cost"] = [1.0, 4000.0, 1.0]
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18157.2; atol = 1e0)
    end

    @testset "linear objective" begin
        data["dcline"]["1"]["cost"] = [4000.0, 1.0]
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18157.2; atol = 1e0)
    end

    @testset "constant objective" begin
        data["dcline"]["1"]["cost"] = [1.0]
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17757.2; atol = 1e0)
    end

    @testset "empty objective" begin
        data["dcline"]["1"]["cost"] = []
        result = run_ac_opf(data, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17756.2; atol = 1e0)
    end
end
