###########################################################################
#                                                                         #
# This file provides functions for interfacing with OPFData dataset files #
#                                                                         #
###########################################################################

"Parses the OPFData data from a json dictionary"
function parse_opfdata(opfdata_dict::Dict{String,Any}, validate=true)::Dict
    pm_data = _opfdata_to_powermodels!(opfdata_dict)
    if validate
        correct_network_data!(pm_data)
    end
    return pm_data
end


### Data and functions specific to OPFData format ###

const _opf_bus_columns = [
    ("base_kv", Float64),
    ("bus_type", Int),
    ("vmin", Float64),
    ("vmax", Float64)
]

const _opf_bus_sol_columns = [
    ("va", Float64), ("vm", Float64)
]

const _opf_gen_columns = [
    ("mbase", Float64),
    ("pg", Float64),
    ("pmin", Float64), ("pmax", Float64),
    ("qg", Float64),
    ("qmin", Float64), ("qmax", Float64),
    ("vg", Float64),
    ("cost_squared", Float64),
    ("cost_linear", Float64),
    ("cost_offset", Float64)
]

const _opf_gen_sol_columns = [
    ("pg", Float64), ("qg", Float64)
]

const _opf_load_columns = [
    ("pd", Float64), ("qd", Float64)
]

const _opf_shunt_columns = [
    ("bs", Float64), ("gs", Float64)
]

const _opf_ac_line_feature_columns = [
    ("angmin", Float64), ("angmax", Float64),
    ("b_fr", Float64), ("b_to", Float64),
    ("br_r", Float64), ("br_x", Float64),
    ("rate_a", Float64),
    ("rate_b", Float64),
    ("rate_c", Float64)
]

const _opf_transformer_line_feature_columns = [
    ("angmin", Float64), ("angmax", Float64),
    ("br_r", Float64), ("br_x", Float64),
    ("rate_a", Float64),
    ("rate_b", Float64),
    ("rate_c", Float64),
    ("tap", Float64), ("shift", Float64),
    ("b_fr", Float64), ("b_to", Float64)
]


### Data and functions specific to PowerModels format ###

