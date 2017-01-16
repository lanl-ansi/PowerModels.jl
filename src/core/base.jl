# stuff that is universal to all power models

export
    GenericPowerModel,
    setdata, setsolver, solve

type TNEPDataSets
    branches
    arcs_from
    arcs_to
    arcs
    bus_arcs
    buspairs
end


abstract AbstractPowerModel
abstract AbstractPowerFormulation
abstract AbstractConicPowerFormulation <: AbstractPowerFormulation

type GenericPowerModel{T<:AbstractPowerFormulation} <: AbstractPowerModel
    model::Model
    data::Dict{AbstractString,Any}
    setting::Dict{AbstractString,Any}
    solution::Dict{AbstractString,Any}

    ref::Dict{Symbol,Any}

    # Extension dictionary
    # Extensions should define a type to hold information particular to
    # their functionality, and store an instance of the type in this
    # dictionary keyed on an extension-specific symbol
    ext::Dict{Symbol,Any}
end

# default generic constructor
function GenericPowerModel{T}(data::Dict{AbstractString,Any}, vars::T; setting = Dict{AbstractString,Any}(), solver = JuMP.UnsetSolver(), data_processor = process_raw_mp_data)
    data, ref, ext = data_processor(data)
    pm = GenericPowerModel{T}(
        Model(solver = solver), # model
        data, # data
        setting, # setting
        Dict{AbstractString,Any}(), # solution
        ref, # sets
        ext # ext
    )

    return pm
end

function process_raw_mp_data(data::Dict{AbstractString,Any})
    ref = build_ref(data)

    ext = Dict{Symbol,Any}()

    return data, ref, ext
end

function process_raw_mp_ne_data(data::Dict{AbstractString,Any})
    ref = build_ref(data)
    ne_sets = build_ne_sets(data)

    ext = Dict{Symbol,Any}()
    ext[:ne] = ne_sets

    return data, ref, ext
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
        warn("there was an issue with getsolvetime() on the solver, falling back on @timed.  This is not a rigorous timing value.");
    end

    return status, solve_time
end


# if the user passed a file name load into Dict
#function run_generic_model(file::AbstractString, model_constructor, solver, post_method; solution_builder = get_solution, kwargs...)
#    data = PowerModels.parse_file(file)
#    return run_generic_model(data, model_constructor, solver, post_method; solution_builder = solution_builder, kwargs...)
#end

function run_generic_model(file::AbstractString, args...; kwargs...)
    data = PowerModels.parse_file(file)
    return run_generic_model(data, args...; kwargs...)
end

# core run function assumes network data is given as a Dict
function run_generic_model(data::Dict{AbstractString,Any}, model_constructor, solver, post_method; solution_builder = get_solution, kwargs...)
    pm = model_constructor(data; solver = solver, kwargs...)

    post_method(pm)

    status, solve_time = solve(pm)

    return build_solution(pm, status, solve_time; solution_builder = solution_builder)
end

function build_ref(data::Dict{AbstractString,Any})
    ref = Dict{Symbol,Any}()
    for (key, item) in data
        if isa(item, Array)
            item_lookup = Dict([(Int(value["index"]), value) for value in item])
            ref[Symbol(key)] = item_lookup
        end
    end

    if haskey(ref, :gencost)
        for (i, gencost) in ref[:gencost]
            merge!(ref[:gen][i], gencost)
        end
    end

    # filter turned off stuff
    ref[:bus] = filter((i, bus) -> bus["bus_type"] != 4, ref[:bus])
    ref[:gen] = filter((i, gen) -> gen["gen_status"] == 1 && gen["gen_bus"] in keys(ref[:bus]), ref[:gen])
    ref[:branch] = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(ref[:bus]) && branch["t_bus"] in keys(ref[:bus]), ref[:branch])

    ref[:arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:branch]]
    ref[:arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:branch]]
    ref[:arcs] = [ref[:arcs_from]; ref[:arcs_to]]

    bus_gens = Dict([(i, []) for (i,bus) in ref[:bus]])
    for (i,gen) in ref[:gen]
        push!(bus_gens[gen["gen_bus"]], i)
    end
    ref[:bus_gens] = bus_gens

    bus_arcs = Dict([(i, []) for (i,bus) in ref[:bus]])
    for (l,i,j) in ref[:arcs]
        push!(bus_arcs[i], (l,i,j))
    end
    ref[:bus_arcs] = bus_arcs

    ref_bus = Union{}
    for (k,v) in ref[:bus]
        if v["bus_type"] == 3
            ref_bus = k
            break
        end
    end
    ref[:ref_bus] = ref_bus

    ref[:buspairs] = buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus])

    return ref
end

function build_ne_sets(data::Dict{AbstractString,Any})    
    bus_lookup = Dict([(Int(bus["index"]), bus) for bus in data["bus"]])
    branch_lookup = Dict([(Int(branch["index"]), branch) for branch in data["ne_branch"]])

    # filter turned off stuff
    bus_lookup = filter((i, bus) -> bus["bus_type"] != 4, bus_lookup)
    branch_lookup = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(bus_lookup) && branch["t_bus"] in keys(bus_lookup), branch_lookup)

    arcs_from = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in branch_lookup]
    arcs_to   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in branch_lookup]
    arcs = [arcs_from; arcs_to]

    bus_arcs = Dict([(i, []) for (i,bus) in bus_lookup])
    for (l,i,j) in arcs_from
        push!(bus_arcs[i], (l,i,j))
        push!(bus_arcs[j], (l,j,i))
    end

    buspairs = buspair_parameters(arcs_from, branch_lookup, bus_lookup)

    return TNEPDataSets(branch_lookup, arcs_from, arcs_to, arcs, bus_arcs, buspairs)
end


# compute bus pair level structures
function buspair_parameters(arcs_from, branches, buses)
    buspair_indexes = collect(Set([(i,j) for (l,i,j) in arcs_from]))

    bp_angmin = Dict([(bp, -Inf) for bp in buspair_indexes])
    bp_angmax = Dict([(bp, Inf) for bp in buspair_indexes])
    bp_line = Dict([(bp, Inf) for bp in buspair_indexes])

    for (l,branch) in branches
        i = branch["f_bus"]
        j = branch["t_bus"]

        bp_angmin[(i,j)] = max(bp_angmin[(i,j)], branch["angmin"])
        bp_angmax[(i,j)] = min(bp_angmax[(i,j)], branch["angmax"])
        bp_line[(i,j)] = min(bp_line[(i,j)], l)
    end

    buspairs = Dict([((i,j), Dict(
        "line"=>bp_line[(i,j)],
        "angmin"=>bp_angmin[(i,j)],
        "angmax"=>bp_angmax[(i,j)],
        "rate_a"=>branches[bp_line[(i,j)]]["rate_a"],
        "tap"=>branches[bp_line[(i,j)]]["tap"],
        "v_from_min"=>buses[i]["vmin"],
        "v_from_max"=>buses[i]["vmax"],
        "v_to_min"=>buses[j]["vmin"],
        "v_to_max"=>buses[j]["vmax"]
        )) for (i,j) in buspair_indexes])
    return buspairs
end


