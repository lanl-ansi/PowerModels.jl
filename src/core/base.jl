# stuff that is universal to all power models

export
    GenericPowerModel,
    setdata, setsolver, solve,
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

"Default generic constructor."
function GenericPowerModel(data::Dict{String,<:Any}, T::DataType; ext = Dict{Symbol,Any}(), setting = Dict{String,Any}(), solver = JuMP.UnsetSolver(), jump_model::JuMP.Model = JuMP.Model(solver = solver))

    # TODO is may be a good place to check component connectivity validity
    # i.e. https://github.com/lanl-ansi/PowerModels.jl/issues/131

    ref = build_ref(data) # refrence data

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



# TODO Ask Miles, why do we need to put JuMP. here?  using at top level should bring it in
function setsolver(pm::GenericPowerModel, solver)
    JuMP.setsolver(pm.model, solver)
end

function JuMP.solve(pm::GenericPowerModel)
    status, solve_time, solve_bytes_alloc, sec_in_gc = @timed JuMP.solve(pm.model)

    try
        solve_time = JuMP.getsolvetime(pm.model)
    catch
        Memento.warn(LOGGER, "there was an issue with getsolvetime() on the solver, falling back on @timed.  This is not a rigorous timing value.");
    end

    return status, solve_time
end

""
function run_generic_model(file::String, model_constructor, solver, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return run_generic_model(data, model_constructor, solver, post_method; kwargs...)
end

""
function run_generic_model(data::Dict{String,<:Any}, model_constructor, solver, post_method; solution_builder = get_solution, kwargs...)
    pm = build_generic_model(data, model_constructor, post_method; kwargs...)
    #pm, time, bytes_alloc, sec_in_gc = @timed build_generic_model(data, model_constructor, post_method; kwargs...)
    #println("model build time: $(time)")

    solution = solve_generic_model(pm, solver; solution_builder = solution_builder)
    #solution, time, bytes_alloc, sec_in_gc = @timed solve_generic_model(pm, solver; solution_builder = solution_builder)
    #println("solution time: $(time)")

    return solution
end

""
function build_generic_model(file::String,  model_constructor, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return build_generic_model(data, model_constructor, post_method; kwargs...)
end

""
function build_generic_model(data::Dict{String,<:Any}, model_constructor, post_method; multinetwork=false, multiconductor=false, kwargs...)
    # NOTE, this model constructor will build the ref dict using the latest info from the data
    pm = model_constructor(data; kwargs...)

    if !multinetwork && ismultinetwork(pm)
        Memento.error(LOGGER, "attempted to build a single-network model with multi-network data")
    end

    if !multiconductor && ismulticonductor(pm)
        Memento.error(LOGGER, "attempted to build a single-conductor model with multi-conductor data")
    end

    post_method(pm)

    return pm
end

""
function solve_generic_model(pm::GenericPowerModel, solver; solution_builder = get_solution)
    setsolver(pm, solver)

    status, solve_time = JuMP.solve(pm)

    solution = build_solution(pm, status, solve_time; solution_builder = solution_builder)
    #solution, time, bytes_alloc, sec_in_gc = @timed build_solution(pm, status, solve_time; solution_builder = solution_builder)
    #println("build_solution time: $(time)")

    return solution
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
function build_ref(data::Dict{String,<:Any})
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

        # add connected components
        component_sets = PowerModels.connected_components(nw_data)
        ref[:components] = Dict(i => c for (i,c) in enumerate(sort(collect(component_sets); by=length)))

        # filter turned off stuff
        ref[:bus] = Dict(x for x in ref[:bus] if x.second["bus_type"] != 4)
        ref[:load] = Dict(x for x in ref[:load] if (x.second["status"] == 1 && x.second["load_bus"] in keys(ref[:bus])))
        ref[:shunt] = Dict(x for x in ref[:shunt] if (x.second["status"] == 1 && x.second["shunt_bus"] in keys(ref[:bus])))
        ref[:gen] = Dict(x for x in ref[:gen] if (x.second["gen_status"] == 1 && x.second["gen_bus"] in keys(ref[:bus])))
        ref[:storage] = Dict(x for x in ref[:storage] if (x.second["status"] == 1 && x.second["storage_bus"] in keys(ref[:bus])))
        ref[:branch] = Dict(x for x in ref[:branch] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))
        ref[:dcline] = Dict(x for x in ref[:dcline] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))


        ref[:arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs] = [ref[:arcs_from]; ref[:arcs_to]]

        ref[:arcs_from_dc] = [(i,dcline["f_bus"],dcline["t_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_to_dc]   = [(i,dcline["t_bus"],dcline["f_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_dc]      = [ref[:arcs_from_dc]; ref[:arcs_to_dc]]

        # maps dc line from and to parameters to arcs
        arcs_dc_param = ref[:arcs_dc_param] = Dict()
        for (l,i,j) in ref[:arcs_from_dc]
            arcs_dc_param[(l,i,j)] = Dict(
                "pmin" => ref[:dcline][l]["pminf"],
                "pmax" => ref[:dcline][l]["pmaxf"],
                "pref" => ref[:dcline][l]["pf"],
                "qmin" => ref[:dcline][l]["qminf"],
                "qmax" => ref[:dcline][l]["qmaxf"],
                "qref" => ref[:dcline][l]["qf"]
            )
            arcs_dc_param[(l,j,i)] = Dict(
                "pmin" => ref[:dcline][l]["pmint"],
                "pmax" => ref[:dcline][l]["pmaxt"],
                "pref" => ref[:dcline][l]["pt"],
                "qmin" => ref[:dcline][l]["qmint"],
                "qmax" => ref[:dcline][l]["qmaxt"],
                "qref" => ref[:dcline][l]["qt"]
            )
        end


        bus_loads = Dict((i, []) for (i,bus) in ref[:bus])
        for (i, load) in ref[:load]
            push!(bus_loads[load["load_bus"]], i)
        end
        ref[:bus_loads] = bus_loads

        bus_shunts = Dict((i, []) for (i,bus) in ref[:bus])
        for (i,shunt) in ref[:shunt]
            push!(bus_shunts[shunt["shunt_bus"]], i)
        end
        ref[:bus_shunts] = bus_shunts

        bus_gens = Dict((i, []) for (i,bus) in ref[:bus])
        for (i,gen) in ref[:gen]
            push!(bus_gens[gen["gen_bus"]], i)
        end
        ref[:bus_gens] = bus_gens

        bus_storage = Dict((i, []) for (i,bus) in ref[:bus])
        for (i,strg) in ref[:storage]
            push!(bus_storage[strg["storage_bus"]], i)
        end
        ref[:bus_storage] = bus_storage


        bus_arcs = Dict((i, []) for (i,bus) in ref[:bus])
        for (l,i,j) in ref[:arcs]
            push!(bus_arcs[i], (l,i,j))
        end
        ref[:bus_arcs] = bus_arcs

        bus_arcs_dc = Dict((i, []) for (i,bus) in ref[:bus])
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
            ref_bus = ref_buses[gen_bus] = ref[:bus][gen_bus]
            ref_bus["bus_type"] = 3
            Memento.warn(LOGGER, "no reference bus found, setting bus $(gen_bus) as reference based on generator $(big_gen["index"])")
        end

        if length(ref_buses) > 1
            Memento.warn(LOGGER, "multiple reference buses found, $(keys(ref_buses)), this can cause infeasibility if they are in the same connected component")
        end

        ref[:ref_buses] = ref_buses

        ref[:buspairs] = buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus], ref[:conductor_ids], haskey(ref, :conductors))

        off_angmin, off_angmax = calc_theta_delta_bounds(nw_data)
        ref[:off_angmin] = off_angmin
        ref[:off_angmax] = off_angmax

        if haskey(ref, :ne_branch)
            ref[:ne_branch] = Dict(x for x in ref[:ne_branch] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))

            ref[:ne_arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:ne_branch]]
            ref[:ne_arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:ne_branch]]
            ref[:ne_arcs] = [ref[:ne_arcs_from]; ref[:ne_arcs_to]]

            ne_bus_arcs = Dict((i, []) for (i,bus) in ref[:bus])
            for (l,i,j) in ref[:ne_arcs]
                push!(ne_bus_arcs[i], (l,i,j))
            end
            ref[:ne_bus_arcs] = ne_bus_arcs

            ref[:ne_buspairs] = buspair_parameters(ref[:ne_arcs_from], ref[:ne_branch], ref[:bus], ref[:conductor_ids], haskey(ref, :conductors))
        end

    end

    return refs