"""
Converts a OPFData dict into a PowerModels dict
"""
function _opfdata_to_powermodels!(opfdata_dict::Dict{String,<:Any})

    grid = opfdata_dict["grid"]
    solution = opfdata_dict["solution"]
    case = Dict{String,Any}()

    case["per_unit"] = true

    if haskey(grid["nodes"], "bus") && haskey(solution["nodes"], "bus")
        @assert(length(grid["nodes"]["bus"]) == length(solution["nodes"]["bus"]))
        buses = []
        for (i, bus_row) in enumerate(grid["nodes"]["bus"])
            bus_data = _IM.row_to_typed_dict(bus_row, _opf_bus_columns)
            # bus_solution_data = _IM.row_to_typed_dict(solution["nodes"]["bus"][i], _opf_bus_sol_columns) # This was for testing if setting to solution voltages gave correct objective
            bus_data["index"] = i
            bus_data["source_id"] = ["bus", i]
            # bus_data["va"] = bus_solution_data["va"]
            # bus_data["vm"] = bus_solution_data["vm"]
            push!(buses, bus_data)
        end
        case["bus"] = buses
    else
        Memento.error(string("no bus table found in OPFData file. The file seems to be missing \"bus\": [...]"))
    end

    if haskey(grid["nodes"], "generator")
        gens = []
        for (i, gen_row) in enumerate(grid["nodes"]["generator"])
            gen_data = _IM.row_to_typed_dict(gen_row, _opf_gen_columns)
            gen_solution_data = _IM.row_to_typed_dict(solution["nodes"]["bus"][i], _opf_gen_sol_columns)
            gen_data["index"] = i
            gen_data["source_id"] = ["gen", i]
            gen_data["model"] = 2
            gen_data["ncost"] = 3
            gen_data["cost"] = [_IM.check_type(Float64, gen_data[key]) for key in ["cost_linear", "cost_squared", "cost_offset"]]
            gen_data["pg"] = gen_solution_data["pg"]
            gen_data["qg"] = gen_solution_data["qg"]
            for key in ["cost_linear", "cost_squared", "cost_offset"]
                delete!(gen_data, key)
            end
            push!(gens, gen_data)
        end
        case["gen"] = gens
    else
        Memento.error(string("no gen table found in OPFData file. The file seems to be missing \"gen\": [...]"))
    end

    if haskey(grid["nodes"], "load")
        loads = []
        for (i, load_row) in enumerate(grid["nodes"]["load"])
            load_data = _IM.row_to_typed_dict(load_row, _opf_load_columns)
            load_data["index"] = i
            load_data["source_id"] = ["load", i]
            push!(loads, load_data)
        end
        case["load"] = loads
    else
        Momento.error(string("no gen table found in OPFData file. The file seems to be missing \"load\": [...]"))
    end

    if haskey(grid["nodes"], "shunt")
        shunts = []
        for (i, shunt_row) in enumerate(grid["nodes"]["shunt"])
            shunt_data = _IM.row_to_typed_dict(shunt_row, _opf_shunt_columns)
            shunt_data["index"] = i
            shunt_data["source_id"] = ["shunt", i]
            push!(shunts, shunt_data)
        end
        case["shunt"] = shunts
    else
        Momento.error(string("no gen table found in OPFData file. The file seems to be missing \"shunt\": [...]"))
    end

    if haskey(grid["edges"], "ac_line")
        ac_lines = []
        for (i, ac_line_row) in enumerate(grid["edges"]["ac_line"]["features"])
            ac_line_data = _IM.row_to_typed_dict(ac_line_row, _opf_ac_line_feature_columns)
            ac_line_data["f_bus"] = grid["edges"]["ac_line"]["senders"][i] + 1
            ac_line_data["t_bus"] = grid["edges"]["ac_line"]["receivers"][i] + 1
            ac_line_data["tap"] = 1.0 # All non-transformer branches are given nominal transformer values (i.e. a tap of 1.0 and shift of 0.0) https://lanl-ansi.github.io/PowerModels.jl/stable/network-data/#Noteworthy-Differences-from-Matpower-Data-Files
            ac_line_data["shift"] = 0.0
            ac_line_data["transformer"] = false

            if ac_line_data["rate_a"] == 0.0
                delete!(ac_line_data, "rate_a")
            end
            if ac_line_data["rate_b"] == 0.0
                delete!(ac_line_data, "rate_b")
            end
            if ac_line_data["rate_c"] == 0.0
                delete!(ac_line_data, "rate_c")
            end
            push!(ac_lines, ac_line_data)
        end
        case["ac_line"] = ac_lines
    else
        Momento.error(string("no gen table found in OPFData file. The file seems to be missing \"ac_line\": [...]"))
    end

    if haskey(grid["edges"], "transformer")
        transformer_lines = []
        for (i, transformer_line_row) in enumerate(grid["edges"]["transformer"]["features"])
            transformer_line_data = _IM.row_to_typed_dict(transformer_line_row, _opf_transformer_line_feature_columns)
            transformer_line_data["f_bus"] = grid["edges"]["transformer"]["senders"][i] + 1
            transformer_line_data["t_bus"] = grid["edges"]["transformer"]["receivers"][i] + 1
            transformer_line_data["transformer"] = true

            if transformer_line_data["rate_a"] == 0.0
                delete!(transformer_line_data, "rate_a")
            end
            if transformer_line_data["rate_b"] == 0.0
                delete!(transformer_line_data, "rate_b")
            end
            if transformer_line_data["rate_c"] == 0.0
                delete!(transformer_line_data, "rate_c")
            end
            push!(transformer_lines, transformer_line_data)
        end
        case["transformer_line"] = transformer_lines
    else
        Momento.error(string("no gen table found in OPFData file. The file seems to be missing \"transformer\": [...]"))
    end

    if haskey(grid, "context")
        case["baseMVA"] = grid["context"][1][1][1]
    else
        Memento.warn(_LOGGER, string("no baseMVA found in OPFData file.  The file seems to be missing \"context\": [...]"))
        case["baseMVA"] = 1.0
    end

    if haskey(grid["edges"], "generator_link")
        gen = case["gen"]
        gen_links = grid["edges"]["generator_link"]["receivers"]
        if length(gen_links) != length(gen)
            if length(gen_links) > length(gen)
                Memento.warn(_LOGGER, "The last $(length(gen_links) - length(gen)) generator links will be ignored due to too few generators.")
            else
                Memento.warn(_LOGGER, "The number of generators ($(length(gen))) does not match the number of generator link records ($(length(gen_links))).")
            end
        end

        for (i, bus_id) in enumerate(gen_links)
            g = gen[i]
            @assert(g["index"] == (grid["edges"]["generator_link"]["senders"][i]+1))
            g["gen_bus"] = bus_id + 1
            bus = case["bus"][bus_id + 1]
            @assert(bus["index"] == (bus_id + 1))
            g["gen_status"] = convert(Int8, bus["bus_type"] != 4)
            bus["vm"] = g["vg"]
        end
    end

    if haskey(grid["edges"], "load_link")
        load = case["load"]
        load_links = grid["edges"]["load_link"]["receivers"]
        if length(load_links) != length(load)
            if length(load_links) > length(load)
                Memento.warn(_LOGGER, "The last $(length(load_links) - length(load)) load links will be ignored due to too few loads.")
            else
                Memento.warn(_LOGGER, "The number of loads ($(length(load))) does not match the number of load link records ($(length(load_links))).")
            end
        end

        for (i, bus_id) in enumerate(load_links)
            l = load[i]
            @assert(l["index"] == (grid["edges"]["load_link"]["senders"][i]+1))
            l["load_bus"] = bus_id + 1
            bus = case["bus"][bus_id + 1]
            @assert(bus["index"] == (bus_id + 1))
            l["status"] = convert(Int8, bus["bus_type"] != 4)
        end
    end
        
    if haskey(grid["edges"], "shunt_link")
        shunt = case["shunt"]
        shunt_links = grid["edges"]["shunt_link"]["receivers"]
        if length(shunt_links) != length(shunt)
            if length(shunt_links) > length(shunt)
                Memento.warn(_LOGGER, "The last $(length(shunt_links) - length(shunt)) shunt links will be ignored due to too few shunts.")
            else
                Memento.warn(_LOGGER, "The number of shunts ($(length(shunt))) does not match the number of shunt link records ($(length(shunt_links))).")
            end
        end

        for (i, bus_id) in enumerate(shunt_links)
            s = shunt[i]
            @assert(s["index"] == (grid["edges"]["shunt_link"]["senders"][i]+1))
            s["shunt_bus"] = bus_id + 1
            bus = case["bus"][bus_id + 1]
            @assert(bus["index"] == (bus_id + 1))
            s["status"] = convert(Int8, bus["bus_type"] != 4)
        end
    end


    # merge ac and transformer lines
    _merge_lines!(case)

    # use once available
    _IM.arrays_to_dicts!(case)

    for optional in ["dcline", "storage", "switch"]
        case[optional] = Dict{String,Any}()
    end

    return case
