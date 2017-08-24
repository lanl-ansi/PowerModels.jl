""
function build_solution(pm::GenericPowerModel, status, solve_time; objective = NaN, solution_builder = get_solution)
    # TODO assert that the model is solved

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(Symbol(typeof(pm.model.solver).name.module), status)
    end

    sol = solution_builder(pm)

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
        "data" => Dict(
            "name" => pm.data["name"],
            "bus_count" => length(pm.data["bus"]),
            "branch_count" => length(pm.data["branch"])
            )
        )

    pm.solution = solution

    return solution
end

""
function init_solution(pm::GenericPowerModel)
    return Dict{String,Any}(key => pm.data[key] for key in ["per_unit", "baseMVA"])
end

""
function get_solution(pm::GenericPowerModel)
    sol = init_solution(pm)
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_dcline_flow_setpoint(sol, pm)
    add_branch_shift_setpoint(sol, pm)
    add_branch_tap_setpoint(sol, pm)
    return sol
end

""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel)
    add_setpoint(sol, pm, "bus", "vm", :vm)
    add_setpoint(sol, pm, "bus", "va", :va)
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
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
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
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
        add_setpoint(sol, pm, "ne_branch", "pf", :p_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "ne_branch", "qf", :q_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "ne_branch", "pt", :p_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, "ne_branch", "qt", :q_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end

""
function add_branch_status_setpoint(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "branch", "br_status", :line_z; default_value = (item) -> 1)
end

function add_branch_status_setpoint_dc(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "dcline", "br_status", :line_z; default_value = (item) -> 1)
end

""
function add_branch_shift_setpoint(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "branch", "index", "shiftf", :t_shift; extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])], default_value = (item) -> 0)
  add_setpoint(sol, pm, "branch", "index", "shiftt", :t_shift; extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])], default_value = (item) -> 0)
end

""
function add_branch_tap_setpoint(sol, pm::GenericPowerModel)
    dict_name = "branch"
    index_name = "index"
    sol_dict = get(sol, dict_name, Dict{String,Any}())
    if length(pm.data[dict_name]) > 0
        sol[dict_name] = sol_dict
    end
    for (i,item) in pm.data[dict_name]
        idx = Int(item[index_name])
        fbus = Int(item["f_bus"])
        tbus = Int(item["t_bus"])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item["tapf"] = 1
        sol_item["tapt"] = 1
        try
            extract_vtap_fr = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])]
            extract_vtap_to = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])]
            vtap_fr = getvalue(extract_vtap_fr(pm.var[:vtap], idx, item))
            vtap_to = getvalue(extract_vtap_to(pm.var[:vtap], idx, item))
            vf = getvalue(pm.var[:v])[fbus]
            vt = getvalue(pm.var[:v])[tbus]
            sol_item["tapf"] = vf / vtap_fr
            sol_item["tapt"] = vt / vtap_to
        catch
        end
    end
end

""
function add_branch_ne_setpoint(sol, pm::GenericPowerModel)
  add_setpoint(sol, pm, "ne_branch", "built", :line_ne; default_value = (item) -> 1)
end

""
function add_setpoint(sol, pm::GenericPowerModel, dict_name, param_name, variable_symbol; index_name = "index", default_value = (item) -> NaN, scale = (x,item) -> x, extract_var = (var,idx,item) -> var[idx])
    sol_dict = get(sol, dict_name, Dict{String,Any}())
    if length(pm.data[dict_name]) > 0
        sol[dict_name] = sol_dict
    end
    for (i,item) in pm.data[dict_name]
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item[param_name] = default_value(item)
        try
            var = extract_var(pm.var[variable_symbol], idx, item)
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
