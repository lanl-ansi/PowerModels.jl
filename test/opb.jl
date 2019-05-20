

@testset "test nfa opb" begin
    @testset "3-bus case" begin
        result = run_opb("../test/data/matpower/case3.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus tranformer swap case" begin
        result = run_opb("../test/data/matpower/case5.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opb("../test/data/matpower/case5_asym.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_opb("../test/data/matpower/case5_gap.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], -27410.0; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_opb("../test/data/matpower/case5_dc.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus with asymmetric line charge" begin
        result = run_opb("../test/data/pti/case5_alc.raw", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 1000.0; atol = 1e0)
    end
    @testset "5-bus with negative generators" begin
        result = run_opb("../test/data/matpower/case5_npg.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], -6844.0; atol = 1e0)
    end
    @testset "5-bus with only current limit data" begin
        result = run_opb("../test/data/matpower/case5_clm.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 14810.0; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opb("../test/data/matpower/case5_pwlc.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 42565.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opb("../test/data/matpower/case6.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opb("../test/data/matpower/case24.m", NFAPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 61001.2; atol = 1e0)
    end
end


@testset "test dcp opb" begin
    @testset "3-bus case" begin
        result = run_opb("../test/data/matpower/case3.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opb("../test/data/matpower/case5_pwlc.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 42565.8; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opb("../test/data/matpower/case6.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    @testset "24-bus case" begin
        result = run_opb("../test/data/matpower/case24.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 61001.2; atol = 1e0)
    end
end


@testset "test soc wr opb" begin
    @testset "3-bus case" begin
        result = run_opb("../test/data/matpower/case3.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 5638.97; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opb("../test/data/matpower/case5_pwlc.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 42565.7; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opb("../test/data/matpower/case6.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 11277.9; atol = 1e0)
    end
    @testset "24-bus case" begin
        result = run_opb("../test/data/matpower/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["objective"], 61001.2; atol = 1e0)
    end
end
