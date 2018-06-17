#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################

""
function parse_matpower(file_string::String)
    mp_data = parse_matpower_file(file_string)
    #display(mp_data)

    pm_data = matpower_to_powermodels(mp_data)

    return pm_data
end


### very generic helper functions ###

"takes a row from a matrix and assigns the values names and types"
function row_to_typed_dict(row_data, columns)
    dict_data = Dict{String,Any}()
    for (i,v) in enumerate(row_data)
        if i <= length(columns)
            name, typ = columns[i]
            dict_data[name] = InfrastructureModels.check_type(typ, v)
        else
            dict_data["col_$(i)"] = v
        end
    end
    return dict_data
end

"takes a row from a matrix and assigns the values names"
function row_to_dict(row_data, columns)
    dict_data = Dict{String,Any}()
    for (i,v) in enumerate(row_data)
        if i <= length(columns)
            dict_data[columns[i]] = v
        else
            dict_data["col_$(i)"] = v
        end
    end
    return dict_data
end



### Data and functions specific to Matpower format ###

mp_data_names = ["mpc.version", "mpc.baseMVA", "mpc.bus", "mpc.gen",
    "mpc.branch", "mpc.dcline", "mpc.gencost", "mpc.dclinecost",
    "mpc.bus_name"
]

mp_bus_columns = [
    ("bus_i", Int),
    ("bus_type", Int),
    ("pd", Float64), ("qd", Float64),
    ("gs", Float64), ("bs", Float64),
    ("area", Int),
    ("vm", Float64), ("va", Float64),
    ("base_kv", Float64),
    ("zone", Int),
    ("vmax", Float64), ("vmin", Float64),
    ("lam_p", Float64), ("lam_q", Float64),
    ("mu_vmax", Float64), ("mu_vmin", Float64)
]

mp_bus_name_columns = [
    ("bus_name", String)
]

mp_gen_columns = [
    ("gen_bus", Int),
    ("pg", Float64), ("qg", Float64),
    ("qmax", Float64), ("qmin", Float64),
    ("vg", Float64),
    ("mbase", Float64),
    ("gen_status", Int),
    ("pmax", Float64), ("pmin", Float64),
    ("pc1", Float64),
    ("pc2", Float64),
    ("qc1min", Float64), ("qc1max", Float64),
    ("qc2min", Float64), ("qc2max", Float64),
    ("ramp_agc", Float64),
    ("ramp_10", Float64),
    ("ramp_30", Float64),
    ("ramp_q", Float64),
    ("apf", Float64),
    ("mu_pmax", Float64), ("mu_pmin", Float64),
    ("mu_qmax", Float64), ("mu_qmin", Float64)
]

mp_branch_columns = [
    ("f_bus", Int),
    ("t_bus", Int),
    ("br_r", Float64), ("br_x", Float64),
    ("br_b", Float64),
    ("rate_a", Float64),
    ("rate_b", Float64),
    ("rate_c", Float64),
    ("tap", Float64), ("shift", Float64),
    ("br_status", Int),
    ("angmin", Float64), ("angmax", Float64),
    ("pf", Float64), ("qf", Float64),
    ("pt", Float64), ("qt", Float64),
    ("mu_sf", Float64), ("mu_st", Float64),
    ("mu_angmin", Float64), ("mu_angmax", Float64)
]

mp_dcline_columns = [
    ("f_bus", Int),
    ("t_bus", Int),
    ("br_status", Int),
    ("pf", Float64), ("pt", Float64),
    ("qf", Float64), ("qt", Float64),
    ("vf", Float64), ("vt", Float64),
    ("pmin", Float64), ("pmax", Float64),
    ("qminf", Float64), ("qmaxf", Float64),
    ("qmint", Float64), ("qmaxt", Float64),
    ("loss0", Float64),
    ("loss1", Float64),
    ("mu_pmin", Float64), ("mu_pmax", Float64),
    ("mu_qminf", Float64), ("mu_qmaxf", Float64),
    ("mu_qmint", Float64), ("mu_qmaxt", Float64)
]


""
function parse_matpower_file(file_string::String)
    data_string = readstring(open(file_string))
    return parse_matpower_string(data_string)
end


