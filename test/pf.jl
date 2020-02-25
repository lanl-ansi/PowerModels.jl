@testset "test ac polar pf" begin
    @testset "3-bus case" begin
        result = run_ac_pf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92617; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.90000; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["qf"], -0.403045; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["qt"],  0.0647562; atol = 1e-5)
    end
    @testset "5-bus transformer swap case" begin
        result = run_pf("../test/data/matpower/case5.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_ac_pf("../test/data/matpower/case5_dc.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["3"]["pg"], 3.336866; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.0635; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 1.0808; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 1.1; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.0641; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], -0; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["5"]["vm"], 1.0530; atol = 1e-3)


        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.15; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.089; atol = 1e-5)

    end
    @testset "6-bus case" begin
        result = run_pf("../test/data/matpower/case6.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test ac rect pf" begin
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", ACRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    #=
    # numerical issues with ipopt, likely div. by zero issue in jacobian
    @testset "5-bus case with hvdc line" begin
        result = run_pf("../test/data/matpower/case5_dc.m", ACRPowerModel, ipopt_solver, setting = Dict("output" => Dict("branch_flows" => true)))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["3"]["pg"], 3.336866; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.0635; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 1.0808; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 1.1; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.0641; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], -0; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["5"]["vm"], 1.0530; atol = 1e-3)


        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.089; atol = 1e-5)
    end
    =#
end


@testset "test ac tan pf" begin
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", ACTPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_pf("../test/data/matpower/case5_dc.m", ACTPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["3"]["pg"], 3.336866; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.0635; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 1.0808; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 1.1; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.0641; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], -0; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["5"]["vm"], 1.0530; atol = 1e-3)


        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.15; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.089; atol = 1e-5)
    end
end



@testset "test iv pf" begin
    @testset "3-bus case" begin
        result = run_pf_iv("../test/data/matpower/case3.m", IVRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92617; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.90000; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-5)
        # @test isapprox(result["solution"]["dcline"]["1"]["qf"], -0.403045; atol = 1e-5) #no reason to expect this is unique
        # @test isapprox(result["solution"]["dcline"]["1"]["qt"],  0.0647562; atol = 1e-5) #no reason to expect this is unique
    end
    @testset "5-bus case with hvdc line" begin
        result = run_pf_iv("../test/data/matpower/case5_dc.m", IVRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["3"]["pg"], 3.336866; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.0635; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 1.0808; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 1.1; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.0641; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], -0; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["5"]["vm"], 1.0530; atol = 1e-3)


        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.15; atol = 1e-5)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.089; atol = 1e-5)
    end
end


@testset "test dc pf" begin
    @testset "3-bus case" begin
        result = run_dc_pf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 1.54994; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["va"],  0.00000; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["2"]["va"],  0.09147654582; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["3"]["va"], -0.28291891895; atol = 1e-5)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_pf("../test/data/matpower/case5_asym.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_dc_pf("../test/data/matpower/case6.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-5)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with matpower DCMP model" begin
        result = run_pf("../test/data/matpower/case5.m", DCMPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED

        @test isapprox(result["solution"]["bus"]["1"]["va"],  0.0621920; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["2"]["va"],  0.0002623; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["3"]["va"], 0.0088601; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-7)

    end
end


@testset "test soc pf" begin
    @testset "3-bus case" begin
        result = run_pf("../test/data/matpower/case3.m", SOCWRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test result["solution"]["gen"]["1"]["pg"] >= 1.480

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-4)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-4)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf("../test/data/matpower/case6.m", SOCWRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end



@testset "test soc distflow pf_bf" begin
    @testset "3-bus case" begin
        result = run_pf_bf("../test/data/matpower/case3.m", SOCBFPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test result["solution"]["gen"]["1"]["pg"] >= 1.480

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-4)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-4)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf_bf("../test/data/matpower/case5_asym.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_pf_bf("../test/data/matpower/case5_dc.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf_bf("../test/data/matpower/case6.m", SOCBFPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf_bf("../test/data/matpower/case24.m", SOCBFPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test linear distflow pf_bf" begin
    @testset "3-bus case" begin
        result = run_pf_bf("../test/data/matpower/case3.m", BFAPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test result["solution"]["gen"]["1"]["pg"] >= 1.480

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-4)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-4)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf_bf("../test/data/matpower/case5_asym.m", BFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_pf_bf("../test/data/matpower/case5_dc.m", BFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf_bf("../test/data/matpower/case6.m", BFAPowerModel, ipopt_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        data = parse_file("../test/data/matpower/case24.m")
        result = run_pf_bf(data, BFAPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(sum(l["pd"] for l in values(data["load"])),
            sum(g["pg"] for g in values(result["solution"]["gen"]));
            atol = 1e-3)
    end
end


@testset "test sdp pf" begin
    # note: may have issues on linux (04/02/18)
    @testset "3-bus case" begin
        result = run_pf("../test/data/matpower/case3.m", SDPWRMPowerModel, scs_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test result["solution"]["gen"]["1"]["pg"] >= 1.480

        @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

        @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-4)
        @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-4)
    end
    # note: may have issues on os x (05/07/18)
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", SDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf("../test/data/matpower/case6.m", SDPWRMPowerModel, scs_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", SDPWRMPowerModel, scs_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test dc pf" begin
    @testset "3-bus case" begin
        result = run_dc_pf("../test/data/matpower/case3.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 1.54994; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["va"],  0.00000; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["2"]["va"],  0.09147654582; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["3"]["va"], -0.28291891895; atol = 1e-5)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_pf("../test/data/matpower/case5_asym.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_dc_pf("../test/data/matpower/case6.m", ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-5)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with matpower DCMP model" begin
        result = run_pf("../test/data/matpower/case5.m", DCMPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED

        @test isapprox(result["solution"]["bus"]["1"]["va"],  0.0621920; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["2"]["va"],  0.0002623; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["3"]["va"], 0.0088601; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-7)

    end
end


@testset "test native dc pf solver" begin
    # degenerate due to no slack bus
    # @testset "3-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case3.m")
    #     result = run_dc_pf(data, ipopt_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_dc_pf(data, ipopt_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    @testset "5-bus asymmetric case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        result = run_dc_pf(data, ipopt_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
    # solve_dc_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    #     result = run_dc_pf(data, ipopt_solver)
    #     native = compute_dc_pf(data)

    #     for (i,bus) in data["bus"]
    #         opt_val = result["solution"]["bus"][i]["va"]
    #         lin_val = native["bus"][i]["va"]
    #         @test isapprox(opt_val, lin_val)
    #     end
    # end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        result = run_dc_pf(data, ipopt_solver)
        native = compute_dc_pf(data)

        for (i,bus) in data["bus"]
            opt_val = result["solution"]["bus"][i]["va"]
            lin_val = native["bus"][i]["va"]
            @test isapprox(opt_val, lin_val; atol = 1e-10)
        end
    end
end
