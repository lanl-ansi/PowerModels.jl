""
function build_solution(pm::GenericPowerModel, status, solve_time; objective = NaN, solution_builder = get_solution)
    # TODO assert that the model is solved

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(Symbol(typeof(pm.model.solver).name.module), status)
    end

    sol = init_solution(pm)
    data = Dict{String,Any}("name" => pm.data["name"])

    if pm.data["multinetwork"]
        sol_nws = sol["nw"] = Dict{String,Any}()
        data_nws = data["nw"] = Dict{String,Any}()

        for (n,nw_data) in pm.data["nw"]
            sol_nw = sol_nws[n] = Dict{String,Any}()
            pm.cnw = parse(Int, n)
            solution_builder(pm, sol_nw)
            data_nws[n] = Dict(
                "name" => nw_data["name"],
                "bus_count" => length(nw_data["bus"]),
                "branch_count" => length(nw_data["branch"])
            )
        end
    else
        solution_builder(pm, sol)
        data["bus_count"] = length(pm.data["bus"])
        data["branch_count"] = length(pm.data["branch"])
    end

    solution = Dict{String,Any}(
        "solver" => string(typeof(pm.model.solver)),
        "status" => status,
        "objective" => objective,
        "objective_lb" => guard_getobjbound(pm.model),
        "solve_time" => solve_time,
        "solution" => sol,
        "machine" => Dict(
            "cpu" => Sys.cpu_info()[1].model,
            "memory" => string(Sys.total_memory()/2^30, " Gb")
            ),
        "data" => data
    )

    pm.solution = solution

    return solution
end

""
function init_solution(pm::GenericPowerModel)
    data_keys = ["per_unit", "baseMVA", "multinetwork"]
    return Dict{String,Any}(key => pm.data[key] for key in data_keys)
end

""
function get_solution(pm::GenericPowerModel, sol::Dict{String,Any})
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_dcline_flow_setpoint(sol, pm)

    add_kcl_duals(sol, pm)
    add_sm_duals(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end

""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel)
    add_setpoint(sol, pm, "bus", "vm", :vm)
    add_setpoint(sol, pm, "bus", "va", :va)
end

""
function add_kcl_duals(sol, pm::GenericPowerModel)
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "duals") && pm.setting["output"]["duals"] == true
        add_dual(sol, pm, "bus", "lam_kcl_r", :kcl_p)
        add_dual(sol, pm, "bus", "lam_kcl_i", :kcl_q)
    end
end

"""

    add_sm_duals(sol::Dict{String, Any}, pm::GenericPowerModel)

Add the duals for the thermal limit constraints to the solution Dict.

# Arguments:

- `sol::Dict{String, Any}`: The dictionary storing the properties of the solution for the output
- `pm::GenericPowerModel`: The power model.

"""
function add_sm_duals(sol::Dict{String, Any}, pm::GenericPowerModel)
    dualsdict = Dict{String,Any}()
    for k in keys(pm.var[:nw])
        res = Dict{Any,Any}()
        try
            aux = pm.var[:nw][k][:p] # This contains the list of variables for the branches
            if isa(aux, Associative) # NOTE: in DCPPowerModel this is a Dict
                for h in keys(aux)
                    isa(aux[h], JuMP.Variable) && (res[h] = getdual(aux[h]))
                end
                dualsdict[string(k)] = res
            elseif isa(aux, JuMP.JuMPArray) # NOTE: in ACPPowerModel this is a:
                # JuMP.JuMPArray{JuMP.Variable,1,Tuple{Array{Tuple{Int64,Int64,Int64},1}}}
                # TODO: probably enforce consistency in the types.
                for (i, idxs) in enumerate(aux.indexsets)
                    res2 = Dict{Any,Any}()
                    for h in idxs
                        isa(aux[h], JuMP.Variable) && (res2[h] = getdual(aux[h]))
                    end
                    res[i] =res2
                end
                dualsdict[string(k)] = res
            end
        catch e
            warn("Could not find the branch flow variables for key $k: $e")
        end
    end
    sol["branch_duals"] = dualsdict
end

""
function add_generator_power_setpoint(sol, pm::GenericPowerModel)
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "gen", "pg", :pg)
    add_setpoint(sol, pm, "gen", "qg", :qg)
end

""
function add_bus_demand_setpoint(sol, pm::GenericPowerModel)
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "bus", "pd", :pd; default_value = (item) -> item["pd"]*mva_base)
    add_setpoint(sol, pm, "bus", "qd", :qd; default_value = (item) -> item["qd"]*mva_base)
end

