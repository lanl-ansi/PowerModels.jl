

@testset "test ac polar opf" begin
    @testset "3-bus case" begin
        result = run_ac_opf("../test/data/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_ac_opf("../test/data/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_ac_opf("../test/data/case5_dc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17760.2; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_ac_opf("../test/data/case6.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11567; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end


@testset "test ac rect opf" begin
    #=
    # numerical issue
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", ACRPowerModel, ipopt_solver)

        #@test result["status"] == :LocalOptimal
        #@test isapprox(result["objective"], 5812; atol = 1e0)
        @test result["status"] == :Error
    end
    =#
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11567; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", ACRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end


@testset "test ac tan opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_ac_opf("../test/data/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11567; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", ACTPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79804; atol = 1e0)
    end
end


@testset "test dc opf" begin
    @testset "3-bus case" begin
        result = run_dc_opf("../test/data/case3.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5782; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_dc_opf("../test/data/case5_asym.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17479; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_dc_opf("../test/data/case5_pwlc.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42565; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_dc_opf("../test/data/case6.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11396; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    # TODO verify this is really infeasible
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/case24.m", DCPPowerModel, ipopt_solver)

    #    @test result["status"] == :LocalOptimal
    #    @test isapprox(result["objective"], 79804; atol = 1e0)
    #end
end

@testset "test dc+ll opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5885; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17693; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/case5_pwlc.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42937; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11515; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", DCPLLPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 82240; atol = 1e0)
    end
end


@testset "test soc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5746.7; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14999; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/case5_pwlc.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11560; atol = 1e0)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", SOCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 70690.7; atol = 1e0)
    end
end


@testset "test qc opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5780; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15921; atol = 1e0)
    end
    @testset "5-bus with pwl costs" begin
        result = run_opf("../test/data/case5_pwlc.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 42895; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11567; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", QCWRPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 76599.9; atol = 1e0)
    end
end

@testset "test qc opf with trilinear convexhull relaxation" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5817.58; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_opf("../test/data/case5_asym.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15816.9; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11567.1; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_opf("../test/data/case24.m", QCWRTriPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 76752.3; atol = 1e0)
    end
end


@testset "test sdp opf" begin
    @testset "3-bus case" begin
        result = run_opf("../test/data/case3.m", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5851.3; atol = 1e0)
    end
    # TODO see if convergence time can be improved
    #@testset "5-bus asymmetric case" begin
    #    result = run_opf("../test/data/case5_asym.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 16664; atol = 1e0)
    #end
    @testset "6-bus case" begin
        result = run_opf("../test/data/case6.m", SDPWRMPowerModel, scs_solver)

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 11558.5; atol = 1e0)
    end
    # TODO replace this with smaller case, way too slow for unit testing
    #@testset "24-bus rts case" begin
    #    result = run_opf("../test/data/case24.m", SDPWRMPowerModel, scs_solver)

    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 75153; atol = 1e0)
    #end
end




@testset "test ac v+t polar opf" begin
    PMs = PowerModels

    function post_opf_var(pm::GenericPowerModel)
        PMs.variable_voltage(pm)
        PMs.variable_generation(pm)
        PMs.variable_branch_flow(pm)
        PMs.variable_dcline_flow(pm)

        PMs.objective_min_fuel_cost(pm)

        PMs.constraint_voltage(pm)

        for i in ids(pm,:ref_buses)
            PMs.constraint_theta_ref(pm, i)
        end

        for i in ids(pm,:bus)
            PMs.constraint_kcl_shunt(pm, i)
        end

        for i in ids(pm,:branch)
            # these are the functions to be tested
            PMs.constraint_ohms_y_from(pm, i)
            PMs.constraint_ohms_y_to(pm, i)

            PMs.constraint_voltage_angle_difference(pm, i)

            PMs.constraint_thermal_limit_from(pm, i)
            PMs.constraint_thermal_limit_to(pm, i)
        end

        for i in ids(pm,:dcline)
            PMs.constraint_dcline(pm, i)
        end
    end

    @testset "3-bus case" begin
        result = run_generic_model("../test/data/case3.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_generic_model("../test/data/case5_asym.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_generic_model("../test/data/case5_dc.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17760.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_generic_model("../test/data/case6.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11567; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_generic_model("../test/data/case24.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end

