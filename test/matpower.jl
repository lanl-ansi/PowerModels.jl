@testset "test matpower parser" begin
    @testset "30-bus case file" begin
        result = run_opf("../test/data/matpower/case30.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_file)" begin
        data = PowerModels.parse_file("../test/data/matpower/case30.m")
        @test isa(JSON.json(data), String)

        result = run_opf(data, ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_matpower)" begin
        data = PowerModels.parse_matpower("../test/data/matpower/case30.m")
        @test isa(JSON.json(data), String)

        result = run_opf(data, ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 204.96; atol = 1e-1)
    end

    @testset "30-bus case matpower data (parse_matpower; iostream)" begin
        open("../test/data/matpower/case30.m") do f
            data = PowerModels.parse_matpower(f)
            @test isa(JSON.json(data), String)

            result = run_opf(data, ACPPowerModel, ipopt_solver)

            @test result["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["objective"], 204.96; atol = 1e-1)
        end
    end

    @testset "14-bus case file with bus names" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        @test data["bus"]["1"]["name"] == "Bus 1     HV"
        @test isa(JSON.json(data), String)
    end

    @testset "5-bus case file with pwl cost functions" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")
        @test data["gen"]["1"]["model"] == 1
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus case file with hvdc lines" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")
        @test length(data["dcline"]) > 0
        @test isa(JSON.json(data), String)
    end

    @testset "2-bus case file with spaces" begin
        result = run_pf("../test/data/matpower/case2.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 0.0; atol = 1e-1)
    end

    @testset "5-bus source ids" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_strg.m")
        @test data["bus"]["1"]["source_id"] == ["bus", 1]
        @test data["gen"]["1"]["source_id"] == ["gen", 1]
        @test data["load"]["1"]["source_id"] == ["bus", 2]
        @test data["branch"]["1"]["source_id"] == ["branch", 1]
        @test data["storage"]["1"]["source_id"] == ["storage", 1]
    end
end


@testset "test matpower data coercion" begin
    @testset "ACP Model" begin
        result = run_opf("../test/data/matpower/case14.m", ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8081.5; atol = 1e0)
        #@test result["status"] = bus_name
    end
    @testset "DC Model" begin
        result = run_opf("../test/data/matpower/case14.m", DCPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 7642.6; atol = 1e0)
    end
    @testset "QC Model" begin
        result = run_opf("../test/data/matpower/case14.m", QCRMPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 8075.1; atol = 1e0)
    end
end


@testset "test matpower extentions parser" begin
    @testset "3-bus extended constants" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test data["const_int"] == 123
        @test data["const_float"] == 4.56
        @test data["const_str"] == "a string"
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended matrix" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas")
        @test data["areas"]["1"]["col_1"] == 1
        @test data["areas"]["1"]["col_2"] == 1
        @test data["areas"]["2"]["col_1"] == 2
        @test data["areas"]["2"]["col_2"] == 3
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended named matrix" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named")
        @test data["areas_named"]["1"]["area"] == 4
        @test data["areas_named"]["1"]["refbus"] == 5
        @test data["areas_named"]["2"]["area"] == 5
        @test data["areas_named"]["2"]["refbus"] == 6
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended predefined matrix" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named")
        @test data["branch"]["1"]["rate_i"] == 50.2
        @test data["branch"]["1"]["rate_p"] == 45
        @test data["branch"]["2"]["rate_i"] == 36
        @test data["branch"]["2"]["rate_p"] == 60.1
        @test data["branch"]["3"]["rate_i"] == 12
        @test data["branch"]["3"]["rate_p"] == 30
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended matrix from cell" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_cells")
        @test data["areas_cells"]["1"]["col_1"] == "Area 1"
        @test data["areas_cells"]["1"]["col_2"] == 123
        @test data["areas_cells"]["1"]["col_4"] == "Slack \\\"Bus\\\" 1"
        @test data["areas_cells"]["1"]["col_5"] == 1.23
        @test data["areas_cells"]["2"]["col_1"] == "Area 2"
        @test data["areas_cells"]["2"]["col_2"] == 456
        @test data["areas_cells"]["2"]["col_4"] == "Slack Bus 3"
        @test data["areas_cells"]["2"]["col_5"] == 4.56
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended named matrix from cell" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named_cells")
        @test data["areas_named_cells"]["1"]["area_name"] == "Area 1"
        @test data["areas_named_cells"]["1"]["area"] == 123
        @test data["areas_named_cells"]["1"]["area2"] == 987
        @test data["areas_named_cells"]["1"]["refbus_name"] == "Slack Bus 1"
        @test data["areas_named_cells"]["1"]["refbus"] == 1.23
        @test data["areas_named_cells"]["2"]["area_name"] == "Area 2"
        @test data["areas_named_cells"]["2"]["area"] == 456
        @test data["areas_named_cells"]["2"]["area2"] == 987
        @test data["areas_named_cells"]["2"]["refbus_name"] == "Slack Bus 3"
        @test data["areas_named_cells"]["2"]["refbus"] == 4.56
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus extended predefined matrix from cell" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")

        @test haskey(data, "areas_named")
        @test data["branch"]["1"]["name"] == "Branch 1"
        @test data["branch"]["1"]["number_id"] == 123
        @test data["branch"]["2"]["name"] == "Branch 2"
        @test data["branch"]["2"]["number_id"] == 456
        @test data["branch"]["3"]["name"] == "Branch 3"
        @test data["branch"]["3"]["number_id"] == 789
        @test isa(JSON.json(data), String)
    end

    @testset "3-bus tnep case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")

        @test haskey(data, "ne_branch")
        @test data["ne_branch"]["1"]["f_bus"] == 2
        @test data["ne_branch"]["1"]["construction_cost"] == 1
        @test isa(JSON.json(data), String)
    end

    @testset "`build_ref` for 3-bus tnep case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3_tnep.m")
        ref = PowerModels.build_ref(data)

        @assert !PowerModels.InfrastructureModels.ismultinetwork(data)
        ref = ref[:nw][0]

        @test haskey(data, "name")
        @test haskey(ref, :name)
        @test data["name"] == ref[:name]
    end
