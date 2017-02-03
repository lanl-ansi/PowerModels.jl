

@testset "test ac opf" begin
    @testset "3-bus case" begin
        result = run_ac_opf("../test/data/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5812; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_ac_opf("../test/data/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
end


@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = run_dc_opf("../test/data/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5695; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_opf("../test/data/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17479; atol = 1e0)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/case24.m", DCPPowerModel, ipopt_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
end


@testset "test soc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5735.9; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70831; atol = 1e0)
    end
end


@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5742.0; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15921; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 77049; atol = 1e0)
    end
end


@testset "test sdp opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5788.7; atol = 1e0)
    end
    # TODO see if convergence time can be improved
    #@testset "5-bus asymmetric case" begin
    #    result = run_opf("../test/data/case5_asym.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 16664; atol = 1e0)
    #end
    # TODO replace this with smaller case, way too slow for unit testing
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/case24.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end




