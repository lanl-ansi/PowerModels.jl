@testset "test multiphase" begin

    @testset "idempotent unit transformation" begin
        @testset "5-bus replicate case" begin
            mp_data = build_mp_data("../test/data/matpower/case5_dc.m")

            PowerModels.make_mixed_units(mp_data)
            PowerModels.make_per_unit(mp_data)

            @test InfrastructureModels.compare_dict(mp_data, build_mp_data("../test/data/matpower/case5_dc.m"))
        end
        @testset "24-bus replicate case" begin
            mp_data = build_mp_data("../test/data/matpower/case24.m")

            PowerModels.make_mixed_units(mp_data)
            PowerModels.make_per_unit(mp_data)

            @test InfrastructureModels.compare_dict(mp_data, build_mp_data("../test/data/matpower/case24.m"))
        end
    end


    @testset "topology processing" begin
        @testset "7-bus replicate status case" begin
            mp_data = build_mp_data("../test/data/matpower/case7_tplgy.m")
            PowerModels.propagate_topology_status(mp_data)
            PowerModels.select_largest_component(mp_data)

            active_buses = Set(["4", "5", "7"])
            active_branches = Set(["8"])
            active_dclines = Set(["3"])

            for (i,bus) in mp_data["bus"]
                if i in active_buses
                    @test bus["bus_type"] != 4
                else
                    @test bus["bus_type"] == 4
                end
            end

            for (i,branch) in mp_data["branch"]
                if i in active_branches
                    @test branch["br_status"] == 1
                else
                    @test branch["br_status"] == 0
                end
            end

            for (i,dcline) in mp_data["dcline"]
                if i in active_dclines
                    @test dcline["br_status"] == 1
                else
                    @test dcline["br_status"] == 0
                end
            end
        end

    end


    @testset "test multi-phase ac opf" begin
        @testset "3-bus 3-phase case" begin
            mp_data = build_mp_data("../test/data/matpower/case3.m", phases=3)
            result = PowerModels.run_mp_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 17720.6; atol = 1e-1)

            for ph in 1:mp_data["phases"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][ph], 1.58067; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][ph], 0.12669; atol = 1e-3)
            end
        end

        @testset "5-bus 5-phase case" begin
            mp_data = build_mp_data("../test/data/matpower/case5.m", phases=5)

            result = PowerModels.run_mp_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 91345.5; atol = 1e-1)
            for ph in 1:mp_data["phases"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][ph],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][ph], -0.00103692; atol = 1e-5)
            end
        end

        @testset "30-bus 3-phase case" begin
            mp_data = build_mp_data("../test/data/matpower/case30.m", phases=3)

            result = PowerModels.run_mp_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 614.905; atol = 1e-1)

            for ph in 1:mp_data["phases"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][ph],  2.18839; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][ph], -0.071759; atol = 1e-4)
            end
        end
    end


    @testset "test multi-phase opf variants" begin
        mp_data = build_mp_data("../test/data/matpower/case5_dc.m")

        @testset "ac 5-bus case" begin
            result = PowerModels.run_mp_opf(mp_data, ACPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 54468.5; atol = 1e-1)
            for ph in 1:mp_data["phases"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][ph],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][ph], -0.0139117; atol = 1e-4)
            end
        end

        @testset "dc 5-bus case" begin
            result = PowerModels.run_mp_opf(mp_data, DCPPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 54272.7; atol = 1e-1)
            for ph in 1:mp_data["phases"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][ph],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["va"][ph], -0.0135206; atol = 1e-4)
            end
        end

        @testset "soc 5-bus case" begin
            result = PowerModels.run_mp_opf(mp_data, SOCWRPowerModel, ipopt_solver)

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 46314.1; atol = 1e-1)
            for ph in 1:mp_data["phases"]
                @test isapprox(result["solution"]["gen"]["1"]["pg"][ph],  0.4; atol = 1e-3)
                @test isapprox(result["solution"]["bus"]["2"]["vm"][ph],  1.08578; atol = 1e-3)
            end
        end

    end


    @testset "dual variable case" begin

        @testset "test dc polar opf" begin
            mp_data = build_mp_data("../test/data/matpower/case5.m")

            result = PowerModels.run_mp_opf(mp_data, DCPPowerModel, ipopt_solver, setting = Dict("output" => Dict("duals" => true)))

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 52839.6; atol = 1e0)


            for (i, bus) in result["solution"]["bus"]
                @test haskey(bus, "lam_kcl_r")
                @test haskey(bus, "lam_kcl_i")

                for ph in 1:mp_data["phases"]
                    @test bus["lam_kcl_r"][ph] >= -4000 && bus["lam_kcl_r"][ph] <= 0
                    @test isnan(bus["lam_kcl_i"][ph])
                end
            end
            for (i, branch) in result["solution"]["branch"]
                @test haskey(branch, "mu_sm_fr")
                @test haskey(branch, "mu_sm_to")

                for ph in 1:mp_data["phases"]
                    @test branch["mu_sm_fr"][ph] >= -1 && branch["mu_sm_fr"][ph] <= 6000
                    @test isnan(branch["mu_sm_to"][ph])
                end
            end

        end
    end


    @testset "test solution feedback" begin
        mp_data = build_mp_data("../test/data/matpower/case5_asym.m")

        result = PowerModels.run_mp_opf(mp_data, ACPPowerModel, ipopt_solver)

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 52655.7; atol = 1e0)

        PowerModels.update_data(mp_data, result["solution"])

        @test !InfrastructureModels.compare_dict(mp_data, build_mp_data("../test/data/matpower/case5_asym.m"))
    end


    @testset "multiphase operations" begin
        mp_data = build_mp_data("../test/data/matpower/case3.m")

        a, b, c, d = mp_data["branch"]["1"]["br_r"], mp_data["branch"]["1"]["br_x"], mp_data["branch"]["1"]["b_fr"], mp_data["branch"]["1"]["b_to"]
        e = PowerModels.MultiPhaseVector([0.225, 0.225, 0.225, 0.225])
        angs_rad = mp_data["branch"]["1"]["angmin"]

        # Transpose
        @test all((a').values == (a).values)
        @test all(c' == RowVector([0.225, 0.225, 0.225]))

        # Basic Math (Matrices)
        x = a + b
        y = a - b
        z = a * b
        w = a / b

        @test all(x.values - [0.685 0.0 0.0; 0.0 0.685 0.0; 0.0 0.0 0.685] .<= 1e-12)
        @test all(y.values - [-0.555 0.0 0.0; 0.0 -0.555 0.0; 0.0 0.0 -0.555] .<= 1e-12)
        @test all(z.values - [0.0403 0.0 0.0; 0.0 0.0403 0.0; 0.0 0.0 0.0403] .<= 1e-12)
        @test all(w.values - [0.104839 0.0 0.0; 0.0 0.104839 0.0; 0.0 0.0 0.104839] .<= 1e-12)

        @test isa(x, PowerModels.MultiPhaseMatrix)
        @test isa(y, PowerModels.MultiPhaseMatrix)
        @test isa(z, PowerModels.MultiPhaseMatrix)
        @test isa(w, PowerModels.MultiPhaseMatrix)

        # Basic Math Vectors
        x = c + d
        y = c - d
        z = c^2

        @test all(x.values - [0.45, 0.45, 0.45] .<= 1e-12)
        @test all(y.values - [0.0, 0.0, 0.0] .<= 1e-12)
        @test all(c .* d - [0.050625, 0.050625, 0.050625] .<= 1e-12)
        @test all(c ./ d - [1.0, 1.0, 1.0] .<= 1e-12)
        @test all(z.values - [0.050625, 0.050625, 0.050625] .<= 1e-12)

        @test isa(x, PowerModels.MultiPhaseVector)
        @test isa(y, PowerModels.MultiPhaseVector)
        @test isa(z, PowerModels.MultiPhaseVector)

        # Broadcasting
        @test all(a .+ c - [0.29   0.225  0.225; 0.225  0.29   0.225; 0.225  0.225  0.29] .<= 1e-12)
        @test all(c .+ b - [0.845  0.225  0.225; 0.225  0.845  0.225; 0.225  0.225  0.845] .<= 1e-12)
        @test all(a.values .+ c - [0.29   0.225  0.225; 0.225  0.29   0.225; 0.225  0.225  0.29] .<= 1e-12)
        @test all(c .+ b.values - [0.845  0.225  0.225; 0.225  0.845  0.225; 0.225  0.225  0.845] .<= 1e-12)

        # Custom Functions
        @test PowerModels.phases(c) == 3
        @test PowerModels.phases(a) == 3
        @test all(size(a) == (3,3))
        @test isa(JSON.lower(a), Array)
        @test all(JSON.lower(a) == a.values)
        @test !isapprox(d, e)
        @test PowerModels.getmpv(a, 1, 1) == a[1,1]

        # diagm
        @test all(diagm(c).values .== [0.225 0.0 0.0; 0.0 0.225 0.0; 0.0 0.0 0.225])

        # rad2deg/deg2rad
        angs_deg = rad2deg(angs_rad)
        angs_deg_rad = deg2rad(angs_deg)
        @test all(angs_deg.values - [-30.0, -30.0, -30.0] .<= 1e-12)
        @test all(angs_deg_rad.values - angs_rad.values .<= 1e-12)

        @test isa(angs_deg, PowerModels.MultiPhaseVector)
        @test isa(deg2rad(angs_deg), PowerModels.MultiPhaseVector)

        a_rad = rad2deg(a)
        @test all(a_rad.values - [3.72423 0.0 0.0; 0.0 3.72423 0.0; 0.0 0.0 3.72423] .<= 1e-12)
        @test isa(rad2deg(a), PowerModels.MultiPhaseMatrix)
        @test isa(deg2rad(a), PowerModels.MultiPhaseMatrix)
    end
end