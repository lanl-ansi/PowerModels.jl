#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################

""
function parse_matpower(file_string::String)
    data_string = readstring(open(file_string))
    mp_data = parse_matpower_data(data_string)

    update_branch_transformer_settings(mp_data)
    standardize_cost_terms(mp_data)
    merge_bus_name_data(mp_data)
    merge_generator_cost_data(mp_data)

    # after this call, Matpower data is consistent with PowerModels data
    mp_data_to_pm_data(mp_data)

    mp_data["multinetwork"] = false

    return mp_data
end

"ensures all polynomial costs functions have at least three terms"
function standardize_cost_terms(data::Dict{String,Any})
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
                end
            end

            if length(gencost["cost"]) < 3
                #println("std gen cost: ",gencost["cost"])
                cost_3 = append!(vec(fill(0.0, (1,3 - length(gencost["cost"])))), gencost["cost"])
                gencost["cost"] = cost_3
                #println("   ",gencost["cost"])
                warn("added zeros to make generator cost ($(gencost["index"])) a quadratic function: $(cost_3)")
            end
        end
    end
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
                end
            end

            if length(dclinecost["cost"]) < 3
                #println("std gen cost: ",dclinecost["cost"])
                cost_3 = append!(vec(fill(0.0, (1,3 - length(dclinecost["cost"])))), dclinecost["cost"])
                dclinecost["cost"] = cost_3
                #println("   ",dclinecost["cost"])
                warn("added zeros to make dcline cost ($(dclinecost["index"])) a quadratic function: $(cost_3)")
            end
        end
    end
end

"sets all branch transformer taps to 1.0, to simplify branch models"
function update_branch_transformer_settings(data::Dict{String,Any})
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

"merges generator cost functions into generator data, if costs exist"
function merge_generator_cost_data(data::Dict{String,Any})
    if haskey(data, "gencost")
        # can assume same length is same as gen (or double)
        # this is validated during parsing
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
        # can assume same length is same as dcline
        # this is validated during parsing
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
        # this is validated during parsing
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
parse_cell(lines, index) = parse_matlab_data(lines, index, '{', '}')

""
parse_matrix(lines, index) = parse_matlab_data(lines, index, '[', ']')

""
function parse_matlab_data(lines, index, start_char, end_char)
    last_index = length(lines)
    line_count = 0
    columns = -1

    assert(contains(lines[index+line_count], "="))
    matrix_assignment = split(lines[index+line_count], '%')[1]
    matrix_assignment = strip(matrix_assignment)

    assert(contains(matrix_assignment, "mpc."))
    matrix_assignment_parts = split(matrix_assignment, '=')
    matrix_name = strip(replace(matrix_assignment_parts[1], "mpc.", ""))

    matrix_assignment_rhs = ""
    if length(matrix_assignment_parts) > 1
        matrix_assignment_rhs = strip(matrix_assignment_parts[2])
    end

    line_count = line_count + 1
    matrix_body_lines = [matrix_assignment_rhs]
    found_close_bracket = contains(matrix_assignment_rhs, string(end_char))

    while index + line_count < last_index && !found_close_bracket
        line = strip(lines[index+line_count])

        if length(line) == 0 || line[1] == '%'
            line_count += 1
            continue
        end

        line = strip(split(line, '%')[1])

        if contains(line, string(end_char))
            found_close_bracket = true
        end

        push!(matrix_body_lines, line)

        line_count = line_count + 1
    end

    #print(matrix_body_lines)
    matrix_body_lines = [add_line_delimiter(line, start_char, end_char) for line in matrix_body_lines]
    #print(matrix_body_lines)

    matrix_body = join(matrix_body_lines, ' ')
    matrix_body = strip(replace(strip(strip(matrix_body), start_char), "$(end_char);", ""))
    matrix_body_rows = split(matrix_body, ';')
    matrix_body_rows = matrix_body_rows[1:(length(matrix_body_rows)-1)]

    matrix = []
    for row in matrix_body_rows
        row_items = split_line(strip(row))
        #println(row_items)
        push!(matrix, row_items)
        if columns < 0
            columns = length(row_items)
        elseif columns != length(row_items)
            error("matrix parsing error, inconsistent number of items in each row\n$(row)")
        end
    end

    matrix_dict = Dict("name" => matrix_name, "data" => matrix, "line_count" => line_count)

    if index > 1 && contains(lines[index-1], "%column_names%")
        column_names_string = lines[index-1]
        column_names_string = replace(column_names_string, "%column_names%", "")
        column_names = split(column_names_string)
        if length(matrix[1]) != length(column_names)
            error("column name parsing error, data rows $(length(matrix[1])), column names $(length(column_names)) \n$(column_names)")
        end
        if any([column_name == "index" for column_name in column_names])
            error("column name parsing error, \"index\" is a reserved column name \n$(column_names)")
        end
        matrix_dict["column_names"] = column_names
    end

    return matrix_dict
