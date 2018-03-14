#########################################################################
#                                                                       #
# This file provides functions for interfacing with Matlab .m files     #
#                                                                       #
#########################################################################

# this could benefit from a much more robust parser

function parse_matlab_file(file_string::String; kwargs...)
    data_string = readstring(open(file_string))
    return parse_matlab_string(data_string; kwargs...)
end

function parse_matlab_string(data_string::String; extended=false)
    data_lines = split(data_string, '\n')

    matlab_dict = Dict{String,Any}()
    function_name = nothing
    column_names = Dict{String,Any}()

    last_index = length(data_lines)
    index = 1
    while index <= last_index
        line = strip(data_lines[index])
        line = "$(line)"

        if length(line) <= 0 || strip(line)[1] == '%'
            index = index + 1
            continue
        end

        if contains(line, "function")
            name, value = extract_matlab_assignment(line)
            function_name = value
        elseif contains(line, "=")
            if contains(line, "[")
                matrix_dict = parse_matlab_matrix(data_lines, index)
                matlab_dict[matrix_dict["name"]] = matrix_dict["data"]
                if haskey(matrix_dict, "column_names")
                    column_names[matrix_dict["name"]] = matrix_dict["column_names"]
                end
                index = index + matrix_dict["line_count"]-1
            elseif contains(line, "{")
                cell_dict = parse_matlab_cells(data_lines, index)
                matlab_dict[cell_dict["name"]] = cell_dict["data"]
                if haskey(cell_dict, "column_names")
                    column_names[cell_dict["name"]] = cell_dict["column_names"]
                end
                index = index + cell_dict["line_count"]-1
            else
                name, value = extract_matlab_assignment(line)
                value = type_value(value)
                matlab_dict[name] = value
            end
        else
            warn(LOGGER, "Matlab parser skipping the following line:\n  $(line)")
        end

        index += 1
    end

    if extended
        return matlab_dict, function_name, column_names
    else
        return matlab_dict
    end
end


"breaks up matlab strings of the form 'name = value;'"
function extract_matlab_assignment(string::AbstractString)
    statement = split(string, ';')[1]
    statement_parts = split(statement, '=')
    assert(length(statement_parts) == 2)
    name = strip(statement_parts[1])
    value = strip(statement_parts[2])
    return name, value
end


"Attempts to determine the type of a string extracted from a matlab file"
function type_value(value_string::AbstractString)
    value_string = strip(value_string)

    if contains(value_string, "'") # value is a string
        value = strip(value_string, '\'')
    else
        # if value is a float
        if contains(value_string, ".") || contains(value_string, "e")
            value = check_type(Float64, value_string)
        else # otherwise assume it is an int
            value = check_type(Int, value_string)
        end
    end

    return value
end

"Attempts to determine the type of an array of strings extracted from a matlab file"
function type_array(string_array::Vector{T}) where T <: AbstractString
    value_string = [strip(value_string) for value_string in string_array]

    return if any(contains(value_string, "'") for value_string in string_array)
        [strip(value_string, '\'') for value_string in string_array]
    elseif any(contains(value_string, ".") || contains(value_string, "e") for value_string in string_array)
        [check_type(Float64, value_string) for value_string in string_array]
    else # otherwise assume it is an int
        [check_type(Int, value_string) for value_string in string_array]
    end
end


""
parse_matlab_cells(lines, index) = parse_matlab_data(lines, index, '{', '}')

""
parse_matlab_matrix(lines, index) = parse_matlab_data(lines, index, '[', ']')

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

    rows = length(matrix)
    typed_columns = [type_array([ matrix[r][c] for r in 1:rows ]) for c in 1:columns]
    for r in 1:rows
        matrix[r] = [typed_columns[c][r] for c in 1:columns]
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



"Checks if the given value is of a given type, if not tries to make it that type"
function check_type(typ, value)
    if isa(value, typ)
        return value
    elseif isa(value, String) || isa(value, SubString)
        try
            value = parse(typ, value)
            return value
        catch e
            error("parsing error, the matlab string \"$(value)\" can not be parsed to $(typ) data")
            rethrow(e)
        end
    else
        try
            value = typ(value)
            return value
        catch e
            error("parsing error, the matlab value $(value) of type $(typeof(value)) can not be parsed to $(typ) data")
            rethrow(e)
        end
    end
end



