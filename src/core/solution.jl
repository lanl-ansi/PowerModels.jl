""
function build_solution(pm::GenericPowerModel, status, solve_time; objective = NaN, solution_builder = get_solution)
    # TODO @assert that the model is solved

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(Symbol(typeof(pm.model.solver).name.module), status)
    end

    sol = init_solution(pm)
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

    solution = Dict(
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
    data_keys = ["per_unit", "baseMVA"]
    return Dict{String,Any}(key => pm.data[key] for key in data_keys)
end

""
function get_solution(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_storage_setpoint(sol, pm)
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

""
function add_sm_duals(sol, pm::GenericPowerModel)
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "duals") && pm.setting["output"]["duals"] == true
        add_dual(sol, pm, "branch", "mu_sm_fr", :sm_fr)
        add_dual(sol, pm, "branch", "mu_sm_to", :sm_to)
    end
end

""
function add_generator_power_setpoint(sol, pm::GenericPowerModel)
    add_setpoint(sol, pm, "gen", "pg", :pg)
    add_setpoint(sol, pm, "gen", "qg", :qg)
end

""
function add_generator_status_setpoint(sol, pm::GenericPowerModel)
    add_setpoint(sol, pm, "gen", "gen_status", :z_gen; conductorless=true, default_value = (item) -> item["gen_status"]*1.0)
end

""
function add_storage_setpoint(sol, pm::GenericPowerModel)
    add_setpoint(sol, pm, "storage", "ps", :ps)
    add_setpoint(sol, pm, "storage", "qs", :qs)
    add_setpoint(sol, pm, "storage", "se", :se, conductorless=true)
    # useful for model debugging
    #add_setpoint(sol, pm, "storage", "sc", :sc, conductorless=true)
    #add_setpoint(sol, pm, "storage", "sd", :sd, conductorless=true)
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



"""
adds setpoint values based on a given default_value function.

this significantly improves performance in models where values are not defined
e.g. the reactive power values in a DC power flow model
"""
function add_setpoint_fixed(
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



"adds values based on JuMP variables"
function add_setpoint(
    sol,
    pm::GenericPowerModel,
    dict_name,
    param_name,
    variable_symbol;
    index_name = "index",
    default_value = (item) -> NaN,
    scale = (x,item,cnd) -> x,
    extract_var = (var,idx,item) -> var[idx],
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
            try
                variable = extract_var(var(pm, pm.cnw, variable_symbol), idx, item)
                sol_item[param_name] = scale(getvalue(variable), item, 1)
            catch
            end
        else
            num_conductors = length(conductor_ids(pm))
            cnd_idx = 1
            sol_item[param_name] = MultiConductorVector{Real}([default_value(item) for i in 1:num_conductors])
            for conductor in conductor_ids(pm)
                try
                    variable = extract_var(var(pm, variable_symbol, cnd=conductor), idx, item)
                    sol_item[param_name][cnd_idx] = scale(getvalue(variable), item, conductor)
                catch
                end
                cnd_idx += 1
            end
        end

        # remove MultiConductorValue, if it was not a ismulticonductor network
        if !ismulticonductor(pm)
            sol_item[param_name] = sol_item[param_name][1]
        end
    end
end


"""

    function add_dual(
        sol::AbstractDict,
        pm::GenericPowerModel,
        dict_name::AbstractString,
        param_name::AbstractString,
        con_symbol::Symbol;
        index_name::AbstractString = "index",
        default_value::Function = (item) -> NaN,
        scale::Function = (x,item,cnd) -> x,
        extract_con::Function = (con,idx,item) -> con[idx],
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
- `extract_con::Function = (con,idx,item) -> con[idx]`: a method to extract the actual dual variables.

"""
function add_dual(
    sol::AbstractDict,
    pm::GenericPowerModel,
    dict_name::AbstractString,
    param_name::AbstractString,
    con_symbol::Symbol;
    index_name::AbstractString = "index",
    default_value::Function = (item) -> NaN,
    scale::Function = (x,item,cnd) -> x,
    extract_con::Function = (con,idx,item) -> con[idx],
    conductorless = false
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
            try
                constraint = extract_con(var(pm, pm.cnw, con_symbol), idx, item)
                sol_item[param_name] = scale(getdual(constraint), item, 1)
            catch
            end
        else
            num_conductors = length(conductor_ids(pm))
            cnd_idx = 1
            sol_item[param_name] = MultiConductorVector(default_value(item), num_conductors)
            for conductor in conductor_ids(pm)
                try
                    constraint = extract_con(con(pm, con_symbol, cnd=conductor), idx, item)
                    sol_item[param_name][cnd_idx] = scale(getdual(constraint), item, conductor)
                catch
                    info(LOGGER, "No constraint: $(con_symbol), $(idx)")
                end
                cnd_idx += 1
            end
        end

        # remove MultiConductorValue, if it was not a ismulticonductor network
        if !ismulticonductor(pm)
            sol_item[param_name] = sol_item[param_name][1]
        end
    end
end


solver_status_lookup = Dict{Any, Dict{Symbol, Symbol}}(
    :Ipopt => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible),
    :Juniper => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible),
    :ConicNonlinearBridge => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible),
    # note that AmplNLWriter.AmplNLSolver is the solver type of bonmin
    :AmplNLWriter => Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible),
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
