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
        @test isapprox(result["objective"], 1036.52; atol=1e0)
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
        @test isapprox(result["objective"], 16551.7; atol=1e0)
    end

end


@testset "test basic network functions" begin

    @testset "basic bus injection" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case14.m"))

        result = run_opf(data, DCPPowerModel, ipopt_solver)
        update_data!(data, result["solution"])

        bi = calc_basic_bus_injection(data)

        @test isapprox(real(sum(bi)), 0.0; atol=1e-6)


        result = run_opf(data, ACPPowerModel, ipopt_solver)
        update_data!(data, result["solution"])

        bi = calc_basic_bus_injection(data)

        @test isapprox(sum(bi), 0.092872 - 0.0586887im; atol=1e-6)
    end

    @testset "basic incidence matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        I = calc_basic_incidence_matrix(data)

        @test size(I, 1) == length(data["branch"])
        @test size(I, 2) == length(data["bus"])
        @test sum(I) == 0
        @test sum(abs.(I)) == 2*length(data["branch"])
    end

    @testset "basic admittance matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        AM = calc_basic_admittance_matrix(data)

        @test size(AM, 1) == length(data["bus"])
        @test size(AM, 2) == length(data["bus"])
        @test isapprox(sum(AM), 0.0151187 + 0.00624668im; atol=1e-6)
    end

    @testset "basic branch series impedance and susceptance matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        bz = calc_basic_branch_series_impedance(data)
        A = calc_basic_incidence_matrix(data)

        # docs example
        Y = imag(LinearAlgebra.Diagonal(inv.(bz)))
        SM_1 = A'*Y*A

        SM_2 = calc_basic_susceptance_matrix(data)

        @test isapprox(SM_1, SM_2; atol=1e-6)


        result = run_opf(data, DCPPowerModel, ipopt_solver)
        update_data!(data, result["solution"])

        va = angle.(calc_basic_bus_voltage(data))
        B = calc_basic_susceptance_matrix(data)

        # docs example
        bus_injection = -B * va
        @test isapprox(bus_injection, real(calc_basic_bus_injection(data)); atol=1e-6)
    end

    @testset "basic bus voltage and branch power matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        va = angle.(calc_basic_bus_voltage(data))

        bz = calc_basic_branch_series_impedance(data)
        A = calc_basic_incidence_matrix(data)

        Y = imag(LinearAlgebra.Diagonal(inv.(bz)))
        BB_1 = (A'*Y)'

        BB_2 = calc_basic_branch_susceptance_matrix(data)

        @test isapprox(BB_1, BB_2; atol=1e-6)

        # docs example
        branch_power = -BB_1*va

        @test length(branch_power) == length(data["branch"])

        for (i,branch) in data["branch"]
            g,b = calc_branch_y(branch)
            pf = -b*(va[branch["f_bus"]] - va[branch["t_bus"]])
            @test isapprox(branch_power[branch["index"]], pf; atol=1e-6)
        end
        println()
    end

    @testset "basic dc power flow" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))
        solution = compute_dc_pf(data)["solution"]

        va = compute_basic_dc_pf(data)

        for (i,val) in enumerate(va)
            @test isapprox(solution["bus"]["$(i)"]["va"], val; atol=1e-6)
        end
    end

    @testset "basic ptdf matrix" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        P = calc_basic_ptdf_matrix(data)

        @test size(P, 1) == length(data["branch"])
        @test size(P, 2) == length(data["bus"])
        @test isapprox(sum(P), 0.9894736; atol=1e-6)


        result = run_opf(data, DCPPowerModel, ipopt_solver)
        update_data!(data, result["solution"])

        bi = real(calc_basic_bus_injection(data))
        # accounts for vm = 1.0 assumption
        for (i,shunt) in data["shunt"]
            if !isapprox(shunt["gs"], 0.0)
                bi[shunt["shunt_bus"]] += shunt["gs"]
            end
        end

        va = angle.(calc_basic_bus_voltage(data))

        # docs example
        branch_power = P*bi

        for (i,branch) in data["branch"]
            g,b = calc_branch_y(branch)
            pf = -b*(va[branch["f_bus"]] - va[branch["t_bus"]])
            @test isapprox(branch_power[branch["index"]], pf; atol=1e-6)
        end
    end

    @testset "basic ptdf columns" begin
        data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case5_sw.m"))

        P = calc_basic_ptdf_matrix(data)

        for i in 1:length(data["branch"])
            row = calc_basic_ptdf_row(data, i)
            @test isapprox(P[i,:], row; atol=1e-6)
        end
    end

    @testset "test basic jacobian" begin
        function test_size(data, J)
            buses = 0; pv = 0; pq = 0;
            for (_, bus) in data["bus"]
                bus_type = bus["bus_type"]
                if bus_type == 1
                    pq += 1
                    buses += 1
                elseif bus_type == 2
                    pv += 1
                    buses += 1
                elseif bus_type == 3
                    buses += 1 
                end
            end
            matrix_size = 2*(buses - 1) - pv
            size(J) == (matrix_size, matrix_size)
        end
        
        @testset "14-bus-case" begin
            data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case14.m"))
            J = PowerModels.calc_basic_jacobian_matrix(data)
    
            @test test_size(data, J)
            @test isapprox(J[1, 1], 32.7603; atol = 1e-4)
            @test isapprox(J[1, 14], -1.2558, atol = 1e-4)
            @test isapprox(J[14, 1], 2.2955, atol = 1e-4)
            @test isapprox(J[14, 14], 39.4697, atol = 1e-4)
            @test isapprox(sum(J), 63.1; atol = 1e-1)
        end
    
        @testset "30-bus-case" begin
            data = make_basic_network(PowerModels.parse_file("../test/data/matpower/case30.m"))
            J = PowerModels.calc_basic_jacobian_matrix(data)
    
            @test test_size(data, J)
            @test isapprox(J[1, 1], 32.7707; atol = 1e-4) 
            @test isapprox(J[1, 31], -1.3548; atol = 1e-4)
            @test isapprox(J[31, 1], 2.1783; atol = 1e-4)
            @test isapprox(J[31, 31], 55.7408; atol = 1e-4)
            @test isapprox(sum(J), 82.4; atol = 1e-1)
        end
    end

end

