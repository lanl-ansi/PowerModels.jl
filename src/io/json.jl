
function parse_json(file_string)
    data_string = readall(open(file_string))
    return JSON.parse(data_string, dicttype = Dict{AbstractString,Any})
end