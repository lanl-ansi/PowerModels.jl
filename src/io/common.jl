"""
    parse_file(file; import_all)

Parses a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a
PowerModels data structure. All fields from PTI files will be imported if
`import_all` is true (Default: false).
"""
function parse_file(file::String; import_all=false, validate=true)
    pm_data = open(file) do io
        pm_data = parse_file(io; import_all=import_all, validate=validate, filetype=split(lowercase(file), '.')[end])
    end
    return pm_data
end


"Parses the iostream from a file"
function parse_file(io::IO; import_all=false, validate=true, filetype="json")
    if filetype == "m"
        pm_data = PowerModels.parse_matpower(io, validate=validate)
    elseif filetype == "raw"
        pm_data = PowerModels.parse_psse(io; import_all=import_all, validate=validate)
    elseif filetype == "json"
        pm_data = PowerModels.parse_json(io; validate=validate)
    else
        Memento.error(_LOGGER, "Unrecognized filetype: \".$filetype\", Supported extensions are \".raw\", \".m\" and \".json\"")
    end

    return pm_data
end


"""
Make a PM multinetwork data structure of the given filenames
"""
function parse_files(filenames::String...)
    mn_data = Dict{String, Any}(
        "nw" => Dict{String, Any}(),
        "per_unit" => true,
        "multinetwork" => true,
    )

    names = Array{String, 1}()

    for (i, filename) in enumerate(filenames)
        data = PowerModels.parse_file(filename)

        delete!(data, "multinetwork")
        delete!(data, "per_unit")

        mn_data["nw"]["$i"] = data
        push!(names, "$(data["name"])")
    end

    mn_data["name"] = join(names, " + ")

    return mn_data
end


"""
    export_file(file, data)

Export a PowerModels data structure to the file according of the extension:
    - `.m` : Matpower
    - `.raw` : PTI (PSS(R)E-v33)
    - `.json` : JSON 
"""
function export_file(file::AbstractString, data::Dict{String, Any})
    if occursin(".", file) 
        open(file, "w") do io
            export_file(io, data, filetype=split(lowercase(file), '.')[end])
        end
    else
        Memento.error(_LOGGER, "The file must have an extension")
    end
end


function export_file(io::IO, data::Dict{String, Any}; filetype="json")
    if filetype == "m"
        PowerModels.export_matpower(io, data)
    elseif filetype == "raw"
        PowerModels.export_pti(io, data)
    elseif filetype == "json"
        stringdata = JSON.json(data)
        write(io, stringdata)
    else
        Memento.error(_LOGGER, "Unrecognized filetype: \".$filetype\", Supported extensions are \".raw\", \".m\" and \".json\"")
    end
end


"""
Runs various data quality checks on a PowerModels data dictionary.
Applies modifications in some cases.  Reports modified component ids.
"""
function correct_network_data!(data::Dict{String,<:Any})
    mod_bus = Dict{Symbol,Set{Int}}()
    mod_gen = Dict{Symbol,Set{Int}}()
    mod_branch = Dict{Symbol,Set{Int}}()
    mod_dcline = Dict{Symbol,Set{Int}}()

    check_conductors(data)
    check_connectivity(data)
    check_status(data)
    check_reference_bus(data)

    make_per_unit!(data)

    mod_branch[:xfer_fix] = correct_transformer_parameters!(data)
    mod_branch[:vad_bounds] = correct_voltage_angle_differences!(data)
    mod_branch[:mva_zero] = correct_thermal_limits!(data)
    mod_branch[:ma_zero] = correct_current_limits!(data)
    mod_branch[:orientation] = correct_branch_directions!(data)
    check_branch_loops(data)

    mod_dcline[:losses] = correct_dcline_limits!(data)

    if length(data["gen"]) > 0 && any(gen["gen_status"] != 0 for (i,gen) in data["gen"])
        mod_bus[:type] = correct_bus_types!(data)
    end
    check_voltage_setpoints(data)

    check_storage_parameters(data)
    check_switch_parameters(data)

    gen, dcline = correct_cost_functions!(data)
    mod_gen[:cost_pwl] = gen
    mod_dcline[:cost_pwl] = dcline

    simplify_cost_terms!(data)

    return Dict(
        "bus" => mod_bus,
        "gen" => mod_gen,
        "branch" => mod_branch,
        "dcline" => mod_dcline
    )
end