""
function add_branch_flow_setpoint(sol, pm::GenericPowerModel)
    # check the branch flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "branch_flows") && pm.setting["output"]["branch_flows"] == true
        add_setpoint(sol, pm, "branch", "pf", :p; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "qf", :q; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "pt", :p; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, "branch", "qt", :q; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end

""
function add_dcline_flow_setpoint(sol, pm::GenericPowerModel)
    add_setpoint(sol, pm, "dcline", "pf", :p_dc; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
    add_setpoint(sol, pm, "dcline", "qf", :q_dc; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
    add_setpoint(sol, pm, "dcline", "pt", :p_dc; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    add_setpoint(sol, pm, "dcline", "qt", :q_dc; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
end

""
function add_branch_flow_setpoint_ne(sol, pm::GenericPowerModel)
    # check the branch flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "branch_flows") && pm.setting["output"]["branch_flows"] == true
        add_setpoint(sol, pm, "ne_branch", "pf", :p_ne; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "ne_branch", "qf", :q_ne; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "ne_branch", "pt", :p_ne; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, "ne_branch", "qt", :q_ne; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end

""
function add_branch_status_setpoint(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "branch", "br_status", :branch_z; default_value = (item) -> 1)
end

function add_branch_status_setpoint_dc(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "dcline", "br_status", :dcline_z; default_value = (item) -> 1)
end

""
function add_branch_ne_setpoint(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "ne_branch", "built", :branch_ne; default_value = (item) -> 1)
end

""
function add_setpoint(sol, pm::GenericPowerModel, dict_name, param_name, variable_symbol; index_name = "index", default_value = (item) -> NaN, scale = (x,item) -> x, extract_var = (var,idx,item) -> var[idx])
    sol_dict = get(sol, dict_name, Dict{String,Any}())

    if pm.data["multinetwork"]
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
        sol_item[param_name] = default_value(item)
        try
            variable = extract_var(var(pm, variable_symbol), idx, item)
            sol_item[param_name] = scale(getvalue(variable), item)
        catch
        end
    end
end


"""

    function add_dual(
        sol::Associative,
        pm::GenericPowerModel,
        dict_name::AbstractString,
        param_name::AbstractString,
        con_symbol::Symbol;
        index_name::AbstractString = "index",
        default_value::Function = (item) -> NaN,
        scale::Function = (x,item) -> x,
        extract_con::Function = (con,idx,item) -> con[idx],
    )

This function takes care of adding the values of dual variables to the solution Dict.

# Arguments

- `sol::Associative`: The dict where the desired final details of the solution are stored;
- `pm::GenericPowerModel`: The PowerModel which has been considered;
- `dict_name::AbstractString`: The particular class of items for the solution (e.g. branch, bus);
- `param_name::AbstractString`: The name associated to the dual variable;
- `con_symbol::Symbol`: the Symbol attached to the class of constraints;
- `index_name::AbstractString = "index"`: ;
- `default_value::Function = (item) -> NaN`: a function that assign to each item a default value, for missing data;
- `scale::Function = (x,item) -> x`: a function to rescale the values of the dual variables, if needed;
- `extract_con::Function = (con,idx,item) -> con[idx]`: a method to extract the actual dual variables.

"""
function add_dual(
    sol::Associative,
    pm::GenericPowerModel,
    dict_name::AbstractString,
    param_name::AbstractString,
    con_symbol::Symbol;
    index_name::AbstractString = "index",
    default_value::Function = (item) -> NaN,
    scale::Function = (x,item) -> x,
    extract_con::Function = (con,idx,item) -> con[idx],
)
    sol_dict = get(sol, dict_name, Dict{String,Any}())

    if pm.data["multinetwork"]
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
        sol_item[param_name] = default_value(item)
        try
            constraint = extract_con(con(pm, con_symbol), idx, item)
            sol_item[param_name] = scale(getdual(constraint), item)
        catch
            # info("No constraint: $(con_symbol), $(idx)") # if we want to log this info.
        end
    end
end

solver_status_lookup = Dict{Any, Dict{Symbol, Symbol}}(
    :Ipopt => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible),
    :ConicNonlinearBridge => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible),
    # note that AmplNLWriter.AmplNLSolver is the solver type of bonmin
    :AmplNLWriter => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible)
    )

"translates solver status codes to our status codes"
function solver_status_dict(solver_module_symbol, status)
    for (st, solver_stat_dict) in solver_status_lookup
        if solver_module_symbol == st
            return get(solver_stat_dict, status, status)
        end
    end
    return status
end

""
function guard_getobjbound(model)
    try
        getobjbound(model)
    catch
        -Inf
    end
end