end


function _merge_lines!(data::Dict{String,Any})
    i = 1
    branches = []
    for ac_line in data["ac_line"]
        ac_line["index"] = i
        ac_line["source_id"] = ["branch", i]
        ac_line["g_fr"] = 0.0
        ac_line["g_to"] = 0.0

        bus_f_id = ac_line["f_bus"]
        bus_t_id = ac_line["t_bus"]
        bus_f = data["bus"][bus_f_id]
        bus_t = data["bus"][bus_t_id]
        @assert(bus_f["index"] == bus_f_id && bus_t["index"] == bus_t_id)
        ac_line["br_status"] = convert(Int8, (bus_f["bus_type"] != 4 && bus_t["bus_type"] != 4))

        push!(branches, ac_line)
        i = i+1
    end
    for transformer_line in data["transformer_line"]
        transformer_line["index"] = i
        transformer_line["source_id"] = ["branch", i]
        transformer_line["g_fr"] = 0.0
        transformer_line["g_to"] = 0.0

        bus_f_id = transformer_line["f_bus"]
        bus_t_id = transformer_line["t_bus"]
        bus_f = data["bus"][bus_f_id]
        bus_t = data["bus"][bus_t_id]
        @assert(bus_f["index"] == bus_f_id && bus_t["index"] == bus_t_id)
        transformer_line["br_status"] = convert(Int8, (bus_f["bus_type"] != 4 && bus_t["bus_type"] != 4))

        push!(branches, transformer_line)
        i = i+1
    end

    @assert(length(branches) == (length(data["ac_line"]) + length(data["transformer_line"])))

    data["branch"] = branches
    delete!(data, "ac_line")
    delete!(data, "transformer_line")
end
