######
#
# These are toy workflows used to test advanced features
#
######

function set_ac_start!(data)
    for (i,bus) in data["bus"]
        bus["vm_start"] = bus["vm"]
        bus["va_start"] = bus["va"]
    end

    for (i,gen) in data["gen"]
        gen["pg_start"] = gen["pg"]
        gen["qg_start"] = gen["qg"]
    end

    for (i,branch) in data["branch"]
        branch["pf_start"] = branch["pf"]
        branch["qf_start"] = branch["qf"]
        branch["pt_start"] = branch["pt"]
        branch["qt_start"] = branch["qt"]
    end
end

function set_dc_start!(data)
    for (i,bus) in data["bus"]
        bus["va_start"] = bus["va"]
    end

    for (i,gen) in data["gen"]
        gen["pg_start"] = gen["pg"]
    end

    for (i,branch) in data["branch"]
        branch["pf_start"] = branch["pf"]
    end
end

@testset "dc warm starts" begin
    @testset "5 bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_dc_opf(data, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)));

        PowerModels.update_data!(data, result["solution"])

        # 14 iterations
        result = run_dc_opf(data, ipopt_solver);

        set_dc_start!(data)

        # 6 iterations
        result = run_dc_opf(data, ipopt_ws_solver);
    end

    @testset "5 bus pwl case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")
        result = run_dc_opf(data, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)));

        PowerModels.update_data!(data, result["solution"])

        # 35 iterations
        result = run_dc_opf(data, ipopt_solver);

        set_dc_start!(data)

        # 6 iterations
        result = run_dc_opf(data, ipopt_ws_solver);
    end
end


@testset "ac warm starts" begin
    @testset "5 bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_ac_opf(data, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)));

        PowerModels.update_data!(data, result["solution"])

        # 22 iterations
        result = run_ac_opf(data, ipopt_solver);

        set_ac_start!(data)

        # 19 iterations
        result = run_ac_opf(data, ipopt_ws_solver);
    end

    @testset "5 bus pwl case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")
        result = run_ac_opf(data, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)));

        PowerModels.update_data!(data, result["solution"])

        # 40 iterations
        result = run_ac_opf(data, ipopt_solver);

        set_ac_start!(data)

        # 12 iterations
        result = run_ac_opf(data, ipopt_ws_solver);
    end
end