end

@testset "test idempotent matpower export" begin

    function test_mp_idempotent(filename::AbstractString, parse_file::Function)
        source_data = parse_file(filename)

        io = PipeBuffer()
        PowerModels.export_matpower(io, source_data)
        destination_data = PowerModels.parse_matpower(io)

        @test InfrastructureModels.compare_dict(source_data, destination_data)
    end

    @testset "test frankenstein_00" begin
        file = "../test/data/matpower/frankenstein_00.m"
        test_mp_idempotent(file, PowerModels.parse_file)
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case14" begin
        file = "../test/data/matpower/case14.m"
        test_mp_idempotent(file, PowerModels.parse_file)
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case2" begin
        file = "../test/data/matpower/case2.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case24" begin
        file = "../test/data/matpower/case24.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case3_tnep" begin
        file = "../test/data/matpower/case3_tnep.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case30" begin
        file = "../test/data/matpower/case30.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 asym" begin
        file = "../test/data/matpower/case5_asym.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 gap" begin
        file = "../test/data/matpower/case5_gap.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 strg" begin
        file = "../test/data/matpower/case5_strg.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    # currently not idempotent due to pwl function simplification
    #@testset "test case5 pwlc" begin
    #    file = "../test/data/matpower/case5_pwlc.m"
    #    test_mp_idempotent(file, PowerModels.parse_matpower)
    #end

    # line reversal, with line charging is not invertable
    #@testset "test case5" begin
    #    file = "../test/data/matpower/case5.m"
    #    test_mp_idempotent(file, PowerModels.parse_matpower)
    #end

    @testset "test case6" begin
        file = "../test/data/matpower/case6.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case3" begin
        file = "../test/data/matpower/case3.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 dc" begin
        file = "../test/data/matpower/case5_dc.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case5 tnep" begin
        file = "../test/data/matpower/case5_tnep.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end

    @testset "test case7 tplgy" begin
        file = "../test/data/matpower/case7_tplgy.m"
        test_mp_idempotent(file, PowerModels.parse_matpower)
    end
end





@testset "test pti to matpower" begin

    function test_mp_export(filename::AbstractString, parse_file::Function)
        source_data = parse_file(filename)

        io = PipeBuffer()
        PowerModels.export_matpower(io, source_data)
        destination_data = PowerModels.parse_matpower(io)
    end

    # special string name edge case
    #@testset "test case3" begin
    #    file = "../test/data/pti/case3.raw"
    #    test_mp_export(file, PowerModels.parse_psse)
    #end

    @testset "test case5" begin
        file = "../test/data/pti/case5.raw"
        test_mp_export(file, PowerModels.parse_psse)
    end

    @testset "test case14" begin
        file = "../test/data/pti/case14.raw"
        test_mp_export(file, PowerModels.parse_psse)
    end

    @testset "test case24" begin
        file = "../test/data/pti/case24.raw"
        test_mp_export(file, PowerModels.parse_psse)
    end

end

