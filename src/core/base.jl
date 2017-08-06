# stuff that is universal to all power models

export
    GenericPowerModel,
    setdata, setsolver, solve,
    run_generic_model, build_generic_model, solve_generic_model

""
@compat abstract type AbstractPowerFormulation end

""
@compat abstract type AbstractConicPowerFormulation <: AbstractPowerFormulation end

"""
```
type GenericPowerModel{T<:AbstractPowerFormulation}
    model::JuMP.Model
    data::Dict{String,Any}
    setting::Dict{String,Any}
    solution::Dict{String,Any}
    var::Dict{Symbol,Any} # model variable lookup
    ref::Dict{Int,Any} # reference data
    ext::Dict{Symbol,Any} # user extentions
end
```
where

* `data` is the original data, usually from reading in a `.json` or `.m` (patpower) file,
* `setting` usually looks something like `Dict("output" => Dict("line_flows" => true))`, and
* `ref` is a place to store commonly used pre-computed data from of the data dictionary,
    primarily for converting data-types, filtering out deactivated components, and storing
    system-wide values that need to be computed globally. See `build_ref(data)` for further details.

Methods on `GenericPowerModel` for defining variables and adding constraints should

* work with the `ref` dict, rather than the original `data` dict,
* add them to `model::JuMP.Model`, and
* follow the conventions for variable and constraint names.
"""
type GenericPowerModel{T<:AbstractPowerFormulation}
    model::Model
    data::Dict{String,Any}
    setting::Dict{String,Any}
    solution::Dict{String,Any}
    ref::Dict{Symbol,Any} # data reference data
    var::Dict{Symbol,Any} # JuMP variables
    # Extension dictionary
    # Extensions should define a type to hold information particular to
    # their functionality, and store an instance of the type in this
    # dictionary keyed on an extension-specific symbol
    ext::Dict{Symbol,Any}
end

# default generic constructor
function GenericPowerModel(data::Dict{String,Any}, T::DataType; setting = Dict{String,Any}(), solver = JuMP.UnsetSolver())

    # TODO is may be a good place to check component connectivity validity
    # i.e. https://github.com/lanl-ansi/PowerModels.jl/issues/131

    ref = build_ref(data)
    
    var = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    ext = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    for nw_id in keys(ref[:nw])
        var[:nw][nw_id] = Dict{Symbol,Any}()
        ext[:nw][nw_id] = Dict{Symbol,Any}()
    end

    pm = GenericPowerModel{T}(
        Model(solver = solver), # model
        data, # data
        setting, # setting
        Dict{String,Any}(), # solution
        ref,
        var,
        ext
    )

    return pm
end


### Helper functions for ignoring the basecase

#nw_data(pm::GenericPowerModel, key::String) = nw_ref(pm, 0, key)
#nw_data(pm::GenericPowerModel, key::String, idx::String) = nw_ref(pm, 0, key, idx)
#nw_data(pm::GenericPowerModel, n::String, key::String) = pm.data["nw"][n][key]
#nw_data(pm::GenericPowerModel, n::String, key::String, idx::String) = pm.data[:nw][n][key][idx]

nw_ref(pm::GenericPowerModel, key::Symbol) = nw_ref(pm, 0, key)
nw_ref(pm::GenericPowerModel, key::Symbol, idx) = nw_ref(pm, 0, key, idx)
nw_ref(pm::GenericPowerModel, n::Int, key::Symbol) = pm.ref[:nw][n][key]
nw_ref(pm::GenericPowerModel, n::Int, key::Symbol, idx) = pm.ref[:nw][n][key][idx]

nw_var(pm::GenericPowerModel, key::Symbol) = nw_var(pm, 0, key)
nw_var(pm::GenericPowerModel, key::Symbol, idx) = nw_var(pm, 0, key, idx)
nw_var(pm::GenericPowerModel, n::Int, key::Symbol) = pm.var[:nw][n][key]
nw_var(pm::GenericPowerModel, n::Int, key::Symbol, idx) = pm.var[:nw][n][key][idx]

nw_ext(pm::GenericPowerModel, key::Symbol) = nw_ext(pm, 0, key)
nw_ext(pm::GenericPowerModel, key::Symbol, idx) = nw_ext(pm, 0, key, idx)
nw_ext(pm::GenericPowerModel, n::Int, key::Symbol) = pm.ext[:nw][n][key]
nw_ext(pm::GenericPowerModel, n::Int, key::Symbol, idx) = pm.ext[:nw][n][key][idx]


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

