# Tests of data checking and transformation code

TESTLOG = Memento.getlogger(PowerModels)

@testset "test data summary" begin

    @testset "5-bus summary from dict" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        output = sprint(PowerModels.summary, data)

        line_count = count(c -> c == '\n', output)
        @test line_count >= 70 && line_count <= 90
        @test occursin("name: case5", output)
        @test occursin("Table: bus", output)
        @test occursin("Table: load", output)
        @test occursin("Table: gen", output)
        @test occursin("Table: branch", output)
    end

    @testset "5-bus summary from file location" begin
        output = sprint(PowerModels.summary, "../test/data/matpower/case5.m")

        line_count = count(c -> c == '\n', output)
        @test line_count >= 70 && line_count <= 90
        @test occursin("name: case5", output)
        @test occursin("Table: bus", output)
        @test occursin("Table: load", output)
        @test occursin("Table: gen", output)
        @test occursin("Table: branch", output)
    end

    @testset "5-bus solution summary from dict" begin
        result = run_ac_opf("../test/data/matpower/case5.m", ipopt_solver)
        output = sprint(PowerModels.summary, result["solution"])

        line_count = count(c -> c == '\n', output)
        @test line_count >= 30 && line_count <= 40
        @test occursin("baseMVA: 100.0", output)
        @test occursin("Table: bus", output)
        @test occursin("Table: gen", output)
        @test occursin("Table: branch", output)
    end

end


@testset "test data component table" begin

    @testset "5-bus tables" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")

        ct1 = PowerModels.component_table(data, "bus", "va")
        @test length(ct1) == 10
        @test size(ct1,1) == 5
        @test size(ct1,2) == 2

        ct2 = PowerModels.component_table(data, "bus", ["vmin", "vmax"])
        @test length(ct2) == 15
        @test size(ct2,1) == 5
        @test size(ct2,2) == 3

        ct3 = PowerModels.component_table(data, "gen", ["pmin", "pmax", "qmin", "qmax"])
        @test length(ct3) == 25
        @test size(ct3,1) == 5
        @test size(ct3,2) == 5
    end

    @testset "14-bus mixed type tables" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")

        ct = PowerModels.component_table(data, "bus", ["vmin", "vmax", "name", "none"])
        @test length(ct) == 70
        @test size(ct,1) == 14
        @test size(ct,2) == 5
        @test typeof(ct[1,4]) <: AbstractString
        @test isnan(ct[1,5])
    end

end


@testset "test idempotent units transformations" begin
    @testset "3-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case3.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units!(data)
        PowerModels.make_per_unit!(data)

        @test InfrastructureModels.compare_dict(data, data_base)
    end
    @testset "5-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_asym.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units!(data)
        PowerModels.make_per_unit!(data)

        @test InfrastructureModels.compare_dict(data, data_base)
    end
    @testset "5-bus case with pwl costs" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units!(data)
        PowerModels.make_per_unit!(data)

        @test InfrastructureModels.compare_dict(data, data_base)
    end
    @testset "14-bus case with ramp rates" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units!(data)
        PowerModels.make_per_unit!(data)

        @test InfrastructureModels.compare_dict(data, data_base)
    end
    @testset "24-bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case24.m")
        data_base = deepcopy(data)

        PowerModels.make_mixed_units!(data)
        PowerModels.make_per_unit!(data)

        @test InfrastructureModels.compare_dict(data, data_base)
    end


    @testset "3-bus case solution" begin
        result = run_ac_opf("../test/data/matpower/case3.m", ipopt_solver)
        result_base = deepcopy(result)

        PowerModels.make_mixed_units!(result["solution"])
        PowerModels.make_per_unit!(result["solution"])

        @test InfrastructureModels.compare_dict(result, result_base)
    end
    @testset "5-bus case solution" begin
        result = run_ac_opf("../test/data/matpower/case5_asym.m", ipopt_solver)
        result_base = deepcopy(result)

        PowerModels.make_mixed_units!(result["solution"])
        PowerModels.make_per_unit!(result["solution"])

        @test InfrastructureModels.compare_dict(result, result_base)
    end
    @testset "24-bus case solution" begin
        result = run_ac_opf("../test/data/matpower/case24.m", ipopt_solver)
        result_base = deepcopy(result)

        PowerModels.make_mixed_units!(result["solution"])
        PowerModels.make_per_unit!(result["solution"])

        @test InfrastructureModels.compare_dict(result, result_base)
    end


    @testset "5-bus case solution with duals" begin
        result = run_dc_opf("../test/data/matpower/case5.m", ipopt_solver, setting = Dict("output" => Dict("branch_flows" => true, "duals" => true)))
        result_base = deepcopy(result)

        PowerModels.make_mixed_units!(result["solution"])
        PowerModels.make_per_unit!(result["solution"])

        @test InfrastructureModels.compare_dict(result, result_base)
    end

