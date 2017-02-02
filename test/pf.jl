

@testset "test ac pf" begin
    @testset "3-bus case" begin
        result = run_ac_pf("../test/data/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 148.0; atol = 1e-1)
        @test isapprox(result["solution"]["gen"]["1"]["qg"], 54.6; atol = 1e-1)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92617; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["va"], 7.25886; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.90000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["va"], -17.26711; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/case24.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test dc pf" begin
    @testset "3-bus case" begin
        result = run_dc_pf("../test/data/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 144.99; atol = 1e-1)

        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["va"], 5.24122; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["va"], -16.21006; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/case24.m", DCPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test soc pf" begin
    @testset "3-bus case" begin
        result = run_pf("../test/data/case3.m", SOCWRPowerModel, ipopt_solver)

        @test result["solution"]["gen"]["1"]["pg"] >= 148.0

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end






