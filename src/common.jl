# TODO figure out how to do this properly, stronger types?
#importall MathProgBase.SolverInterface
solver_status_lookup = Dict{Any, Dict{Symbol, Symbol}}()


if (Pkg.installed("Ipopt") != nothing)
  using Ipopt
  solver_status_lookup[Ipopt.IpoptSolver] = Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible)
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





# NOTE, this function assumes all values are p.u. and angles are in radians
function add_branch_parameters(data :: Dict{AbstractString,Any})
    for branch in data["branch"]
        r = branch["br_r"]
        x = branch["br_x"]
        tap_ratio = branch["tap"]
        angle_shift = branch["shift"]

        branch["g"] =  r/(x^2 + r^2)
        branch["b"] = -x/(x^2 + r^2)
        branch["tr"] = tap_ratio*cos(angle_shift)
        branch["ti"] = tap_ratio*sin(angle_shift)
    end
end


function standardize_cost_order(data :: Dict{AbstractString,Any})
    for gencost in data["gencost"]
        if gencost["model"] == 2 && length(gencost["cost"]) < 3
            println("std gen cost: ",gencost["cost"])
            cost_3 = [zeros(1,3 - length(gencost["cost"])); gencost["cost"]]
            gencost["cost"] = cost_3
            println("   ",gencost["cost"])
        end
    end
end





function calc_max_phase_angle(buses, branches)
    bus_count = length(buses)
    angle_max = [b["angmax"] for (idx,b) in branches]
    sort!(angle_max, rev=true)

    return sum(angle_max[1:bus_count-1])
end

function calc_min_phase_angle(buses, branches)
    bus_count = length(buses)
    angle_min = [b["angmin"] for (idx,b) in branches]
    sort!(angle_min)

    return sum(angle_min[1:bus_count-1])
end


function eval_sol(sol)
    for (k,v) in sol
        if isa(v, Dict)
            eval_sol(v)
        else
            if isa(v, Function)
                sol[k] = v()
            end
        end
    end
end

function add_bus_voltage_setpoint(sol, data, v_val, t_val)

    sol_buses = "None"
    if !haskey(sol, "bus")
        sol_buses = Dict{Int,Any}()
        sol["bus"] = sol_buses
    else
        sol_buses = sol["bus"]
    end

    for bus in data["bus"]
        idx = Int(bus["bus_i"])

        sol_bus = "None"
        if !haskey(sol_buses, idx)
            sol_bus = Dict{AbstractString,Any}()
            sol_buses[idx] = sol_bus
        else
            sol_bus = sol_buses[idx]
        end
        sol_bus["vm"] = () -> NaN
        sol_bus["va"] = () -> NaN

        if bus["bus_type"] != 4
            sol_bus["vm"] = () -> v_val(idx)
            sol_bus["va"] = () -> t_val(idx)*180/pi
        end
    end

end

function add_bus_demand_setpoint(sol, data, pd_val, qd_val)
    mva_base = data["baseMVA"]

    sol_buses = "None"
    if !haskey(sol, "bus")
        sol_buses = Dict{Int,Any}()
        sol["bus"] = sol_buses
    else
        sol_buses = sol["bus"]
    end

    for bus in data["bus"]
        idx = Int(bus["bus_i"])

        sol_bus = "None"
        if !haskey(sol_buses, idx)
            sol_bus = Dict{AbstractString,Any}()
            sol_buses[idx] = sol_bus
        else
            sol_bus = sol_buses[idx]
        end
        sol_bus["pd"] = () -> NaN
        sol_bus["qd"] = () -> NaN

        if bus["bus_type"] != 4
            sol_bus["pd"] = () -> pd_val(idx)*mva_base
            sol_bus["qd"] = () -> qd_val(idx)*mva_base
        end
    end

end

