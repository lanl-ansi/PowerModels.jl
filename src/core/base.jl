# stuff that is universal to all power models

export
    GenericPowerModel,
    setdata, setsolver, solve

type PowerDataSets
    ref_bus
    buses
    gens
    branches
    bus_gens
    arcs_from
    arcs_to
    arcs
    bus_arcs
    buspairs
end

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
    bus_lookup = Dict([(Int(bus["index"]), bus) for bus in data["bus"]])
    gen_lookup = Dict([(Int(gen["index"]), gen) for gen in data["gen"]])
    for gencost in data["gencost"]
        i = Int(gencost["index"])
        gen_lookup[i] = merge(gen_lookup[i], gencost)
    end
    branch_lookup = Dict([(Int(branch["index"]), branch) for branch in data["branch"]])

    # filter turned off stuff
    bus_lookup = filter((i, bus) -> bus["bus_type"] != 4, bus_lookup)
    gen_lookup = filter((i, gen) -> gen["gen_status"] == 1 && gen["gen_bus"] in keys(bus_lookup), gen_lookup)
    branch_lookup = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(bus_lookup) && branch["t_bus"] in keys(bus_lookup), branch_lookup)

    arcs_from = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in branch_lookup]
    arcs_to   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in branch_lookup]
    arcs = [arcs_from; arcs_to]

    bus_gens = Dict([(i, []) for (i,bus) in bus_lookup])
    for (i,gen) in gen_lookup
        push!(bus_gens[gen["gen_bus"]], i)
    end

    bus_arcs = Dict([(i, []) for (i,bus) in bus_lookup])
    for (l,i,j) in arcs_from
        push!(bus_arcs[i], (l,i,j))
        push!(bus_arcs[j], (l,j,i))
    end

    #ref_bus = [i for (i,bus) in bus_lookup | bus["bus_type"] == 3][1]
    ref_bus = Union{}
    for (k,v) in bus_lookup
        if v["bus_type"] == 3
            ref_bus = k
            break
        end
    end

    buspairs_lookup = buspair_parameters(arcs_from, branch_lookup, bus_lookup)

    ref = Dict(
        :ref_bus => ref_bus,
        :bus => bus_lookup,
        :gen => gen_lookup,
        :branch => branch_lookup,
        :bus_gens => bus_gens,
        :arcs_from => arcs_from,
        :arcs_to => arcs_to,
        :arcs => arcs,
        :bus_arcs => bus_arcs,
        :buspairs => buspairs_lookup
    )
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