""
function parse_matpower_string(data_string::String)
    matlab_data, func_name, colnames = parse_matlab_string(data_string, extended=true)

    case = Dict{String,Any}()

    if func_name != nothing
        case["name"] = func_name
    else
        warn(LOGGER, string("no case name found in matpower file.  The file seems to be missing \"function mpc = ...\""))
        case["name"] = "no_name_found"
    end

    case["source_type"] = "matpower"
    if haskey(matlab_data, "mpc.version")
        case["source_version"] = VersionNumber(matlab_data["mpc.version"])
    else
        warn(LOGGER, string("no case version found in matpower file.  The file seems to be missing \"mpc.version = ...\""))
        case["source_version"] = "0.0.0+"
    end

    if haskey(matlab_data, "mpc.baseMVA")
        case["baseMVA"] = matlab_data["mpc.baseMVA"]
    else
        warn(LOGGER, string("no baseMVA found in matpower file.  The file seems to be missing \"mpc.baseMVA = ...\""))
        case["baseMVA"] = 1.0
    end


    if haskey(matlab_data, "mpc.bus")
        buses = []
        for bus_row in matlab_data["mpc.bus"]
            bus_data = row_to_typed_dict(bus_row, mp_bus_columns)
            bus_data["index"] = InfrastructureModels.check_type(Int, bus_row[1])
            push!(buses, bus_data)
        end
        case["bus"] = buses
    else
        error(string("no bus table found in matpower file.  The file seems to be missing \"mpc.bus = [...];\""))
    end

    if haskey(matlab_data, "mpc.gen")
        gens = []
        for (i, gen_row) in enumerate(matlab_data["mpc.gen"])
            gen_data = row_to_typed_dict(gen_row, mp_gen_columns)
            gen_data["index"] = i
            push!(gens, gen_data)
        end
        case["gen"] = gens
    else
        error(string("no gen table found in matpower file.  The file seems to be missing \"mpc.gen = [...];\""))
    end

    if haskey(matlab_data, "mpc.branch")
        branches = []
        for (i, branch_row) in enumerate(matlab_data["mpc.branch"])
            branch_data = row_to_typed_dict(branch_row, mp_branch_columns)
            branch_data["index"] = i
            push!(branches, branch_data)
        end
        case["branch"] = branches
    else
        error(string("no branch table found in matpower file.  The file seems to be missing \"mpc.branch = [...];\""))
    end

    if haskey(matlab_data, "mpc.dcline")
        dclines = []
        for (i, dcline_row) in enumerate(matlab_data["mpc.dcline"])
            dcline_data = row_to_typed_dict(dcline_row, mp_dcline_columns)
            dcline_data["index"] = i
            push!(dclines, dcline_data)
        end
        case["dcline"] = dclines
    end


    if haskey(matlab_data, "mpc.bus_name")
        bus_names = []
        for (i, bus_name_row) in enumerate(matlab_data["mpc.bus_name"])
            bus_name_data = row_to_typed_dict(bus_name_row, mp_bus_name_columns)
            bus_name_data["index"] = i
            push!(bus_names, bus_name_data)
        end
        case["bus_name"] = bus_names

        if length(case["bus_name"]) != length(case["bus"])
            error("incorrect Matpower file, the number of bus names ($(length(case["bus_name"]))) is inconsistent with the number of buses ($(length(case["bus"]))).\n")
        end
    end

    if haskey(matlab_data, "mpc.gencost")
        gencost = []
        for (i, gencost_row) in enumerate(matlab_data["mpc.gencost"])
            gencost_data = mp_cost_data(gencost_row)
            gencost_data["index"] = i
            push!(gencost, gencost_data)
        end
        case["gencost"] = gencost

        if length(case["gencost"]) != length(case["gen"]) && length(case["gencost"]) != 2*length(case["gen"])
            error("incorrect Matpower file, the number of generator cost functions ($(length(case["gencost"]))) is inconsistent with the number of generators ($(length(case["gen"]))).\n")
        end
    end

    if haskey(matlab_data, "mpc.dclinecost")
        dclinecosts = []
        for (i, dclinecost_row) in enumerate(matlab_data["mpc.dclinecost"])
            dclinecost_data = mp_cost_data(dclinecost_row)
            dclinecost_data["index"] = i
            push!(dclinecosts, dclinecost_data)
        end
        case["dclinecost"] = dclinecosts

        if length(case["dclinecost"]) != length(case["dcline"])
            error("incorrect Matpower file, the number of dcline cost functions ($(length(case["dclinecost"]))) is inconsistent with the number of dclines ($(length(case["dcline"]))).\n")
        end
    end

    for k in keys(matlab_data)
        if !in(k, mp_data_names) && startswith(k, "mpc.")
            case_name = k[5:length(k)]
            value = matlab_data[k]
            if isa(value, Array)
                column_names = []
                if haskey(colnames, k)
                    column_names = colnames[k]
                end
                tbl = []
                for (i, row) in enumerate(matlab_data[k])
                    row_data = row_to_dict(row, column_names)
                    row_data["index"] = i
                    push!(tbl, row_data)
                end
                case[case_name] = tbl
                info(LOGGER, "extending matpower format with data: $(case_name) $(length(tbl))x$(length(tbl[1])-1)")
            else
                case[case_name] = value
                info(LOGGER, "extending matpower format with constant data: $(case_name)")
            end
        end
    end

    #println("Case:")
    #println(case)

    return case
