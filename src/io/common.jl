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
    for (i,network_data) in data
        make_per_unit(network_data)
        check_transformer_parameters(network_data)
        check_phase_angle_differences(network_data)
        check_thermal_limits(network_data)
        check_bus_types(network_data)
        check_dcline_limits(network_data)
    end
end
