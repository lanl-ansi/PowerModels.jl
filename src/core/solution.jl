
function build_solution{T}(pm::GenericPowerModel{T}, status; objective = NaN, solve_time_override = NaN, solve_time_alternate = NaN)
    # TODO assert that the model is solved

    solve_time = NaN

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(typeof(pm.model.solver), status)

        if !isnan(solve_time_override)
            solve_time = solve_time_override
        else
            try
                solve_time = getsolvetime(pm.model)
            catch
                warn("there was an issue with getsolvetime() on the solver, falling back on @timed.  This is not a rigorous timing value.");
                solve_time = solve_time_alternate
            end
        end
    end

    solution = Dict{AbstractString,Any}(
        "solver" => string(typeof(pm.model.solver)), 
        "status" => status, 
        "objective" => objective, 
        "objective_lb" => guard_getobjbound(pm.model),
        "solve_time" => solve_time,
        "solution" => getsolution(pm),
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

function getsolution{T}(pm::GenericPowerModel{T})
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










#=

export run_power_model, run_power_model_file, run_power_model_string, run_power_model_dict

function run_power_model(file, model_builder, solver, model_settings = Dict())
    tic()
    result = run_power_model_file(file, model_builder, solver, model_settings)
    run_time = toc()

    #TODO make this consistent with CLI
    println("//START_JSON//")
    JSON.print(result)
    println()
    println("//END_JSON//")

    if result["status"] != :Error
        println("solve results...")

        println("Solution: ")
        #TODO make this print nicer
        dump(result["solution"])
        println()

        println("Objective Val: ", result["objective"])
        println("Solver Status: ", result["status"])
        println("Solve Time:    ", result["solve_time"])
        println("Run Time:      ", run_time)

        println("DATA, $(result["data"]["name"]), $(result["data"]["bus_count"]), $(result["data"]["branch_count"]), $(result["objective"]), $(result["solve_time"]), $(result["objective_lb"])")

    end

    println("done")
    return result
end


function run_power_model_file(file, model_builder, solver, model_settings = Dict())
    println("working on: ", file)

    data_string = readall(open(file))

    matpower = false
    # TODO make this cleaner
    str_len = length(file)
    matpower = (file[str_len-1:str_len] == ".m")

    return run_power_model_string(data_string, model_builder, solver, model_settings, matpower)
end

function run_power_model_string(data_string, model_builder, solver, model_settings = Dict(), matpower = false)
    println("parsing data string...")
    if matpower
        data = parse_matpower(data_string)
    else
        data = JSON.parse(data_string, dicttype = Dict{AbstractString,Any})
    end
    run_power_model_dict(data, model_builder, solver, model_settings)
end


function run_power_model_dict(data, model_builder, solver, model_settings = Dict())
    println("prepare data for solve...")
    initial_mva_base = data["baseMVA"]
    make_per_unit(data)
    unify_transformer_taps(data)
    add_branch_parameters(data)
    standardize_cost_order(data)

    println("building model with: ", model_builder)

    model, abstract_sol = model_builder(data, model_settings)

    # This is VERY slow
    #println(model)

    println("solve model...")

    setsolver(model, solver)
    status, solve_sec_elapsed, solve_bytes_alloc, sec_in_gc = @timed solve(model)

    solution = Dict{AbstractString,Any}()
    objective = NaN
    solve_time = NaN

    #println(typeof(bus_v))

    if status != :Error
        objective = getobjectivevalue(model)
        status = solver_status_dict(typeof(solver), status)
        solve_time = solve_sec_elapsed
        eval_sol(abstract_sol)
        solution = abstract_sol
    end

    results = Dict{AbstractString,Any}(
        "solver" => string(typeof(solver)), 
        "status" => status, 
        "objective" => objective, 
        "objective_lb" => guard_getobjbound(model),
        "solve_time" => solve_time,
        "solution" => solution,
        "machine" => Dict(
            "cpu" => Sys.cpu_info()[1].model,
            "memory" => string(Sys.total_memory()/2^30, " Gb")
            ),
        "data" => Dict(
            "name" => data["name"],
            "bus_count" => length(data["bus"]),
            "branch_count" => length(data["branch"])
            )
        )

    return results
end

=#




