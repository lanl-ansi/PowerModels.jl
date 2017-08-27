# Tests of data checking and transformation code

@testset "test idempotent units transformations" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/case3.m")
        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, PowerModels.parse_file("../test/data/case3.m"))
    end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/case5_asym.m")
        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, PowerModels.parse_file("../test/data/case5_asym.m"))
    end
    @testset "24-bus case" begin
        data = PowerModels.parse_file("../test/data/case24.m")
        PowerModels.make_mixed_units(data)
        PowerModels.make_per_unit(data)

        @test compare_dict(data, PowerModels.parse_file("../test/data/case24.m"))
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