""
function run_generic_model(file::String, model_constructor, solver, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return run_generic_model(data, model_constructor, solver, post_method; kwargs...)
end

""
function run_generic_model(data::Dict{String,Any}, model_constructor, solver, post_method; solution_builder = get_solution, kwargs...)
    pm = build_generic_model(data, model_constructor, post_method; kwargs...)

    solution = solve_generic_model(pm, solver; solution_builder = solution_builder)

    return solution
end

""
function build_generic_model(file::String,  model_constructor, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return build_generic_model(data, model_constructor, post_method; kwargs...)
end

""
function build_generic_model(data::Dict{String,Any}, model_constructor, post_method; kwargs...)
    # NOTE, this model constructor will build the ref dict using the latest info from the data
    pm = model_constructor(data; kwargs...)

    post_method(pm)

    return pm
end

""
function solve_generic_model(pm::GenericPowerModel, solver; solution_builder = get_solution)
    setsolver(pm.model, solver)

    status, solve_time = solve(pm)

    return build_solution(pm, status, solve_time; solution_builder = solution_builder)
end

"""
Returns a dict that stores commonly used pre-computed data from of the data dictionary,
primarily for converting data-types, filtering out deactivated components, and storing
system-wide values that need to be computed globally.

Some of the common keys include:

* `:off_angmin` and `:off_angmax` (see `calc_theta_delta_bounds(data)`),
* `:bus` -- the set `{(i, bus) in ref[:bus] : bus["bus_type"] != 4}`,
* `:gen` -- the set `{(i, gen) in ref[:gen] : gen["gen_status"] == 1 && gen["gen_bus"] in keys(ref[:bus])}`,
* `:branch` -- the set of branches that are active in the network (based on the component status values),
* `:arcs_from` -- the set `[(i,b["f_bus"],b["t_bus"]) for (i,b) in ref[:branch]]`,
* `:arcs_to` -- the set `[(i,b["t_bus"],b["f_bus"]) for (i,b) in ref[:branch]]`,
* `:arcs` -- the set of arcs from both `arcs_from` and `arcs_to`,
* `:bus_arcs` -- the mapping `Dict(i => [(l,i,j) for (l,i,j) in ref[:arcs]])`,
* `:buspairs` -- (see `buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus])`),
* `:bus_gens` -- the mapping `Dict(i => [gen["gen_bus"] for (i,gen) in ref[:gen]])`.
* `:arcs_from_dc` -- the set `[(i,b["f_bus"],b["t_bus"]) for (i,b) in ref[:dcline]]`,
* `:arcs_to_dc` -- the set `[(i,b["t_bus"],b["f_bus"]) for (i,b) in ref[:dcline]]`,
* `:arcs_dc` -- the set of arcs from both `arcs_from_dc` and `arcs_to_dc`,
* `:bus_arcs_dc` -- the mapping `Dict(i => [(l,i,j) for (l,i,j) in ref[:arcs_dc]])`, and
* `:buspairs_dc` -- (see `buspair_parameters(ref[:arcs_from_dc], ref[:dcline], ref[:bus])`),

If `:ne_branch` exists, then the following keys are also available with similar semantics:

* `:ne_branch`, `:ne_arcs_from`, `:ne_arcs_to`, `:ne_arcs`, `:ne_bus_arcs`, `:ne_buspairs`.
"""
function build_ref(data::Dict{String,Any})
    refs = Dict{Symbol,Any}()
    nws = refs[:nw] = Dict{Int,Any}()

    for (n,nw_data) in data["nw"]
        nw_id = parse(Int, n)
        ref = nws[nw_id] = Dict{Symbol,Any}()

        for (key, item) in nw_data
            if isa(item, Dict)
                item_lookup = Dict([(parse(Int, k), v) for (k,v) in item])
                ref[Symbol(key)] = item_lookup
            else
                ref[Symbol(key)] = item
            end
        end

        off_angmin, off_angmax = calc_theta_delta_bounds(nw_data)
        ref[:off_angmin] = off_angmin
        ref[:off_angmax] = off_angmax

        # filter turned off stuff
        ref[:bus] = filter((i, bus) -> bus["bus_type"] != 4, ref[:bus])
        ref[:gen] = filter((i, gen) -> gen["gen_status"] == 1 && gen["gen_bus"] in keys(ref[:bus]), ref[:gen])
        ref[:branch] = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(ref[:bus]) && branch["t_bus"] in keys(ref[:bus]), ref[:branch])
        ref[:dcline] = filter((i, dcline) -> dcline["br_status"] == 1 && dcline["f_bus"] in keys(ref[:bus]) && dcline["t_bus"] in keys(ref[:bus]), ref[:dcline])

        ref[:arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs] = [ref[:arcs_from]; ref[:arcs_to]]

        ref[:arcs_from_dc] = [(i,dcline["f_bus"],dcline["t_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_to_dc]   = [(i,dcline["t_bus"],dcline["f_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_dc] = [ref[:arcs_from_dc]; ref[:arcs_to_dc]]

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

        bus_arcs_dc = Dict([(i, []) for (i,bus) in ref[:bus]])
        for (l,i,j) in ref[:arcs_dc]
            push!(bus_arcs_dc[i], (l,i,j))
        end
        ref[:bus_arcs_dc] = bus_arcs_dc

        # a set of buses to support multiple connected components
        ref_buses = Dict()
        for (k,v) in ref[:bus]
            if v["bus_type"] == 3
                ref_buses[k] = v
            end
        end

        if length(ref_buses) == 0
            big_gen = biggest_generator(ref[:gen])
            gen_bus = big_gen["gen_bus"]
            ref_buses[gen_bus] = ref[:bus][gen_bus]
            warn("no reference bus found, setting bus $(gen_bus) as reference based on generator $(big_gen["index"])")
        end

        if length(ref_buses) > 1
            warn("multiple reference buses found, $(keys(ref_buses)), this can cause infeasibility if they are in the same connected component")
        end

        ref[:ref_buses] = ref_buses


        ref[:buspairs] = buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus])
        ############################ DC LINES##########################################
        if haskey(ref, :dcline)
            ref[:buspairs_dc] = buspair_parameters_dc(ref[:arcs_from_dc], ref[:dcline], ref[:bus])
        end
        ###############################################################################

        if haskey(ref, :ne_branch)
            ref[:ne_branch] = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(ref[:bus]) && branch["t_bus"] in keys(ref[:bus]), ref[:ne_branch])

            ref[:ne_arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:ne_branch]]
            ref[:ne_arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:ne_branch]]
            ref[:ne_arcs] = [ref[:ne_arcs_from]; ref[:ne_arcs_to]]

            ne_bus_arcs = Dict([(i, []) for (i,bus) in ref[:bus]])
            for (l,i,j) in ref[:ne_arcs]
                push!(ne_bus_arcs[i], (l,i,j))
            end
            ref[:ne_bus_arcs] = ne_bus_arcs

            ref[:ne_buspairs] = buspair_parameters(ref[:ne_arcs_from], ref[:ne_branch], ref[:bus])
        end

    end

    return refs
