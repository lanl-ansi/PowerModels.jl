# Tests for data conversion from PSSE to PowerModels data structure

function set_costs!(data::Dict)
    for (n, gen) in data["gen"]
        gen["cost"] = [0., 100., 0.]
        gen["ncost"] = 3
        gen["startup"] = 0.
        gen["shutdown"] = 0.
        gen["model"] = 2
    end

    for (n, dcline) in data["dcline"]
        dcline["cost"] = [0., 100., 0.]
        dcline["ncost"] = 3
        dcline["startup"] = 0.
        dcline["shutdown"] = 0.
        dcline["model"] = 2
    end
end

@testset "test PSS(R)E parser" begin
    @testset "4-bus frankenstein file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/frankenstein_00.raw")
            data_mp = PowerModels.parse_file("../test/data/matpower/frankenstein_00.m")

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal
            @test isapprox(result_mp["objective"], result_pti["objective"]; atol = 1e-5)
        end

        @testset "with two-winding transformer unit conversions" begin
            data_pti = PowerModels.parse_file("../test/data/pti/frankenstein_00_2.raw")

            for (k, v) in data_pti["branch"]
                if v["transformer"]
                    @test isapprox(v["br_r"], 0.; atol=1e-2)
                    @test isapprox(v["br_x"], 0.179; atol=1e-2)
                    @test isapprox(v["tap"], 1.019; atol=1e-2)
                    @test isapprox(v["shift"], 0.; atol=1e-2)
                    @test isapprox(v["rate_a"], 0.84; atol=1e-2)
                    @test isapprox(v["rate_b"], 0.84; atol=1e-2)
                    @test isapprox(v["rate_c"], 0.84; atol=1e-2)
                end
            end

            result_opf = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_opf["status"] == :LocalOptimal
            @test isapprox(result_opf["objective"], 29.4043; atol=1e-4)

            result_pf = PowerModels.run_pf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)

            for (bus, vm, va) in zip(["1002", "1005", "1008", "1009"],
                                     [1.0032721, 1.0199983, 1.0203627, 1.03],
                                     [2.946182, 0.129922, -0.002062, 0.])
                @test isapprox(result_pf["solution"]["bus"][bus]["vm"], vm; atol=1e-1)
                @test isapprox(result_pf["solution"]["bus"][bus]["va"], deg2rad(va); atol=1e-2)
            end
        end
    end

    @testset "3-bus case file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/case3.raw")
            data_mp = PowerModels.parse_file("../test/data/matpower/case3.m")

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal

            # TODO: Needs approximation of DCLINES
            @test isapprox(result_pti["objective"], result_mp["objective"]; atol=10)
        end
    end

    @testset "5-bus case file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/case5.raw")
            data_mp = PowerModels.parse_file("../test/data/matpower/case5.m")

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal

            @test isapprox(result_pti["objective"], result_mp["objective"]; atol=1e-5)
        end
    end

    @testset "7-bus topology case file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/case7_tplgy.raw")
            data_mp  = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")

            PowerModels.propagate_topology_status(data_pti)
            PowerModels.propagate_topology_status(data_mp)

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal

            # TODO: Needs approximation of DCLINES
            @test isapprox(result_mp["objective"], result_pti["objective"]; atol=20)
        end
    end

    @testset "14-bus case file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/case14.raw")
            data_mp = PowerModels.parse_file("../test/data/matpower/case14.m")

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal

            @test isapprox(result_pti["objective"], result_mp["objective"]; atol=1e-5)
        end
    end

    @testset "24-bus case file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/case24.raw")
            data_mp = PowerModels.parse_file("../test/data/matpower/case24.m")

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal

            # NOTE: ANGMIN and ANGMAX do not exist in PSSE Spec, accounting for the objective differences
            @test isapprox(result_pti["objective"], result_mp["objective"]; atol=0.6914)
        end
    end

    @testset "30-bus case file" begin
        @testset "AC Model" begin
            data_pti = PowerModels.parse_file("../test/data/pti/case30.raw")
            data_mp = PowerModels.parse_file("../test/data/matpower/case30.m")

            set_costs!(data_mp)

            result_pti = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)
            result_mp  = PowerModels.run_opf(data_mp, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_pti["status"] == :LocalOptimal
            @test result_mp["status"]  == :LocalOptimal

            @test isapprox(result_pti["objective"], result_mp["objective"]; atol=1e-5)
        end
    end

    @testset "exception handling" begin
        dummy_data = PowerModels.parse_file("../test/data/pti/frankenstein_70.raw")

        setlevel!(getlogger(PowerModels), "warn")

        @test_warn(getlogger(PowerModels), "Could not find bus 1, returning 0 for field vm",
                   PowerModels.get_bus_value(1, "vm", dummy_data))

        @test_warn(getlogger(PowerModels), "Two-Terminal DC Lines are not yet fully supported",
                   PowerModels.parse_file("../test/data/pti/frankenstein_70.raw"))

        @test_warn(getlogger(PowerModels), "Switched shunt converted to fixed shunt, with default value gs=0.0",
                   PowerModels.parse_file("../test/data/pti/frankenstein_70.raw"))

       @test_warn(getlogger(PowerModels), "Voltage Source Converter DC lines are not yet supported",
                   PowerModels.parse_file("../test/data/pti/frankenstein_70.raw"))

        @test_warn(getlogger(PowerModels), "Magnetizing admittance is not yet supported",
                   PowerModels.parse_file("../test/data/pti/frankenstein_70.raw"))

        @test_warn(getlogger(PowerModels), "PTI v33 does not contain vmin and vmax values, defaults of 0.9 and 1.1, respectively, assumed.",
                   PowerModels.parse_file("../test/data/pti/parser_test_i.raw"))


        setlevel!(getlogger(PowerModels), "error")
    end

    @testset "three-winding transformer" begin
        @testset "without unit conversion" begin
            data_pti = PowerModels.parse_file("../test/data/pti/three_winding_test.raw")

            for (branch, br_r, br_x, tap, shift, rate_a, rate_b, rate_c) in zip(["1", "2", "3"],
                                                                                [0.00225, 0.00225, -0.00155],
                                                                                [0.05, 0.15, 0.15],
                                                                                [1.1, 1.0, 1.0],
                                                                                [0.0, 0.0, 0.0],
                                                                                [2.0, 1.0, 1.0],
                                                                                [2.0, 1.0, 1.0],
                                                                                [4.0, 1.0, 1.0])
                @test isapprox(data_pti["branch"][branch]["br_r"], br_r; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["br_x"], br_x; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["tap"], tap; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["shift"], shift; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["rate_a"], rate_a; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["rate_b"], rate_b; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["rate_c"], rate_c; atol=1e-4)
            end

            @test length(data_pti["bus"]) == 4
            @test length(data_pti["branch"]) == 3

            result_opf = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_opf["status"] == :LocalOptimal
            @test isapprox(result_opf["objective"], 9.99647; atol=1e-5)

            result_pf = PowerModels.run_pf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)

            for (bus, vm, va) in zip(["1001", "1002", "1003", "11001"], [1.09, 1.0, 1.0, 0.997], [2.304, 0., 6.042244, 2.5901])
                @test isapprox(result_pf["solution"]["bus"][bus]["vm"], vm; atol=1e-1)
                @test isapprox(result_pf["solution"]["bus"][bus]["va"], deg2rad(va); atol=1e-2)
            end
        end

        @testset "with unit conversion" begin
            data_pti = PowerModels.parse_file("../test/data/pti/three_winding_test_2.raw")

            for (branch, br_r, br_x, tap, shift, rate_a, rate_b, rate_c) in zip(["1", "2", "3"],
                                                                                [0.0, 0.0, 0.0],
                                                                                [0.05, 0.15, 0.15],
                                                                                [1.1, 1.0, 1.0],
                                                                                [0.0, 0.0, 0.0],
                                                                                [2.0, 1.0, 1.0],
                                                                                [2.0, 1.0, 1.0],
                                                                                [4.0, 1.0, 1.0])
                @test isapprox(data_pti["branch"][branch]["br_r"], br_r; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["br_x"], br_x; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["tap"], tap; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["shift"], shift; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["rate_a"], rate_a; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["rate_b"], rate_b; atol=1e-4)
                @test isapprox(data_pti["branch"][branch]["rate_c"], rate_c; atol=1e-4)
            end


            result_opf = PowerModels.run_opf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)

            @test result_opf["status"] == :LocalOptimal
            @test isapprox(result_opf["objective"], 10.0; atol=1e-5)

            result_pf = PowerModels.run_pf(data_pti, PowerModels.ACPPowerModel, ipopt_solver)

            for (bus, vm, va) in zip(["1001", "1002", "1003", "11001"], [1.09, 1.0, 1.0, 0.997], [2.304, 0., 6.042244, 2.5901])
                @test isapprox(result_pf["solution"]["bus"][bus]["vm"], vm; atol=1e-1)
                @test isapprox(result_pf["solution"]["bus"][bus]["va"], deg2rad(va); atol=1e-2)
            end

        end
    end
end
