# Tests of basic data transformation and utilities


@testset "test basic network transformation" begin

    @testset "7-bus with inactive components" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case7_tplgy.m"))

        @test length(data["bus"]) == 4
        @test length(data["load"]) == 2
        @test length(data["shunt"]) == 2
        @test length(data["gen"]) == 1
        @test length(data["branch"]) == 2
        @test length(data["dcline"]) == 0
        @test length(data["switch"]) == 0
        @test length(data["storage"]) == 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test isapprox(result["objective"], 1046.62; atol=1e0)
    end

    @testset "5-bus with switches components" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        @test length(data["bus"]) == 4
        @test length(data["load"]) == 3
        @test length(data["shunt"]) == 1
        @test length(data["gen"]) == 5
        @test length(data["branch"]) == 5
        @test length(data["dcline"]) == 0
        @test length(data["switch"]) == 0
        @test length(data["storage"]) == 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        @test isapprox(result["objective"], 16641.20; atol=1e0)
    end

end


@testset "test basic network functions" begin

    @testset "basic incidence matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        I = calc_basic_incidence_matrix(data)

        @test size(I, 1) == length(data["bus"])
        @test size(I, 2) == length(data["branch"])
        @test sum(I) == 2*length(data["branch"])
    end

    @testset "basic admittance matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        AM = calc_basic_admittance_matrix(data)

        @test size(AM, 1) == length(data["bus"])
        @test size(AM, 2) == length(data["bus"])
        @test isapprox(sum(AM), 0.0670529 - 0.0130956im; atol=1e-6)
    end

    @testset "basic susceptance matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        SM = calc_basic_susceptance_matrix(data)

        @test size(SM, 1) == length(data["bus"])
        @test size(SM, 2) == length(data["bus"])
        @test isapprox(sum(SM), 0.0; atol=1e-6)
    end

    @testset "basic dc power flow" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))
        solution = compute_dc_pf(data)

        va = PowerModels.compute_basic_dc_pf(data)

        for (i,val) in enumerate(va)
            @test isapprox(solution["bus"]["$(i)"]["va"], val; atol=1e-6)
        end
    end

    @testset "basic ptdf matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        P = calc_basic_ptdf_matrix(data)

        @test size(P, 1) == length(data["bus"])
        @test size(P, 2) == length(data["branch"])
        @test isapprox(sum(P), 0.030133084; atol=1e-6)
    end

    @testset "basic ptdf columns" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        P = calc_basic_ptdf_matrix(data)

        for i in 1:length(data["branch"])
            c = calc_basic_ptdf_column(data, i)
            isapprox(P[:,i], c; atol=1e-6)
        end
    end

    @testset "basic jacobian matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        J = calc_basic_jacobian_matrix(data)

        @test size(J, 1) == 2*length(data["bus"])
        @test size(J, 2) == 2*length(data["bus"])
        @test isapprox(sum(J), 10.19339; atol=1e-4)
    end

end