end


@testset "test component status updates " begin

    @testset "topology propagation updates" begin
        data_initial = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")

        data = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")
        PowerModels.propagate_topology_status!(data)

        @test length(data_initial["bus"]) == length(data["bus"])
        @test length(data_initial["gen"]) == length(data["gen"])
        @test length(data_initial["branch"]) == length(data["branch"])

        active_buses = Set(["1", "2", "3", "4", "5", "7"])
        active_branches = Set(["5", "8"])
        active_dclines = Set(["3"])
        active_storage = Set([])
        active_switches = Set([])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test bus["bus_type"] != 4
            else
                @test bus["bus_type"] == 4
            end
        end

        for (i,strg) in data["storage"]
            if i in active_storage
                @test strg["status"] != 0
            else
                @test strg["status"] == 0
            end
        end

        for (i,branch) in data["branch"]
            if i in active_branches
                @test branch["br_status"] == 1
            else
                @test branch["br_status"] == 0
            end
        end

        for (i,dcline) in data["dcline"]
            if i in active_dclines
                @test dcline["br_status"] == 1
            else
                @test dcline["br_status"] == 0
            end
        end

        for (i,switch) in data["switch"]
            if i in active_switches
                @test switch["status"] == 1
            else
                @test switch["status"] == 0
            end
        end
    end


    @testset "isolated components updates" begin
        data_initial = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")

        data = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")
        PowerModels.deactivate_isolated_components!(data)

        @test length(data_initial["bus"]) == length(data["bus"])
        @test length(data_initial["gen"]) == length(data["gen"])
        @test length(data_initial["branch"]) == length(data["branch"])

        active_buses = Set(["2", "3", "4", "5", "7"])
        active_branches = Set(["5", "6", "7", "8"])
        active_dclines = Set(["2", "3"])
        active_storage = Set(["1"])
        active_switches = Set([])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test bus["bus_type"] != 4
            else
                @test bus["bus_type"] == 4
            end
        end

        for (i,strg) in data["storage"]
            if i in active_storage
                @test strg["status"] != 0
            else
                @test strg["status"] == 0
            end
        end

        for (i,branch) in data["branch"]
            if i in active_branches
                @test branch["br_status"] == 1
            else
                @test branch["br_status"] == 0
            end
        end

        for (i,dcline) in data["dcline"]
            if i in active_dclines
                @test dcline["br_status"] == 1
            else
                @test dcline["br_status"] == 0
            end
        end

        for (i,switch) in data["switch"]
            if i in active_switches
                @test switch["status"] == 1
            else
                @test switch["status"] == 0
            end
        end
    end


    @testset "simplify network updates" begin
        data_initial = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")

        data = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")
        PowerModels.simplify_network!(data)

        @test length(data_initial["bus"]) == length(data["bus"])
        @test length(data_initial["gen"]) == length(data["gen"])
        @test length(data_initial["branch"]) == length(data["branch"])

        active_buses = Set(["2", "4", "5", "7"])
        active_branches = Set(["8"])
        active_dclines = Set(["3"])
        active_storage = Set([])
        active_switches = Set([])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test bus["bus_type"] != 4
            else
                @test bus["bus_type"] == 4
            end
        end

        for (i,strg) in data["storage"]
            if i in active_storage
                @test strg["status"] != 0
            else
                @test strg["status"] == 0
            end
        end

        for (i,branch) in data["branch"]
            if i in active_branches
                @test branch["br_status"] == 1
            else
                @test branch["br_status"] == 0
            end
        end

        for (i,dcline) in data["dcline"]
            if i in active_dclines
                @test dcline["br_status"] == 1
            else
                @test dcline["br_status"] == 0
            end
        end

        for (i,switch) in data["switch"]
            if i in active_switches
                @test switch["status"] == 1
            else
                @test switch["status"] == 0
            end
        end
    end


    @testset "connecected components" begin
        data = PowerModels.parse_file("../test/data/matpower/case6.m")
        cc = PowerModels.calc_connected_components(data)

        cc_ordered = sort(collect(cc); by=length)

        @test length(cc_ordered) == 2
        @test length(cc_ordered[1]) == 3
        @test length(cc_ordered[2]) == 3

        # arbitrary edge types test
        data["trans"] = Dict{String,Any}()
        data["trans"]["1"] = deepcopy(data["branch"]["6"])
        delete!(data["branch"], "6")

        cc2 = PowerModels.calc_connected_components(data; edges=["branch", "trans"])
        @test cc2 == cc
    end

    @testset "connecected components with switches" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_sw_nb.m")
        cc = PowerModels.calc_connected_components(data)

        cc_ordered = sort(collect(cc); by=length)

        @test length(cc_ordered) == 1
        @test length(cc_ordered[1]) == 19
    end

    @testset "connecected components with simplify network" begin
        data = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")
        PowerModels.simplify_network!(data)
        cc = PowerModels.calc_connected_components(data)

        cc_ordered = sort(collect(cc); by=length)

        @test length(cc_ordered) == 2
        @test length(cc_ordered[1]) == 1
        @test length(cc_ordered[2]) == 3

        active_buses = Set([2, 4, 5, 7])

        for cc in cc_ordered
            for i in cc
                @test i in active_buses
            end
        end
    end

    @testset "component filtering updates" begin
        data_initial = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")

        data = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")
        PowerModels.simplify_network!(data)
        PowerModels.select_largest_component!(data)

        @test length(data_initial["bus"]) == length(data["bus"])
        @test length(data_initial["gen"]) == length(data["gen"])
        @test length(data_initial["branch"]) == length(data["branch"])

        active_buses = Set(["4", "5", "7"])
        active_branches = Set(["8"])
        active_dclines = Set(["3"])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test bus["bus_type"] != 4
            else
                @test bus["bus_type"] == 4
            end
        end

        for (i,branch) in data["branch"]
            if i in active_branches
                @test branch["br_status"] == 1
            else
                @test branch["br_status"] == 0
            end
        end

        for (i,dcline) in data["dcline"]
            if i in active_dclines
                @test dcline["br_status"] == 1
            else
                @test dcline["br_status"] == 0
            end
        end
    end

    @testset "output values" begin
        data = PowerModels.parse_file("../test/data/matpower/case7_tplgy.m")
        PowerModels.simplify_network!(data)
        result = run_opf(data, ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 1778; atol = 1e0)

        solution = result["solution"]

        active_buses = Set(["2", "4", "5", "7"])
        active_gens = Set(["2", "3"])

        for (i,bus) in data["bus"]
            if i in active_buses
                @test !isequal(solution["bus"][i]["va"], NaN)
            else
                #@test isequal(solution["bus"][i]["va"], NaN)
            end
        end

        for (i,gen) in data["gen"]
            if i in active_gens
                @test !isequal(solution["gen"][i]["pg"], NaN)
            else
                #@test isequal(solution["gen"][i]["pg"], NaN)
            end
        end
    end
