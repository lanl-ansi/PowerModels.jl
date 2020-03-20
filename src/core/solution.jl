
function _IM.solution_preprocessor(pm::AbstractPowerModel, solution::Dict)
    solution["per_unit"] = pm.data["per_unit"]
    for (nw_id, nw_ref) in nws(pm)
        solution["nw"]["$(nw_id)"]["baseMVA"] = nw_ref[:baseMVA]
        if ismulticonductor(pm, nw_id)
            solution["nw"]["$(nw_id)"]["conductors"] = nw_ref[:conductors]
        end
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