end


function mp_cost_data(cost_row)
    cost_data = Dict{String,Any}(
        "model" => InfrastructureModels.check_type(Int, cost_row[1]),
        "startup" => InfrastructureModels.check_type(Float64, cost_row[2]),
        "shutdown" => InfrastructureModels.check_type(Float64, cost_row[3]),
        "ncost" => InfrastructureModels.check_type(Int, cost_row[4]),
        "cost" => [InfrastructureModels.check_type(Float64, x) for x in cost_row[5:length(cost_row)]]
    )

    #=
    # skip this literal interpretation, as its hard to invert
    cost_values = [InfrastructureModels.check_type(Float64, x) for x in cost_row[5:length(cost_row)]]
    if cost_data["model"] == 1:
        if length(cost_values)%2 != 0
            error("incorrect matpower file, odd number of pwl cost function values")
        end
        for i in 0:(length(cost_values)/2-1)
            p_idx = 1+2*i
            f_idx = 2+2*i
            cost_data["p_$(i)"] = cost_values[p_idx]
            cost_data["f_$(i)"] = cost_values[f_idx]
        end
    else:
        for (i,v) in enumerate(cost_values)
            cost_data["c_$(length(cost_values)+1-i)"] = v
        end
    =#
    return cost_data
end



### Data and functions specific to PowerModels format ###

"""
Converts a Matpower dict into a PowerModels dict
"""
function matpower_to_powermodels(mp_data::Dict{String,Any})
    pm_data = deepcopy(mp_data)

    # required default values
    if !haskey(pm_data, "dcline")
        pm_data["dcline"] = []
    end
    if !haskey(pm_data, "gencost")
        pm_data["gencost"] = []
    end
    if !haskey(pm_data, "dclinecost")
        pm_data["dclinecost"] = []
    end

    # translate component models
    mp2pm_branch(pm_data)
    mp2pm_dcline(pm_data)

    # translate cost models
    add_dcline_costs(pm_data)
    standardize_cost_terms(pm_data)

    # merge data tables
    merge_bus_name_data(pm_data)
    merge_generator_cost_data(pm_data)
    merge_generic_data(pm_data)

    # split loads and shunts from buses
    split_loads_shunts(pm_data)

    # use once available
    InfrastructureModels.arrays_to_dicts!(pm_data)

    for optional in ["dcline", "load", "shunt"]
        if length(pm_data[optional]) == 0
            pm_data[optional] = Dict{String,Any}()
        end
    end

    return pm_data
end


