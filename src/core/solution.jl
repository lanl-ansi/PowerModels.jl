
function build_solution{T}(pm::GenericPowerModel{T}, status, solve_time; objective = NaN, solution_builder = get_solution)
    # TODO assert that the model is solved

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(typeof(pm.model.solver), status)
    end

    solution = Dict{AbstractString,Any}(
        "solver" => string(typeof(pm.model.solver)), 
        "status" => status, 
        "objective" => objective, 
        "objective_lb" => guard_getobjbound(pm.model),
        "solve_time" => solve_time,
        "solution" => solution_builder(pm),
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

function get_solution{T}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    return sol
end

function add_bus_voltage_setpoint{T}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t; scale = (x,item) -> x*180/pi)
end

function add_generator_power_setpoint{T}(sol, pm::GenericPowerModel{T})
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "gen", "index", "pg", :pg; scale = (x,item) -> x*mva_base)
    add_setpoint(sol, pm, "gen", "index", "qg", :qg; scale = (x,item) -> x*mva_base)
end

function add_bus_demand_setpoint{T}(sol, pm::GenericPowerModel{T})
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "bus", "bus_i", "pd", :pd; default_value = (item) -> item["pd"]*mva_base, scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> ())
    add_setpoint(sol, pm, "bus", "bus_i", "qd", :qd; default_value = (item) -> item["qd"]*mva_base, scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> ())
end

function add_branch_flow_setpoint{T}(sol, pm::GenericPowerModel{T})
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
        mva_base = pm.data["baseMVA"]

        add_setpoint(sol, pm, "branch", "index", "p_from", :p; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "index", "q_from", :q; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "index",   "p_to", :p; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, "branch", "index",   "q_to", :q; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end

function add_branch_status_setpoint{T}(sol, pm::GenericPowerModel{T})
  add_setpoint(sol, pm, "branch", "index", "br_status", :line_z; default_value = (item) -> 1)
end

function add_setpoint{T}(sol, pm::GenericPowerModel{T}, dict_name, index_name, param_name, variable_symbol; default_value = (item) -> NaN, scale = (x,item) -> x, extract_var = (var,idx,item) -> var[idx])
    sol_dict = nothing
    if !haskey(sol, dict_name)
        sol_dict = Dict{Int,Any}()
        sol[dict_name] = sol_dict
    else
        sol_dict = sol[dict_name]
    end

    for item in pm.data[dict_name]
        idx = Int(item[index_name])

        sol_item = nothing
        if !haskey(sol_dict, idx)
            sol_item = Dict{AbstractString,Any}()
            sol_dict[idx] = sol_item
        else
            sol_item = sol_dict[idx]
        end
        sol_item[param_name] = default_value(item)

        try
            var = extract_var(getvariable(pm.model, variable_symbol), idx, item)
            sol_item[param_name] = scale(getvalue(var), item)
        catch
        end
    end
end



# TODO figure out how to do this properly, stronger types?
#importall MathProgBase.SolverInterface
solver_status_lookup = Dict{Any, Dict{Symbol, Symbol}}()

if (Pkg.installed("Ipopt") != nothing)
    using Ipopt
    solver_status_lookup[Ipopt.IpoptSolver] = Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible)
end

if (Pkg.installed("ConicNonlinearBridge") != nothing)
    using ConicNonlinearBridge
    solver_status_lookup[ConicNonlinearBridge.ConicNLPWrapper] = Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible)
end

if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)
    # note that AmplNLWriter.AmplNLSolver is the solver type of bonmin
    using AmplNLWriter
    using CoinOptServices
    solver_status_lookup[AmplNLWriter.AmplNLSolver] = Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible)
end

# translates solver status codes to our status codes
function solver_status_dict(solver_type, status)
    for (st, solver_stat_dict) in solver_status_lookup
        if solver_type == st
            if status in keys(solver_stat_dict)
                return solver_stat_dict[status]
            else
                return status
            end
        end
    end
    return status
end

function guard_getobjbound(model)
    try
        getobjbound(model)
    catch
        -Inf
    end
end



