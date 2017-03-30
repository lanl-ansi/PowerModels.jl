function parse_json(file_string)
    data_string = readstring(open(file_string))
    return JSON.parse(data_string)
end