end


"find the largest active generator in the network"
function biggest_generator(gens)
    biggest_gen = nothing
    biggest_value = -Inf
    for (k,gen) in gens
        pmax = maximum(gen["pmax"])
        if pmax > biggest_value
            biggest_gen = gen
            biggest_value = pmax
        end
    end
    @assert(biggest_gen != nothing)
    return biggest_gen
end


"compute bus pair level structures"
function buspair_parameters(arcs_from, branches, buses, conductor_ids, ismulticondcutor)
    buspair_indexes = collect(Set([(i,j) for (l,i,j) in arcs_from]))

    bp_branch = Dict((bp, typemax(Int64)) for bp in buspair_indexes)

    if ismulticondcutor
        bp_angmin = Dict((bp, MultiConductorVector([-Inf for c in conductor_ids])) for bp in buspair_indexes)
        bp_angmax = Dict((bp, MultiConductorVector([ Inf for c in conductor_ids])) for bp in buspair_indexes)
    else
        @assert(length(conductor_ids) == 1)
        bp_angmin = Dict((bp, -Inf) for bp in buspair_indexes)
        bp_angmax = Dict((bp,  Inf) for bp in buspair_indexes)
    end

    for (l,branch) in branches
        i = branch["f_bus"]
        j = branch["t_bus"]

        if ismulticondcutor
            for c in conductor_ids
                bp_angmin[(i,j)][c] = max(bp_angmin[(i,j)][c], branch["angmin"][c])
                bp_angmax[(i,j)][c] = min(bp_angmax[(i,j)][c], branch["angmax"][c])
            end
        else
            bp_angmin[(i,j)] = max(bp_angmin[(i,j)], branch["angmin"])
            bp_angmax[(i,j)] = min(bp_angmax[(i,j)], branch["angmax"])
        end

        bp_branch[(i,j)] = min(bp_branch[(i,j)], l)
    end

    buspairs = Dict(((i,j), Dict(
        "branch"=>bp_branch[(i,j)],
        "angmin"=>bp_angmin[(i,j)],
        "angmax"=>bp_angmax[(i,j)],
        "tap"=>branches[bp_branch[(i,j)]]["tap"],
        "vm_fr_min"=>buses[i]["vmin"],
        "vm_fr_max"=>buses[i]["vmax"],
        "vm_to_min"=>buses[j]["vmin"],
        "vm_to_max"=>buses[j]["vmax"]
        )) for (i,j) in buspair_indexes
    )

    # add optional parameters
    for bp in buspair_indexes
        branch = branches[bp_branch[bp]]
        if haskey(branch, "rate_a")
            buspairs[bp]["rate_a"] = branch["rate_a"]
        end
        if haskey(branch, "c_rating_a")
            buspairs[bp]["c_rating_a"] = branch["c_rating_a"]
        end
    end

    return buspairs
end
