#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matpower data files #
#                                                                       #
#########################################################################

export parse_matpower


function parse_matrix(lines, index)
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
    found_close_bracket = contains(matrix_assignment_rhs, "]")

    while index + line_count < last_index && !found_close_bracket 
        line = strip(lines[index+line_count])

        if length(line) == 0 || line[1] == '%'
            line_count += 1
            continue
        end

        line = split(line, '%')[1]

        if contains(line, "]")
            found_close_bracket = true
        end

        if contains(line, ";")
            push!(matrix_body_lines, strip(split(line, '%')[1]))
        end

        line_count = line_count + 1
    end

    matrix_body = join(matrix_body_lines, ' ')
    matrix_body = strip(replace(strip(strip(matrix_body), '['), "];", ""))
    matrix_body_rows = split(matrix_body, ';')
    matrix_body_rows = matrix_body_rows[1:(length(matrix_body_rows)-1)]

    maxtrix = []
    for row in matrix_body_rows
        row_items = split(row, '\t')
        push!(maxtrix, row_items)
        if columns < 0
            columns = length(row_items)
        elseif columns != length(row_items)
            error("matrix parsing error, inconsistent number of items in each row\n"+row)
        end
    end

    return Dict("name" => matrix_name, "data" => maxtrix, "line_count" => line_count)
end


function extract_assignment(string)
    statement = split(string, ';')[1]
    value = split(statement, '=')[2]
    return strip(value)
end


function parse_matpower(data_string)

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
        elseif contains(line, "mpc.version")
            version = extract_assignment(line)
        elseif contains(line, "mpc.baseMVA")
            baseMVA = parse(Float64, extract_assignment(line))
        elseif contains(line, "[")
            matrix = parse_matrix(data_lines, index)
            push!(parsed_matrixes, matrix)
            index = index + matrix["line_count"]-1
        end
        index += 1
    end

    case = Dict{AbstractString,Any}(
        "name" => name, 
        "version" => version, 
        "baseMVA" => baseMVA,
        "dcline" => [], 
        "gencost" => []
    )

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
                    branch_data["pf"] = parse(Float64, gen_row[14])
                    branch_data["qf"] = parse(Float64, gen_row[15])
                    branch_data["pt"] = parse(Float64, gen_row[16])
                    branch_data["qt"] = parse(Float64, gen_row[17])
                    branch_data["mu_sf"] = parse(Float64, gen_row[18])
                    branch_data["mu_st"] = parse(Float64, gen_row[19])
                    branch_data["mu_angmin"] = parse(Float64, gen_row[20])
                    branch_data["mu_angmax"] = parse(Float64, gen_row[21])
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
            println(parsed_matrix["name"])
            warn(string("unrecognized data matrix named \"", parsed_matrix["name"], "\" data was ignored."))
        end

    end

    #println("Case:")
    #println(case)

    return case
end


