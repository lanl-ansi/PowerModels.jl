#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################

function parse_matpower(file_string)
    data_string = readstring(open(file_string))
    mp_data = parse_matpower_data(data_string)

    standardize_cost_order(mp_data)

    # TODO make this work on PowerModels data, not MatPower Data, move to data.jl
    make_per_unit(mp_data)

    merge_bus_name_data(mp_data)
    merge_generator_cost_data(mp_data)

    # after this call, Matpower data is consistent with PowerModels data
    mp_data_to_pm_data(mp_data)

    check_phase_angle_differences(mp_data)
    check_thermal_limits(mp_data)
    check_bus_types(mp_data)

    unify_transformer_taps(mp_data)

    return mp_data
end


# checks that phase angle differences are within 90 deg., if not tightens
function check_phase_angle_differences(data, default_pad = 1.0472)
    assert("per_unit" in keys(data) && data["per_unit"])

    for (i, branch) in data["branch"]
        if branch["angmin"] <= -pi/2
            warn("this code only supports angmin values in -90 deg. to 90 deg., tightening the value on branch $(branch["index"]) from $(rad2deg(branch["angmin"])) to -$(rad2deg(default_pad)) deg.")
            branch["angmin"] = -default_pad
        end
        if branch["angmax"] >= pi/2
            warn("this code only supports angmax values in -90 deg. to 90 deg., tightening the value on branch $(branch["index"]) from $(rad2deg(branch["angmax"])) to $(rad2deg(default_pad)) deg.")
            branch["angmax"] = default_pad
        end
        if branch["angmin"] == 0.0 && branch["angmax"] == 0.0
            warn("angmin and angmax values are 0, widening these values on branch $(branch["index"]) to +/- $(rad2deg(default_pad)) deg.")
            branch["angmin"] = -rad2deg(default_pad)
            branch["angmax"] = rad2deg(default_pad)
        end
    end
end


# checks that each line has a reasonable line thermal rating, if not computes one
function check_thermal_limits(data)
    assert("per_unit" in keys(data) && data["per_unit"])
    mva_base = data["baseMVA"]

    for (i, branch) in data["branch"]
        if branch["rate_a"] <= 0.0
            theta_max = max(abs(branch["angmin"]), abs(branch["angmax"]))

            r = branch["br_r"]
            x = branch["br_x"]
            g =  r / (r^2 + x^2)
            b = -x / (r^2 + x^2)

            y_mag = sqrt(g^2 + b^2)

            fr_vmax = data["bus"][string(branch["f_bus"])]["vmax"]
            to_vmax = data["bus"][string(branch["t_bus"])]["vmax"]
            m_vmax = max(fr_vmax, to_vmax)

            c_max = sqrt(fr_vmax^2 + to_vmax^2 - 2*fr_vmax*to_vmax*cos(theta_max))

            new_rate = y_mag*m_vmax*c_max

            warn("this code only supports positive rate_a values, changing the value on branch $(branch["index"]) from $(mva_base*branch["rate_a"]) to $(mva_base*new_rate)")
            branch["rate_a"] = new_rate
        end
    end
end


# checks bus types are consistent with generator connections, if not, fixes them
function check_bus_types(data)
    bus_gens = Dict([(i, []) for (i,bus) in data["bus"]])

    for (i,gen) in data["gen"]
        #println(gen)
        if gen["gen_status"] == 1
            push!(bus_gens[string(gen["gen_bus"])], i)
        end
    end

    for (i, bus) in data["bus"]
        if bus["bus_type"] != 4 && bus["bus_type"] != 3
            bus_gens_count = length(bus_gens[i])

            if bus_gens_count == 0 && bus["bus_type"] != 1
                warn("no active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 1")
                bus["bus_type"] = 1
            end

            if bus_gens_count != 0 && bus["bus_type"] != 2
                warn("active generators found at bus $(bus["bus_i"]), updating to bus type from $(bus["bus_type"]) to 2")
                bus["bus_type"] = 2
            end

        end
    end

end


# ensures all costs functions are quadratic and reverses their order
function standardize_cost_order(data::Dict{AbstractString,Any})
    for gencost in data["gencost"]
        if gencost["model"] == 2 && length(gencost["cost"]) < 3
            #println("std gen cost: ",gencost["cost"])
            cost_3 = [zeros(1,3 - length(gencost["cost"])); gencost["cost"]]
            gencost["cost"] = cost_3
            #println("   ",gencost["cost"])
            warn("added zeros to make generator cost ($(gencost["index"])) a quadratic function: $(cost_3)")
        end
    end
