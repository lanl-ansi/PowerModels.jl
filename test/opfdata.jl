@testset "test opfdata parser" begin
    @testset "example 0 file" begin
        result = solve_opf("../test/data/opfdata/example_0.json", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1354333.3168954465; atol = 1e2)
    end

    @testset "example 0 case opfdata (parse_file)" begin
        data = PowerModels.parse_file("../test/data/opfdata/example_0.json")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1354333.3168954465; atol = 1e2)
    end

    @testset "example 0 case opfdata (parse_opfdata)" begin
        data = PowerModels.parse_opfdata("../test/data/opfdata/example_0.json")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1354333.3168954465; atol = 1e2)
    end

    @testset "example 0 case opfdata (parse_opfdata; iostream)" begin
        open("../test/data/opfdata/example_0.json") do f
            data = PowerModels.parse_matpower(f)
            @test isa(JSON.json(data), String)

            result = solve_opf(data, ACPPowerModel, nlp_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 1354333.3168954465; atol = 1e2)
        end
    end

    @testset "example 1 file" begin
        result = solve_opf("../test/data/opfdata/example_1.json", ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 6935.242110031468; atol = 1e0)
    end

    @testset "example 1 case opfdata (parse_file)" begin
        data = PowerModels.parse_file("../test/data/opfdata/example_1.json")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 6935.242110031468; atol = 1e0)
    end

    @testset "example 1 case opfdata (parse_opfdata)" begin
        data = PowerModels.parse_opfdata("../test/data/opfdata/example_1.json")
        @test isa(JSON.json(data), String)

        result = solve_opf(data, ACPPowerModel, nlp_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 6935.242110031468; atol = 1e0)
    end

    @testset "example 1 case opfdata (parse_opfdata; iostream)" begin
        open("../test/data/opfdata/example_1.json") do f
            data = PowerModels.parse_matpower(f)
            @test isa(JSON.json(data), String)

            result = solve_opf(data, ACPPowerModel, nlp_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 6935.242110031468; atol = 1e0)
        end
    end
end