"""
    split_loads_shunts(data)

Seperates Loads and Shunts in `data` under separate "load" and "shunt" keys in the
PowerModels data format. Includes references to originating bus via "load_bus"
and "shunt_bus" keys, respectively.
"""
function split_loads_shunts(data::Dict{String,Any})
    data["load"] = []
    data["shunt"] = []

    load_num = 1
    shunt_num = 1
    for (i,bus) in enumerate(data["bus"])
        if bus["pd"] != 0.0 || bus["qd"] != 0.0
            append!(data["load"], [Dict{String,Any}("pd" => bus["pd"],
                                                    "qd" => bus["qd"],
                                                    "load_bus" => bus["bus_i"],
                                                    "status" => convert(Int8, bus["bus_type"] != 4),
                                                    "index" => load_num)])
            load_num += 1
        end

        if bus["gs"] != 0.0 || bus["bs"] != 0.0
            append!(data["shunt"], [Dict{String,Any}("gs" => bus["gs"],
                                                     "bs" => bus["bs"],
                                                     "shunt_bus" => bus["bus_i"],
                                                     "status" => convert(Int8, bus["bus_type"] != 4),
                                                     "index" => shunt_num)])
            shunt_num += 1
        end

        for key in ["pd", "qd", "gs", "bs"]
            delete!(bus, key)
        end
    end
end


"ensures all polynomial costs functions have at least three terms"
function standardize_cost_terms(data::Dict{String,Any})
    if haskey(data, "gencost")
        for gencost in data["gencost"]
            if gencost["model"] == 2
                if length(gencost["cost"]) > 3
                    max_nonzero_index = 1
                    for i in 1:length(gencost["cost"])
                        max_nonzero_index = i
                        if gencost["cost"][i] != 0.0
                            break
                        end
                    end

                    if max_nonzero_index > 1
                        warn(LOGGER, "removing $(max_nonzero_index-1) zeros from generator cost model ($(gencost["index"]))")
                        #println(gencost["cost"])
                        gencost["cost"] = gencost["cost"][max_nonzero_index:length(gencost["cost"])]
                        #println(gencost["cost"])
                        gencost["ncost"] = length(gencost["cost"])
                    end
                end

                if length(gencost["cost"]) < 3
                    #println("std gen cost: ",gencost["cost"])
                    cost_3 = append!(vec(fill(0.0, (1,3 - length(gencost["cost"])))), gencost["cost"])
                    gencost["cost"] = cost_3
                    gencost["ncost"] = 3
                    #println("   ",gencost["cost"])
                    warn(LOGGER, "added zeros to make generator cost ($(gencost["index"])) a quadratic function: $(cost_3)")
                end
            end
        end
    end

    if haskey(data, "dclinecost")
        for dclinecost in data["dclinecost"]
            if dclinecost["model"] == 2
                if length(dclinecost["cost"]) > 3
                    max_nonzero_index = 1
                    for i in 1:length(dclinecost["cost"])
                        max_nonzero_index = i
                        if dclinecost["cost"][i] != 0.0
                            break
                        end
                    end

                    if max_nonzero_index > 1
                        warn(LOGGER, "removing $(max_nonzero_index-1) zeros from dcline cost model ($(dclinecost["index"]))")
                        #println(dclinecost["cost"])
                        dclinecost["cost"] = dclinecost["cost"][max_nonzero_index:length(dclinecost["cost"])]
                        #println(dclinecost["cost"])
                        dclinecost["ncost"] = length(dclinecost["cost"])
                    end
                end

                if length(dclinecost["cost"]) < 3
                    #println("std gen cost: ",dclinecost["cost"])
                    cost_3 = append!(vec(fill(0.0, (1,3 - length(dclinecost["cost"])))), dclinecost["cost"])
                    dclinecost["cost"] = cost_3
                    dclinecost["ncost"] = 3
                    #println("   ",dclinecost["cost"])
                    warn(LOGGER, "added zeros to make dcline cost ($(dclinecost["index"])) a quadratic function: $(cost_3)")
                end
            end
        end
    end
end

"sets all branch transformer taps to 1.0, to simplify branch models"
function mp2pm_branch(data::Dict{String,Any})
    branches = [branch for branch in data["branch"]]
    if haskey(data, "ne_branch")
        append!(branches, data["ne_branch"])
    end
    for branch in branches
        if branch["tap"] == 0.0
            branch["transformer"] = false
            branch["tap"] = 1.0
        else
            branch["transformer"] = true
        end

        branch["g_fr"] = 0.0
        branch["g_to"] = 0.0

        branch["b_fr"] = branch["br_b"] / 2.0
        branch["b_to"] = branch["br_b"] / 2.0

        delete!(branch, "br_b")
    end
end


