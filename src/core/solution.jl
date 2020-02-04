""
function build_result(pm::AbstractPowerModel, solve_time; solution_processors=[])

    # TODO replace with JuMP.result_count(pm.model) after version v0.21
    # try-catch is needed until solvers reliably support ResultCount()
    result_count = 1
    try
        result_count = _MOI.get(pm.model, _MOI.ResultCount())
    catch
        Memento.warn(_LOGGER, "the given optimizer does not provide the ResultCount() attribute, assuming the solver returned a solution which may be incorrect.");
    end

    sol = Dict{String,Any}()
    if result_count > 0
        sol = build_solution(pm, post_processors=solution_processors)
    else
        Memento.warn(_LOGGER, "model has no results, solution cannot be built")
    end

    data = Dict{String,Any}("name" => pm.data["name"])
    if InfrastructureModels.ismultinetwork(pm.data)
        data_nws = data["nw"] = Dict{String,Any}()

        for (n,nw_data) in pm.data["nw"]
            data_nws[n] = Dict(
                "name" => get(nw_data, "name", "anonymous"),
                "bus_count" => length(nw_data["bus"]),
                "branch_count" => length(nw_data["branch"])
            )
        end
    else
        data["bus_count"] = length(pm.data["bus"])
        data["branch_count"] = length(pm.data["branch"])
    end

    solution = Dict{String,Any}(
        "optimizer" => JuMP.solver_name(pm.model),
        "termination_status" => JuMP.termination_status(pm.model),
        "primal_status" => JuMP.primal_status(pm.model),
        "dual_status" => JuMP.dual_status(pm.model),
        "objective" => _guard_objective_value(pm.model),
        "objective_lb" => _guard_objective_bound(pm.model),
        "solve_time" => solve_time,
        "solution" => sol,
        "machine" => Dict(
            "cpu" => Sys.cpu_info()[1].model,
            "memory" => string(Sys.total_memory()/2^30, " Gb")
            ),
        "data" => data
    )

    return solution
end


""
function _guard_objective_value(model)
    obj_val = NaN

    try
        obj_val = JuMP.objective_value(model)
    catch
    end

    return obj_val
end


""
function _guard_objective_bound(model)
    obj_lb = -Inf

    try
        obj_lb = JuMP.objective_bound(model)
    catch
    end

    return obj_lb
end


""
function build_solution(pm::AbstractPowerModel; post_processors=[])
    # TODO @assert that the model is solved

    sol = _build_solution_values(pm.sol)

    sol["per_unit"] = pm.data["per_unit"]
    for (nw_id, nw_ref) in nws(pm)
        sol["nw"]["$(nw_id)"]["baseMVA"] = nw_ref[:baseMVA]
        if ismulticonductor(pm, nw_id)
            sol["nw"]["$(nw_id)"]["conductors"] = nw_ref[:conductors]
        end
    end

    if !ismultinetwork(pm)
        for (k,v) in sol["nw"]["$(pm.cnw)"]
            sol[k] = v
        end
        delete!(sol, "nw")
    end

    for post_processor in post_processors
        post_processor(pm, sol)
    end

    return sol
end


""
function _build_solution_values(var::Dict)
    sol = Dict{String,Any}()
    for (key, val) in var
        sol[string(key)] = _build_solution_values(val)
    end
    return sol
end

""
function _build_solution_values(var::Array{<:Any,1})
    return [_build_solution_values(val) for val in var]
end

""
function _build_solution_values(var::Array{<:Any,2})
    return [_build_solution_values(var[i,j]) for i in 1:size(var,1), j in 1:size(var,2)]
end

"support for Symmetric JuMP matrix variables"
function _build_solution_values(var::LinearAlgebra.Symmetric{T,Array{T,2}}) where T
    return [_build_solution_values(var[i,j]) for i in 1:size(var,1), j in 1:size(var,2)]
end

""
function _build_solution_values(var::Number)
    return var
end

""
function _build_solution_values(var::JuMP.VariableRef)
    return JuMP.value(var)
end

""
function _build_solution_values(var::JuMP.GenericAffExpr)
    return JuMP.value(var)
end

""
function _build_solution_values(var::JuMP.GenericQuadExpr)
    return JuMP.value(var)
end

""
function _build_solution_values(var::JuMP.NonlinearExpression)
    return JuMP.value(var)
end

""
function _build_solution_values(var::JuMP.ConstraintRef)
    return JuMP.dual(var)
end

""
function _build_solution_values(var::Any)
    Memento.warn(_LOGGER, "_build_solution_values found unknown type $(typeof(var))")
    return var
end

function Base.haskey(cont::JuMP.Containers.DenseAxisArray, key)
    return isassigned(cont,key)
end

"converts vr,vi solution values at buses into vm,va"
function sol_vr_to_vp!(pm::AbstractPowerModel, solution::Dict)
    if haskey(solution, "nw")
        nws_data = solution["nw"]
    else
        nws_data = Dict("0" => solution)
    end

    for (n, nw_data) in nws_data
        if haskey(nw_data, "bus")
            for (i,bus) in nw_data["bus"]
                if haskey(bus, "vr") && haskey(bus, "vi")
                    vm = sqrt(bus["vr"]^2 + bus["vi"]^2)

                    bus["vm"] = vm
                    bus["va"] = atan(bus["vi"], bus["vr"])
                end
            end
        end
    end
end

"converts w solution values at buses into vm"
function sol_w_to_vm!(pm::AbstractPowerModel, solution::Dict)
    if haskey(solution, "nw")
        nws_data = solution["nw"]
    else
        nws_data = Dict("0" => solution)
    end

    for (n, nw_data) in nws_data
        if haskey(nw_data, "bus")
            for (i,bus) in nw_data["bus"]
                if haskey(bus, "w")
                    bus["vm"] = sqrt(bus["w"])
                end
            end
        end
    end
end

"converts phi solution values at buses into vm"
function sol_phi_to_vm!(pm::AbstractPowerModel, solution::Dict)
    if haskey(solution, "nw")
        nws_data = solution["nw"]
    else
        nws_data = Dict("0" => solution)
    end

    for (n, nw_data) in nws_data
        if haskey(nw_data, "bus")
            for (i,bus) in nw_data["bus"]
                if haskey(bus, "phi")
                    bus["vm"] = 1.0 + bus["phi"]
                end
            end
        end
    end
end