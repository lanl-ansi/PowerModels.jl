

@testset "test ac polar tfopf" begin
    @testset "5-bus tf case" begin
        result = run_ac_tfopf("../test/data/case5_tf.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 15155.17; atol = 1e0)
        @test isapprox(result["branch"]["shiftf"], XXX; atol = 1e0)
        @test isapprox(result["branch"]["tapf"], XXX; atol = 1e0)
    end
end


#@testset "test ac rect tfopf" begin
#    @testset "5-bus tf case" begin
#        result = run_tfopf("../test/data/case5_tf.m", ACRPowerModel, ipopt_solver)
#
#        @test result["status"] == :LocalOptimal
#        @test isapprox(result["objective"], 15155.17; atol = 1e0)
#    end
#end


@testset "test dc tfopf" begin
    @testset "5-bus tf case" begin
        result = run_dc_tfopf("../test/data/case5_tf.m", ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 14979.73; atol = 1e0)
    end
end