"adds pmin and pmax values at to and from buses"
function mp2pm_dcline(data::Dict{String,Any})
    for dcline in data["dcline"]
        pmin = dcline["pmin"]
        pmax = dcline["pmax"]
        loss0 = dcline["loss0"]
        loss1 = dcline["loss1"]

        delete!(dcline, "pmin")
        delete!(dcline, "pmax")

        if pmin >= 0 && pmax >=0
            pminf = pmin
            pmaxf = pmax
            pmint = loss0 - pmaxf * (1 - loss1)
            pmaxt = loss0 - pminf * (1 - loss1)
        end
        if pmin >= 0 && pmax < 0
            pminf = pmin
            pmint = pmax
            pmaxf = (-pmint + loss0) / (1-loss1)
            pmaxt = loss0 - pminf * (1 - loss1)
        end
        if pmin < 0 && pmax >= 0
            pmaxt = -pmin
            pmaxf = pmax
            pminf = (-pmaxt + loss0) / (1-loss1)
            pmint = loss0 - pmaxf * (1 - loss1)
        end
        if pmin < 0 && pmax < 0
            pmaxt = -pmin
            pmint = pmax
            pmaxf = (-pmint + loss0) / (1-loss1)
            pminf = (-pmaxt + loss0) / (1-loss1)
        end

        dcline["pmaxt"] = pmaxt
        dcline["pmint"] = pmint
        dcline["pmaxf"] = pmaxf
        dcline["pminf"] = pminf

        dcline["pt"] = -dcline["pt"] # matpower has opposite convention
        dcline["qf"] = -dcline["qf"] # matpower has opposite convention
        dcline["qt"] = -dcline["qt"] # matpower has opposite convention
    end
end


"adds dcline costs, if gen costs exist"
function add_dcline_costs(data::Dict{String,Any})
    if length(data["gencost"]) > 0 && length(data["dclinecost"]) <= 0
        warn(LOGGER, "added zero cost function data for dclines")
        model = data["gencost"][1]["model"]
        if model == 1
            for (i, dcline) in enumerate(data["dcline"])
                dclinecost = Dict(
                    "index" => i,
                    "model" => 1,
                    "startup" => 0.0,
                    "shutdown" => 0.0,
                    "ncost" => 2,
                    "cost" => [0.0, 0.0, 0.0, 0.0]
                )
                push!(data["dclinecost"], dclinecost)
            end
        else
            for (i, dcline) in enumerate(data["dcline"])
                dclinecost = Dict(
                    "index" => i,
                    "model" => 2,
                    "startup" => 0.0,
                    "shutdown" => 0.0,
                    "ncost" => 3,
                    "cost" => [0.0, 0.0, 0.0]
                )
                push!(data["dclinecost"], dclinecost)
            end
        end
    end
end


"merges generator cost functions into generator data, if costs exist"
function merge_generator_cost_data(data::Dict{String,Any})
    if haskey(data, "gencost")
        for (i, gencost) in enumerate(data["gencost"])
            gen = data["gen"][i]
            assert(gen["index"] == gencost["index"])
            delete!(gencost, "index")

            check_keys(gen, keys(gencost))
            merge!(gen, gencost)
        end
        delete!(data, "gencost")
    end

    if haskey(data, "dclinecost")
        for (i, dclinecost) in enumerate(data["dclinecost"])
            dcline = data["dcline"][i]
            assert(dcline["index"] == dclinecost["index"])
            delete!(dclinecost, "index")

            check_keys(dcline, keys(dclinecost))
            merge!(dcline, dclinecost)
        end
        delete!(data, "dclinecost")
    end
end


"merges bus name data into buses, if names exist"
function merge_bus_name_data(data::Dict{String,Any})
    if haskey(data, "bus_name")
        # can assume same length is same as bus
        # this is validated during matpower parsing
        for (i, bus_name) in enumerate(data["bus_name"])
            bus = data["bus"][i]
            delete!(bus_name, "index")

            check_keys(bus, keys(bus_name))
            merge!(bus, bus_name)
        end
        delete!(data, "bus_name")
    end
end


