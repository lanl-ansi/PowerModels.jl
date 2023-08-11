@testset "test multiconductor data" begin

    @testset "multiconductor calc_theta_delta_bounds" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        data["conductors"] = 1

        theta_lb, theta_ub = calc_theta_delta_bounds(data)

        @test theta_lb[1] <= -2.0
        @test theta_ub[1] >=  2.0
    end

end