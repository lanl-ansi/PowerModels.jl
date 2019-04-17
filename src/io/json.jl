# Parse PowerModels data from JSON exports of PowerModels data structures.
# Necessary in order to support MultiConductorValues


function _jsonver2juliaver!(pm_data)
    if haskey(pm_data, "source_version") && isa(pm_data["source_version"], Dict)
        pm_data["source_version"] = "$(pm_data["source_version"]["major"]).$(pm_data["source_version"]["minor"]).$(pm_data["source_version"]["patch"])"
    end
end


function _parse_mcv!(pm_data)
    eltypes = Dict("Float"=>Float64,
                   "Int"=>Int64,
                   "Real"=>Real,
                   "Complex"=>Complex,
                   "String"=>String)

    for (comp_type, comp_items) in pm_data
        if isa(comp_items, Dict)
            for (n, item) in comp_items
                for (field, value) in item
                    if isa(value, Dict) && haskey(value, "values") && haskey(value, "type")
                        element_type = match(r"MultiConductor(?:Vector|Matrix){([a-zA-Z]+)\d*}", value["type"]).captures[1]
                        if startswith(value["type"], "MultiConductorVector") || startswith(value["type"], "PowerModels.MultiConductorVector")
                            pm_data[comp_type][n][field] = PowerModels.MultiConductorVector(convert(Array{eltypes[element_type]}, value["values"]))
                        elseif startswith(value["type"], "MultiConductorMatrix") || startswith(value["type"], "PowerModels.MultiConductorMatrix")
                            pm_data[comp_type][n][field] = PowerModels.MultiConductorMatrix(convert(Array{eltypes[element_type]}, hcat(value["values"]...)))
                        end
                    end
                end
            end
        end
    end
end


"Parses json from iostream or string"
function parse_json(io::Union{IO,String}; kwargs...)::Dict{String,Any}
    if VERSION <= v"0.7.0-"
        kwargs = Dict{Symbol,Any}(kwargs)
    end
    pm_data = JSON.parse(io)

    _jsonver2juliaver!(pm_data)

    if haskey(pm_data, "conductors")
        _parse_mcv!(pm_data)
    end

    if get(kwargs, :validate, true)
        PowerModels.check_network_data(pm_data)
    end

    return pm_data
end
