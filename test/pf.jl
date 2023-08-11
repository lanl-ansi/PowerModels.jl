@testset "test ac polar pf" begin
    @testset "3-bus case" begin
        result = run_ac_pf("../test/data/matpower/case3.m", nlp_solver)

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

        # removed due to cross platform consistnecy, started failing 05/22/2020 when ipopt moved to jll artifacts
        #@test isapprox(result["solution"]["dcline"]["1"]["qf"], -0.403045; atol = 1e-5)
        #@test isapprox(result["solution"]["dcline"]["1"]["qt"],  0.0647562; atol = 1e-5)
    end
    @testset "5-bus transformer swap case" begin
        result = run_pf("../test/data/matpower/case5.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus multiple slack gens case" begin
        result = run_pf("../test/data/matpower/case5_ext.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 0.40; atol = 1e-3)
        @test isapprox(result["solution"]["gen"]["1"]["qg"], 0.30; atol = 1e-3)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_ac_pf("../test/data/matpower/case5_dc.m", nlp_solver)

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
        result = run_pf("../test/data/matpower/case6.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.10000; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test ac rect pf" begin
    @testset "5-bus asymmetric case" begin
        result = run_pf("../test/data/matpower/case5_asym.m", ACRPowerModel, nlp_solver)
        if VERSION >= v"1.9" && Sys.iswindows()
            # Some numerical issue on Windows with Julia 1.9?
            @test result["termination_status"] in (LOCALLY_SOLVED, ITERATION_LIMIT)
        else
            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 0; atol = 1e-2)
        end
    end
    #=
    # numerical issues with ipopt, likely div. by zero issue in jacobian
    @testset "5-bus case with hvdc line" begin
        result = run_pf("../test/data/matpower/case5_dc.m", ACRPowerModel, nlp_solver, setting = Dict("output" => Dict("branch_flows" => true)))

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
    # removed for cross platform compat (julia v1.6, linux)
    # @testset "5-bus asymmetric case" begin
    #     result = run_pf("../test/data/matpower/case5_asym.m", ACTPowerModel, nlp_solver)

    #     @test result["termination_status"] == LOCALLY_SOLVED
    #     @test isapprox(result["objective"], 0; atol = 1e-2)
    # end
    @testset "5-bus case with hvdc line" begin
        result = run_pf("../test/data/matpower/case5_dc.m", ACTPowerModel, nlp_solver, solution_processors=[sol_data_model!])

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
        result = run_pf_iv("../test/data/matpower/case3.m", IVRPowerModel, nlp_solver, solution_processors=[sol_data_model!])

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
        result = run_pf_iv("../test/data/matpower/case5_dc.m", IVRPowerModel, nlp_solver, solution_processors=[sol_data_model!])

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
        result = run_dc_pf("../test/data/matpower/case3.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 1.54994; atol = 1e-3)

        @test isapprox(result["solution"]["bus"]["1"]["va"],  0.00000; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["2"]["va"],  0.09147654582; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["3"]["va"], -0.28291891895; atol = 1e-5)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_pf("../test/data/matpower/case5_asym.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus multiple slack gens case" begin
        result = run_dc_pf("../test/data/matpower/case5_ext.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)

        @test isapprox(result["solution"]["gen"]["1"]["pg"], 0.40; atol = 1e-3)
    end
    @testset "6-bus case" begin
        result = run_dc_pf("../test/data/matpower/case6.m", nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.00000; atol = 1e-5)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.00000; atol = 1e-5)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", DCPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test matpower dc pf" begin
    @testset "5-bus case with matpower DCMP model" begin
        result = run_pf("../test/data/matpower/case5.m", DCMPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED

        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0621920; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["2"]["va"], 0.0002623; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["3"]["va"], 0.0088601; atol = 1e-7)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0000000; atol = 1e-7)
    end
end


@testset "test soc pf" begin
    # started failing 05/22/2020 when ipopt moved to jll artifacts
    # @testset "3-bus case" begin
    #     result = run_pf("../test/data/matpower/case3.m", SOCWRPowerModel, nlp_solver, solution_processors=[sol_data_model!])

    #     @test result["termination_status"] == LOCALLY_SOLVED
    #     @test isapprox(result["objective"], 0; atol = 1e-2)

    #     @test result["solution"]["gen"]["1"]["pg"] >= 1.480

    #     @test isapprox(result["solution"]["gen"]["2"]["pg"], 1.600063; atol = 1e-3)
    #     @test isapprox(result["solution"]["gen"]["3"]["pg"], 0.0; atol = 1e-3)

    #     @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
    #     @test isapprox(result["solution"]["bus"]["2"]["vm"], 0.92616; atol = 1e-3)
    #     @test isapprox(result["solution"]["bus"]["3"]["vm"], 0.89999; atol = 1e-3)

    #     @test isapprox(result["solution"]["dcline"]["1"]["pf"],  0.10; atol = 1e-4)
    #     @test isapprox(result["solution"]["dcline"]["1"]["pt"], -0.10; atol = 1e-4)
    # end
    # started failing 05/22/2020 when ipopt moved to jll artifacts (only on travis)
    # @testset "5-bus asymmetric case" begin
    #     result = run_pf("../test/data/matpower/case5_asym.m", SOCWRPowerModel, nlp_solver)

    #     @test result["termination_status"] == LOCALLY_SOLVED
    #     @test isapprox(result["objective"], 0; atol = 1e-2)
    # end
    @testset "6-bus case" begin
        result = run_pf("../test/data/matpower/case6.m", SOCWRPowerModel, nlp_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", SOCWRPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end



@testset "test soc distflow pf_bf" begin
    @testset "3-bus case" begin
        result = run_pf_bf("../test/data/matpower/case3.m", SOCBFPowerModel, nlp_solver, solution_processors=[sol_data_model!])

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
    # removed due to windows instability in Julia v1.9
    # @testset "5-bus asymmetric case" begin
    #     result = run_pf_bf("../test/data/matpower/case5_asym.m", SOCBFPowerModel, nlp_solver)

    #     @test result["termination_status"] == LOCALLY_SOLVED
    #     @test isapprox(result["objective"], 0; atol = 1e-2)
    # end
    @testset "5-bus case with hvdc line" begin
        result = run_pf_bf("../test/data/matpower/case5_dc.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf_bf("../test/data/matpower/case6.m", SOCBFPowerModel, nlp_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf_bf("../test/data/matpower/case24.m", SOCBFPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end


@testset "test linear distflow pf_bf" begin
    @testset "3-bus case" begin
        result = run_pf_bf("../test/data/matpower/case3.m", BFAPowerModel, nlp_solver, solution_processors=[sol_data_model!])

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
        result = run_pf_bf("../test/data/matpower/case5_asym.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "5-bus case with hvdc line" begin
        result = run_pf_bf("../test/data/matpower/case5_dc.m", BFAPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf_bf("../test/data/matpower/case6.m", BFAPowerModel, nlp_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        data = parse_file("../test/data/matpower/case24.m")
        result = run_pf_bf(data, BFAPowerModel, nlp_solver)

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
        result = run_pf("../test/data/matpower/case3.m", SDPWRMPowerModel, sdp_solver, solution_processors=[sol_data_model!])

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
        result = run_pf("../test/data/matpower/case5_asym.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
    @testset "6-bus case" begin
        result = run_pf("../test/data/matpower/case6.m", SDPWRMPowerModel, sdp_solver, solution_processors=[sol_data_model!])

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)
        @test isapprox(result["solution"]["bus"]["1"]["vm"], 1.09999; atol = 1e-3)
        @test isapprox(result["solution"]["bus"]["4"]["vm"], 1.09999; atol = 1e-3)
    end
    @testset "24-bus rts case" begin
        result = run_pf("../test/data/matpower/case24.m", SDPWRMPowerModel, sdp_solver)

        @test result["termination_status"] == OPTIMAL
        @test isapprox(result["objective"], 0; atol = 1e-2)
    end
end

