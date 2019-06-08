""
function build_solution(pm::GenericPowerModel, solve_time; solution_builder=solution_opf!)
    # TODO @assert that the model is solved

    sol = _init_solution(pm)
    data = Dict{String,Any}("name" => pm.data["name"])

    if InfrastructureModels.ismultinetwork(pm.data)
        sol["multinetwork"] = true
        sol_nws = sol["nw"] = Dict{String,Any}()
        data_nws = data["nw"] = Dict{String,Any}()

        for (n,nw_data) in pm.data["nw"]
            sol_nw = sol_nws[n] = Dict{String,Any}()
            if haskey(nw_data, "conductors")
                sol_nw["conductors"] = nw_data["conductors"]
            end
            pm.cnw = parse(Int, n)
            solution_builder(pm, sol_nw)
            data_nws[n] = Dict(
                "name" => get(nw_data, "name", "anonymous"),
                "bus_count" => length(nw_data["bus"]),
                "branch_count" => length(nw_data["branch"])
            )
        end
    else
        if haskey(pm.data, "conductors")
            sol["conductors"] = pm.data["conductors"]
        end
        solution_builder(pm, sol)
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
function _init_solution(pm::GenericPowerModel)
    data_keys = ["per_unit", "baseMVA"]
    return Dict{String,Any}(key => pm.data[key] for key in data_keys)
end

""
function solution_opf!(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_storage!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_dcline_flow!(sol, pm)

    add_dual_kcl!(sol, pm)
    add_dual_sm!(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end

""
function add_setpoint_bus_voltage!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "bus", "vm", :vm, status_name="bus_type", inactive_status_value = 4)
    add_setpoint!(sol, pm, "bus", "va", :va, status_name="bus_type", inactive_status_value = 4)
end

""
function add_dual_kcl!(sol, pm::GenericPowerModel)
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "duals") && pm.setting["output"]["duals"] == true
        add_dual!(sol, pm, "bus", "lam_kcl_r", :kcl_p, status_name="bus_type", inactive_status_value = 4)
        add_dual!(sol, pm, "bus", "lam_kcl_i", :kcl_q, status_name="bus_type", inactive_status_value = 4)
    end
end

""
function add_dual_sm!(sol, pm::GenericPowerModel)
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "duals") && pm.setting["output"]["duals"] == true
        add_dual!(sol, pm, "branch", "mu_sm_fr", :sm_fr, status_name="br_status")
        add_dual!(sol, pm, "branch", "mu_sm_to", :sm_to, status_name="br_status")
    end
end

""
function add_setpoint_generator_power!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "gen", "pg", :pg, status_name="gen_status")
    add_setpoint!(sol, pm, "gen", "qg", :qg, status_name="gen_status")
end

""
function add_setpoint_generator_status!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "gen", "gen_status", :z_gen, status_name="gen_status", conductorless=true, default_value = (item) -> item["gen_status"]*1.0)

end

""
function add_setpoint_storage!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "storage", "ps", :ps)
    add_setpoint!(sol, pm, "storage", "qs", :qs)
    add_setpoint!(sol, pm, "storage", "se", :se, conductorless=true)
    # useful for model debugging
    #add_setpoint!(sol, pm, "storage", "sc", :sc, conductorless=true)
    #add_setpoint!(sol, pm, "storage", "sd", :sd, conductorless=true)
end

