
function build_mn_data(base_data; replicates::Int=2)
    mp_data = PowerModels.parse_file(base_data)
    return PowerModels.replicate(mp_data, replicates)
end

function build_mn_data(base_data_1, base_data_2)
    data_1 = PowerModels.parse_file(base_data_1)
    data_2 = PowerModels.parse_file(base_data_2)

    @assert data_1["per_unit"] == data_2["per_unit"]

    mn_data = Dict(
        "name" => "$(data_1["name"]) + $(data_2["name"])",
        "multinetwork" => true,
        "per_unit" => data_1["per_unit"],
        "nw" => Dict{String,Any}()
    )

    delete!(data_1, "multinetwork")
    delete!(data_1, "per_unit")
    mn_data["nw"]["1"] = data_1

    delete!(data_2, "multinetwork")
    delete!(data_2, "per_unit")
    mn_data["nw"]["2"] = data_2

    PowerModels.standardize_cost_terms!(mn_data)

    return mn_data
end


"checks that no bounds are in Inf"
function check_variable_bounds(model)
    for v in JuMP.all_variables(model)
        #println(v)
        if JuMP.has_lower_bound(v)
            if isinf(JuMP.lower_bound(v))
                println(v, JuMP.lower_bound(v))
                return false
            end
        end
        if JuMP.has_upper_bound(v)
            if isinf(JuMP.upper_bound(v))
                println(v, JuMP.upper_bound(v))
                return false
            end
        end
    end
    return true
end


function all_loads_on(result; atol=1e-5)
    # tolerance of 1e-5 is needed for SCS tests to pass
    return !haskey(result["solution"], "load") || all(isapprox(load["status"], 1.0, atol=atol) for (i,load) in result["solution"]["load"])
end

function all_shunts_on(result; atol=1e-5)
    # tolerance of 1e-5 is needed for SCS tests to pass
    return !haskey(result["solution"], "shunt") ||all(isapprox(shunt["status"], 1.0, atol=atol) for (i,shunt) in result["solution"]["shunt"])
end

""
function load_status(result, nw_id, load_id)
    return result["solution"]["nw"][nw_id]["load"][load_id]["status"]
end

""
function load_status(result, load_id)
    return result["solution"]["load"][load_id]["status"]
end

""
function shunt_status(result, nw_id, shunt_id)
    return result["solution"]["nw"][nw_id]["shunt"][shunt_id]["status"]
end

""
function shunt_status(result, shunt_id)
    return result["solution"]["shunt"][shunt_id]["status"]
end

""
function active_power_served(result)
    return sum([load["pd"] for (i,load) in result["solution"]["load"]])
end
