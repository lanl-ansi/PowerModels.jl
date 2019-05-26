# stuff that is universal to all power models

export
    GenericPowerModel,
    optimize!,
    run_generic_model, build_generic_model, solve_generic_model,
    ismultinetwork, nw_ids, nws,
    ismulticonductor, conductor_ids,
    ids, ref, var, con, ext


"root of the power formulation type hierarchy"
abstract type AbstractPowerFormulation end

"""
```
type GenericPowerModel{T<:AbstractPowerFormulation}
    model::JuMP.Model
    data::Dict{String,<:Any}
    setting::Dict{String,<:Any}
    solution::Dict{String,<:Any}
    ref::Dict{Symbol,<:Any} # reference data
    var::Dict{Symbol,<:Any} # JuMP variables
    con::Dict{Symbol,<:Any} # JuMP constraint references
    cnw::Int              # current network index value
    ccnd::Int             # current conductor index value
    ext::Dict{Symbol,<:Any} # user extentions
end
```
where

* `data` is the original data, usually from reading in a `.json` or `.m` (patpower) file,
* `setting` usually looks something like `Dict("output" => Dict("branch_flows" => true))`, and
* `ref` is a place to store commonly used pre-computed data from of the data dictionary,
    primarily for converting data-types, filtering out deactivated components, and storing
    system-wide values that need to be computed globally. See `build_ref(data)` for further details.

Methods on `GenericPowerModel` for defining variables and adding constraints should

* work with the `ref` dict, rather than the original `data` dict,
* add them to `model::JuMP.Model`, and
* follow the conventions for variable and constraint names.
"""
mutable struct GenericPowerModel{T<:AbstractPowerFormulation}
    model::JuMP.Model

    data::Dict{String,<:Any}
    setting::Dict{String,<:Any}
    solution::Dict{String,<:Any}

    ref::Dict{Symbol,<:Any}
    var::Dict{Symbol,<:Any}
    con::Dict{Symbol,<:Any}
    cnw::Int
    ccnd::Int

    # Extension dictionary
    # Extensions should define a type to hold information particular to
    # their functionality, and store an instance of the type in this
    # dictionary keyed on an extension-specific symbol
    ext::Dict{Symbol,<:Any}
end

# default generic constructor
function GenericPowerModel(data::Dict{String,<:Any}, T::DataType; ext = Dict{Symbol,Any}(), setting = Dict{String,Any}(), jump_model::JuMP.Model=JuMP.Model())

    # TODO is may be a good place to check component connectivity validity
    # i.e. https://github.com/lanl-ansi/PowerModels.jl/issues/131

    ref = build_generic_ref(data) # refrence data

    var = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    con = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    for (nw_id, nw) in ref[:nw]
        nw_var = var[:nw][nw_id] = Dict{Symbol,Any}()
        nw_con = con[:nw][nw_id] = Dict{Symbol,Any}()

        nw_var[:cnd] = Dict{Int,Any}()
        nw_con[:cnd] = Dict{Int,Any}()

        for cnd_id in nw[:conductor_ids]
            nw_var[:cnd][cnd_id] = Dict{Symbol,Any}()
            nw_con[:cnd][cnd_id] = Dict{Symbol,Any}()
        end
    end

    cnw = minimum([k for k in keys(var[:nw])])
    ccnd = minimum([k for k in keys(var[:nw][cnw][:cnd])])

    pm = GenericPowerModel{T}(
        jump_model,
        data,
        setting,
        Dict{String,Any}(), # solution
        ref,
        var,
        con,
        cnw,
        ccnd,
        ext
    )

    return pm
end

### Helper functions for working with multinetworks and multiconductors
""
ismultinetwork(pm::GenericPowerModel) = (length(pm.ref[:nw]) > 1)

""
nw_ids(pm::GenericPowerModel) = keys(pm.ref[:nw])

""
nws(pm::GenericPowerModel) = pm.ref[:nw]

""
ismulticonductor(pm::GenericPowerModel, nw::Int) = haskey(pm.ref[:nw][nw], :conductors)
ismulticonductor(pm::GenericPowerModel; nw::Int=pm.cnw) = haskey(pm.ref[:nw][nw], :conductors)

