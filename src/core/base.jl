# stuff that is universal to all power models

export
    GenericPowerModel,
    setdata, setsolver, solve

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

#end

# TODO Ask Miles, why do we need to put JuMP. here?  using at top level should bring it in
function JuMP.setsolver(pm::GenericPowerModel, solver::MathProgBase.AbstractMathProgSolver)
    setsolver(pm.model, solver)
end

function JuMP.solve(pm::GenericPowerModel)
    status, solve_time, solve_bytes_alloc, sec_in_gc = @timed solve(pm.model)

    try
        solve_time = getsolvetime(pm.model)
    catch
        warn("there was an issue with getsolvetime() on the solver, falling back to @timed.  This is not a rigorous timing value.")
    end

    return status, solve_time
end

function run_generic_model(file, model_constructor, solver, post_method; solution_builder = get_solution, kwargs...)
    data = PowerModels.parse_file(file)

    pm = model_constructor(data; solver = solver, kwargs...)

    post_method(pm)

    status, solve_time = solve(pm)

    return build_solution(pm, status, solve_time; solution_builder = solution_builder)
end

function build_sets(data::Dict{AbstractString,Any})
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
                    warn("Skipping generator cost model of type other than 2")
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
function add_branch_parameters(data::Dict{AbstractString,Any})
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

function standardize_cost_order(data::Dict{AbstractString,Any})
    for gencost in data["gencost"]
        if gencost["model"] == 2 && length(gencost["cost"]) < 3
            println("std gen cost: ",gencost["cost"])
            cost_3 = [zeros(1,3 - length(gencost["cost"])); gencost["cost"]]
            gencost["cost"] = cost_3
            println("   ",gencost["cost"])
        end
    end
end

function calc_max_phase_angle(data::Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    angle_max = [branch["angmax"] for branch in data["branch"]]
    sort!(angle_max, rev=true)

    return sum(angle_max[1:bus_count-1])
end

function calc_min_phase_angle(data::Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    angle_min = [branch["angmin"] for branch in data["branch"]]
    sort!(angle_min)

    return sum(angle_min[1:bus_count-1])
end
