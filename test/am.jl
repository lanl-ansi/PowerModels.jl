@testset "admittance matrix computation" begin
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        am = calc_admittance_matrix(data)

        @test isa(am, AdmittanceMatrix{Complex{Float64}})
        @test SparseArrays.nnz(am.matrix) == 17
        @test isapprox(LinearAlgebra.det(am.matrix), 7.133429246315739e6 + 1.0156167905437486e7im)
    end
    @testset "5-bus ext case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        am = calc_admittance_matrix(data)

        @test isa(am, AdmittanceMatrix{Complex{Float64}})
        @test SparseArrays.nnz(am.matrix) == 17
        @test isapprox(LinearAlgebra.det(am.matrix), 7.133429246315739e6 + 1.0156167905437486e7im)
    end
    @testset "14-bus pti case" begin
        data = PowerModels.parse_file("../test/data/pti/case14.raw")
        am = calc_admittance_matrix(data)

        @test SparseArrays.nnz(am.matrix) == 54
        @test isapprox(LinearAlgebra.det(am.matrix), -5.930071424866359e12 + 5.026659473516862e12im)
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        am = calc_admittance_matrix(data)

        @test SparseArrays.nnz(am.matrix) == 92
        @test isapprox(LinearAlgebra.det(am.matrix), 3.283715190798021e36 - 1.688494962783582e36im)
    end
end


@testset "susceptance matrix computation" begin
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        sm = calc_susceptance_matrix(data)

        @test isa(sm, AdmittanceMatrix{Float64})
        @test SparseArrays.nnz(sm.matrix) == 17
        @test isapprox(LinearAlgebra.det(sm.matrix), 0.0)
    end
    @testset "5-bus ext case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
        sm = calc_susceptance_matrix(data)

        @test isa(sm, AdmittanceMatrix{Float64})
        @test SparseArrays.nnz(sm.matrix) == 17
        @test isapprox(LinearAlgebra.det(sm.matrix), 0.0)
    end
    @testset "14-bus pti case" begin
        data = PowerModels.parse_file("../test/data/pti/case14.raw")
        sm = calc_susceptance_matrix(data)

        @test SparseArrays.nnz(sm.matrix) == 54
        # not stable on travis
        #@test isapprox(LinearAlgebra.det(sm.matrix), 0.015385010604145787)
    end
    @testset "24-bus rts case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        sm = calc_susceptance_matrix(data)

        @test SparseArrays.nnz(sm.matrix) == 92
        # not stable on travis
        #@test isapprox(LinearAlgebra.det(sm.matrix), -4.5651071333163315e21)
    end
end


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
    @testset "5-bus ext case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_ext.m")
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