end

@testset "test errors and warnings" begin
    data = PowerModels.parse_file("../test/data/matpower/case3.m")

    # check_cost_functions
    data["gen"]["1"]["model"] = 1
    data["gen"]["1"]["ncost"] = 1
    data["gen"]["1"]["cost"] = [0, 1, 0]
    @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(data))

    data["gen"]["1"]["cost"] = [0, 0]
    @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(data))

    data["gen"]["1"]["model"] = 2
    @test_throws(TESTLOG, ErrorException, PowerModels.correct_cost_functions!(data))

    # check_connectivity
    data["load"]["1"]["load_bus"] = 1000
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))

    data["load"]["1"]["load_bus"] = 1
    data["shunt"]["1"] = Dict("gs"=>0, "bs"=>1, "shunt_bus"=>1000, "index"=>1, "status"=>1)
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))

    data["shunt"]["1"]["shunt_bus"] = 1
    data["gen"]["1"]["gen_bus"] = 1000
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))

    data["gen"]["1"]["gen_bus"] = 1
    data["branch"]["1"]["f_bus"] = 1000
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))

    data["branch"]["1"]["f_bus"] = 1
    data["branch"]["1"]["t_bus"] = 1000
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))

    data["branch"]["1"]["t_bus"] = 3
    data["dcline"]["1"]["f_bus"] = 1000
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))

    data["dcline"]["1"]["f_bus"] = 1
    data["dcline"]["1"]["t_bus"] = 1000
    @test_throws(TESTLOG, ErrorException, PowerModels.check_connectivity(data))
    data["dcline"]["1"]["t_bus"] = 2

    #warnings
    Memento.setlevel!(TESTLOG, "warn")

    data["gen"]["1"]["model"] = 3
    @test_warn(TESTLOG, "Skipping cost model of type 3 in per unit transformation", PowerModels.make_mixed_units!(data))
    @test_warn(TESTLOG, "Skipping cost model of type 3 in per unit transformation", PowerModels.make_per_unit!(data))
    @test_warn(TESTLOG, "Unknown cost model of type 3 on generator 1", PowerModels.correct_cost_functions!(data))

    data["gen"]["1"]["model"] = 1
    data["gen"]["1"]["ncost"] = 2
    data["gen"]["1"]["cost"] = [0.0, 1.0, 18.0, 2.0]
    @test_warn(TESTLOG, "exending the pwl costs model on generator 1 by 2.0100000000000016 to include the maximum active power value 20.0", PowerModels.correct_cost_functions!(data))

    data["gen"]["1"]["cost"][1] = 2.0
    @test_warn(TESTLOG, "exending the pwl costs model on generator 1 by -2.01 to include the minimum active power value 0.0", PowerModels.correct_cost_functions!(data))

    data["dcline"]["1"]["loss0"] = -1.0
    @test_warn(TESTLOG, "this code only supports positive loss0 values, changing the value on dcline 1 from -100.0 to 0.0", PowerModels.correct_dcline_limits!(data))

    data["dcline"]["1"]["loss1"] = -1.0
    @test_warn(TESTLOG, "this code only supports positive loss1 values, changing the value on dcline 1 from -1.0 to 0.0", PowerModels.correct_dcline_limits!(data))

    @test data["dcline"]["1"]["loss0"] == 0.0
    @test data["dcline"]["1"]["loss1"] == 0.0

    data["dcline"]["1"]["loss1"] = 100.0
    @test_warn(TESTLOG, "this code only supports loss1 values < 1, changing the value on dcline 1 from 100.0 to 0.0", PowerModels.correct_dcline_limits!(data))

    delete!(data["branch"]["1"], "tap")
    @test_warn(TESTLOG, "branch found without tap value, setting a tap to 1.0", PowerModels.correct_transformer_parameters!(data))

    delete!(data["branch"]["1"], "shift")
    @test_warn(TESTLOG, "branch found without shift value, setting a shift to 0.0", PowerModels.correct_transformer_parameters!(data))

    data["branch"]["1"]["tap"] = -1.0
    @test_warn(TESTLOG, "branch found with non-positive tap value of -1.0, setting a tap to 1.0", PowerModels.correct_transformer_parameters!(data))

    Memento.setlevel!(TESTLOG, "error")
