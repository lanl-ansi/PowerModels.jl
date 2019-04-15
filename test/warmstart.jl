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

    #=
    # TBD this should be improved
    for (i,branch) in data["branch"]
        branch["p_start"] = branch["pf"]
        branch["q_start"] = branch["qf"]
    end
    =#
end

function set_dc_start!(data)
    for (i,bus) in data["bus"]
        bus["va_start"] = bus["va"]
    end

    for (i,gen) in data["gen"]
        gen["pg_start"] = gen["pg"]
    end

    for (i,branch) in data["branch"]
        branch["p_start"] = branch["pf"]
    end
end

@testset "dc warm starts" begin
    @testset "5 bus case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5.m")
        result = run_dc_opf(data, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)));

        PowerModels.update_data(data, result["solution"])

        result = run_dc_opf(data, ipopt_solver);

        set_dc_start!(data)

        result = run_dc_opf(data, ipopt_ws_solver);
    end

    @testset "5 bus pwl case" begin
        data = PowerModels.parse_file("../test/data/matpower/case5_pwlc.m")
        result = run_dc_opf(data, ipopt_solver; setting = Dict("output" => Dict("branch_flows" => true)));

        PowerModels.update_data(data, result["solution"])

        result = run_dc_opf(data, ipopt_solver);

        set_dc_start!(data)

        result = run_dc_opf(data, ipopt_ws_solver);
    end
end


@testset "ac warm starts" begin
    #TODO this will require better handling of line flow starts
end


