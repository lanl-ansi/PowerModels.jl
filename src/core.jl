# stuff that is universal to all power models

export 
    WRPowerModel, GenericPowerModel,
    WRData,
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
end

abstract AbstractPowerModel

type GenericPowerModel{T} <: AbstractPowerModel
    model::Model
    data::Dict{AbstractString,Any}
    set::PowerDataSets
    setting::Dict{AbstractString,Any}
    solution::Dict{AbstractString,Any}
    ext::T
end

# default generic constructor
function GenericPowerModel{T}(data::Dict{AbstractString,Any}, ext::T; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    make_per_unit(data)
    unify_transformer_taps(data)
    add_branch_parameters(data)
    standardize_cost_order(data)

    sets = build_sets(data)

    return GenericPowerModel{T}(
        Model(), # model
        data, # data
        sets, # sets
        setting, # setting
        Dict{AbstractString,Any}(), # solution
        ext # extension
    )
end


type WRData end
typealias WRPowerModel GenericPowerModel{WRData}

# default WR constructor
function WRPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}(), ext::WRData = WRData())
    return GenericPowerModel(data, ext; setting = setting)
end



#function testit(val::ACPPowerModel)
#    println("AC Model!")
#    typeof(val)
#end

#function testit(val::DCPPowerModel)
#    println("DC Model!")
#    typeof(val)
#end

#function testit{T}(val::GenericPowerModel{T})
#    println("Any Model!")
#    typeof(val)
#    typeof(T)
#end


function setdata{T}(pm::GenericPowerModel{T}, data::Dict{AbstractString,Any})
    make_per_unit(data)
    unify_transformer_taps(data)
    add_branch_parameters(data)
    standardize_cost_order(data)

    sets = build_sets(data)

    pm.model = Model()
    pm.set = sets
    pm.solution = Dict{AbstractString,Any}()
    pm.data = data
end

# TODO Ask Miles, why do we need to put JuMP here?  using at top level should bring it in
function setsolver{T}(pm::GenericPowerModel{T}, solver::MathProgBase.AbstractMathProgSolver)
    JuMP.setsolver(pm.model, solver)
end

function getsolution{T}(pm::GenericPowerModel{T})
    return Dict{AbstractString,Any}()
end


function solve{T}(pm::GenericPowerModel{T})

    status, solve_sec_elapsed, solve_bytes_alloc, sec_in_gc = @timed JuMP.solve(pm.model)

    objective = NaN
    solve_time = NaN

    if status != :Error
        objective = getobjectivevalue(pm.model)
        status = solver_status_dict(typeof(pm.model.solver), status)
        solve_time = solve_sec_elapsed
    end

    results = Dict{AbstractString,Any}(
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

    pm.solution = results
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

    bus_idxs = collect(keys(bus_lookup))
    gen_idxs = collect(keys(gen_lookup))
    branch_idxs = collect(keys(branch_lookup))

    return PowerDataSets(ref_bus, bus_lookup, bus_idxs, gen_lookup, gen_idxs, branch_lookup, branch_idxs, bus_gens, arcs_from, arcs_to, arcs)
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