""
function add_setpoint_branch_flow!(sol, pm::GenericPowerModel)
    # check the branch flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "branch_flows") && pm.setting["output"]["branch_flows"] == true
        add_setpoint!(sol, pm, "branch", "pf", :p, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "branch", "qf", :q, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "branch", "pt", :p, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
        add_setpoint!(sol, pm, "branch", "qt", :q, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
    end
end

""
function add_setpoint_dcline_flow!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "dcline", "pf", :p_dc, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
    add_setpoint!(sol, pm, "dcline", "qf", :q_dc, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
    add_setpoint!(sol, pm, "dcline", "pt", :p_dc, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
    add_setpoint!(sol, pm, "dcline", "qt", :q_dc, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
end


""
function add_setpoint_branch_status!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "branch", "br_status", :branch_z, status_name="br_status", default_value = (item) -> 1)
end

""
function add_setpoint_dcline_status!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "dcline", "br_status", :dcline_z, status_name="br_status", default_value = (item) -> 1)
end


"adds values based on JuMP variables"
function add_setpoint!(
    sol,
    pm::GenericPowerModel,
    dict_name,
    param_name,
    variable_symbol;
    index_name = "index",
    default_value = (item) -> NaN,
    scale = (x,item,cnd) -> x,
    var_key = (idx,item) -> idx,
    sol_dict = get(sol, dict_name, Dict{String,Any}()),
    conductorless = false,
    status_name = "status",
    inactive_status_value = 0,
)
    if conductorless
        has_variable_symbol = haskey(var(pm, pm.cnw), variable_symbol)
    else
        has_variable_symbol = haskey(var(pm, pm.cnw, pm.ccnd), variable_symbol)
    end

    if !has_variable_symbol
        add_setpoint_fixed!(sol, pm, dict_name, param_name; index_name=index_name, default_value=default_value, conductorless=conductorless)
        return
    else
        if conductorless
            variables = var(pm, pm.cnw, variable_symbol)
        else
            variables = var(pm, pm.cnw, pm.ccnd, variable_symbol)
        end
    end

    if InfrastructureModels.ismultinetwork(pm.data)
        data_dict = pm.data["nw"]["$(pm.cnw)"][dict_name]
    else
        data_dict = pm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    mc = ismulticonductor(pm)
    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())

        if conductorless || !mc
            sol_item[param_name] = default_value(item)

            if item[status_name] != inactive_status_value
                var_id = var_key(idx, item)
                #variables = var(pm, variable_symbol, cnd=conductor)
                #if var_id in keys(variables)
                sol_item[param_name] = scale(JuMP.value(variables[var_id]), item, 1)
                #end
            end
        else
            num_conductors = length(conductor_ids(pm))
            cnd_idx = 1
            sol_item[param_name] = MultiConductorVector{Real}([default_value(item) for i in 1:num_conductors])

            if item[status_name] != inactive_status_value
                for conductor in conductor_ids(pm)
                    var_id = var_key(idx, item)
                    #variables = var(pm, variable_symbol, cnd=conductor)
                    #if var_id in keys(variables)
                    sol_item[param_name][cnd_idx] = scale(JuMP.value(variables[var_id]), item, conductor)
                    #end
                    cnd_idx += 1
                end
            end
        end

    end
end


"""
adds setpoint values based on a given default_value function.

this significantly improves performance in models where values are not defined
e.g. the reactive power values in a DC power flow model
"""
function add_setpoint_fixed!(
    sol,
    pm::GenericPowerModel,
    dict_name,
    param_name;
    index_name = "index",
    default_value = (item) -> NaN,
    sol_dict = get(sol, dict_name, Dict{String,Any}()),
    conductorless = false
)

    if InfrastructureModels.ismultinetwork(pm.data)
        data_dict = pm.data["nw"]["$(pm.cnw)"][dict_name]
    else
        data_dict = pm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())

        if conductorless
            sol_item[param_name] = default_value(item)
        else
            num_conductors = length(conductor_ids(pm))
            cnd_idx = 1
            sol_item[param_name] = MultiConductorVector{Real}([default_value(item) for i in 1:num_conductors])
        end

        # remove MultiConductorValue, if it was not a ismulticonductor network
        if !ismulticonductor(pm)
            sol_item[param_name] = sol_item[param_name][1]
        end
    end
end



"""

    function add_dual!(
        sol::AbstractDict,
        pm::GenericPowerModel,
        dict_name::AbstractString,
        param_name::AbstractString,
        con_symbol::Symbol;
        index_name::AbstractString = "index",
        default_value::Function = (item) -> NaN,
        scale::Function = (x,item,cnd) -> x,
        con_key::Function = (idx,item) -> idx,
    )

This function takes care of adding the values of dual variables to the solution Dict.

# Arguments

- `sol::AbstractDict`: The dict where the desired final details of the solution are stored;
- `pm::GenericPowerModel`: The PowerModel which has been considered;
- `dict_name::AbstractString`: The particular class of items for the solution (e.g. branch, bus);
- `param_name::AbstractString`: The name associated to the dual variable;
- `con_symbol::Symbol`: the Symbol attached to the class of constraints;
- `index_name::AbstractString = "index"`: ;
- `default_value::Function = (item) -> NaN`: a function that assign to each item a default value, for missing data;
- `scale::Function = (x,item) -> x`: a function to rescale the values of the dual variables, if needed;
- `con_key::Function = (idx,item) -> idx`: a method to extract the actual dual variables.
- `status_name::AbstractString: the status field of the given component type`
- `inactive_status_value::Any: the value of the status field indicating an inactive component`

"""
function add_dual!(
    sol::AbstractDict,
    pm::GenericPowerModel,
    dict_name::AbstractString,
    param_name::AbstractString,
    con_symbol::Symbol;
    index_name::AbstractString = "index",
    default_value::Function = (item) -> NaN,
    scale::Function = (x,item,cnd) -> x,
    con_key::Function = (idx,item) -> idx,
    conductorless = false,
    status_name = "status",
    inactive_status_value = 0,
)
    sol_dict = get(sol, dict_name, Dict{String,Any}())


    constraints = []
    if conductorless
        has_con_symbol = haskey(con(pm, pm.cnw), con_symbol)
    else
        has_con_symbol = haskey(con(pm, pm.cnw, pm.ccnd), con_symbol)
    end

    if has_con_symbol
        if conductorless
            constraints = con(pm, pm.cnw, con_symbol)
        else
            constraints = con(pm, pm.cnw, pm.ccnd, con_symbol)
        end
    end

    if !has_con_symbol || length(constraints) == 0
        add_dual_fixed!(sol, pm, dict_name, param_name; index_name=index_name, default_value=default_value, conductorless=conductorless)
        return
    end


    if ismultinetwork(pm)
        data_dict = pm.data["nw"]["$(pm.cnw)"][dict_name]
    else
        data_dict = pm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    mc = ismulticonductor(pm)
    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())

        if conductorless || !mc
            sol_item[param_name] = default_value(item)

            if item[status_name] != inactive_status_value
                con_id = con_key(idx, item)
                #constraints = con(pm, con_symbol)
                #if con_id in keys(constraints)
                sol_item[param_name] = scale(JuMP.dual(constraints[con_id]), item, 1)
                #end
            end
        else
            num_conductors = length(conductor_ids(pm))
            cnd_idx = 1
            sol_item[param_name] = MultiConductorVector(default_value(item), num_conductors)

            if item[status_name] != inactive_status_value
                for conductor in conductor_ids(pm)
                    con_id = con_key(idx, item)
                    #constraints = con(pm, con_symbol, cnd=conductor)
                    #if con_id in keys(constraints)
                    sol_item[param_name][cnd_idx] = scale(JuMP.dual(constraints[con_id]), item, conductor)
                    #Memento.info(_LOGGER, "No constraint: $(con_symbol), $(idx)")
                    cnd_idx += 1
                end
            end
        end
    end
end


function add_dual_fixed!(
    sol::AbstractDict,
    pm::GenericPowerModel,
    dict_name::AbstractString,
    param_name::AbstractString;
    index_name::AbstractString = "index",
    default_value::Function = (item) -> NaN,
    conductorless=false
)
    sol_dict = get(sol, dict_name, Dict{String,Any}())

    if ismultinetwork(pm)
        data_dict = pm.data["nw"]["$(pm.cnw)"][dict_name]
    else
        data_dict = pm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())

        if conductorless
            sol_item[param_name] = default_value(item)
        else
            num_conductors = length(conductor_ids(pm))
            cnd_idx = 1
            sol_item[param_name] = MultiConductorVector{Real}([default_value(item) for i in 1:num_conductors])
        end

        # remove MultiConductorValue, if it was not a ismulticonductor network
        if !ismulticonductor(pm)
            sol_item[param_name] = sol_item[param_name][1]
        end
    end
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
