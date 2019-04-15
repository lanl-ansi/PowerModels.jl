# Parse PowerModels data from JSON exports of PowerModels data structures.
# Necessary in order to support MultiConductorValues


function jsonver2juliaver!(pm_data)
    if isa(pm_data["source_version"], Dict)
        pm_data["source_version"] = "$(pm_data["source_version"]["major"]).$(pm_data["source_version"]["minor"]).$(pm_data["source_version"]["patch"])"
    end
end


function bus2mcv!(pm_data)
    for (i, bus) in get(pm_data, "bus", Dict())
        for key in ["vm", "va", "vmin", "vmax"]
            if haskey(bus, key)
                bus[key] = MultiConductorVector(convert(Array{Float64}, bus[key]))
            end
        end
    end
end


function load2mcv!(pm_data)
    for (i, load) in get(pm_data, "load", Dict())
        for key in ["pd", "qd"]
            if haskey(load, key)
                load[key] = MultiConductorVector(convert(Array{Float64}, load[key]))
            end
        end
    end
end


function shunt2mcv!(pm_data)
    for (i, shunt) in get(pm_data, "shunt", Dict())
        for key in ["gs", "bs"]
            if haskey(shunt, key)
                shunt[key] = MultiConductorVector(convert(Array{Float64}, shunt[key]))
            end
        end
    end
end


function branch2mcv!(pm_data)
    for (i, branch) in get(pm_data, "branch", Dict())
        for key in ["g_fr", "g_to", "b_fr", "b_to", "rate_a", "rate_b", "rate_c", "tap", "shift", "angmin", "angmax", "br_r", "br_x"]
            if haskey(branch, key)
                if key in ["br_r", "br_x"]
                    branch[key] = hcat(branch[key]...)
                    branch[key] = MultiConductorMatrix(convert(Array{Float64}, branch[key]))
                else
                    branch[key] = MultiConductorVector(convert(Array{Float64}, branch[key]))
                end
            end
        end
    end
end


function gen2mcv!(pm_data)
    for (i, gen) in get(pm_data, "gen", Dict())
        for key in ["pg", "qg", "qmin", "qmax", "pmin", "pmax", "vg", "apf", "ramp_q", "ramp_10", "ramp_30", "ramp_agc", "pc1", "pc2", "qc1min", "qc1max", "qc2min", "qc2max"]
            if haskey(gen, key)
                gen[key] = MultiConductorVector(convert(Array{Float64}, gen[key]))
            end
        end
    end
end


function storage2mcv!(pm_data)
    for (i, strg) in get(pm_data, "storage", Dict())
        for key in ["thermal_rating", "current_rating", "qmin", "qmax", "r", "x"]
            if haskey(strg, key)
                strg[key] = MultiConductorVector(convert(Array{Float64}, strg[key]))
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

    jsonver2juliaver!(pm_data)

    if get(pm_data, "conductors", 1) > 1
        bus2mcv!(pm_data)
        load2mcv!(pm_data)
        shunt2mcv!(pm_data)
        branch2mcv!(pm_data)
        gen2mcv!(pm_data)
        storage2mcv!(pm_data)
    end

    if get(kwargs, :validate, true)
        check_network_data(pm_data)
    end

    return pm_data
end
