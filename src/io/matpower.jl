#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################

""
function parse_matpower(file_string::String)
    data_string = readstring(open(file_string))
    mp_data = parse_matpower_data(data_string)

    #display(mp_data)

    pm_data = matpower_to_powermodels(mp_data)

    return pm_data
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
                        warn("removing $(max_nonzero_index-1) zeros from generator cost model ($(gencost["index"]))")
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
                    warn("added zeros to make generator cost ($(gencost["index"])) a quadratic function: $(cost_3)")
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
                        warn("removing $(max_nonzero_index-1) zeros from dcline cost model ($(dclinecost["index"]))")
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
                    warn("added zeros to make dcline cost ($(dclinecost["index"])) a quadratic function: $(cost_3)")
                end
            end
        end
    end
end

"sets all branch transformer taps to 1.0, to simplify branch models"
function mp_branch_to_pm_branch(data::Dict{String,Any})
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
    end
end


""
function mp_dcline_to_pm_dcline(data::Dict{String,Any})
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
        warn("added zero cost function data for dclines")
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
    for (i, gencost) in enumerate(data["gencost"])
        gen = data["gen"][i]
        assert(gen["index"] == gencost["index"])
        delete!(gencost, "index")

        check_keys(gen, keys(gencost))
        merge!(gen, gencost)
    end
    delete!(data, "gencost")

    for (i, dclinecost) in enumerate(data["dclinecost"])
        dcline = data["dcline"][i]
        assert(dcline["index"] == dclinecost["index"])
        delete!(dclinecost, "index")

        check_keys(dcline, keys(dclinecost))
        merge!(dcline, dclinecost)
    end
    delete!(data, "dclinecost")
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


""
function merge_generic_data(data::Dict{String,Any})
    mp_matrix_names = [name[5:length(name)] for name in mp_data_names]

    key_to_delete = []
    for (k,v) in data
        if isa(v, Array)
            mp_name = nothing
            mp_matrix = nothing

            for mp_name in mp_matrix_names
                if startswith(k, "$(mp_name)_")
                    mp_matrix = data[mp_name]
                    push!(key_to_delete, k)
                    break
                end
            end

            #println(mp_name)
            #println(mp_matrix)

            if mp_matrix != nothing
                if length(mp_matrix) != length(v)
                    error("failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(k)\" because they do not have the same number of rows, $(length(mp_matrix)) and $(length(v)) respectively.")
                end

                info("extending matpower format by appending matrix \"$(k)\" in to \"$(mp_name)\"")

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
            end
        end
    end

    for key in key_to_delete
        delete!(data, key)
    end
end



""
function add_line_delimiter(mp_line::AbstractString, start_char, end_char)
    if strip(mp_line) == string(start_char)
        return mp_line
    end

    if !contains(mp_line, ";") && !contains(mp_line, string(end_char))
        mp_line = "$(mp_line);"
    end

    if contains(mp_line, string(end_char))
        prefix = strip(split(mp_line, end_char)[1])
        if length(prefix) > 0 && ! contains(prefix, ";")
            mp_line = replace(mp_line, end_char, ";$(end_char)")
        end
    end

    return mp_line
end

#=
""
function extract_mpc_assignment(string::AbstractString)
    assert(contains(string, "mpc."))
    statement = split(string, ';')[1]
    statement = replace(statement, "mpc.", "")
    name, value = split(statement, '=')
    name = strip(name)
    value = type_value(strip(value))

    return (name, value)
end

"Attempts to determine the type of a string extracted from a matlab file"
function type_value(value_string::AbstractString)
    value_string = strip(value_string)

    if contains(value_string, "'") # value is a string
        value = strip(value_string, '\'')
    else
        # if value is a float
        if contains(value_string, ".") || contains(value_string, "e")
            value = parse_type(Float64, value_string)
        else # otherwise assume it is an int
            value = parse_type(Int, value_string)
        end
    end

    return value
end

"Attempts to determine the type of an array of strings extracted from a matlab file"
function type_array{T <: AbstractString}(string_array::Vector{T})
    value_string = [strip(value_string) for value_string in string_array]

    return if any(contains(value_string, "'") for value_string in string_array)
        [strip(value_string, '\'') for value_string in string_array]
    elseif any(contains(value_string, ".") || contains(value_string, "e") for value_string in string_array)
        [parse_type(Float64, value_string) for value_string in string_array]
    else # otherwise assume it is an int
        [parse_type(Int, value_string) for value_string in string_array]
    end
end
=#

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


"takes a row from a matrix and assigns the values names and types"
function row_to_typed_dict(row_data, columns)
    dict_data = Dict{String,Any}()
    for (i,v) in enumerate(row_data)
        if i <= length(columns)
            name, typ = columns[i]
            dict_data[name] = check_type(typ, v)
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

