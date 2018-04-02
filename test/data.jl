# Tests of data checking and transformation code

@testset "test idempotent units transformations" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/case3.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, data_base)
    end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/case5_asym.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, data_base)
    end
    @testset "5-bus case with pwl costs" begin
        data = PowerModels.parse_file("../test/data/case5_pwlc.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, data_base)
    end
    @testset "24-bus case" begin
        data = PowerModels.parse_file("../test/data/case24.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, data_base)
    end


    @testset "3-bus case solution" begin
        result = run_ac_opf("../test/data/case3.m", ipopt_solver)
        result_base = deepcopy(result)

        PowerModels.make_mixed_units(result["solution"])
        PowerModels.make_per_unit(result["solution"])

        @test compare_dict(result, result_base)
    end
    @testset "5-bus case solution" begin
        result = run_ac_opf("../test/data/case5_asym.m", ipopt_solver, setting = Dict("output" => Dict("branch_flows" => true)))
        result_base = deepcopy(result)

        PowerModels.make_mixed_units(result["solution"])
        PowerModels.make_per_unit(result["solution"])

        @test compare_dict(result, result_base)
    end
    @testset "24-bus case solution" begin
        result = run_ac_opf("../test/data/case24.m", ipopt_solver, setting = Dict("output" => Dict("branch_flows" => true)))
        result_base = deepcopy(result)

        PowerModels.make_mixed_units(result["solution"])
        PowerModels.make_per_unit(result["solution"])

        @test compare_dict(result, result_base)
    end


    @testset "5-bus case solution with duals" begin
        result = run_dc_opf("../test/data/case5.m", ipopt_solver, setting = Dict("output" => Dict("branch_flows" => true, "duals" => true)))
        result_base = deepcopy(result)

        PowerModels.make_mixed_units(result["solution"])
        PowerModels.make_per_unit(result["solution"])

        @test compare_dict(result, result_base)
    end

end


@testset "test topology propagation" begin
    @testset "component status updates" begin

        data_initial = PowerModels.parse_file("../test/data/case7_tplgy.m")

        data = PowerModels.parse_file("../test/data/case7_tplgy.m")
        PowerModels.propagate_topology_status(data)

        @test length(data_initial["bus"]) == length(data["bus"])
        @test length(data_initial["gen"]) == length(data["gen"])
        @test length(data_initial["branch"]) == length(data["branch"])

        active_buses = Set(["2", "4", "5", "7"])
        active_branches = Set(["8"])
        active_dclines = Set(["3"])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test bus["bus_type"] != 4
            else
                @test bus["bus_type"] == 4
            end
        end

        for (i,branch) in data["branch"]
            if i in active_branches
                @test branch["br_status"] == 1
            else
                @test branch["br_status"] == 0
            end
        end

        for (i,dcline) in data["dcline"]
            if i in active_dclines
                @test dcline["br_status"] == 1
            else
                @test dcline["br_status"] == 0
            end
        end
    end

    @testset "component filtering updates" begin
        data_initial = PowerModels.parse_file("../test/data/case7_tplgy.m")

        data = PowerModels.parse_file("../test/data/case7_tplgy.m")
        PowerModels.propagate_topology_status(data)
        PowerModels.select_largest_component(data)

        @test length(data_initial["bus"]) == length(data["bus"])
        @test length(data_initial["gen"]) == length(data["gen"])
        @test length(data_initial["branch"]) == length(data["branch"])

        active_buses = Set(["4", "5", "7"])
        active_branches = Set(["8"])
        active_dclines = Set(["3"])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test bus["bus_type"] != 4
            else
                @test bus["bus_type"] == 4
            end
        end

        for (i,branch) in data["branch"]
            if i in active_branches
                @test branch["br_status"] == 1
            else
                @test branch["br_status"] == 0
            end
        end

        for (i,dcline) in data["dcline"]
            if i in active_dclines
                @test dcline["br_status"] == 1
            else
                @test dcline["br_status"] == 0
            end
        end
    end

    @testset "output values" begin
        data = PowerModels.parse_file("../test/data/case7_tplgy.m")
        PowerModels.propagate_topology_status(data)
        result = run_opf(data, ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 1778; atol = 1e0)

        solution = result["solution"]

        active_buses = Set(["2", "4", "5", "7"])
        active_gens = Set(["2", "3"])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test !isequal(solution["bus"][i]["va"], NaN)
            else
                @test isequal(solution["bus"][i]["va"], NaN)
            end
        end

        for (i,gen) in data["gen"]
            if i in active_gens
                @test !isequal(solution["gen"][i]["pg"], NaN)
            else
                @test isequal(solution["gen"][i]["pg"], NaN)
            end
        end
    end

end


@testset "test user ext init" begin
    @testset "3-bus case" begin
        pm = build_generic_model("../test/data/case3.m", ACPPowerModel, PowerModels.post_opf, ext = Dict(:some_data => "bloop"))

        #println(pm.ext)

        @test haskey(pm.ext, :some_data)
        @test pm.ext[:some_data] == "bloop"

        result = solve_generic_model(pm, IpoptSolver(print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
end