end

const single_quote_expr = r"\'((\\.|[^\'])*?)\'"

""
function split_line(mp_line::AbstractString)
    if ismatch(single_quote_expr, mp_line)
        # splits a string on white space while escaping text quoted with "'"
        # note that quotes will be stripped later, when data typing occurs

        #println(mp_line)
        tokens = []
        while length(mp_line) > 0 && ismatch(single_quote_expr, mp_line)
            #println(mp_line)
            m = match(single_quote_expr, mp_line)

            if m.offset > 1
                push!(tokens, mp_line[1:m.offset-1])
            end
            push!(tokens, replace(m.match, "\\'", "'")) # replace escaped quotes

            mp_line = mp_line[m.offset+length(m.match):end]
        end
        if length(mp_line) > 0
            push!(tokens, mp_line)
        end
        #println(tokens)

        items = []
        for token in tokens
            if contains(token, "'")
                push!(items, strip(token))
            else
                for parts in split(token)
                    push!(items, strip(parts))
                end
            end
        end
        #println(items)

        #return [strip(mp_line, '\'')]
        return items
    else
        return split(mp_line)
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

""
function extract_assignment(string::AbstractString)
    statement = split(string, ';')[1]
    value = split(statement, '=')[2]
    return strip(value)
end

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
            value = parse(Float64, value_string)
        else # otherwise assume it is an int
            value = parse(Int, value_string)
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
        [parse(Float64, value_string) for value_string in string_array]
    else # otherwise assume it is an int
        [parse(Int, value_string) for value_string in string_array]
    end
end