end


"find the largest active generator in the network"
function biggest_generator(gens)
    biggest_gen = nothing
    biggest_value = -Inf
    for (k,gen) in gens
        if gen["pmax"] > biggest_value
            biggest_gen = gen
            biggest_value = gen["pmax"]
        end
    end
    assert(biggest_gen != nothing)
    return biggest_gen
end


"compute bus pair level structures"
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

"compute bus pair level structures for DC"
function buspair_parameters_dc(arcs_from_dc, dclines, buses)
    buspair_indexes = collect(Set([(i,j) for (l,i,j) in arcs_from_dc]))

    bp_angmin = Dict([(bp, -Inf) for bp in buspair_indexes])
    bp_angmax = Dict([(bp, Inf) for bp in buspair_indexes])
    bp_line = Dict([(bp, Inf) for bp in buspair_indexes])
    pmint = Dict([(bp, Inf) for bp in buspair_indexes])
    pminf = Dict([(bp, Inf) for bp in buspair_indexes])
    pmaxt = Dict([(bp, Inf) for bp in buspair_indexes])
    pmaxf = Dict([(bp, Inf) for bp in buspair_indexes])

    for (l,dcline) in dclines
        i = dcline["f_bus"]
        j = dcline["t_bus"]

        bp_line[(i,j)] = min(bp_line[(i,j)], l)
    end

    buspairs_dc = Dict([((i,j), Dict(
        "line"=>bp_line[(i,j)],
        "pminf"=>dclines[bp_line[(i,j)]]["pminf"],
        "pmaxf"=>dclines[bp_line[(i,j)]]["pmaxf"],
        "pmint"=>dclines[bp_line[(i,j)]]["pmint"],
        "pmaxt"=>dclines[bp_line[(i,j)]]["pmaxt"],
        "qminf"=>dclines[bp_line[(i,j)]]["qminf"],
        "qmaxf"=>dclines[bp_line[(i,j)]]["qmaxf"],
        "qmint"=>dclines[bp_line[(i,j)]]["qmint"],
        "qmaxt"=>dclines[bp_line[(i,j)]]["qmaxt"],
        "pf"=>dclines[bp_line[(i,j)]]["pf"],
        "pt"=>dclines[bp_line[(i,j)]]["pt"],
        "qf"=>dclines[bp_line[(i,j)]]["qf"],
        "qt"=>dclines[bp_line[(i,j)]]["qt"],
        "vf"=>dclines[bp_line[(i,j)]]["vf"],
        "vt"=>dclines[bp_line[(i,j)]]["vt"]
        )) for (i,j) in buspair_indexes])

    return buspairs_dc
end