"merges Matpower tables based on the table extension syntax"
function merge_generic_data(data::Dict{String,Any})
    mp_matrix_names = [name[5:length(name)] for name in mp_data_names]
    
    key_to_delete = []
    for (k,v) in data
        if isa(v, Array)
            for mp_name in mp_matrix_names
                if startswith(k, "$(mp_name)_")
                    mp_matrix = data[mp_name]
                    push!(key_to_delete, k)

                    if length(mp_matrix) != length(v)
                        error("failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(k)\" because they do not have the same number of rows, $(length(mp_matrix)) and $(length(v)) respectively.")
                    end

                    info(LOGGER, "extending matpower format by appending matrix \"$(k)\" in to \"$(mp_name)\"")

                    for (i, row) in enumerate(mp_matrix)
                        merge_row = v[i]
                        #assert(row["index"] == merge_row["index"]) # note this does not hold for the bus table
                        delete!(merge_row, "index")
                        for key in keys(merge_row)
                            if haskey(row, key)
                                error("failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(k)\" because they both share \"$(key)\" as a column name.")
                            end
                            row[key] = merge_row[key]
                        end
                    end

                    break # out of mp_matrix_names loop
                end
            end

        end
    end

    for key in key_to_delete
        delete!(data, key)
    end
end