end


@testset "test user ext init" begin
    @testset "3-bus case" begin
        pm = instantiate_model("../test/data/matpower/case3.m", ACPPowerModel, PowerModels.build_opf, ext = Dict(:some_data => "bloop"))

        #println(pm.ext)

        @test haskey(pm.ext, :some_data)
        @test pm.ext[:some_data] == "bloop"

        result = optimize_model!(pm, optimizer=JuMP.with_optimizer(Ipopt.Optimizer, print_level=0))

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 5907; atol = 1e0)
    end
end

@testset "test impedance to admittance" begin
    branch = Dict{String, Any}()
    branch["br_r"] = 1
    branch["br_x"] = 2
    g,b  = PowerModels.calc_branch_y(branch)
    @test isapprox(g, 0.2)
    @test isapprox(b, -0.4)

    branch["br_r"] = 0
    branch["br_x"] = 0
    g,b  = PowerModels.calc_branch_y(branch)
    @test isapprox(g, 0)
    @test isapprox(b, 0)
end


@testset "test buspair computations" begin

     @testset "5-bus test" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        data["branch"]["4"]["br_status"] = 0
        data["buspairs"] = PowerModels.calc_buspair_parameters(data["bus"], data["branch"], 1:1, false)
        result = run_opf(data, ACPPowerModel, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(result["objective"], 16642; atol = 1e0)
    end

end


@testset "test branch flow computations" begin

     @testset "5-bus ac polar flow" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        ac_flows = PowerModels.calc_branch_flow_ac(data)

        for (i,branch) in data["branch"]
            if branch["br_status"] != 0
                branch_flow = ac_flows["branch"][i]
                for k in ["pf","pt","qf","qt"]
                    @test (isnan(branch[k]) && isnan(branch_flow[k])) || isapprox(branch[k], branch_flow[k]; atol=1e-6)
                end
            end
        end
    end

    @testset "5-bus ac rect flow" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, ACRPowerModel, ipopt_solver, solution_processors=[sol_data_model!])
        PowerModels.update_data!(data, result["solution"])

        ac_flows = PowerModels.calc_branch_flow_ac(data)

        for (i,branch) in data["branch"]
            if branch["br_status"] != 0
                branch_flow = ac_flows["branch"][i]
                for k in ["pf","pt","qf","qt"]
                    @test (isnan(branch[k]) && isnan(branch_flow[k])) || isapprox(branch[k], branch_flow[k]; atol=1e-6)
                end
            end
        end
    end

    @testset "5-bus dc flow" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, DCPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        dc_flows = PowerModels.calc_branch_flow_dc(data)

        for (i,branch) in data["branch"]
            if branch["br_status"] != 0
                branch_flow = dc_flows["branch"][i]
                for k in ["pf","pt"]
                    @test (isnan(branch[k]) && isnan(branch_flow[k])) || isapprox(branch[k], branch_flow[k]; atol=1e-6)
                end
            end
        end
    end

