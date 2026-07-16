"""
    parse_file(io::String; import_all=false, validate=true)
    parse_file(io::IO; import_all=false, validate=true, filetype="json")

Parse a file into a PowerModels data structure.

The supported file types are:

 * `.m`: a Matpower file
 * `.raw`: a PTI (PSS(R)E-v33)
 * `.json`: a PowerModels.jl JSON file

All fields from PTI files will be imported if `import_all` is true.

If `validate = true`, PowerModels will validate the imported data for correctness.
"""
function parse_file(io::Union{IO,String}; import_all=false, validate=true, filetype="json")
    if io isa String
        filetype=lowercase(last(split(io, '.')))
    end
    if filetype == "m"
        return PowerModels.parse_matpower(io; validate)
    elseif filetype == "raw"
        return PowerModels.parse_psse(io; import_all, validate)
    elseif filetype == "json"
        return PowerModels.parse_json(io; validate)
    else
        @_error("Unrecognized filetype: \".$filetype\", Supported extensions are \".raw\", \".m\" and \".json\"")
    end
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
        @_error("The file must have an extension")
    end
end


function export_file(io::IO, data::Dict{String, Any}; filetype="json")
    if filetype == "m"
        PowerModels.export_matpower(io, data)
    elseif filetype == "raw"
        PowerModels.export_pti(io, data)
    elseif filetype == "json"
        # This call reverts the writing behavior of JSON@1 to the pre-1.0
        # behavior of `Inf => null` and so on. The new default in JSON@1 is to
        # error (if allownan is not set), and to print `Inf => "Infinity"` if
        # `inf` is not set. Ditto for `ninf` (for -Inf) and `nan` (for NaN).
        JSON.json(io, data; allownan = true, inf = "null", ninf = "null", nan = "null")
    else
        @_error("Unrecognized filetype: \".$filetype\", Supported extensions are \".raw\", \".m\" and \".json\"")
    end
end


"""
Runs various data quality checks on a PowerModels data dictionary.
Applies modifications in some cases.  Reports modified component ids.
"""
function correct_network_data!(data::Dict{String,<:Any})
    check_connectivity(data)
    check_status(data)
    check_reference_bus(data)
    make_per_unit!(data)

    correct_transformer_parameters!(data)
    correct_voltage_angle_differences!(data)
    correct_thermal_limits!(data)
    correct_current_limits!(data)
    correct_branch_directions!(data)

    check_branch_loops(data)
    correct_dcline_limits!(data)

    data_ep = _IM.ismultiinfrastructure(data) ? data["it"][pm_it_name] : data

    if length(data_ep["gen"]) > 0 && any(gen["gen_status"] != 0 for (i, gen) in data_ep["gen"])
        correct_bus_types!(data)
    end

    check_voltage_setpoints(data)
    check_storage_parameters(data)
    check_switch_parameters(data)

    correct_cost_functions!(data)

    simplify_cost_terms!(data)
end