"Export a power flow case in matpower format"
function export_matpower(io::Base.PipeEndpoint, data::Dict{String,Any})
    
    # collect all the loads
    for (idx,bus) in sort(data["bus"])
        bus["pd"] = 0
        bus["qd"] = 0  
    end
    for (idx,load) in sort(data["load"])
        bus = data["bus"][string(load["load_bus"])]
        bus["pd"] = bus["pd"] + load["pd"]  
        bus["qd"] = bus["qd"] + load["qd"]  
    end

    # collect all the shunts
    for (idx,bus) in sort(data["bus"])
        bus["gs"] = 0
        bus["bs"] = 0  
    end
    for (idx, shunt) in data["shunt"]
        bus = data["bus"][string(shunt["shunt_bus"])]
        bus["gs"] = bus["gs"] + shunt["gs"]
        bus["bs"] = bus["bs"] + shunt["bs"]      
    end

    mvabase = data["baseMVA"]

    # Print the header information  
    println(io, "%% MATPOWER Case Format : Version 2")
    println(io, "mpc.version = '2';")
    println(io)
    println(io, "%%-----  Power Flow Data  -----%%")
    println(io, "%% system MVA base")
    print(io, "mpc.baseMVA = ")
    print(io, mvabase)
    println(io, ";")
    println(io)
    
    # Print the bus data
    buses = Dict{Int, Dict}()
    for (idx,bus) in data["bus"]
        buses[bus["index"]] = bus
    end        
    println(io, "%% bus data")
    println(io, "%    bus_i    type    Pd    Qd    Gs    Bs    area    Vm    Va    baseKV    zone    Vmax    Vmin")
    println(io, "mpc.bus = [")
    for (idx,bus) in sort(buses)
        s = @sprintf "\t%d\t%d\t%g\t%g\t%g\t%g\t%d\t%f\t%f\t%g\t%d\t%g\t%g" bus["index"] bus["bus_type"] (bus["pd"]*mvabase) (bus["qd"]*mvabase) (bus["gs"]*mvabase) (bus["bs"]*mvabase) bus["area"] bus["vm"] rad2deg(bus["va"]) bus["base_kv"] bus["zone"] bus["vmax"] bus["vmin"]
        println(io, s)
    end  
    println(io, "];")
    println(io)  
    
    # Print the generator data
    generators = Dict{Int, Dict}()
    for (idx,gen) in data["gen"]
        generators[gen["index"]] = gen
    end    
    println(io, "%% generator data")
    println(io, "%    bus    Pg    Qg    Qmax    Qmin    Vg    mBase    status    Pmax    Pmin    Pc1    Pc2    Qc1min    Qc1max    Qc2min    Qc2max    ramp_agc    ramp_10    ramp_30    ramp_q    apf")
    println(io, "mpc.gen = [")
    i = 1
    for (idx,gen) in sort(generators)
        if idx != gen["index"]
            warn(LOGGER, "The index of the generator does not match the matpower assigned index. Any data that uses generator indexes for reference is corrupted.");           
        end  
        s = @sprintf "\t%d\t%g\t%g\t%g\t%g\t%f\t%g\t%d\t%g\t%g\t%g\t%g\t%g\t%g\t%g\t%g\t%g\t%g\t%g\t%g\t%g" gen["gen_bus"] (gen["pg"]*mvabase) (gen["qg"]*mvabase) (gen["qmax"]*mvabase) (gen["qmin"]*mvabase) gen["vg"] gen["mbase"] gen["gen_status"] (gen["pmax"]*mvabase) (gen["pmin"]*mvabase) gen["pc1"] gen["pc2"] gen["qc1min"] gen["qc1max"] gen["qc2min"] gen["qc2max"] gen["ramp_agc"] (haskey(gen, "ramp_10") ? gen["ramp_10"] : 0) gen["ramp_30"] gen["ramp_q"] gen["apf"]
        println(io, s)      
        i = i+1
    end
    println(io,"];")
    println(io)
    
    # Print the branch data
    branches = Dict{Int, Dict}()
    for (idx,branch) in data["branch"]
       branches[branch["index"]] = branch
    end
    println("%% branch data")
    println("%    fbus    tbus    r    x    b    rateA    rateB    rateC    ratio    angle    status    angmin    angmax")
    println("mpc.branch = [")
    i = 1
    for (idx,branch) in sort(branches)
        if idx != branch["index"]
            warn(LOGGER, "The index of the branch does not match the matpower assigned index. Any data that uses branch indexes for reference is corrupted.");           
        end 
        s = @sprintf "\t%d\t%d\t%f\t%f\t%f\t%g\t%g\t%g\t%g\t%f\t%d\t%f\t%f" branch["f_bus"] branch["t_bus"] branch["br_r"] branch["br_x"] (haskey(branch,"b_to") ? branch["b_to"] + branch["b_fr"]  : 0) (branch["rate_a"]*mvabase) (branch["rate_b"]*mvabase) (branch["rate_c"]*mvabase) branch["tap"] (rad2deg(branch["shift"])) branch["br_status"] (rad2deg(branch["angmin"])) (rad2deg(branch["angmax"]))
        println(io, s) 
      
        i = i+1
    end
    println(io, "];")
    println(io)
       
    # Print the gen cost data
    println(io, "%%-----  OPF Data  -----%%")
    println(io, "%% generator cost data")
    println(io, "%    1    startup    shutdown    n    x1    y1    ...    xn    yn")
    println(io, "%    2    startup    shutdown    n    c(n-1)    ...    c0")
    println(io, "mpc.gencost = [")
    for (idx,gen) in (sort(generators))
        s = @sprintf "\t2\t0\t0\t3\t%f\t%f\t%f" (gen["cost"][1] / mvabase^2) (gen["cost"][2] / mvabase) gen["cost"][3]
        println(io, s)
    end
    println(io, "];");
    println(io)

    # Print the extra bus data
    export_extra_data(io, data, "bus", Set(["index", "gs", "bs", "zone", "bus_i", "bus_type", "qd",  "vmax", "area",  "vmin", "va", "vm", "base_kv", "pd"]))
        
    # Print the extra bus string data
    export_extra_data_string(io, data, "bus", Set(["index", "gs", "bs", "zone", "bus_i", "bus_type", "qd",  "vmax", "area",  "vmin", "va", "vm", "base_kv", "pd"]))

    # Print the extra generator data
    export_extra_data(io, data, "gen", Set(["index", "gen_bus", "pg", "qg", "qmax", "qmin", "vg", "mbase", "gen_status", "pmax", "pmin", "pc1", "pc2", "qc1min", "qc1max", "qc2min", "qc2max", "ramp_agc", "ramp_10", "ramp_30", "ramp_q", "apf", "ncost", "model", "shutdown", "startup", "cost"]))

    # Print the extra generator string data
    export_extra_data_string(io, data, "gen", Set(["index", "gen_bus", "pg", "qg", "qmax", "qmin", "vg", "mbase", "gen_status", "pmax", "pmin", "pc1", "pc2", "qc1min", "qc1max", "qc2min", "qc2max", "ramp_agc", "ramp_10", "ramp_30", "ramp_q", "apf", "ncost", "model", "shutdown", "startup", "cost"]))

    # Print the extra branch data
    export_extra_data(io, data, "branch", Set(["index", "f_bus", "t_bus", "br_r", "br_x", "br_b", "b_to", "b_fr", "rate_a", "rate_b", "rate_c", "tap", "shift", "br_status", "angmin", "angmax", "transformer", "g_to", "g_fr"]))
      
    # print the extra branch string data
    export_extra_data_string(io, data, "branch", Set(["index", "f_bus", "t_bus", "br_r", "br_x", "br_b", "b_to", "b_fr", "rate_a", "rate_b", "rate_c", "tap", "shift", "br_status", "angmin", "angmax", "transformer", "g_to", "g_fr"]))

    # print the extra load data
    export_extra_data(io, data, "load", Set(["index", "load_bus", "status", "qd", "pd"]))

    # print the extra load string data
    export_extra_data_string(io, data, "load", Set(["index", "load_bus", "status", "qd", "pd"]))

    # print the extra shunt data
    export_extra_data(io, data, "shunt", Set(["index", "shunt_bus", "status", "gs", "bs"]))

    # print the extra shunt string data
    export_extra_data_string(io, data, "shunt", Set(["index", "shunt_bus", "status", "gs", "bs"]))
      
    # print the extra component data
    for (key, value) in data
        if key != "bus" && key != "gen" && key != "branch" && key != "load" && key != "shunt"
            export_extra_data(io, data, key)
            export_extra_data_string(io, data, key)          
        end      
    end
    
