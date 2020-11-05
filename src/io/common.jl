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

    _IM.modify_data_with_function!(data, "ep", check_conductors; apply_to_nws = false)
    _IM.modify_data_with_function!(data, "ep", check_connectivity; apply_to_nws = false)
    _IM.modify_data_with_function!(data, "ep", check_status; apply_to_nws = false)
    _IM.modify_data_with_function!(data, "ep", check_reference_bus; apply_to_nws = false)
    _IM.modify_data_with_function!(data, "ep", make_per_unit!; apply_to_nws = false)

    mod_branch[:xfer_fix] = _IM.modify_data_with_function!(data, "ep", correct_transformer_parameters!; apply_to_nws = false)
    mod_branch[:vad_bounds] = _IM.modify_data_with_function!(data, "ep", correct_voltage_angle_differences!; apply_to_nws = false)
    mod_branch[:mva_zero] = _IM.modify_data_with_function!(data, "ep", correct_thermal_limits!; apply_to_nws = false)
    mod_branch[:ma_zero] = _IM.modify_data_with_function!(data, "ep", correct_current_limits!; apply_to_nws = false)
    mod_branch[:orientation] = _IM.modify_data_with_function!(data, "ep", correct_branch_directions!; apply_to_nws = false)

    _IM.modify_data_with_function!(data, "ep", check_branch_loops)

    mod_dcline[:losses] = _IM.modify_data_with_function!(data, "ep", correct_dcline_limits!; apply_to_nws = false)

    if length(data["gen"]) > 0 && any(gen["gen_status"] != 0 for (i,gen) in data["gen"])
        mod_bus[:type] = _IM.modify_data_with_function!(data, "ep", correct_bus_types!; apply_to_nws = false)
    end

    _IM.modify_data_with_function!(data, "ep", check_voltage_setpoints)
    _IM.modify_data_with_function!(data, "ep", check_storage_parameters)
    _IM.modify_data_with_function!(data, "ep", check_switch_parameters)

    gen, dcline = _IM.modify_data_with_function!(data, "ep", correct_cost_functions!; apply_to_nws = false)
    mod_gen[:cost_pwl] = gen
    mod_dcline[:cost_pwl] = dcline

    _IM.modify_data_with_function!(data, "ep", simplify_cost_terms!)

    return Dict(
        "bus" => mod_bus,
        "gen" => mod_gen,
        "branch" => mod_branch,
        "dcline" => mod_dcline
    )
end
