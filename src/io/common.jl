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
        Memento.info(_LOGGER, "The PSS(R)E parser currently supports buses, loads, shunts, generators, branches, transformers, and dc lines")
        pm_data = PowerModels.parse_psse(io; import_all=import_all, validate=validate)
    elseif filetype == "json"
        pm_data = PowerModels.parse_json(io; validate=validate)
    else
        Memento.error(_LOGGER, "Unrecognized filetype")
    end

    return pm_data
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
    check_reference_bus(data)

    make_per_unit!(data)

    mod_branch[:xfer_fix] = correct_transformer_parameters!(data)
    mod_branch[:vad_bounds] = correct_voltage_angle_differences!(data)
    mod_branch[:mva_zero] = correct_thermal_limits!(data)
    mod_branch[:orientation] = correct_branch_directions!(data)
    check_branch_loops(data)

    mod_dcline[:losses] = correct_dcline_limits!(data)

    mod_bus[:type] = correct_bus_types!(data)
    check_voltage_setpoints(data)

    check_storage_parameters(data)

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
