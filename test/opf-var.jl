### Tests for OPF variants ###

function build_current_data(base_data)
    c_data = PowerModels.parse_file(base_data)
    PowerModels.check_current_limits(c_data)
    for (i,branch) in c_data["branch"]
        delete!(branch, "rate_a")
    end

    return c_data
end


@testset "test current limit opf" begin

    @testset "test ac polar opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels.run_cl_opf(data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        # does not converge in SCS.jl v0.4.0
        #@testset "5-bus current limit case" begin
        #    result = PowerModels.run_cl_opf("../test/data/matpower/case5_clm.m", ACPPowerModel, ipopt_solver)

        #    @test result["status"] == :LocalOptimal
        #    @test isapprox(result["objective"], 17239.3; atol = 1e0)
        #end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels.run_cl_opf(data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test ac rect opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels.run_cl_opf(data, ACRPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels.run_cl_opf(data, ACRPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test ac tan opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels.run_cl_opf(data, ACTPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15669.8; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels.run_cl_opf(data, ACTPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 8081.52; atol = 1e0)
        end
    end

    @testset "test dc opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels.run_cl_opf(data, DCPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 16154.5; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels.run_cl_opf(data, DCPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 7642.59; atol = 1e0)
        end
    end

    @testset "test dc+ll opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels.run_cl_opf(data, DCPLLPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 16282.6; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels.run_cl_opf(data, DCPLLPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 8110.61; atol = 1e0)
        end
    end

    @testset "test soc (BIM) opf" begin
        @testset "5-bus case" begin
            data = build_current_data("../test/data/matpower/case5.m")
            result = PowerModels.run_cl_opf(data, SOCWRPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15047.7; atol = 1e0)
        end
        @testset "14-bus no limits case" begin
            data = build_current_data("../test/data/matpower/case14.m")
            result = PowerModels.run_cl_opf(data, SOCWRPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 8075.12; atol = 1e0)
        end
    end

    @testset "test sdp opf" begin
        @testset "3-bus case" begin
            data = build_current_data("../test/data/matpower/case3.m")
            result = PowerModels.run_cl_opf(data, SDPWRMPowerModel, scs_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 5747.47; atol = 1e0)
        end
        #@testset "5-bus case" begin
        #    data = build_current_data("../test/data/matpower/case5.m")
        #    result = PowerModels.run_cl_opf(data, SDPWRMPowerModel, scs_solver)

        #    @test result["status"] == :LocalOptimal
        #    @test isapprox(result["objective"], 15418.4; atol = 1e0)
        #end
        #@testset "14-bus case" begin
        #    data = build_current_data("../test/data/matpower/case14.m")
        #    result = PowerModels.run_cl_opf(data, SDPWRMPowerModel, scs_solver)

        #    @test result["status"] == :LocalOptimal
        #    @test isapprox(result["objective"], 8081.52; atol = 1e0)
        #end
    end

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
        result = run_generic_model("../test/data/matpower/case3.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
    @testset "5-bus asymmetric case" begin
        result = run_generic_model("../test/data/matpower/case5_asym.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 17551; atol = 1e0)
    end
    @testset "5-bus gap case" begin
        result = run_generic_model("../test/data/matpower/case5_gap.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], -27497.7; atol = 1e0)
    end
    @testset "5-bus with dcline costs" begin
        result = run_generic_model("../test/data/matpower/case5_dc.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 18156.2; atol = 1e0)
    end
    @testset "6-bus case" begin
        result = run_generic_model("../test/data/matpower/case6.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 11625.3; atol = 1e0)
        @test isapprox(result["solution"]["bus"]["1"]["va"], 0.0; atol = 1e-4)
        @test isapprox(result["solution"]["bus"]["4"]["va"], 0.0; atol = 1e-4)
    end
    @testset "24-bus rts case" begin
        result = run_generic_model("../test/data/matpower/case24.m", ACPPowerModel, ipopt_solver, post_opf_var)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 79805; atol = 1e0)
    end
end

