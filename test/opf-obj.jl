### Tests for OPF objective variants ###

@testset "linear objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [1400.0, 1.0]
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = []

    @testset "nlp solver" begin
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5420.3; atol = 1e0)
    end

    @testset "conic solver" begin
        result = run_opf(data, SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 3095.88; atol = 1e0)
    end

    @testset "lp solver" begin
        result = run_dc_opf(data, cbc_solver)

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
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5420.46; atol = 1e0)
    end

    @testset "conic solver" begin
        result = run_opf(data, SOCWRConicPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 3096.04; atol = 1e0)
    end
end

@testset "nlp objective" begin
    data = PowerModels.parse_file("data/matpower/case5.m")
    data["gen"]["1"]["cost"] = [1.0, 1.0, 1400.0, 1.0]
    data["gen"]["4"]["cost"] = [1.0]
    data["gen"]["5"]["cost"] = []

    @testset "opf objective" begin
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5458.52; atol = 1e0)
    end

    @testset "opb objective" begin
        result = run_opb(data, SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 2962.22; atol = 1e0)
    end

end


@testset "dcline objectives" begin
    data = PowerModels.parse_file("data/matpower/case5_dc.m")

    @testset "nlp objective" begin
        data["dcline"]["1"]["cost"] = [1.0, 1.0, 4000.0, 1.0]
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18197.2; atol = 1e0)
    end

    @testset "qp objective" begin
        data["dcline"]["1"]["cost"] = [1.0, 4000.0, 1.0]
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18157.2; atol = 1e0)
    end

    @testset "linear objective" begin
        data["dcline"]["1"]["cost"] = [4000.0, 1.0]
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 18157.2; atol = 1e0)
    end

    @testset "constant objective" begin
        data["dcline"]["1"]["cost"] = [1.0]
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17757.2; atol = 1e0)
    end

    @testset "empty objective" begin
        data["dcline"]["1"]["cost"] = []
        result = run_ac_opf(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 17756.2; atol = 1e0)
    end
end
