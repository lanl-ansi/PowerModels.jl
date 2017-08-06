""
function parse_file(file::String)
    if endswith(file, ".m")
        data = PowerModels.parse_matpower(file)
    else
        data = PowerModels.parse_json(file)
    end

    check_network_data(data)

    return data
end

""
function check_network_data(data::Dict{String,Any})
    for (n,nw_data) in data["nw"]
        make_network_per_unit(nw_data)
        check_transformer_parameters(nw_data)
        check_phase_angle_differences(nw_data)
        check_thermal_limits(nw_data)
        check_bus_types(nw_data)
        check_dcline_limits(nw_data)
    end
end
