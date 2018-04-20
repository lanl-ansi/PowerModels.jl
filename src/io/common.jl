"""
    parse_file(file)

Parses a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a
PowerModels data structure.
"""
function parse_file(file::String)
    if endswith(file, ".m")
        pm_data = PowerModels.parse_matpower(file)
    elseif endswith(lowercase(file), ".raw")
        warn(LOGGER, "The PSS(R)E parser is partially implimented, and currently only supports buses, loads, shunts, generators, branches, and transformers (two- and three-winding, without magnetizing admittance)")
        pm_data = PowerModels.parse_psse(file)
    else
        pm_data = parse_json(file)
    end

    check_network_data(pm_data)

    return pm_data
end


"Adds PowerModels version to native data structure"
function add_powermodels_version(data::Dict{String,Any})
    data["version"] = Pkg.installed("PowerModels")
end


""
function parse_json(file_string::String)
    data_string = readstring(open(file_string))
    return JSON.parse(data_string)
end

""
function check_network_data(data::Dict{String,Any})
    add_powermodels_version(data)
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
