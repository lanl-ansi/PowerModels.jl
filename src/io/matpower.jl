#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################


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
    matrix_assignment_parts = split(matrix_assignment, '=')
    matrix_name = strip(matrix_assignment_parts[1])

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

    maxtrix = []
    for row in matrix_body_rows
        row_items = split_line(strip(row))
        #println(row_items)
        push!(maxtrix, row_items)
        if columns < 0
            columns = length(row_items)
        elseif columns != length(row_items)
            error("matrix parsing error, inconsistent number of items in each row\n$(row)")
        end
    end

    return Dict("name" => matrix_name, "data" => maxtrix, "line_count" => line_count)
end

function split_line(mp_line)
    if contains(mp_line, "'")
        # TODO fix this so that it will split a string escaping single quoted strings
        return [strip(mp_line, '\'')]
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
    value = strip(value)
    
    if contains(value, "'") # value is a string
        value = strip(value, '\'')
    else
        # if value is a float
        if contains(value, ".") || contains(value, "e")
            value = parse(Float64, value)
        else # otherwise assume it is an int
            value = parse(Int, value)
        end
    end

    return (name, value)
end


function parse_matpower(file_string)
    data_string = readstring(open(file_string))
    data = parse_matpower_data(data_string)

    for branch in data["branch"]
        if branch["angmin"] <= -90
            warn("this code only supports angmin values in -89 deg. to 89 deg., tightening the value on branch $(branch["index"]) from $(branch["angmin"]) to -60 deg.")
            branch["angmin"] = -60.0
        end
        if branch["angmax"] >= 90
            warn("this code only supports angmax values in -89 deg. to 89 deg., tightening the value on branch $(branch["index"]) from $(branch["angmax"]) to 60 deg.")
            branch["angmax"] = 60.0
        end
        if branch["angmin"] == 0.0 && branch["angmax"] == 0.0
            warn("angmin and angmax values are 0, widening these values on branch $(branch["index"]) to +/- 60 deg.")
            branch["angmin"] = -60.0
            branch["angmax"] = 60.0
        end
    end

    mva_base = data["baseMVA"]
    vmax_lookup = Dict([(bus["index"], bus["vmax"]) for bus in data["bus"]])
    vmin_lookup = Dict([(bus["index"], bus["vmin"]) for bus in data["bus"]])

    for branch in data["branch"]
        if branch["rate_a"] <= 0.0
            theta_max = max(abs(branch["angmin"]), abs(branch["angmax"]))

            r = branch["br_r"]
            x = branch["br_x"]
            g =  r / (r^2 + x^2)
            b = -x / (r^2 + x^2)

            y_mag = sqrt(g^2 + b^2)

            fr_vmax = vmax_lookup[branch["f_bus"]]
            to_vmax = vmax_lookup[branch["f_bus"]]
            m_vmax = max(fr_vmax, to_vmax)

            c_max = sqrt(fr_vmax^2 + to_vmax^2 - 2*fr_vmax*to_vmax*cos(deg2rad(theta_max)))

            new_rate = mva_base*y_mag*m_vmax*c_max

            warn("this code only supports positive rate_a values, changing the value on branch $(branch["index"]) from $(branch["rate_a"]) to $(new_rate)")
            branch["rate_a"] = new_rate
        end
    end

    return data
end


function parse_matpower_data(data_string)

    data_lines = split(data_string, '\n')
    #println(data_lines)

    #data_lines = filter(line -> !(length(strip(line)) <= 0 || strip(line)[1] == '%'), data_lines)
    #data_lines = filter(line -> !(strip(line)[1] == '%'), data_lines)
    #for line in data_lines
        #println(line)
    #end

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
            info("extending matpower format with constant value: $(name)")
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

        if parsed_matrix["name"] == "mpc.bus"
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

                bus_data["bus_name"] = "Bus $(bus_data["bus_i"])"
                push!(buses, bus_data)
            end

            case["bus"] = buses

        elseif parsed_matrix["name"] == "mpc.gen"
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

        elseif parsed_matrix["name"] == "mpc.branch"
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

        elseif parsed_matrix["name"] == "mpc.gencost"
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

        elseif parsed_matrix["name"] == "mpc.dcline"
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
            #println(parsed_matrix["name"])
            warn(string("unrecognized data matrix named \"", parsed_matrix["name"], "\" data was ignored."))
        end
    end


    for parsed_cell in parsed_cells
        #println(parsed_cell)
        if parsed_cell["name"] == "mpc.bus_name" 

            if length(parsed_cell["data"]) != length(case["bus"])
                error("incorrect Matpower file, the number of bus names ($(length(parsed_cell["data"]))) is inconsistent with the number of buses ($(length(case["bus"]))).\n")
            end

            for (i, bus) in enumerate(case["bus"])
                bus["bus_name"] = parsed_cell["data"][i][1]
                #println(bus["bus_name"])
            end
        else
            #println(parsed_cell["name"])
            warn(string("unrecognized data cell array named \"", parsed_cell["name"], "\" data was ignored."))
        end

    end

    #println("Case:")
    #println(case)

    return case
end
