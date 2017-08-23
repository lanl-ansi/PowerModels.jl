""
function build_solution(pm::GenericPowerModel, status, solve_time; objective = NaN, solution_builder = get_solution)
    # TODO assert that the model is solved

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(Symbol(typeof(pm.model.solver).name.module), status)
    end

    sol = Dict{String,Any}()
    data = Dict{String,Any}()

    sol_nw = sol["nw"] = Dict{String,Any}()
    data_nw = data["nw"] = Dict{String,Any}()

    for (n,nw_data) in pm.data["nw"]
        sol_nw[n] = solution_builder(pm, n)
        data_nw[n] = Dict(
            "name" => nw_data["name"],
            "bus_count" => length(nw_data["bus"]),
            "branch_count" => length(nw_data["branch"])
        )
    end

    solution = Dict{String,Any}(
        "solver" => string(typeof(pm.model.solver)),
        "status" => status,
        "objective" => objective,
        "objective_lb" => guard_getobjbound(pm.model),
        "solve_time" => solve_time,
        "solution" => sol,
        "data" => data,
        "machine" => Dict(
            "cpu" => Sys.cpu_info()[1].model,
            "memory" => string(Sys.total_memory()/2^30, " Gb")
        )
    )

    pm.solution = solution

    return solution
end

""
function init_solution(pm::GenericPowerModel, n::String)
    return Dict{String,Any}(key => pm.data["nw"][n][key] for key in ["per_unit", "baseMVA"])
end

""
function get_solution(pm::GenericPowerModel, n::String)
    sol = init_solution(pm, n)
    add_bus_voltage_setpoint(sol, pm, n)
    add_generator_power_setpoint(sol, pm, n)
    add_branch_flow_setpoint(sol, pm, n)
    add_dcline_flow_setpoint(sol, pm, n)
    return sol
end

""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel, n::String)
    add_setpoint(sol, pm, n, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, n, "bus", "bus_i", "va", :t)
end

""
function add_generator_power_setpoint(sol, pm::GenericPowerModel, n::String)
    add_setpoint(sol, pm, n, "gen", "index", "pg", :pg)
    add_setpoint(sol, pm, n, "gen", "index", "qg", :qg)
end

""
function add_bus_demand_setpoint(sol, pm::GenericPowerModel, n::String)
    add_setpoint(sol, pm, n, "bus", "bus_i", "pd", :pd; default_value = (item) -> item["pd"])
    add_setpoint(sol, pm, n, "bus", "bus_i", "qd", :qd; default_value = (item) -> item["qd"])
end

""
function add_branch_flow_setpoint(sol, pm::GenericPowerModel, n::String)
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
        add_setpoint(sol, pm, n, "branch", "index", "pf", :p; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, n, "branch", "index", "qf", :q; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, n, "branch", "index", "pt", :p; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, n, "branch", "index", "qt", :q; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end

""
function add_dcline_flow_setpoint(sol, pm::GenericPowerModel, n::String)
    add_setpoint(sol, pm, n, "dcline", "index", "pf", :p_dc; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
    add_setpoint(sol, pm, n, "dcline", "index", "qf", :q_dc; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
    add_setpoint(sol, pm, n, "dcline", "index", "pt", :p_dc; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    add_setpoint(sol, pm, n, "dcline", "index", "qt", :q_dc; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
end

""
function add_branch_flow_setpoint_ne(sol, pm::GenericPowerModel, n::String)
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
        add_setpoint(sol, pm, n, "ne_branch", "index", "pf", :p_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, n, "ne_branch", "index", "qf", :q_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, n, "ne_branch", "index", "pt", :p_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, n, "ne_branch", "index", "qt", :q_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end

""
function add_branch_status_setpoint(sol, pm::GenericPowerModel, n::String)
  add_setpoint(sol, pm, n, "branch", "index", "br_status", :line_z; default_value = (item) -> 1)
end

function add_branch_status_setpoint_dc(sol, pm::GenericPowerModel, n::String)
  add_setpoint(sol, pm, n, "dcline", "index", "br_status", :line_z; default_value = (item) -> 1)
end

""
function add_branch_ne_setpoint(sol, pm::GenericPowerModel, n::String)
  add_setpoint(sol, pm, n, "ne_branch", "index", "built", :line_ne; default_value = (item) -> 1)
end

""
function add_setpoint(sol, pm::GenericPowerModel, n::String, dict_name, index_name, param_name, variable_symbol; default_value = (item) -> NaN, scale = (x,item) -> x, extract_var = (var,idx,item) -> var[idx])
    sol_dict = get(sol, dict_name, Dict{String,Any}())
    if length(pm.data["nw"][n][dict_name]) > 0
        sol[dict_name] = sol_dict
    end
    for (i,item) in pm.data["nw"][n][dict_name]
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item[param_name] = default_value(item)
        try
            ns = parse(Int, n)
            var = extract_var(pm.var[:nw][ns][variable_symbol], idx, item)
            sol_item[param_name] = scale(getvalue(var), item)
        catch
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
