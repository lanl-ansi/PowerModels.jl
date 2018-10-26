"""
    parse_file(file; import_all)

Parses a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a
PowerModels data structure. All fields from PTI files will be imported if
`import_all` is true (Default: false).
"""
function parse_file(file::String; import_all=false)
    try
        if endswith(file, ".m")
            pm_data = PowerModels.parse_matpower(file)
        elseif endswith(lowercase(file), ".raw")
            info(LOGGER, "The PSS(R)E parser currently supports buses, loads, shunts, generators, branches, transformers, and dc lines")
            pm_data = PowerModels.parse_psse(file; import_all=import_all)
        else
            pm_data = parse_json(file)
        end

        return pm_data
    catch e
        if isa(e, UnicodeError)
            error(LOGGER, "UnicodeError: PowerModels can only load UTF-8 or ASCII encoded files, re-encode \"$file\" to supported encoding")
        end
    end
end


"Adds PowerModels version to native data structure"
function add_powermodels_version(data::Dict{String,Any})
    data["version"] = Pkg.installed("PowerModels")
end


""
function parse_json(file_string::String)
    open(file_string) do f
        parse_json(f)
    end
end


""
function parse_json(io::IO)
    data_string = readstring(io)
    pm_data = JSON.parse(data_string)
    check_network_data(pm_data)
    return pm_data
end


""
function check_network_data(data::Dict{String,Any})
    add_powermodels_version(data)
    check_conductors(data)
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
    check_storage_parameters(data)
end


