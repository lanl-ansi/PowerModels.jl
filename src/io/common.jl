function parse_file(file)
    if endswith(file, ".m")
        pm_data = PowerModels.parse_matpower(file)
    else
        pm_data = PowerModels.parse_json(file)
    end

    check_network_data(pm_data)

    return pm_data
end

function check_network_data(data::Dict{String,Any})
    make_per_unit(data)
    check_transformer_parameters(data)
    check_phase_angle_differences(data)
    check_thermal_limits(data)
    check_bus_types(data)
end 