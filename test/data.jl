# Tests of data checking and transformation code

function compare_dict(d1, d2)
    for (k1,v1) in d1
        if !haskey(d2, k1)
            #@test false
            return false
        end
        v2 = d2[k1]

        if isa(v1, Number)
            #@test isapprox(v1, v2)
            if !isapprox(v1, v2)
                return false
            end
        elseif isa(v1, Dict)
            if !compare_dict(v1, v2)
                return false
            end
        else
            #@test v1 == v2
            if v1 != v2
                return false
            end
        end
    end
    return true
end

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
