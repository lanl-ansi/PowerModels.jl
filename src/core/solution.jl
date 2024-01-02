function _IM.solution_preprocessor(pm::AbstractPowerModel, solution::Dict)
    per_unit = _IM.get_data(x -> x["per_unit"], pm.data, pm_it_name; apply_to_subnetworks = false)
    solution["it"][pm_it_name]["per_unit"] = per_unit

    for (nw_id, nw_ref) in nws(pm)
        solution["it"][pm_it_name]["nw"]["$(nw_id)"]["baseMVA"] = nw_ref[:baseMVA]
    end
end


"add support for Symmetric JuMP matrix variables"
function _IM.build_solution_values(var::LinearAlgebra.Symmetric{T,Array{T,2}}) where T
    return [_IM.build_solution_values(var[i,j]) for i in 1:size(var,1), j in 1:size(var,2)]
end


"converts the solution data into the data model's standard space, polar voltages and rectangular power"
function sol_data_model!(pm::AbstractPowerModel, solution::Dict)
    Memento.warn(_LOGGER, "sol_data_model! not defined for power model of type $(typeof(pm))")
end


"PowerModels wrapper for the InfrastructureModels `sol_component_value` function."
function sol_component_fixed(aim::AbstractPowerModel, n::Int, comp_name::Symbol, field_name::Symbol, comp_ids, constant)
    return _IM.sol_component_fixed(aim, pm_it_sym, n, comp_name, field_name, comp_ids, constant)
end


"PowerModels wrapper for the InfrastructureModels `sol_component_value` function."
function sol_component_value(aim::AbstractPowerModel, n::Int, comp_name::Symbol, field_name::Symbol, comp_ids, variables)
    return _IM.sol_component_value(aim, pm_it_sym, n, comp_name, field_name, comp_ids, variables)
end


"PowerModels wrapper for the InfrastructureModels `sol_component_value_edge` function."
function sol_component_value_edge(aim::AbstractPowerModel, n::Int, comp_name::Symbol, field_name_fr::Symbol, field_name_to::Symbol, comp_ids_fr, comp_ids_to, variables)
    return _IM.sol_component_value_edge(aim, pm_it_sym, n, comp_name, field_name_fr, field_name_to, comp_ids_fr, comp_ids_to, variables)
end