end


# sets all line transformer taps to 1.0, to simplify line models
function unify_transformer_taps(data::Dict{AbstractString,Any})
    branches = [branch for branch in values(data["branch"])]
    if haskey(data, "ne_branch")
        append!(branches, values(data["ne_branch"]))
    end
    for branch in branches
        if branch["tap"] == 0.0
            branch["tap"] = 1.0
        end
    end
end


### Recursive Per Unit Computation ###

not_pu = Set(["rate_a","rate_b","rate_c","bs","gs","pd","qd","pg","qg","pmax","pmin","qmax","qmin"])
not_rad = Set(["angmax","angmin","shift","va"])

function make_per_unit(data::Dict{AbstractString,Any})
    if !haskey(data, "per_unit") || data["per_unit"] == false
        make_per_unit(data["baseMVA"], data)
        data["per_unit"] = true
    end
end

function make_per_unit(mva_base::Number, data::Dict{AbstractString,Any})
    for k in keys(data)
        if k == "gencost"
            for cost_model in data[k]
                if cost_model["model"] != 2
                    warn("Skipping generator cost model of type other than 2")
                    continue
                end
                degree = length(cost_model["cost"])
                for (i, item) in enumerate(cost_model["cost"])
                    cost_model["cost"][i] = item*mva_base^(degree-i)
                end
            end
        elseif isa(data[k], Number)
            if k in not_pu
                data[k] = data[k]/mva_base
            end
            if k in not_rad
                data[k] = pi*data[k]/180.0
            end
            #println("$(k) $(data[k])")
        else
            make_per_unit(mva_base, data[k])
        end
    end
end

function make_per_unit(mva_base::Number, data::Array{Any,1})
    for item in data
        make_per_unit(mva_base, item)
    end
end

function make_per_unit(mva_base::Number, data::AbstractString)
    #nothing to do
end

function make_per_unit(mva_base::Number, data::Number)
    #nothing to do
end

# merges generator cost functions into generator data, if costs exist
function merge_generator_cost_data(data::Dict{AbstractString,Any})
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
end

# merges bus name data into buses, if names exist
function merge_bus_name_data(data::Dict{AbstractString,Any})
    if haskey(data, "bus_name")
        # can assume same length is same as bus
        # this is validated during parsing
        for (i, bus_name) in enumerate(data["bus_name"])
            bus = data["bus"][i]
            assert(bus["index"] == bus_name["index"])
            delete!(bus_name, "index")

            check_keys(bus, keys(bus_name))
            merge!(bus, bus_name)
        end
        delete!(data, "bus_name")
    end
end


function parse_cell(lines, index)
    return parse_matlab_data(lines, index, '{', '}')
end

function parse_matrix(lines, index)
    return parse_matlab_data(lines, index, '[', ']')
end

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


single_quote_expr = r"\'((\\.|[^\'])*?)\'"

function split_line(mp_line)
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

function add_line_delimiter(mp_line, start_char, end_char)
    if strip(mp_line) == string(start_char)
        return mp_line
    end

    if ! contains(mp_line, ";") && ! contains(mp_line, string(end_char))
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


function extract_assignment(string)
    statement = split(string, ';')[1]
    value = split(statement, '=')[2]
    return strip(value)
end

function extract_mpc_assignment(string)
    assert(contains(string, "mpc."))
    statement = split(string, ';')[1]
    statement = replace(statement, "mpc.", "")
    name, value = split(statement, '=')
    name = strip(name)
    value = type_value(strip(value))

    return (name, value)
end


# Attempts to determine the type of a string extracted from a matlab file
function type_value(value_string)
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

# Attempts to determine the type of an array of strings extracted from a matlab file
function type_array(string_array)
    value_string = [strip(value_string) for value_string in string_array]

    if any([contains(value_string, "'") for value_string in string_array])
        value_array = [strip(value_string, '\'') for value_string in string_array]
    else
        if any([contains(value_string, ".") || contains(value_string, "e") for value_string in string_array])
            value_array = [parse(Float64, value_string) for value_string in string_array]
        else # otherwise assume it is an int
            value_array = [parse(Int, value_string) for value_string in string_array]
        end
    end

    return value_array
end