""
function parse_matpower_data(data_string::String)
    matlab_data, func_name, colnames = parse_matlab(data_string, extended=true)

    case = Dict{String,Any}()


    if func_name != nothing
        case["name"] = func_name
    else
        warn(string("no case name found in matpower file.  The file seems to be missing \"function mpc = ...\""))
        case["name"] = "no_name_found"
    end

    if haskey(matlab_data, "mpc.version")
        case["version"] = matlab_data["mpc.version"]
    else
        warn(string("no case version found in matpower file.  The file seems to be missing \"mpc.version = ...\""))
        case["version"] = "unknown"
    end

    if haskey(matlab_data, "mpc.baseMVA")
        case["baseMVA"] = matlab_data["mpc.baseMVA"]
    else
        warn(string("no baseMVA found in matpower file.  The file seems to be missing \"mpc.baseMVA = ...\""))
        case["baseMVA"] = 1.0
    end


    if haskey(matlab_data, "mpc.bus")
        buses = []
        for bus_row in matlab_data["mpc.bus"]
            bus_data = row_to_typed_dict(bus_row, mp_bus_columns)
            bus_data["index"] = check_type(Int, bus_row[1])
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
        if !in(k, mp_data_names) && k[1:4] == "mpc."
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
                info("extending matpower format with data: $(case_name) $(length(tbl))x$(length(tbl[1])-1)")
            else
                case[case_name] = value
                info("extending matpower format with constant data: $(case_name)")
            end
        end
    end

    #println("Case:")
    #println(case)

    return case
end


function mp_cost_data(cost_row)
    cost_data = Dict{String,Any}(
        "model" => check_type(Int, cost_row[1]),
        "startup" => check_type(Float64, cost_row[2]),
        "shutdown" => check_type(Float64, cost_row[3]),
        "ncost" => check_type(Int, cost_row[4]),
        "cost" => [check_type(Float64, x) for x in cost_row[5:length(cost_row)]]
    )

    #=
    # skip this literal interpretation, as its hard to invert
    cost_values = [check_type(Float64, x) for x in cost_row[5:length(cost_row)]]
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


"takes a list of list of strings and turns it into a list of typed dictionaries"
function build_typed_dict(data, column_names)
    # TODO see if there is a more julia-y way of doing this
    rows = length(data)
    columns = length(data[1])

    typed_columns = [type_array([ data[r][c] for r in 1:rows ]) for c in 1:columns]

    typed_data = Dict{String,Any}[]
    for r in 1:rows
        data_dict = Dict{String,Any}()
        data_dict["index"] = r
        for c in 1:columns
            data_dict[column_names[c]] = typed_columns[c][r]
        end
        push!(typed_data, data_dict)
    end
    #println(typed_data)

    return typed_data
end

"extends a give case data with typed dictionary data"
function extend_case_data(case, name, typed_dict_data, has_column_names)
    matpower_matrix_names = ["bus", "gen", "branch", "dcline"]

    if any([startswith(name, "$(mp_name)_") for mp_name in matpower_matrix_names])
        mp_name = "none"
        mp_matrix = "none"

        for mp_name in matpower_matrix_names
            if startswith(name, "$(mp_name)_")
                mp_matrix = case[mp_name]
                break
            end
        end

        if !has_column_names
            error("failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(name)\" because it does not have column names.")
        end

        if length(mp_matrix) != length(typed_dict_data)
            error("failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(name)\" because they do not have the same number of rows, $(length(mp_matrix)) and $(length(typed_dict_data)) respectively.")
        end

        info("extending matpower format by appending matrix \"$(name)\" onto \"$(mp_name)\"")
        for (i, row) in enumerate(mp_matrix)
            merge_row = typed_dict_data[i]
            #assert(row["index"] == merge_row["index"]) # note this does not hold for the bus table
            delete!(merge_row, "index")
            for key in keys(merge_row)
                if haskey(row, key)
                    error("failed to extend the matpower matrix \"$(mp_name)\" with the matrix \"$(name)\" because they both share \"$(key)\" as a column name.")
                end
                row[key] = merge_row[key]
            end
        end

    else
        # minus 1 for excluding added "index" key
        info("extending matpower format with data: $(name) $(length(typed_dict_data))x$(length(typed_dict_data[1])-1)")
        case[name] = typed_dict_data
    end
end

"""
converts a Matpower dict into a PowerModels dict
"""
function matpower_to_powermodels(mp_data::Dict{String,Any})
    pm_data = deepcopy(mp_data)

    pm_data["multinetwork"] = false

    if !haskey(pm_data, "dcline")
        pm_data["dcline"] = []
    end
    if !haskey(pm_data, "gencost")
        pm_data["gencost"] = []
    end
    if !haskey(pm_data, "dclinecost")
        pm_data["dclinecost"] = []
    end

    mp_branch_to_pm_branch(pm_data)
    mp_dcline_to_pm_dcline(pm_data)

    add_dcline_costs(pm_data)
    standardize_cost_terms(pm_data)
    merge_bus_name_data(pm_data)
    merge_generator_cost_data(pm_data)

    merge_generic_data(pm_data)

    for (k,v) in pm_data
        if isa(v, Array)
            #println("updating $(k)")
            dict = Dict{String,Any}()
            for item in v
                assert("index" in keys(item))
                dict[string(item["index"])] = item
            end
            pm_data[k] = dict
        end
    end

    return pm_data
end
