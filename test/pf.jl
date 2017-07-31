@testset "test ac pf" begin
    @testset "3-bus case" begin
        result = run_ac_pf("../test/data/case3.m", ipopt_solver, setting = Dict("output" => Dict("line_flows" => true)))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 160.0063; atol = 1e-1)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0; atol = 1e-1)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92617; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.90000; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  10; atol = 1e-3)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -10; atol = 1e-3)
        @test isapprox(result["solution"]["dcline"]["1"]["qf"], -40.3045; atol = 1e-3)
        @test isapprox(result["solution"]["dcline"]["1"]["qt"],   6.47562; atol = 1e-3)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/case5_asym.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_ac_pf("../test/data/case5_dc.m", ipopt_solver, setting = Dict("output" => Dict("line_flows" => true)))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["3"]["pg"], 333.6866; atol = 1e-1)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.0635; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 1.0808; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 1.1; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.0641; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], -0; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["5"]["vm"], 1.0530; atol = 1e-3)


        @test isapprox(result["solution"]["dcline"]["1"]["pf"], 10; atol = 1e-3)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -8.9; atol = 1e-3)

    end
    @testset "6-bus case" begin
        result = run_pf("../test/data/case6.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-3)
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

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 154.994; atol = 1e-1)

        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["va"], 5.24122; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["va"], -16.21006; atol = 1e-3)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_pf("../test/data/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_dc_pf("../test/data/case6.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-3)
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

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test result["solution"]["gen"]["1"]["pg"] >= 148.0

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 160.0063; atol = 1e-1)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0; atol = 1e-1)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"], 10; atol = 1e-3)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -10; atol = 1e-3)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/case5_asym.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf("../test/data/case6.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end
