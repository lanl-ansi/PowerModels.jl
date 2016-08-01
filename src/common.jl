
not_pu = Set(["rate_a","rate_b","rate_c","bs","gs","pd","qd","pg","qg","pmax","pmin","qmax","qmin"])
not_rad = Set(["angmax","angmin","shift","va"])

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




function make_per_unit(data :: Dict{AbstractString,Any})
    make_per_unit(data["baseMVA"], data)
end

function make_per_unit(mva_base :: Number, data :: Dict{AbstractString,Any})
    for k in keys(data)
        if k == "gencost"
            for cost_model in data[k]
                if cost_model["model"] != 2
                    println("WARNING: Skipping generator cost model of tpye other than 2")
                    continue
                end
                degree = length(cost_model["cost"])
                for (i, item) in enumerate(cost_model["cost"])
                    cost_model["cost"][i] = item*mva_base^(degree-i)
                end
            end
        elseif isa(data[k], Number)
            if k in not_pu
                data[k] = data[k]/mva_base
            end
            if k in not_rad
                data[k] = pi*data[k]/180.0
            end
            #println("$(k) $(data[k])")
        else
            make_per_unit(mva_base, data[k])
        end
    end
end

function make_per_unit(mva_base :: Number, data :: Array{Any,1})
    for item in data
        make_per_unit(mva_base, item)
    end
end

function make_per_unit(mva_base :: Number, data :: AbstractString)
    #nothing to do
    #println("$(parent) $(data)")
end

function make_per_unit(mva_base :: Number, data :: Number)
    #nothing to do
    #println("$(parent) $(data)")
end


function unify_transformer_taps(data :: Dict{AbstractString,Any})
    for branch in data["branch"]
        if branch["tap"] == 0.0
            branch["tap"] = 1.0
        end
    end
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


function build_sets(data :: Dict{AbstractString,Any})
    bus_lookup = [ Int(bus["index"]) => bus for bus in data["bus"] ]
    gen_lookup = [ Int(gen["index"]) => gen for gen in data["gen"] ]
    for gencost in data["gencost"]
        i = Int(gencost["index"])
        gen_lookup[i] = merge(gen_lookup[i], gencost)
    end
    branch_lookup = [ Int(branch["index"]) => branch for branch in data["branch"] ]

    # filter turned off stuff 
    bus_lookup = filter((i, bus) -> bus["bus_type"] != 4, bus_lookup)
    gen_lookup = filter((i, gen) -> gen["gen_status"] == 1 && gen["gen_bus"] in keys(bus_lookup), gen_lookup)
    branch_lookup = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(bus_lookup) && branch["t_bus"] in keys(bus_lookup), branch_lookup)

    bus_gens = [i => [] for (i,bus) in bus_lookup]
    for (i,gen) in gen_lookup
        push!(bus_gens[gen["gen_bus"]], i)
    end

    arcs_from = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in branch_lookup]
    arcs_to   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in branch_lookup]
    arcs = [arcs_from; arcs_to] 

    #ref_bus = [i for (i,bus) in bus_lookup | bus["bus_type"] == 3][1]
    ref_bus = Union{}
    for (k,v) in bus_lookup
        if v["bus_type"] == 3
            ref_bus = k
            break
        end
    end

    return ref_bus, bus_lookup, gen_lookup, branch_lookup, bus_gens, arcs_from, arcs_to, arcs
end


# compute bus pair level structures
function buspair_parameters(buspair_indexes, branches, buses)
    bp_angmin = [bp => -Inf for bp in buspair_indexes] 
    bp_angmax = [bp =>  Inf for bp in buspair_indexes] 
    bp_line = [bp => Inf for bp in buspair_indexes]

    for (l,branch) in branches
        i = branch["f_bus"]
        j = branch["t_bus"]

        bp_angmin[(i,j)] = max(bp_angmin[(i,j)], branch["angmin"])
        bp_angmax[(i,j)] = min(bp_angmax[(i,j)], branch["angmax"])
        bp_line[(i,j)] = min(bp_line[(i,j)], l)
    end

    buspairs = [(i,j) => Dict(
        "line"=>bp_line[(i,j)], 
        "angmin"=>bp_angmin[(i,j)], 
        "angmax"=>bp_angmax[(i,j)],
        "rate_a"=>branches[bp_line[(i,j)]]["rate_a"],
        "tap"=>branches[bp_line[(i,j)]]["tap"],
        "v_from_min"=>buses[i]["vmin"],
        "v_from_max"=>buses[i]["vmax"],
        "v_to_min"=>buses[j]["vmin"],
        "v_to_max"=>buses[j]["vmax"]
        ) for (i,j) in buspair_indexes]
    return buspairs
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