end


@testset "test cost model computations" begin

     @testset "5-bus polynomial gen cost" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        gen_cost = PowerModels.calc_gen_cost(data)
        dcline_cost = PowerModels.calc_dcline_cost(data)
        @test isapprox(result["objective"], gen_cost + dcline_cost; atol=1e-1)
    end

     @testset "5-bus pwlc gen cost" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")

        for (i,gen) in data["gen"]
            @test isa(gen["ncost"], Int)
        end

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        gen_cost = PowerModels.calc_gen_cost(data)
        dcline_cost = PowerModels.calc_dcline_cost(data)
        @test isapprox(result["objective"], gen_cost + dcline_cost; atol=1e-1)
    end

     @testset "5-bus polynomial gen and dcline cost" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_dc.m")
        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        gen_cost = PowerModels.calc_gen_cost(data)
        dcline_cost = PowerModels.calc_dcline_cost(data)
        @test isapprox(result["objective"], gen_cost + dcline_cost; atol=1e-1)
    end

     @testset "5-bus inactive components" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_dc.m")
        data["gen"]["1"]["gen_status"] = 0
        data["dcline"]["1"]["br_status"] = 0

        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        gen_cost = PowerModels.calc_gen_cost(data)
        dcline_cost = PowerModels.calc_dcline_cost(data)
        @test isapprox(result["objective"], gen_cost + dcline_cost; atol=1e-1)
    end

end


@testset "test power balance computations" begin

     @testset "5-bus ac polar balance" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_dc.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        balance = PowerModels.calc_power_balance(data)

        for (i,bus) in balance["bus"]
            @test isapprox(bus["p_delta"], 0.0; atol=1e-6)
            @test isapprox(bus["q_delta"], 0.0; atol=1e-6)
        end
    end

     @testset "5-bus dc balance" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_dc.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, DCPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        balance = PowerModels.calc_power_balance(data)

        for (i,bus) in balance["bus"]
            @test isapprox(bus["p_delta"], 0.0; atol=1e-6)
            @test isnan(bus["q_delta"])
        end
    end


     @testset "5-bus ac polar balance with storage" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_strg.m")
        data["branch"]["4"]["br_status"] = 0
        result = PowerModels._run_opf_strg(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        balance = PowerModels.calc_power_balance(data)

        for (i,bus) in balance["bus"]
            @test isapprox(bus["p_delta"], 0.0; atol=1e-6)
            @test isapprox(bus["q_delta"], 0.0; atol=1e-6)
        end
    end

     @testset "5-bus dc balance with storage" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_strg.m")
        data["branch"]["4"]["br_status"] = 0
        result = PowerModels._run_opf_strg(data, DCPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        balance = PowerModels.calc_power_balance(data)

        for (i,bus) in balance["bus"]
            @test isapprox(bus["p_delta"], 0.0; atol=1e-6)
            @test isnan(bus["q_delta"])
        end
    end


     @testset "5-bus balance from flow ac" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_dc.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, ACPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        flows = PowerModels.calc_branch_flow_ac(data)
        PowerModels.update_data!(data, flows)

        balance = PowerModels.calc_power_balance(data)

        for (i,bus) in balance["bus"]
            @test isapprox(bus["p_delta"], 0.0; atol=1e-6)
            @test isapprox(bus["q_delta"], 0.0; atol=1e-6)
        end
    end

     @testset "5-bus balance from flow dc" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_dc.m")
        data["branch"]["4"]["br_status"] = 0
        result = run_opf(data, DCPPowerModel, ipopt_solver)
        PowerModels.update_data!(data, result["solution"])

        flows = PowerModels.calc_branch_flow_dc(data)
        PowerModels.update_data!(data, flows)

        balance = PowerModels.calc_power_balance(data)

        for (i,bus) in balance["bus"]
            @test isapprox(bus["p_delta"], 0.0; atol=1e-6)
            @test isnan(bus["q_delta"])
        end
    end

end