function add_generator_power_setpoint(sol, data, pg_val, qg_val)
    mva_base = data["baseMVA"]

    sol_gens = "None"
    if !haskey(sol, "gen")
        sol_gens = Dict{Int,Any}()
        sol["gen"] = sol_gens
    else
        sol_gens = sol["gen"]
    end

    for gen in data["gen"]
        idx = Int(gen["index"])
        
        sol_gen = "None"
        if !haskey(sol_gens, idx)
            sol_gen = Dict{AbstractString,Any}()
            sol_gens[idx] = sol_gen
        else
            sol_gen = sol_gens[idx]
        end
        sol_gen["pg"] = () -> NaN
        sol_gen["qg"] = () -> NaN

        if gen["gen_status"] == 1
            sol_gen["pg"] = () -> pg_val(idx)*mva_base
            sol_gen["qg"] = () -> qg_val(idx)*mva_base
        end
    end

end


function add_generator_status_setpoint(sol, data, z_val)

    sol_gens = "None"
    if !haskey(sol, "gen")
        sol_gens = Dict{Int,Any}()
        sol["gen"] = sol_gens
    else
        sol_gens = sol["gen"]
    end

    for gen in data["gen"]
        idx = Int(gen["index"])
        
        sol_gen = "None"
        if !haskey(sol_gens, idx)
            sol_gen = Dict{AbstractString,Any}()
            sol_gens[idx] = sol_gen
        else
            sol_gen = sol_gens[idx]
        end
        sol_gen["gen_status"] = () -> gen["gen_status"]

        if Int(gen["gen_status"]) == 1
            sol_gen["gen_status"] = () -> z_val(idx)
        end
    end

end


function add_branch_status_setpoint(sol, data, z_val)

    sol_branches = "None"
    if !haskey(sol, "branch")
        sol_branches = Dict{Int,Any}()
        sol["branch"] = sol_branches
    else
        sol_branches = sol["branch"]
    end

    for branch in data["branch"]
        idx = Int(branch["index"])
        
        sol_branch = "None"
        if !haskey(sol_branches, idx)
            sol_branch = Dict{AbstractString,Any}()
            sol_branches[idx] = sol_branch
        else
            sol_branch = sol_branches[idx]
        end
        sol_branch["br_status"] = () -> branch["br_status"]

        if Int(branch["br_status"]) == 1
            sol_branch["br_status"] = () -> z_val(idx)
        end
    end

end


function add_branch_flow_setpoint(sol, data, settings, p_fr_val, q_fr_val, p_to_val, q_to_val)
    mva_base = data["baseMVA"]

    # check the line flows were requested
    if haskey(settings, "output") && haskey(settings["output"], "line_flows") && settings["output"]["line_flows"] == true

        sol_branches = "None"
        if !haskey(sol, "branch")
            sol_branches = Dict{Int,Any}()
            sol["branch"] = sol_branches
        else
            sol_branches = sol["branch"]
        end

        for branch in data["branch"]
            idx = Int(branch["index"])
            
            sol_branch = "None"
            if !haskey(sol_branches, idx)
                sol_branch = Dict{AbstractString,Any}()
                sol_branches[idx] = sol_branch
            else
                sol_branch = sol_branches[idx]
            end
            sol_branch["br_status"] = () -> 0.111

            sol_branch["p_from"] = () -> NaN
            sol_branch["q_from"] = () -> NaN
            sol_branch["p_to"] = () -> NaN
            sol_branch["q_to"] = () -> NaN

            if Int(branch["br_status"]) == 1
                sol_branch["p_from"] = () -> p_fr_val(idx)*mva_base
                sol_branch["q_from"] = () -> q_fr_val(idx)*mva_base
                sol_branch["p_to"] = () -> p_to_val(idx)*mva_base
                sol_branch["q_to"] = () -> q_to_val(idx)*mva_base
            end
        end

    end
end

function add_default_start_values(data, indexes, tag, value)
  for i in indexes
    if !haskey(data[i],tag) 
      data[i][tag] = value
    end
  end  
end