end

"Export fields of a component type"
function export_extra_data(io::Base.PipeEndpoint, data::Dict{String,Any}, component, excluded_fields=Set(["index"]))
    if !isa(data[component], Dict)
        return  
    end 

    if length(data[component]) == 0
        return
    end
       
    # Gather the fields
    included_fields = []   
    c = nothing 
    for temp in values(data[component])
        c = temp
        break    
    end 
    for (key, value) in c
        if !in(key, excluded_fields) && !isa(value, String)
            push!(included_fields, key)
        end      
    end
    
    if length(included_fields) == 0
        return
    end
    
    # Print the header
    print(io, "%column_names% ")
    for field in included_fields
        print(io, field)
        print(io, " ")  
    end
    println(io)
    print(io, "mpc.")
    print(io, component)
    println(io, "_data = [")
    
    # sort the data
    components = Dict{Int, Dict}()
    for (idx,c) in data[component]
        components[c["index"]] = c
    end    
        
    # print the data    
    i = 1
    for (idx,c) in sort(components)
        if idx != c["index"]
            warn(LOGGER, "The index of a component does not match the matpower assigned index. Any data that uses component indexes for reference is corrupted.");           
        end 
     
        for field in included_fields
            print(io,"\t")
            print(io,c[field])
        end
        println(io)
        i = i+1
    end
    println(io, "];")
    println(io)    
end

"Export the string fields of a component type"
function export_extra_data_string(io::Base.PipeEndpoint, data::Dict{String,Any}, component, excluded_fields=Set(["index"]))
    if !isa(data[component], Dict)
        return  
    end 

    if length(data[component]) == 0
        return
    end  
  
    # Gather the fields
    included_fields = []   
    c = nothing 
    for temp in values(data[component])
        c = temp
        break    
    end 
    for (key, value) in c
        if !in(key, excluded_fields) && isa(value, String)
            push!(included_fields, key)
        end      
    end
    
    if length(included_fields) == 0
        return
    end
    
    # Print the header
    print(io, "%column_names% ")
    for field in included_fields
        print(io, field)
        print(io, " ")  
    end
    println(io)
    print(io, "mpc.")
    print(io, component)
    println(io, "_data_strings = {")
    
    # sort the data
    components = Dict{Int, Dict}()
    for (idx,c) in data[component]
        components[c["index"]] = c
    end    
        
    # print the data    
    i = 1
    for (idx,c) in sort(components)
        if idx != c["index"]
            warn(LOGGER, "The index of a component does not match the matpower assigned index. Any data that uses component indexes for reference is corrupted.");           
        end 
     
        for field in included_fields
            print(io,"\t'")
            print(io,c[field])
            print(io,"'")            
        end
        println(io)
        i = i+1
    end
    println(io, "};")
    println(io)    
end



