function parse_file(file)
    if endswith(file, ".m")
        return PowerModels.parse_matpower(file)
    else
        return PowerModels.parse_json(file)
    end
end