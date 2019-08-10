
function build_mn_data(base_data; replicates::Int=2)
    mp_data = PowerModels.parse_file(base_data)
    return PowerModels.replicate(mp_data, replicates)
end

function build_mn_data(base_data_1, base_data_2)
    data_1 = PowerModels.parse_file(base_data_1)
    data_2 = PowerModels.parse_file(base_data_2)

    @assert data_1["per_unit"] == data_2["per_unit"]
    @assert data_1["baseMVA"] == data_2["baseMVA"]

    mn_data = Dict(
        "name" => "$(data_1["name"]) + $(data_2["name"])",
        "multinetwork" => true,
        "per_unit" => data_1["per_unit"],
        "baseMVA" => data_1["baseMVA"],
        "nw" => Dict{String,Any}()
    )

    delete!(data_1, "multinetwork")
    delete!(data_1, "per_unit")
    delete!(data_1, "baseMVA")
    mn_data["nw"]["1"] = data_1

    delete!(data_2, "multinetwork")
    delete!(data_2, "per_unit")
    delete!(data_2, "baseMVA")
    mn_data["nw"]["2"] = data_2

    PowerModels.standardize_cost_terms!(mn_data)

    return mn_data
end


function build_mc_data!(base_data; conductors::Int=3)
    mp_data = PowerModels.parse_file(base_data)
    PowerModels.make_multiconductor!(mp_data, conductors)
    return mp_data
end


function build_mn_mc_data!(base_data; replicates::Int=3, conductors::Int=3)
    mp_data = PowerModels.parse_file(base_data)
    PowerModels.make_multiconductor!(mp_data, conductors)
    mn_mc_data = PowerModels.replicate(mp_data, replicates)
    mn_mc_data["conductors"] = mn_mc_data["nw"]["1"]["conductors"]
    return mn_mc_data
end


function build_mn_mc_data!(base_data_1, base_data_2; conductors_1::Int=3, conductors_2::Int=3)
    mp_data_1 = PowerModels.parse_file(base_data_1)
    mp_data_2 = PowerModels.parse_file(base_data_2)

    @assert mp_data_1["per_unit"] == mp_data_2["per_unit"]
    @assert mp_data_1["baseMVA"] == mp_data_2["baseMVA"]

    if conductors_1 > 0
        PowerModels.make_multiconductor!(mp_data_1, conductors_1)
    end

    if conductors_2 > 0
        PowerModels.make_multiconductor!(mp_data_2, conductors_2)
    end

    mn_data = Dict(
        "name" => "$(mp_data_1["name"]) + $(mp_data_2["name"])",
        "multinetwork" => true,
        "per_unit" => mp_data_1["per_unit"],
        "baseMVA" => mp_data_1["baseMVA"],
        "nw" => Dict{String,Any}()
    )

    delete!(mp_data_1, "multinetwork")
    delete!(mp_data_1, "per_unit")
    delete!(mp_data_1, "baseMVA")
    mn_data["nw"]["1"] = mp_data_1

    delete!(mp_data_2, "multinetwork")
    delete!(mp_data_2, "per_unit")
    delete!(mp_data_2, "baseMVA")
    mn_data["nw"]["2"] = mp_data_2

    PowerModels.standardize_cost_terms!(mn_data)

    return mn_data
end
