export parse_file

function parse_file(file)
    # TODO see if this can be made cleaner
    str_len = length(file)
    if (file[str_len-1:str_len] == ".m")
        return parse_matpower(file)
    else
        return parse_json(file)
    end
end