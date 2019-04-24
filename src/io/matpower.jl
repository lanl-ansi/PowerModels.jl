#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################

"Parses the matpwer data from either a filename or an IO object"
function parse_matpower(file::Union{IO, String}; validate=true)
    mp_data = parse_matpower_file(file)
    pm_data = matpower_to_powermodels(mp_data)
    if validate
        check_network_data(pm_data)
    end
    return pm_data
end


### Data and functions specific to Matpower format ###

mp_data_names = ["mpc.version", "mpc.baseMVA", "mpc.bus", "mpc.gen",
    "mpc.branch", "mpc.dcline", "mpc.gencost", "mpc.dclinecost",
    "mpc.bus_name", "mpc.storage"
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
    ("bus_name", Union{String,SubString{String}})
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

mp_storage_columns = [
    ("storage_bus", Int),
    ("energy", Float64), ("energy_rating", Float64),
    ("charge_rating", Float64), ("discharge_rating", Float64),
    ("charge_efficiency", Float64), ("discharge_efficiency", Float64),
    ("thermal_rating", Float64),
    ("qmin", Float64), ("qmax", Float64),
    ("r", Float64), ("x", Float64),
    ("standby_loss", Float64),
    ("status", Int)
]


""
function parse_matpower_file(file_string::String)
    mp_data = open(file_string) do io
        parse_matpower_file(io)
    end

    return mp_data
end


""
function parse_matpower_file(io::IO)
    data_string = read(io, String)

    return parse_matpower_string(data_string)
end


""
function parse_matpower_string(data_string::String)
    matlab_data, func_name, colnames = InfrastructureModels.parse_matlab_string(data_string, extended=true)

    case = Dict{String,Any}()

    if func_name != nothing
        case["name"] = func_name
    else
        Memento.warn(LOGGER, string("no case name found in matpower file.  The file seems to be missing \"function mpc = ...\""))
        case["name"] = "no_name_found"
    end

    case["source_type"] = "matpower"
    if haskey(matlab_data, "mpc.version")
        case["source_version"] = matlab_data["mpc.version"]
    else
        Memento.warn(LOGGER, string("no case version found in matpower file.  The file seems to be missing \"mpc.version = ...\""))
        case["source_version"] = "0.0.0+"
    end

    if haskey(matlab_data, "mpc.baseMVA")
        case["baseMVA"] = matlab_data["mpc.baseMVA"]
    else
        Memento.warn(LOGGER, string("no baseMVA found in matpower file.  The file seems to be missing \"mpc.baseMVA = ...\""))
        case["baseMVA"] = 1.0
    end


    if haskey(matlab_data, "mpc.bus")
        buses = []
        for bus_row in matlab_data["mpc.bus"]
            bus_data = InfrastructureModels.row_to_typed_dict(bus_row, mp_bus_columns)
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
            gen_data = InfrastructureModels.row_to_typed_dict(gen_row, mp_gen_columns)
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
            branch_data = InfrastructureModels.row_to_typed_dict(branch_row, mp_branch_columns)
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
            dcline_data = InfrastructureModels.row_to_typed_dict(dcline_row, mp_dcline_columns)
            dcline_data["index"] = i
            push!(dclines, dcline_data)
        end
        case["dcline"] = dclines
    end

    if haskey(matlab_data, "mpc.storage")
        storage = []
        for (i, storage_row) in enumerate(matlab_data["mpc.storage"])
            storage_data = InfrastructureModels.row_to_typed_dict(storage_row, mp_storage_columns)
            storage_data["index"] = i
            push!(storage, storage_data)
        end
        case["storage"] = storage
    end


    if haskey(matlab_data, "mpc.bus_name")
        bus_names = []
        for (i, bus_name_row) in enumerate(matlab_data["mpc.bus_name"])
            bus_name_data = InfrastructureModels.row_to_typed_dict(bus_name_row, mp_bus_name_columns)
            bus_name_data["index"] = i
            push!(bus_names, bus_name_data)
        end
        case["bus_name"] = bus_names

        if length(case["bus_name"]) != length(case["bus"])
            error(LOGGER, "incorrect Matpower file, the number of bus names ($(length(case["bus_name"]))) is inconsistent with the number of buses ($(length(case["bus"]))).\n")
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
            error(LOGGER, "incorrect Matpower file, the number of generator cost functions ($(length(case["gencost"]))) is inconsistent with the number of generators ($(length(case["gen"]))).\n")
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
            error(LOGGER, "incorrect Matpower file, the number of dcline cost functions ($(length(case["dclinecost"]))) is inconsistent with the number of dclines ($(length(case["dcline"]))).\n")
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
                    row_data = InfrastructureModels.row_to_dict(row, column_names)
                    row_data["index"] = i
                    push!(tbl, row_data)
                end
                case[case_name] = tbl
                Memento.info(LOGGER, "extending matpower format with data: $(case_name) $(length(tbl))x$(length(tbl[1])-1)")
            else
                case[case_name] = value
                Memento.info(LOGGER, "extending matpower format with constant data: $(case_name)")
            end
        end
    end

    return case
end


""
function mp_cost_data(cost_row)
    ncost = cost_row[4]
    model = cost_row[1]
    if model == 1
        nr_parameters = ncost*2
    elseif model == 2
       nr_parameters = ncost
    end
    cost_data = Dict(
        "model" => InfrastructureModels.check_type(Int, cost_row[1]),
        "startup" => InfrastructureModels.check_type(Float64, cost_row[2]),
        "shutdown" => InfrastructureModels.check_type(Float64, cost_row[3]),
        "ncost" => InfrastructureModels.check_type(Int, cost_row[4]),
        "cost" => [InfrastructureModels.check_type(Float64, x) for x in cost_row[5:5+nr_parameters-1]]
    )

    #=
    # skip this literal interpretation, as its hard to invert
    cost_values = [InfrastructureModels.check_type(Float64, x) for x in cost_row[5:length(cost_row)]]
    if cost_data["model"] == 1:
        if length(cost_values)%2 != 0
            error(LOGGER, "incorrect matpower file, odd number of pwl cost function values")
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
function matpower_to_powermodels(mp_data::Dict{String,<:Any})
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
    if !haskey(pm_data, "storage")
        pm_data["storage"] = []
    end

    # translate component models
    mp2pm_branch(pm_data)
    mp2pm_dcline(pm_data)

    # translate cost models
    add_dcline_costs(pm_data)

    # merge data tables
    merge_bus_name_data(pm_data)
    merge_generator_cost_data(pm_data)
    merge_generic_data(pm_data)

    # split loads and shunts from buses
    split_loads_shunts(pm_data)

    # use once available
    InfrastructureModels.arrays_to_dicts!(pm_data)

    for optional in ["dcline", "load", "shunt", "storage"]
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

        if branch["rate_a"] == 0.0
            delete!(branch, "rate_a")
        end
        if branch["rate_b"] == 0.0
            delete!(branch, "rate_b")
        end
        if branch["rate_c"] == 0.0
            delete!(branch, "rate_c")
        end
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

        # preserve the old pmin and pmax values
        dcline["mp_pmin"] = pmin
        dcline["mp_pmax"] = pmax

        dcline["pt"] = -dcline["pt"] # matpower has opposite convention
        dcline["qf"] = -dcline["qf"] # matpower has opposite convention
        dcline["qt"] = -dcline["qt"] # matpower has opposite convention
    end
end


"adds dcline costs, if gen costs exist"
function add_dcline_costs(data::Dict{String,Any})
    if length(data["gencost"]) > 0 && length(data["dclinecost"]) <= 0 && length(data["dcline"]) > 0
        Memento.warn(LOGGER, "added zero cost function data for dclines")
        model = data["gencost"][1]["model"]
        if model == 1
            for (i, dcline) in enumerate(data["dcline"])
                dclinecost = Dict(
                    "index" => i,
                    "model" => 1,
                    "startup" => 0.0,
                    "shutdown" => 0.0,
                    "ncost" => 2,
                    "cost" => [dcline["pminf"], 0.0, dcline["pmaxf"], 0.0]
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
            @assert(gen["index"] == gencost["index"])
            delete!(gencost, "index")

            check_keys(gen, keys(gencost))
            merge!(gen, gencost)
        end
        delete!(data, "gencost")
    end

    if haskey(data, "dclinecost")
        for (i, dclinecost) in enumerate(data["dclinecost"])
            dcline = data["dcline"][i]
            @assert(dcline["index"] == dclinecost["index"])
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
                        error(LOGGER, "failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(k)\" because they do not have the same number of rows, $(length(mp_matrix)) and $(length(v)) respectively.")
                    end

                    Memento.info(LOGGER, "extending matpower format by appending matrix \"$(k)\" in to \"$(mp_name)\"")

                    for (i, row) in enumerate(mp_matrix)
                        merge_row = v[i]
                        #@assert(row["index"] == merge_row["index"]) # note this does not hold for the bus table
                        delete!(merge_row, "index")
                        for key in keys(merge_row)
                            if haskey(row, key)
                                error(LOGGER, "failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(k)\" because they both share \"$(key)\" as a column name.")
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


"Export power network data in the matpower format"
function export_matpower(data::Dict{String,Any})
    return sprint(export_matpower, data)
end

" Get a default value for dict entry "
function get_default(dict, key, default=0.0)
    if haskey(dict, key) && dict[key] != NaN
        return dict[key]
    end
    return default
end


"Export power network data in the matpower format"
function export_matpower(io::IO, data::Dict{String,Any})
    data = deepcopy(data)

    #convert data to mixed unit
    if data["per_unit"]
       make_mixed_units(data)
    end

    # make all costs have the name number of items (to prepare for table export)
    standardize_cost_terms(data)

    # create some useful maps and data structures
    buses = Dict{Int, Dict}()
    for (idx,bus) in data["bus"]
        buses[bus["index"]] = bus
    end
    generators = Dict{Int, Dict}()
    for (idx,gen) in data["gen"]
        generators[gen["index"]] = gen
    end
    branches = Dict{Int, Dict}()
    for (idx,branch) in data["branch"]
       branches[branch["index"]] = branch
    end
    dclines = Dict{Int, Dict}()
    for (idx,dcline) in data["dcline"]
       dclines[dcline["index"]] = dcline
    end
    ne_branches = Dict{Int, Dict}()
    if haskey(data, "ne_branch")
        for (idx,branch) in data["ne_branch"]
            ne_branches[branch["index"]] = branch
        end
    end

    pd = Dict{Int, Float64}()
    qd = Dict{Int, Float64}()
    gs = Dict{Int, Float64}()
    bs = Dict{Int, Float64}()

    # collect all the loads
    for (idx,bus) in sort(data["bus"])
        pd[bus["index"]] = 0
        qd[bus["index"]] = 0
    end
    for (idx,load) in sort(data["load"])
        bus = buses[load["load_bus"]]
        pd[bus["index"]] = pd[bus["index"]] + load["pd"]
        qd[bus["index"]] = qd[bus["index"]] + load["qd"]
    end

    # collect all the shunts
    for (idx,bus) in sort(data["bus"])
        gs[bus["index"]] = 0
        bs[bus["index"]] = 0
    end
    for (idx, shunt) in data["shunt"]
        bus = buses[shunt["shunt_bus"]]
        bs[bus["index"]] = bs[bus["index"]] + shunt["bs"]
        gs[bus["index"]] = gs[bus["index"]] + shunt["gs"]
    end

    mvaBase = data["baseMVA"]

    # Print the header information
    println(io, "%% MATPOWER Case Format : Version 2")
    println(io, "function mpc = ", data["name"])
    println(io, "mpc.version = '2';")
    println(io)
    println(io, "%%-----  Power Flow Data  -----%%")
    println(io, "%% system MVA base")
    println(io, "mpc.baseMVA = ", mvaBase, ";")

    # Print the bus data
    println(io, "%% bus data")
    println(io, "%    bus_i    type    Pd    Qd    Gs    Bs    area    Vm    Va    baseKV    zone    Vmax    Vmin")
    println(io, "mpc.bus = [")
    for (idx,bus) in sort(buses)
    println(io, "\t", bus["index"],
                "\t", bus["bus_type"],
                "\t", get_default(pd, bus["index"]),
                "\t", get_default(qd, bus["index"]),
                "\t", get_default(gs, bus["index"]),
                "\t", get_default(bs, bus["index"]),
                "\t", get_default(bus, "area"),
                "\t", get_default(bus, "vm"),
                "\t", get_default(bus, "va"),
                "\t", get_default(bus, "base_kv"),
                "\t", get_default(bus, "zone"),
                "\t", get_default(bus, "vmax"),
                "\t", get_default(bus, "vmin"),
                "\t", get_default(bus, "lam_p", ""),
                "\t", get_default(bus, "lam_q", ""),
                "\t", get_default(bus, "mu_vmax", ""),
                "\t", get_default(bus, "mu_vmin",""),
                )
    end
    println(io, "];")
    println(io)

    # Print the bus names
    if haskey(collect(values(buses))[1], "bus_name")
        println(io, "%% bus names")
        println(io, "mpc.bus_name = {")
        for (idx,bus) in sort(buses)
            println(io, "\t'", bus["bus_name"], "'")
        end
        println(io, "};")
        println(io)
    end

    # Print the generator data
    println(io, "%% generator data")
    println(io, "%    bus    Pg    Qg    Qmax    Qmin    Vg    mBase    status    Pmax    Pmin    Pc1    Pc2    Qc1min    Qc1max    Qc2min    Qc2max    ramp_agc    ramp_10    ramp_30    ramp_q    apf")
    println(io, "mpc.gen = [")
    i = 1
    for (idx,gen) in sort(generators)
        if idx != gen["index"]
            Memento.warn(LOGGER, "The index of the generator does not match the matpower assigned index. Any data that uses generator indexes for reference is corrupted.");
        end
    println(io, "\t", gen["gen_bus"],
                "\t", get_default(gen, "pg"),
                "\t", get_default(gen, "qg"),
                "\t", get_default(gen, "qmax"),
                "\t", get_default(gen, "qmin"),
                "\t", get_default(gen, "vg"),
                "\t", get_default(gen, "mbase"),
                "\t", get_default(gen, "gen_status"),
                "\t", get_default(gen, "pmax"),
                "\t", get_default(gen, "pmin"),
                "\t", get_default(gen, "pc1", ""),
                "\t", get_default(gen, "pc2", ""),
                "\t", get_default(gen, "qc1min", ""),
                "\t", get_default(gen, "qc1max", ""),
                "\t", get_default(gen, "qc2min", ""),
                "\t", get_default(gen, "qc2max", ""),
                "\t", get_default(gen, "ramp_agc", ""),
                "\t", (haskey(gen, "ramp_10") ? gen["ramp_10"] : haskey(gen, "ramp_30") ? 0 : ""),
                "\t", get_default(gen, "ramp_30", ""),
                "\t", get_default(gen, "ramp_q", ""),
                "\t", get_default(gen, "apf", ""),
                "\t", get_default(gen, "mu_pmax", ""),
                "\t", get_default(gen, "mu_pmin", ""),
                "\t", get_default(gen, "mu_qmax", ""),
                "\t", get_default(gen, "mu_qmin", ""),
                )

        i = i+1
    end
    println(io,"];")
    println(io)

    # Print the branch data
    println(io, "%% branch data")
    println(io, "%    fbus    tbus    r    x    b    rateA    rateB    rateC    ratio    angle    status    angmin    angmax")
    println(io, "mpc.branch = [")
    i = 1
    for (idx,branch) in sort(branches)
        if idx != branch["index"]
            Memento.warn(LOGGER, "The index of the branch does not match the matpower assigned index. Any data that uses branch indexes for reference is corrupted.");
        end
        println(io,
            "\t", get_default(branch, "f_bus"),
            "\t", get_default(branch, "t_bus"),
            "\t", get_default(branch, "br_r"),
            "\t", get_default(branch, "br_x"),
            "\t", (branch["b_to"] + branch["b_fr"]) != NaN ? (branch["b_to"] + branch["b_fr"]) : 0,
            "\t", get_default(branch, "rate_a"),
            "\t", get_default(branch, "rate_b"),
            "\t", get_default(branch, "rate_c"),

            "\t", (branch["transformer"] ? branch["tap"] : 0),
            "\t", (branch["transformer"] ? branch["shift"] : 0),
            "\t", get_default(branch, "br_status"),
            "\t", get_default(branch, "angmin"),
            "\t", get_default(branch, "angmax"),
            "\t", get_default(branch, "pf", ""),
            "\t", get_default(branch, "qf", ""),
            "\t", get_default(branch, "pt", ""),
            "\t", get_default(branch, "qt", ""),
            "\t", get_default(branch, "mu_sf", ""),
            "\t", get_default(branch, "mu_st", ""),
            "\t", get_default(branch, "mu_angmin", ""),
            "\t", get_default(branch, "mu_angmax", ""),
        )
        i = i+1
    end
    println(io, "];")
    println(io)

    # print the dcline data
    println(io, "%% dcline data")
    println(io, "%	fbus	tbus	status	Pf	Pt	Qf	Qt	Vf	Vt	Pmin	Pmax	QminF	QmaxF	QminT	QmaxT	loss0	loss1")
    println(io, "mpc.dcline = [")
    for (idx, dcline) in sort(dclines)
        println(io,
            "\t", get_default(dcline, "f_bus"),
            "\t", get_default(dcline, "t_bus"),
            "\t", get_default(dcline, "br_status"),
            "\t", get_default(dcline, "pf"),
            "\t", -get_default(dcline, "pt"),  # opposite convention
            "\t", -get_default(dcline, "qf"),  # opposite convention
            "\t", -get_default(dcline, "qt"),  # opposite convention
            "\t", get_default(dcline, "vf"),
            "\t", get_default(dcline, "vt"),
            "\t", (haskey(dcline, "mp_pmin") ? dcline["mp_pmin"] : min(dcline["pmaxt"], dcline["pmint"], dcline["pmaxf"], dcline["pminf"])),
            "\t", (haskey(dcline, "mp_pmax") ? dcline["mp_pmax"] : max(dcline["pmaxt"], dcline["pmint"], dcline["pmaxf"], dcline["pminf"])),
            "\t", get_default(dcline, "qminf"),
            "\t", get_default(dcline, "qmaxf"),
            "\t", get_default(dcline, "qmint"),
            "\t", get_default(dcline, "qmaxt"),
            "\t", get_default(dcline, "loss0"),
            "\t", get_default(dcline, "loss1"),
            "\t", get_default(dcline, "mu_pmin", ""),
            "\t", get_default(dcline, "mu_pmax", ""),
            "\t", get_default(dcline, "mu_qminf", ""),
            "\t", get_default(dcline, "mu_qmaxf", ""),
            "\t", get_default(dcline, "mu_qmint", ""),
            "\t", get_default(dcline, "mu_qmaxt", ""),
        )
    end
    println(io, "];")
    println(io)

    # Print the gen cost data
    export_cost_data(io, generators, "mpc.gencost")

    # Print the dcline cost data
    export_cost_data(io, dclines, "mpc.dclinecost")

    # ne branch is not part of the matpower specs. However, it is treated as a special case by the matpower parser
    # for example, br_b is converted into b_to and b_fr
    if haskey(data, "ne_branch")
        println(io, "%column_names%	f_bus	t_bus	br_r	br_x	br_b	rate_a	rate_b	rate_c	tap	shift	br_status	angmin	angmax	construction_cost")
        println(io, "mpc.ne_branch = [")
        i = 1
        for (idx,branch) in sort(ne_branches)
            if idx != branch["index"]
                Memento.warn(LOGGER, "The index of the ne_branch does not match the matpower assigned index. Any data that uses branch indexes for reference is corrupted.");
            end
            println(io,
                "\t", branch["f_bus"],
                "\t", branch["t_bus"],
                "\t", get_default(branch, "br_r"),
                "\t", get_default(branch, "br_x"),
                "\t", (haskey(branch,"b_to") ? branch["b_to"] + branch["b_fr"]  : 0),
                "\t", get_default(branch, "rate_a"),
                "\t", get_default(branch, "rate_b"),
                "\t", get_default(branch, "rate_c"),
                "\t", (branch["transformer"] ? branch["tap"] : 0),
                "\t", (branch["transformer"] ? branch["shift"] : 0),
                "\t", get_default(branch, "br_status"),
                "\t", get_default(branch, "angmin"),
                "\t", get_default(branch, "angmax"),
                "\t", get_default(branch, "construction_cost"),
            )
            i = i+1
        end
        println(io, "];");
        println(io)
    end

    # Print the extra bus data
    export_extra_data(io, data, "bus", Set(["index", "gs", "bs", "zone", "bus_i", "bus_type", "qd",  "vmax", "area", "vmin", "va", "vm", "base_kv", "pd", "bus_name", "lam_p", "lam_q", "mu_vmax", "mu_vmin"]); postfix="_data")

    # Print the extra generator data
    export_extra_data(io, data, "gen", Set(["index", "gen_bus", "pg", "qg", "qmax", "qmin", "vg", "mbase", "gen_status", "pmax", "pmin", "pc1", "pc2", "qc1min", "qc1max", "qc2min", "qc2max", "ramp_agc", "ramp_10", "ramp_30", "ramp_q", "apf", "ncost", "model", "shutdown", "startup", "cost", "mu_pmax", "mu_pmin", "mu_qmax", "mu_qmin"]); postfix="_data")

    # Print the extra branch data
    export_extra_data(io, data, "branch", Set(["index", "f_bus", "t_bus", "br_r", "br_x", "br_b", "b_to", "b_fr", "rate_a", "rate_b", "rate_c", "tap", "shift", "br_status", "angmin", "angmax", "transformer", "g_to", "g_fr", "pf", "qf", "pt", "qt", "mu_sf", "mu_st", "mu_angmin", "mu_angmax"]); postfix="_data")

    # Print the extra dcline data
    export_extra_data(io, data, "dcline", Set(["index", "mu_qmaxt", "mu_qmint", "mu_qmaxf", "mu_qminf", "mu_pmax", "mu_pmin", "loss0", "loss1", "qmint", "qmaxt", "pmin", "pmax", "qminf", "qmaxf", "f_bus", "t_bus", "br_status", "pf", "pt", "qf", "qt", "vf", "vt", "ncost", "model", "shutdown", "pmaxt", "startup", "pmint", "cost", "pminf", "pmaxf", "mp_pmax", "mp_pmin"]); postfix="_data")

    # Print the extra ne_branch data
    if haskey(data, "ne_branch")
        export_extra_data(io, data, "ne_branch", Set(["index", "f_bus", "t_bus", "br_r", "br_x", "br_b", "b_to", "b_fr", "rate_a", "rate_b", "rate_c", "tap", "shift", "br_status", "angmin", "angmax", "transformer", "construction_cost", "g_to", "g_fr"]); postfix="_data")
    end

    # print the extra load data
    export_extra_data(io, data, "load", Set(["index", "load_bus", "status", "qd", "pd"]); postfix="_data")

    # print the extra shunt data
    export_extra_data(io, data, "shunt", Set(["index", "shunt_bus", "status", "gs", "bs"]); postfix="_data")

    # print the extra component data
    for (key, value) in data
        if key != "bus" && key != "gen" && key != "branch" && key != "load" && key != "shunt" && key != "dcline" && key != "ne_branch" && key != "version" && key != "baseMVA" && key != "per_unit" && key != "name" && key != "source_type" && key != "source_version"
            export_extra_data(io, data, key)
        end
    end
end

"Export fields of a component type"
function export_extra_data(io::IO, data::Dict{String,<:Any}, component, excluded_fields=Set(["index"]); postfix="")
    if isa(data[component], Int) || isa(data[component], Int64) || isa(data[component], Float64)
        println(io, "mpc.", component, " = ", data[component], ";")
        println(io)
        return
    end

    if isa(data[component], String) || isa(data[component], SubString{String})
        println(io, "mpc.", component, " = '", data[component], "';")
        println(io)
        return
    end

    if !isa(data[component], Dict)
        return
    end

    if length(data[component]) == 0
        return
    end

    # Gather the fields
    included_fields = []
    c = collect(values(data[component]))[1]
    for (key, value) in c
        if !in(key, excluded_fields)
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
    println(io, "mpc.", component, postfix, " = {")

    # sort the data
    components = Dict{Int, Dict}()
    for (idx,c) in data[component]
        components[c["index"]] = c
    end

    # print the data
    i = 1
    for (idx,c) in sort(components)
        if idx != c["index"]
            Memento.warn(LOGGER, "The index of a component does not match the matpower assigned index. Any data that uses component indexes for reference is corrupted.");
        end

        for field in included_fields
            print(io,"\t")
            if isa(c[field], Union{String,SubString})
                print(io, "'")
            end
            print(io,c[field])
            if isa(c[field], Union{String,SubString})
                print(io, "'")
            end
        end
        println(io)
        i = i+1
    end
    println(io, "};")
    println(io)
end

"Export cost data"
function export_cost_data(io::IO, components::Dict{Int,Dict}, prefix::String)
    if length(components) <= 0
        return
    end

    a_comp = collect(values(components))[1]
    if haskey(a_comp, "cost")
        ncost = length(a_comp["cost"])
        model = a_comp["model"]

        for (i,comp) in components
            if length(comp["cost"]) != ncost || comp["model"] != model
                Memento.warn(LOGGER, "heterogeneous cost functions will be ommited in Matpower data")
                return
            end
        end

        println(io, "%%-----  OPF Data  -----%%")
        println(io, "%% cost data")
        println(io, "%    1    startup    shutdown    n    x1    y1    ...    xn    yn")
        println(io, "%    2    startup    shutdown    n    c(n-1)    ...    c0")
        println(io, prefix, " = [")

        for (idx,gen) in (sort(components))
            if gen["model"] == 1
                print(io, "\t1\t", gen["startup"], "\t", gen["shutdown"], "\t", (length(gen["cost"])/2) ),
                for l=1:length(gen["cost"])
                    print(io, "\t", gen["cost"][l])
                end
            else
                print(io, "\t2\t", gen["startup"], "\t", gen["shutdown"], "\t", length(gen["cost"])),
                for l=1:length(gen["cost"])
                    print(io, "\t", gen["cost"][l])
                end
            end
            println(io)
        end
        println(io, "];");
        println(io)
    end
end
