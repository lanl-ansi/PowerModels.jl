
function build_mn_data(base_data; replicates::Int=2)
    mp_data = PowerModels.parse_file(base_data)
    return InfrastructureModels.replicate(mp_data, replicates)
end


function build_mn_data(base_data_1, base_data_2)
    mp_data_1 = PowerModels.parse_file(base_data_1)
    mp_data_2 = PowerModels.parse_file(base_data_2)
    
    @assert mp_data_1["per_unit"] == mp_data_2["per_unit"]
    @assert mp_data_1["baseMVA"] == mp_data_2["baseMVA"]

    mn_data = Dict{String,Any}(
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

    return mn_data
end


function build_mp_data(base_data; phases::Int=3)
    mp_data = PowerModels.parse_file(base_data)
    PowerModels.make_multiphase(mp_data, phases)
    return mp_data
end

