""
function parse_file(file::String)
    if endswith(file, ".m")
        pm_data = PowerModels.parse_matpower(file)
    elseif endswith(lowercase(file), ".raw")
        warn(LOGGER, "This feature is incomplete, and will currently only return RAW data from a PTI file")
        pm_data = PowerModels.parse_pti(file)
    else
        pm_data = parse_json(file)
    end

    check_network_data(pm_data)

    return pm_data
end

""
function check_network_data(data::Dict{String,Any})
    make_per_unit(data)
    check_connectivity(data)
    check_transformer_parameters(data)
    check_voltage_angle_differences(data)
    check_thermal_limits(data)
    check_branch_directions(data)
    check_branch_loops(data)
    check_bus_types(data)
    check_dcline_limits(data)
    check_voltage_setpoints(data)
    check_cost_functions(data)
end
