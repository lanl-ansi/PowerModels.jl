# stuff that is universal to all power models

export 
    GenericPowerModel,
    setdata, setsolver, solve, getsolution


type PowerDataSets
    ref_bus
    buses
    bus_indexes
    gens
    gen_indexes
    branches
    branch_indexes
    bus_gens
    arcs_from
    arcs_to
    arcs
    bus_branches
    buspairs
    buspair_indexes
end

abstract AbstractPowerModel
abstract AbstractPowerFormulation
abstract AbstractConicPowerFormulation <: AbstractPowerFormulation



type GenericPowerModel{T<:AbstractPowerFormulation} <: AbstractPowerModel
    model::Model
    data::Dict{AbstractString,Any}
    set::PowerDataSets
    setting::Dict{AbstractString,Any}
    solution::Dict{AbstractString,Any}
end


# for setting up the model variables
function init_vars{T}(pm::GenericPowerModel{T}) end

# add model constraints that should be applied universalaly to all models
# a key example being voltage relaxation constraints
function constraint_universal{T}(pm::GenericPowerModel{T}) end

# default generic constructor
function GenericPowerModel{T}(data::Dict{AbstractString,Any}, vars::T; setting = Dict{AbstractString,Any}(), solver = JuMP.UnsetSolver())
    data, sets = process_raw_data(data)

    pm = GenericPowerModel{T}(
        Model(solver = solver), # model
        data, # data
        sets, # sets
        setting, # setting
        Dict{AbstractString,Any}(), # solution
    )

    init_vars(pm)
    constraint_universal(pm)
    return pm
end


function process_raw_data(data::Dict{AbstractString,Any})
    make_per_unit(data)
    unify_transformer_taps(data)
    add_branch_parameters(data)
    standardize_cost_order(data)

    sets = build_sets(data)

    return data, sets
end



#
# Just seems too hard to maintain with the default constructor
#
#function setdata{T}(pm::GenericPowerModel{T}, data::Dict{AbstractString,Any})
#    data, sets = process_raw_data(data)

#    pm.model = Model()
#    pm.set = sets
#    pm.solution = Dict{AbstractString,Any}()
#    pm.data = data

#    init_vars(pm)
#end


# TODO Ask Miles, why do we need to put JuMP. here?  using at top level should bring it in
function setsolver{T}(pm::GenericPowerModel{T}, solver::MathProgBase.AbstractMathProgSolver)
    JuMP.setsolver(pm.model, solver)
end

function solve{T}(pm::GenericPowerModel{T})
    status, solve_sec_elapsed, solve_bytes_alloc, sec_in_gc = @timed JuMP.solve(pm.model)

    build_solution(pm, status; solve_time_alternate = solve_sec_elapsed)
end


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


    arcs_from = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in branch_lookup]
    arcs_to   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in branch_lookup]
    arcs = [arcs_from; arcs_to] 

    bus_gens = [i => [] for (i,bus) in bus_lookup]
    for (i,gen) in gen_lookup
        push!(bus_gens[gen["gen_bus"]], i)
    end

    bus_branches = [i => [] for (i,bus) in bus_lookup]
    for (l,i,j) in arcs_from
        push!(bus_branches[i], (l,i,j))
        push!(bus_branches[j], (l,j,i))
    end

    #ref_bus = [i for (i,bus) in bus_lookup | bus["bus_type"] == 3][1]
    ref_bus = Union{}
    for (k,v) in bus_lookup
        if v["bus_type"] == 3
            ref_bus = k
            break
        end
    end

    bus_idxs = collect(keys(bus_lookup))
    gen_idxs = collect(keys(gen_lookup))
    branch_idxs = collect(keys(branch_lookup))


    buspair_indexes = collect(Set([(i,j) for (l,i,j) in arcs_from]))
    buspairs = buspair_parameters(buspair_indexes, branch_lookup, bus_lookup)  

    return PowerDataSets(ref_bus, bus_lookup, bus_idxs, gen_lookup, gen_idxs, branch_lookup, branch_idxs, bus_gens, arcs_from, arcs_to, arcs, bus_branches, buspairs, buspair_indexes)
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




not_pu = Set(["rate_a","rate_b","rate_c","bs","gs","pd","qd","pg","qg","pmax","pmin","qmax","qmin"])
not_rad = Set(["angmax","angmin","shift","va"])

function make_per_unit(data::Dict{AbstractString,Any})
    if !haskey(data, "perUnit") || data["perUnit"] == false
        make_per_unit(data["baseMVA"], data)
        data["perUnit"] = true
    end
end

function make_per_unit(mva_base::Number, data::Dict{AbstractString,Any})
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

function make_per_unit(mva_base::Number, data::Array{Any,1})
    for item in data
        make_per_unit(mva_base, item)
    end
end

function make_per_unit(mva_base::Number, data::AbstractString)
    #nothing to do
    #println("$(parent) $(data)")
end

function make_per_unit(mva_base::Number, data::Number)
    #nothing to do
    #println("$(parent) $(data)")
end

function unify_transformer_taps(data::Dict{AbstractString,Any})
    for branch in data["branch"]
        if branch["tap"] == 0.0
            branch["tap"] = 1.0
        end
    end
end



# NOTE, this function assumes all values are p.u. and angles are in radians
function add_branch_parameters(data :: Dict{AbstractString,Any})
    min_theta_delta = calc_min_phase_angle(data)
    max_theta_delta = calc_max_phase_angle(data)

    for branch in data["branch"]
        r = branch["br_r"]
        x = branch["br_x"]
        tap_ratio = branch["tap"]
        angle_shift = branch["shift"]

        branch["g"] =  r/(x^2 + r^2)
        branch["b"] = -x/(x^2 + r^2)
        branch["tr"] = tap_ratio*cos(angle_shift)
        branch["ti"] = tap_ratio*sin(angle_shift)

        branch["off_angmin"] = min_theta_delta
        branch["off_angmax"] = max_theta_delta
    end
end


function calc_max_phase_angle(data :: Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    angle_max = [branch["angmax"] for branch in data["branch"]]
    sort!(angle_max, rev=true)

    return sum(angle_max[1:bus_count-1])
end

function calc_min_phase_angle(data :: Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    angle_min = [branch["angmin"] for branch in data["branch"]]
    sort!(angle_min)

    return sum(angle_min[1:bus_count-1])
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