function parse_matpower_data(data_string)
    data_lines = split(data_string, '\n')

    version = -1
    name = -1
    baseMVA = -1

    bus = -1
    gen = -1
    branch = -1
    gencost = -1
    dcline = -1

    parsed_matrixes = []
    parsed_cells = []

    case = Dict{AbstractString,Any}(
        "dcline" => [],
        "gencost" => []
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
                bus_data = Dict{AbstractString,Any}(
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
                gen_data = Dict{AbstractString,Any}(
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
                branch_data = Dict{AbstractString,Any}(
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
                gencost_data = Dict{AbstractString,Any}(
                    "index" => i,
                    "model" => parse(Int, gencost_row[1]),
                    "startup" => parse(Float64, gencost_row[2]),
                    "shutdown" => parse(Float64, gencost_row[3]),
                    "ncost" => parse(Int, gencost_row[4]),
                    "cost" => [parse(Float64, x) for x in gencost_row[5:length(gencost_row)]]
                )
                push!(gencost, gencost_data)
            end

            case["gencost"] = gencost

            if length(case["gencost"]) != length(case["gen"]) && length(case["gencost"]) != 2*length(case["gen"])
                error("incorrect Matpower file, the number of generator cost functions ($(length(case["gencost"]))) is inconsistent with the number of generators ($(length(case["gen"]))).\n")
            end

        elseif parsed_matrix["name"] == "dcline"
            dclines = []

            for (i, dcline_row) in enumerate(parsed_matrix["data"])
                dcline_data = Dict{AbstractString,Any}(
                    "index" => i,
                    "f_bus" => parse(Int, dcline_row[1]),
                    "t_bus" => parse(Int, dcline_row[2]),
                    "br_status" => parse(Int, dcline_row[3]),
                    "pf" => parse(Float64, dcline_row[4]),
                    "pt" => parse(Float64, dcline_row[5]),
                    "qf" => parse(Float64, dcline_row[6]),
                    "qt" => parse(Float64, dcline_row[7]),
                    "vf" => parse(Float64, dcline_row[8]),
                    "vt" => parse(Float64, dcline_row[9]),
                    "pmin" => parse(Float64, dcline_row[10]),
                    "pmax" => parse(Float64, dcline_row[11]),
                    "qminf" => parse(Float64, dcline_row[12]),
                    "qmaxf" => parse(Float64, dcline_row[13]),
                    "qmint" => parse(Float64, dcline_row[14]),
                    "qmaxt" => parse(Float64, dcline_row[15]),
                    "loss0" => parse(Float64, dcline_row[16]),
                    "loss1" => parse(Float64, dcline_row[17]),
                )
                if length(dcline_row) > 17
                    branch_data["mu_pmin"] = parse(Float64, dcline_row[18])
                    branch_data["mu_pmax"] = parse(Float64, dcline_row[19])
                    branch_data["mu_qminf"] = parse(Float64, dcline_row[20])
                    branch_data["mu_qmaxf"] = parse(Float64, dcline_row[21])
                    branch_data["mu_qmint"] = parse(Float64, dcline_row[22])
                    branch_data["mu_qmaxt"] = parse(Float64, dcline_row[23])
                end

                push!(dclines, dcline_data)
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

            #for (i, bus) in enumerate(case["bus"])
            #    # note striping the single quotes is not necessary in general, column typing takes care of this
            #    bus["bus_name"] = strip(parsed_cell["data"][i][1], '\'')
            #    #println(bus["bus_name"])
            #end

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


# takes a list of list of strings and turns it into a list of typed dictionaries
function build_typed_dict(data, column_names)
    # TODO see if there is a more julia-y way of doing this
    rows = length(data)
    columns = length(data[1])

    typed_columns = []
    for c in 1:columns
        column = [ data[r][c] for r in 1:rows ]
        #println(column)
        typed_column = type_array(column)
        #println(typed_column)
        push!(typed_columns, typed_column)
    end

    typed_data = []
    for r in 1:rows
        data_dict = Dict{AbstractString,Any}()
        data_dict["index"] = r
        for c in 1:columns
            data_dict[column_names[c]] = typed_columns[c][r]
        end
        push!(typed_data, data_dict)
    end
    #println(typed_data)

    return typed_data
end

# extends a give case data with typed dictionary data
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
            assert(row["index"] == merge_row["index"])
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


# converts arrays of objects into a dicts with lookup by "index"
function mp_data_to_pm_data(mp_data)
    for (k,v) in mp_data
        if isa(v, Array)
            #println("updating $(k)")
            dict = Dict{AbstractString,Any}()
            for item in v
                assert("index" in keys(item))
                dict[string(item["index"])] = item
            end
            mp_data[k] = dict
        end
    end
end