""
function parse_matpower_data(data_string::String)
    data_lines = split(data_string, '\n')

    version = -1
    name = -1
    baseMVA = -1

    bus = -1
    gen = -1
    branch = -1
    gencost = -1
    dcline = -1
    dclinecost = -1

    parsed_matrixes = []
    parsed_cells = []

    case = Dict{String,Any}(
        "dcline" => [],
        "gencost" => [],
        "dclinecost" => []
    )

    last_index = length(data_lines)
    index = 1
    while index <= last_index
        line = strip(data_lines[index])

        if length(line) <= 0 || strip(line)[1] == '%'
            index = index + 1
            continue
        end

        if contains(line, "function mpc")
            name = extract_assignment(line)
            case["name"] = name
        elseif contains(line, "mpc.version")
            version = extract_mpc_assignment(line)[2]
            case["version"] = version
        elseif contains(line, "mpc.baseMVA")
            baseMVA = extract_mpc_assignment(line)[2]
            case["baseMVA"] = baseMVA
        elseif contains(line, "[")
            matrix = parse_matrix(data_lines, index)
            push!(parsed_matrixes, matrix)
            index = index + matrix["line_count"]-1
        elseif contains(line, "{")
            cell = parse_cell(data_lines, index)
            push!(parsed_cells, cell)
            index = index + cell["line_count"]-1
        elseif contains(line, "mpc.")
            name, value = extract_mpc_assignment(line)
            case[name] = value
            info("extending matpower format with value named: $(name)")
        end
        index += 1
    end

    if !haskey(case, "name")
        warn(string("no case name found in matpower file.  The file seems to be missing \"function mpc = ...\""))
        case["name"] = "no_name_found"
    end

    if !haskey(case, "version")
        warn(string("no case version found in matpower file.  The file seems to be missing \"mpc.version = ...\""))
        case["version"] = "unknown"
    end

    if !haskey(case, "baseMVA")
        warn(string("no baseMVA found in matpower file.  The file seems to be missing \"mpc.baseMVA = ...\""))
        case["baseMVA"] = 1.0
    end

    for parsed_matrix in parsed_matrixes
        #println(parsed_matrix)

        if parsed_matrix["name"] == "bus"
            buses = []

            for bus_row in parsed_matrix["data"]
                bus_data = Dict{String,Any}(
                    "index" => parse(Int, bus_row[1]),
                    "bus_i" => parse(Int, bus_row[1]),
                    "bus_type" => parse(Int, bus_row[2]),
                    "pd" => parse(Float64, bus_row[3]),
                    "qd" => parse(Float64, bus_row[4]),
                    "gs" => parse(Float64, bus_row[5]),
                    "bs" => parse(Float64, bus_row[6]),
                    "area" => parse(Int, bus_row[7]),
                    "vm" => parse(Float64, bus_row[8]),
                    "va" => parse(Float64, bus_row[9]),
                    "base_kv" => parse(Float64, bus_row[10]),
                    "zone" => parse(Int, bus_row[11]),
                    "vmax" => parse(Float64, bus_row[12]),
                    "vmin" => parse(Float64, bus_row[13]),
                )
                if length(bus_row) > 13
                    bus_data["lam_p"] = parse(Float64, bus_row[14])
                    bus_data["lam_q"] = parse(Float64, bus_row[15])
                    bus_data["mu_vmax"] = parse(Float64, bus_row[16])
                    bus_data["mu_vmin"] = parse(Float64, bus_row[17])
                end

                push!(buses, bus_data)
            end

            case["bus"] = buses

        elseif parsed_matrix["name"] == "gen"
            gens = []

            for (i, gen_row) in enumerate(parsed_matrix["data"])
                gen_data = Dict{String,Any}(
                    "index" => i,
                    "gen_bus" => parse(Int, gen_row[1]),
                    "pg" => parse(Float64, gen_row[2]),
                    "qg" => parse(Float64, gen_row[3]),
                    "qmax" => parse(Float64, gen_row[4]),
                    "qmin" => parse(Float64, gen_row[5]),
                    "vg" => parse(Float64, gen_row[6]),
                    "mbase" => parse(Float64, gen_row[7]),
                    "gen_status" => parse(Int, gen_row[8]),
                    "pmax" => parse(Float64, gen_row[9]),
                    "pmin" => parse(Float64, gen_row[10]),
                    "pc1" => parse(Float64, gen_row[11]),
                    "pc2" => parse(Float64, gen_row[12]),
                    "qc1min" => parse(Float64, gen_row[13]),
                    "qc1max" => parse(Float64, gen_row[14]),
                    "qc2min" => parse(Float64, gen_row[15]),
                    "qc2max" => parse(Float64, gen_row[16]),
                    "ramp_agc" => parse(Float64, gen_row[17]),
                    "ramp_10" => parse(Float64, gen_row[18]),
                    "ramp_30" => parse(Float64, gen_row[19]),
                    "ramp_q" => parse(Float64, gen_row[20]),
                    "apf" => parse(Float64, gen_row[21]),
                )
                if length(gen_row) > 21
                    gen_data["mu_pmax"] = parse(Float64, gen_row[22])
                    gen_data["mu_pmin"] = parse(Float64, gen_row[23])
                    gen_data["mu_qmax"] = parse(Float64, gen_row[24])
                    gen_data["mu_qmin"] = parse(Float64, gen_row[25])
                end

                push!(gens, gen_data)
            end

            case["gen"] = gens

        elseif parsed_matrix["name"] == "branch"
            branches = []

            for (i, branch_row) in enumerate(parsed_matrix["data"])
                branch_data = Dict{String,Any}(
                    "index" => i,
                    "f_bus" => parse(Int, branch_row[1]),
                    "t_bus" => parse(Int, branch_row[2]),
                    "br_r" => parse(Float64, branch_row[3]),
                    "br_x" => parse(Float64, branch_row[4]),
                    "br_b" => parse(Float64, branch_row[5]),
                    "rate_a" => parse(Float64, branch_row[6]),
                    "rate_b" => parse(Float64, branch_row[7]),
                    "rate_c" => parse(Float64, branch_row[8]),
                    "tap" => parse(Float64, branch_row[9]),
                    "shift" => parse(Float64, branch_row[10]),
                    "br_status" => parse(Int, branch_row[11]),
                    "angmin" => parse(Float64, branch_row[12]),
                    "angmax" => parse(Float64, branch_row[13]),
                )
                if length(branch_row) > 13
                    branch_data["pf"] = parse(Float64, branch_row[14])
                    branch_data["qf"] = parse(Float64, branch_row[15])
                    branch_data["pt"] = parse(Float64, branch_row[16])
                    branch_data["qt"] = parse(Float64, branch_row[17])
                end
                if length(branch_row) > 17
                    branch_data["mu_sf"] = parse(Float64, branch_row[18])
                    branch_data["mu_st"] = parse(Float64, branch_row[19])
                    branch_data["mu_angmin"] = parse(Float64, branch_row[20])
                    branch_data["mu_angmax"] = parse(Float64, branch_row[21])
                end

                push!(branches, branch_data)
            end

            case["branch"] = branches

        elseif parsed_matrix["name"] == "gencost"
            gencost = []

            for (i, gencost_row) in enumerate(parsed_matrix["data"])
                gencost_data = cost_data(i, gencost_row)
                push!(gencost, gencost_data)
            end

            case["gencost"] = gencost

            if length(case["gencost"]) != length(case["gen"]) && length(case["gencost"]) != 2*length(case["gen"])
                error("incorrect Matpower file, the number of generator cost functions ($(length(case["gencost"]))) is inconsistent with the number of generators ($(length(case["gen"]))).\n")
            end

        elseif parsed_matrix["name"] == "dcline"
            dclines = []
            for (i, dcline_row) in enumerate(parsed_matrix["data"])
                pmin = parse(Float64, dcline_row[10])
                pmax = parse(Float64, dcline_row[11])
                loss0 = parse(Float64, dcline_row[16])
                loss1 = parse(Float64, dcline_row[17])

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

                dcline_data = Dict{String,Any}(
                    "index" => i,
                    "f_bus" => parse(Int, dcline_row[1]),
                    "t_bus" => parse(Int, dcline_row[2]),
                    "br_status" => parse(Int, dcline_row[3]),
                    "pf" => parse(Float64, dcline_row[4]),
                    "pt" => -parse(Float64, dcline_row[5]), # matpower has opposite convention
                    "qf" => -parse(Float64, dcline_row[6]), # matpower has opposite convention
                    "qt" => -parse(Float64, dcline_row[7]), # matpower has opposite convention
                    "vf" => parse(Float64, dcline_row[8]),
                    "vt" => parse(Float64, dcline_row[9]),
                    "pmint" => pmint,
                    "pminf" => pminf,
                    "pmaxt" => pmaxt,
                    "pmaxf" => pmaxf,
                    "qminf" => parse(Float64, dcline_row[12]),
                    "qmaxf" => parse(Float64, dcline_row[13]),
                    "qmint" => parse(Float64, dcline_row[14]),
                    "qmaxt" => parse(Float64, dcline_row[15]),
                    "loss0" => parse(Float64, dcline_row[16]),
                    "loss1" => parse(Float64, dcline_row[17]),
                )
                if length(dcline_row) > 17
                    dcline_data["mu_pmin"] = parse(Float64, dcline_row[18])
                    dcline_data["mu_pmax"] = parse(Float64, dcline_row[19])
                    dcline_data["mu_qminf"] = parse(Float64, dcline_row[20])
                    dcline_data["mu_qmaxf"] = parse(Float64, dcline_row[21])
                    dcline_data["mu_qmint"] = parse(Float64, dcline_row[22])
                    dcline_data["mu_qmaxt"] = parse(Float64, dcline_row[23])
                end
                push!(dclines, dcline_data)
            end
            case["dcline"] = dclines
        elseif parsed_matrix["name"] == "dclinecost"
            dclinecost = []

            for (i, dclinecost_row) in enumerate(parsed_matrix["data"])
                dclinecost_data = cost_data(i, dclinecost_row)
                push!(dclinecost, dclinecost_data)
            end

            case["dclinecost"] = dclinecost

            if length(case["dclinecost"]) != length(case["dcline"])
                error("incorrect Matpower file, the number of dcline cost functions ($(length(case["dclinecost"]))) is inconsistent with the number of dclines ($(length(case["dcline"]))).\n")
            end
        else
            name = parsed_matrix["name"]
            data = parsed_matrix["data"]

            column_names = ["col_$(c)" for c in 1:length(data[1])]
            if haskey(parsed_matrix, "column_names")
                column_names = parsed_matrix["column_names"]
            end

            typed_dict_data = build_typed_dict(data, column_names)

            extend_case_data(case, name, typed_dict_data, haskey(parsed_matrix, "column_names"))
        end
    end

    for parsed_cell in parsed_cells
        #println(parsed_cell)
        if parsed_cell["name"] == "bus_name"
            if length(parsed_cell["data"]) != length(case["bus"])
                error("incorrect Matpower file, the number of bus names ($(length(parsed_cell["data"]))) is inconsistent with the number of buses ($(length(case["bus"]))).\n")
            end

            typed_dict_data = build_typed_dict(parsed_cell["data"], ["bus_name"])
            case["bus_name"] = typed_dict_data
        else
            name = parsed_cell["name"]
            data = parsed_cell["data"]

            column_names = ["col_$(c)" for c in 1:length(data[1])]
            if haskey(parsed_cell, "column_names")
                column_names = parsed_cell["column_names"]
            end

            typed_dict_data = build_typed_dict(data, column_names)

            extend_case_data(case, name, typed_dict_data, haskey(parsed_cell, "column_names"))
        end
    end

    #println("Case:")
    #println(case)

    return case
end


function cost_data(index, costrow)
    cost_data = Dict{String,Any}(
        "index" => index,
        "model" => parse(Int, costrow[1]),
        "startup" => parse(Float64, costrow[2]),
        "shutdown" => parse(Float64, costrow[3]),
        "ncost" => parse(Int, costrow[4]),
        "cost" => [parse(Float64, x) for x in costrow[5:length(costrow)]]
    )
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
converts arrays of objects into a dicts with lookup by "index"
"""
function mp_data_to_pm_data(mp_data)
    for (k,v) in mp_data
        if isa(v, Array)
            #println("updating $(k)")
            dict = Dict{String,Any}()
            for item in v
                assert("index" in keys(item))
                dict[string(item["index"])] = item
            end
            mp_data[k] = dict
        end
    end
end