""
conductor_ids(pm::GenericPowerModel, nw::Int) = pm.ref[:nw][nw][:conductor_ids]
conductor_ids(pm::GenericPowerModel; nw::Int=pm.cnw) = pm.ref[:nw][nw][:conductor_ids]

""
ids(pm::GenericPowerModel, nw::Int, key::Symbol) = keys(pm.ref[:nw][nw][key])
ids(pm::GenericPowerModel, key::Symbol; nw::Int=pm.cnw) = keys(pm.ref[:nw][nw][key])

""
ref(pm::GenericPowerModel, nw::Int) = pm.ref[:nw][nw]
ref(pm::GenericPowerModel, nw::Int, key::Symbol) = pm.ref[:nw][nw][key]
ref(pm::GenericPowerModel, nw::Int, key::Symbol, idx) = pm.ref[:nw][nw][key][idx]
ref(pm::GenericPowerModel, nw::Int, key::Symbol, idx, param::String) = pm.ref[:nw][nw][key][idx][param]
ref(pm::GenericPowerModel, nw::Int, key::Symbol, idx, param::String, cnd::Int) = pm.ref[:nw][nw][key][idx][param][cnd]

ref(pm::GenericPowerModel; nw::Int=pm.cnw) = pm.ref[:nw][nw]
ref(pm::GenericPowerModel, key::Symbol; nw::Int=pm.cnw) = pm.ref[:nw][nw][key]
ref(pm::GenericPowerModel, key::Symbol, idx; nw::Int=pm.cnw) = pm.ref[:nw][nw][key][idx]
ref(pm::GenericPowerModel, key::Symbol, idx, param::String; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.ref[:nw][nw][key][idx][param][cnd]


var(pm::GenericPowerModel, nw::Int) = pm.var[:nw][nw]
var(pm::GenericPowerModel, nw::Int, key::Symbol) = pm.var[:nw][nw][key]
var(pm::GenericPowerModel, nw::Int, key::Symbol, idx) = pm.var[:nw][nw][key][idx]
var(pm::GenericPowerModel, nw::Int, cnd::Int) = pm.var[:nw][nw][:cnd][cnd]
var(pm::GenericPowerModel, nw::Int, cnd::Int, key::Symbol) = pm.var[:nw][nw][:cnd][cnd][key]
var(pm::GenericPowerModel, nw::Int, cnd::Int, key::Symbol, idx) = pm.var[:nw][nw][:cnd][cnd][key][idx]

var(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.var[:nw][nw][:cnd][cnd]
var(pm::GenericPowerModel, key::Symbol; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.var[:nw][nw][:cnd][cnd][key]
var(pm::GenericPowerModel, key::Symbol, idx; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.var[:nw][nw][:cnd][cnd][key][idx]

""
con(pm::GenericPowerModel, nw::Int) = pm.con[:nw][nw]
con(pm::GenericPowerModel, nw::Int, key::Symbol) = pm.con[:nw][nw][key]
con(pm::GenericPowerModel, nw::Int, key::Symbol, idx) = pm.con[:nw][nw][key][idx]
con(pm::GenericPowerModel, nw::Int, cnd::Int) = pm.con[:nw][nw][:cnd][cnd]
con(pm::GenericPowerModel, nw::Int, cnd::Int, key::Symbol) = pm.con[:nw][nw][:cnd][cnd][key]
con(pm::GenericPowerModel, nw::Int, cnd::Int, key::Symbol, idx) = pm.con[:nw][nw][:cnd][cnd][key][idx]

con(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.con[:nw][nw][:cnd][cnd]
con(pm::GenericPowerModel, key::Symbol; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.con[:nw][nw][:cnd][cnd][key]
con(pm::GenericPowerModel, key::Symbol, idx; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.con[:nw][nw][:cnd][cnd][key][idx]


function JuMP.optimize!(pm::GenericPowerModel, optimizer::JuMP.OptimizerFactory)
    if pm.model.moi_backend.state == MOIU.NO_OPTIMIZER
        _, solve_time, solve_bytes_alloc, sec_in_gc = @timed JuMP.optimize!(pm.model, optimizer)
    else
        Memento.warn(LOGGER, "Model already contains optimizer factory, cannot use optimizer specified in `solve_generic_model`")
        _, solve_time, solve_bytes_alloc, sec_in_gc = @timed JuMP.optimize!(pm.model)
    end

    try
        solve_time = MOI.get(pm.model, MOI.SolveTime())
    catch
        Memento.warn(LOGGER, "the given optimizer does not provide the SolveTime() attribute, falling back on @timed.  This is not a rigorous timing value.");
    end

    return solve_time
end

""
function run_generic_model(file::String, model_constructor, optimizer, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return run_generic_model(data, model_constructor, optimizer, post_method; kwargs...)
end

""
function run_generic_model(data::Dict{String,<:Any}, model_constructor, optimizer, post_method; ref_extensions=[], solution_builder=get_solution, kwargs...)
    #start_time = time()
    pm = build_generic_model(data, model_constructor, post_method; ref_extensions=ref_extensions, kwargs...)
    #Memento.info(LOGGER, "pm model build time: $(time() - start_time)")

    #start_time = time()
    solution = solve_generic_model(pm, optimizer; solution_builder = solution_builder)
    #Memento.info(LOGGER, "pm model solve and solution time: $(time() - start_time)")

    return solution
end

""
function build_generic_model(file::String,  model_constructor, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return build_generic_model(data, model_constructor, post_method; kwargs...)
end

""
function build_generic_model(data::Dict{String,<:Any}, model_constructor, post_method; ref_extensions=[], multinetwork=false, multiconductor=false, kwargs...)
    # NOTE, this model constructor will build the ref dict using the latest info from the data

    #start_time = time()
    pm = model_constructor(data; kwargs...)
    #Memento.info(LOGGER, "pm model_constructor time: $(time() - start_time)")

    if !multinetwork && ismultinetwork(pm)
        Memento.error(LOGGER, "attempted to build a single-network model with multi-network data")
    end

    if !multiconductor && ismulticonductor(pm)
        Memento.error(LOGGER, "attempted to build a single-conductor model with multi-conductor data")
    end

    #start_time = time()
    core_ref!(pm)
    for ref_ext in ref_extensions
        ref_ext(pm)
    end
    #Memento.info(LOGGER, "pm build ref time: $(time() - start_time)")

    #start_time = time()
    post_method(pm)
    #Memento.info(LOGGER, "pm post_method time: $(time() - start_time)")

    return pm
end


""
function solve_generic_model(pm::GenericPowerModel, optimizer::JuMP.OptimizerFactory; solution_builder = get_solution)

    #start_time = time()
    solve_time = JuMP.optimize!(pm, optimizer)
    #Memento.info(LOGGER, "JuMP model optimize time: $(time() - start_time)")

    #start_time = time()
    solution = build_solution(pm, solve_time; solution_builder = solution_builder)
    #Memento.info(LOGGER, "PowerModels solution build time: $(time() - start_time)")

    return solution
end


"used for building ref without the need to build a GenericPowerModel"
function build_ref(data::Dict{String,<:Any}; ref_extensions=[])
    ref = build_generic_ref(data)
    core_ref!(ref[:nw])
    for ref_ext in ref_extensions
        ref_ext(pm)
    end
    return ref
end


function build_generic_ref(data::Dict{String,<:Any})
    refs = Dict{Symbol,Any}()

    nws = refs[:nw] = Dict{Int,Any}()

    if InfrastructureModels.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end

    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        ref = nws[nw_id] = Dict{Symbol,Any}()

        for (key, item) in nw_data
            if isa(item, Dict{String,Any})
                item_lookup = Dict{Int,Any}([(parse(Int, k), v) for (k,v) in item])
                ref[Symbol(key)] = item_lookup
            else
                ref[Symbol(key)] = item
            end
        end

        if !haskey(ref, :conductors)
            ref[:conductor_ids] = 1:1
        else
            ref[:conductor_ids] = 1:ref[:conductors]
        end
    end

    return refs
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
* `:bus_loads` -- the mapping `Dict(i => [load["load_bus"] for (i,load) in ref[:load]])`.
* `:bus_shunts` -- the mapping `Dict(i => [shunt["shunt_bus"] for (i,shunt) in ref[:shunt]])`.
* `:arcs_from_dc` -- the set `[(i,b["f_bus"],b["t_bus"]) for (i,b) in ref[:dcline]]`,
* `:arcs_to_dc` -- the set `[(i,b["t_bus"],b["f_bus"]) for (i,b) in ref[:dcline]]`,
* `:arcs_dc` -- the set of arcs from both `arcs_from_dc` and `arcs_to_dc`,
* `:bus_arcs_dc` -- the mapping `Dict(i => [(l,i,j) for (l,i,j) in ref[:arcs_dc]])`, and
* `:buspairs_dc` -- (see `buspair_parameters(ref[:arcs_from_dc], ref[:dcline], ref[:bus])`),

If `:ne_branch` exists, then the following keys are also available with similar semantics:

* `:ne_branch`, `:ne_arcs_from`, `:ne_arcs_to`, `:ne_arcs`, `:ne_bus_arcs`, `:ne_buspairs`.
"""
function core_ref!(pm::GenericPowerModel)
    core_ref!(pm.ref[:nw])
end

function core_ref!(nw_refs::Dict)
    for (nw, ref) in nw_refs

        ### filter out inactive components ###
        ref[:bus] = Dict(x for x in ref[:bus] if x.second["bus_type"] != 4)
        ref[:load] = Dict(x for x in ref[:load] if (x.second["status"] == 1 && x.second["load_bus"] in keys(ref[:bus])))
        ref[:shunt] = Dict(x for x in ref[:shunt] if (x.second["status"] == 1 && x.second["shunt_bus"] in keys(ref[:bus])))
        ref[:gen] = Dict(x for x in ref[:gen] if (x.second["gen_status"] == 1 && x.second["gen_bus"] in keys(ref[:bus])))
        ref[:storage] = Dict(x for x in ref[:storage] if (x.second["status"] == 1 && x.second["storage_bus"] in keys(ref[:bus])))
        ref[:branch] = Dict(x for x in ref[:branch] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))
        ref[:dcline] = Dict(x for x in ref[:dcline] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))


        ### setup arcs from edges ###
        ref[:arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs] = [ref[:arcs_from]; ref[:arcs_to]]

        ref[:arcs_from_dc] = [(i,dcline["f_bus"],dcline["t_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_to_dc]   = [(i,dcline["t_bus"],dcline["f_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_dc]      = [ref[:arcs_from_dc]; ref[:arcs_to_dc]]


        ### bus connected component lookups ###
        bus_loads = Dict((i, Int[]) for (i,bus) in ref[:bus])
        for (i, load) in ref[:load]
            push!(bus_loads[load["load_bus"]], i)
        end
        ref[:bus_loads] = bus_loads

        bus_shunts = Dict((i, Int[]) for (i,bus) in ref[:bus])
        for (i,shunt) in ref[:shunt]
            push!(bus_shunts[shunt["shunt_bus"]], i)
        end
        ref[:bus_shunts] = bus_shunts

        bus_gens = Dict((i, Int[]) for (i,bus) in ref[:bus])
        for (i,gen) in ref[:gen]
            push!(bus_gens[gen["gen_bus"]], i)
        end
        ref[:bus_gens] = bus_gens

        bus_storage = Dict((i, Int[]) for (i,bus) in ref[:bus])
        for (i,strg) in ref[:storage]
            push!(bus_storage[strg["storage_bus"]], i)
        end
        ref[:bus_storage] = bus_storage

        bus_arcs = Dict((i, Tuple{Int,Int,Int}[]) for (i,bus) in ref[:bus])
        for (l,i,j) in ref[:arcs]
            push!(bus_arcs[i], (l,i,j))
        end
        ref[:bus_arcs] = bus_arcs

        bus_arcs_dc = Dict((i, Tuple{Int,Int,Int}[]) for (i,bus) in ref[:bus])
        for (l,i,j) in ref[:arcs_dc]
            push!(bus_arcs_dc[i], (l,i,j))
        end
        ref[:bus_arcs_dc] = bus_arcs_dc


        ### reference bus lookup (a set to support multiple connected components) ###
        ref_buses = Dict{Int,Any}()
        for (k,v) in ref[:bus]
            if v["bus_type"] == 3
                ref_buses[k] = v
            end
        end

        ref[:ref_buses] = ref_buses

        if length(ref_buses) > 1
            Memento.warn(LOGGER, "multiple reference buses found, $(keys(ref_buses)), this can cause infeasibility if they are in the same connected component")
        end


        ### aggregate info for pairs of connected buses ###
        ref[:buspairs] = buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus], ref[:conductor_ids], haskey(ref, :conductors))

    end
end
