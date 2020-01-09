
@testset "injection factor computation" begin
    # degenerate due to no slack bus
    # @testset "3-bus case" begin
    #    data = PowerModels.parse_file("../test/data/matpower/case3.m")
    # end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        sm = calc_susceptance_matrix(data)
        sm_inv = calc_susceptance_matrix_inv(data)

        ref_bus = reference_bus(data)
        for (i,bus) in data["bus"]
            sm_injection_factors = injection_factors_va(sm, bus["index"])
            sm_inv_injection_factors = injection_factors_va(sm_inv, bus["index"])

            @test length(sm_injection_factors) == length(sm_inv_injection_factors)
            @test all(isapprox(sm_injection_factors[j], v) for (j,v) in sm_inv_injection_factors)
        end
    end
    @testset "14-bus pti case" begin
        data = PowerModels.parse_file("../test/data/pti/case14.raw")
        sm = calc_susceptance_matrix(data)
        sm_inv = calc_susceptance_matrix_inv(data)

        ref_bus = reference_bus(data)
        for (i,bus) in data["bus"]
            sm_injection_factors = injection_factors_va(sm, bus["index"])
            sm_inv_injection_factors = injection_factors_va(sm_inv, bus["index"])

            @test length(sm_injection_factors) == length(sm_inv_injection_factors)
            @test all(isapprox(sm_injection_factors[j], v) for (j,v) in sm_inv_injection_factors)
        end
    end
    # solve_dc_pf does not yet support multiple slack buses
    # @testset "6-bus case" begin
    #     data = PowerModels.parse_file("../test/data/matpower/case6.m")
    # end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        sm = calc_susceptance_matrix(data)
        sm_inv = calc_susceptance_matrix_inv(data)

        ref_bus = reference_bus(data)
        for (i,bus) in data["bus"]
            sm_injection_factors = injection_factors_va(sm, bus["index"])
            sm_inv_injection_factors = injection_factors_va(sm_inv, bus["index"])

            @test length(sm_injection_factors) == length(sm_inv_injection_factors)
            @test all(isapprox(sm_injection_factors[j], v) for (j,v) in sm_inv_injection_factors)
        end
    end
end
