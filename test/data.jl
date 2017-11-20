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
