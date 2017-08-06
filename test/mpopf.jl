
@testset "test ac polar opf" begin
    @testset "2 period 5-bus asymmetric case" begin
        mp_data = PowerModels.parse_file("../test/data/case5_asym.m")
        mp_data["nw"]["1"] = mp_data["nw"]["0"]
        mp_data["nw"]["2"] = mp_data["nw"]["0"]
        delete!(mp_data["nw"], "0")

        result = PowerModels.run_ac_mpopf(mp_data, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 35117.1; atol = 1e0)
        @test isapprox(
            result["solution"]["nw"]["1"]["gen"]["1"]["pg"],
            result["solution"]["nw"]["2"]["gen"]["4"]["pg"]; 
            atol = 1e-3
        )
    end
end
