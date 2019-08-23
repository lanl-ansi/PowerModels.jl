# stuff that is universal to all power models

"root of the power formulation type hierarchy"
abstract type AbstractPowerModel end

"a macro for adding the base PowerModels fields to a type definition"
InfrastructureModels.@def pm_fields begin
    model::JuMP.AbstractModel

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
function InitializePowerModel(PowerModel::Type, data::Dict{String,<:Any}; ext = Dict{Symbol,Any}(), setting = Dict{String,Any}(), jump_model::JuMP.AbstractModel=JuMP.Model())
    @assert PowerModel <: AbstractPowerModel

    # TODO is may be a good place to check component connectivity validity
    # i.e. https://github.com/lanl-ansi/PowerModels.jl/issues/131

    ref = InfrastructureModels.ref_initialize(data, _pm_global_keys) # refrence data

    var = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    con = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    for (nw_id, nw) in ref[:nw]
        nw_var = var[:nw][nw_id] = Dict{Symbol,Any}()
        nw_con = con[:nw][nw_id] = Dict{Symbol,Any}()

        nw_var[:cnd] = Dict{Int,Any}()
        nw_con[:cnd] = Dict{Int,Any}()

        if !haskey(nw, :conductors)
            nw[:conductor_ids] = 1:1
        else
            nw[:conductor_ids] = 1:nw[:conductors]
        end

        for cnd_id in nw[:conductor_ids]
            nw_var[:cnd][cnd_id] = Dict{Symbol,Any}()
            nw_con[:cnd][cnd_id] = Dict{Symbol,Any}()
        end
    end

    cnw = minimum([k for k in keys(var[:nw])])
    ccnd = minimum([k for k in keys(var[:nw][cnw][:cnd])])

    pm = PowerModel(
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
ismultinetwork(pm::AbstractPowerModel) = (length(pm.ref[:nw]) > 1)

""
nw_ids(pm::AbstractPowerModel) = keys(pm.ref[:nw])

""
nws(pm::AbstractPowerModel) = pm.ref[:nw]

""
ismulticonductor(pm::AbstractPowerModel, nw::Int) = haskey(pm.ref[:nw][nw], :conductors)
ismulticonductor(pm::AbstractPowerModel; nw::Int=pm.cnw) = haskey(pm.ref[:nw][nw], :conductors)

""
conductor_ids(pm::AbstractPowerModel, nw::Int) = pm.ref[:nw][nw][:conductor_ids]
conductor_ids(pm::AbstractPowerModel; nw::Int=pm.cnw) = pm.ref[:nw][nw][:conductor_ids]

""
ids(pm::AbstractPowerModel, nw::Int, key::Symbol) = keys(pm.ref[:nw][nw][key])
ids(pm::AbstractPowerModel, key::Symbol; nw::Int=pm.cnw) = keys(pm.ref[:nw][nw][key])

""
ref(pm::AbstractPowerModel, nw::Int) = pm.ref[:nw][nw]
ref(pm::AbstractPowerModel, nw::Int, key::Symbol) = pm.ref[:nw][nw][key]
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = pm.ref[:nw][nw][key][idx]
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx, param::String) = pm.ref[:nw][nw][key][idx][param]
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx, param::String, cnd::Int) = pm.ref[:nw][nw][key][idx][param][cnd]

ref(pm::AbstractPowerModel; nw::Int=pm.cnw) = pm.ref[:nw][nw]
ref(pm::AbstractPowerModel, key::Symbol; nw::Int=pm.cnw) = pm.ref[:nw][nw][key]
ref(pm::AbstractPowerModel, key::Symbol, idx; nw::Int=pm.cnw) = pm.ref[:nw][nw][key][idx]
ref(pm::AbstractPowerModel, key::Symbol, idx, param::String; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.ref[:nw][nw][key][idx][param][cnd]


var(pm::AbstractPowerModel, nw::Int) = pm.var[:nw][nw]
var(pm::AbstractPowerModel, nw::Int, key::Symbol) = pm.var[:nw][nw][key]
var(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = pm.var[:nw][nw][key][idx]
var(pm::AbstractPowerModel, nw::Int, cnd::Int) = pm.var[:nw][nw][:cnd][cnd]
var(pm::AbstractPowerModel, nw::Int, cnd::Int, key::Symbol) = pm.var[:nw][nw][:cnd][cnd][key]
var(pm::AbstractPowerModel, nw::Int, cnd::Int, key::Symbol, idx) = pm.var[:nw][nw][:cnd][cnd][key][idx]

var(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.var[:nw][nw][:cnd][cnd]
var(pm::AbstractPowerModel, key::Symbol; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.var[:nw][nw][:cnd][cnd][key]
var(pm::AbstractPowerModel, key::Symbol, idx; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.var[:nw][nw][:cnd][cnd][key][idx]

""
con(pm::AbstractPowerModel, nw::Int) = pm.con[:nw][nw]
con(pm::AbstractPowerModel, nw::Int, key::Symbol) = pm.con[:nw][nw][key]
con(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = pm.con[:nw][nw][key][idx]
con(pm::AbstractPowerModel, nw::Int, cnd::Int) = pm.con[:nw][nw][:cnd][cnd]
con(pm::AbstractPowerModel, nw::Int, cnd::Int, key::Symbol) = pm.con[:nw][nw][:cnd][cnd][key]
con(pm::AbstractPowerModel, nw::Int, cnd::Int, key::Symbol, idx) = pm.con[:nw][nw][:cnd][cnd][key][idx]

con(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.con[:nw][nw][:cnd][cnd]
con(pm::AbstractPowerModel, key::Symbol; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.con[:nw][nw][:cnd][cnd][key]
con(pm::AbstractPowerModel, key::Symbol, idx; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.con[:nw][nw][:cnd][cnd][key][idx]


function JuMP.optimize!(pm::AbstractPowerModel, optimizer::JuMP.OptimizerFactory)
    if pm.model.moi_backend.state == _MOI.Utilities.NO_OPTIMIZER
        _, solve_time, solve_bytes_alloc, sec_in_gc = @timed JuMP.optimize!(pm.model, optimizer)
    else
        Memento.warn(_LOGGER, "Model already contains optimizer factory, cannot use optimizer specified in `solve_generic_model`")
        _, solve_time, solve_bytes_alloc, sec_in_gc = @timed JuMP.optimize!(pm.model)
    end

    try
        solve_time = _MOI.get(pm.model, _MOI.SolveTime())
    catch
        Memento.warn(_LOGGER, "the given optimizer does not provide the SolveTime() attribute, falling back on @timed.  This is not a rigorous timing value.");
    end

    return solve_time
end

""
function run_model(file::String, model_type::Type, optimizer, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return run_model(data, model_type, optimizer, post_method; kwargs...)
end

""
function run_model(data::Dict{String,<:Any}, model_type::Type, optimizer, post_method; ref_extensions=[], solution_builder=solution_opf!, kwargs...)
    #start_time = time()
    pm = build_model(data, model_type, post_method; ref_extensions=ref_extensions, kwargs...)
    #Memento.debug(_LOGGER, "pm model build time: $(time() - start_time)")

    #start_time = time()
    result = optimize_model!(pm, optimizer; solution_builder=solution_builder)
    #Memento.debug(_LOGGER, "pm model solve and solution time: $(time() - start_time)")

    return result
end

""
function build_model(file::String, model_type::Type, post_method; kwargs...)
    data = PowerModels.parse_file(file)
    return build_model(data, model_type, post_method; kwargs...)
end

""
function build_model(data::Dict{String,<:Any}, model_type::Type, post_method; ref_extensions=[], multinetwork=false, multiconductor=false, kwargs...)
    # NOTE, this model constructor will build the ref dict using the latest info from the data

    #start_time = time()
    pm = InitializePowerModel(model_type, data; kwargs...)
    #Memento.info(LOGGER, "pm model_type time: $(time() - start_time)")

    if !multinetwork && ismultinetwork(pm)
        Memento.error(_LOGGER, "attempted to build a single-network model with multi-network data")
    end

    if !multiconductor && ismulticonductor(pm)
        Memento.error(_LOGGER, "attempted to build a single-conductor model with multi-conductor data")
    end

    start_time = time()
    ref_add_core!(pm)
    for ref_ext in ref_extensions
        ref_ext(pm)
    end
    Memento.debug(_LOGGER, "pm build ref time: $(time() - start_time)")

    start_time = time()
    post_method(pm)
    Memento.debug(_LOGGER, "pm post_method time: $(time() - start_time)")

    return pm
end


""
function optimize_model!(pm::AbstractPowerModel, optimizer::JuMP.OptimizerFactory; solution_builder = solution_opf!)
    start_time = time()
    solve_time = JuMP.optimize!(pm, optimizer)
    Memento.debug(_LOGGER, "JuMP model optimize time: $(time() - start_time)")

    start_time = time()
    result = build_solution(pm, solve_time; solution_builder = solution_builder)
    Memento.debug(_LOGGER, "PowerModels solution build time: $(time() - start_time)")

    pm.solution = result["solution"]

    return result
end


"used for building ref without the need to build a initialize an AbstractPowerModel"
function build_ref(data::Dict{String,<:Any}; ref_extensions=[])
    ref = InfrastructureModels.ref_initialize(data, _pm_global_keys)
    _ref_add_core!(ref[:nw])
    for ref_ext in ref_extensions
        ref_ext(pm)
    end
    return ref
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
function ref_add_core!(pm::AbstractPowerModel)
    _ref_add_core!(pm.ref[:nw])
end

function _ref_add_core!(nw_refs::Dict)
    for (nw, ref) in nw_refs
        if !haskey(ref, :conductor_ids)
            if !haskey(ref, :conductors)
                ref[:conductor_ids] = 1:1
            else
                ref[:conductor_ids] = 1:ref[:conductors]
            end
        end

        ### filter out inactive components ###
        ref[:bus] = Dict(x for x in ref[:bus] if (x.second["bus_type"] != pm_component_status_inactive["bus"]))
        ref[:load] = Dict(x for x in ref[:load] if (x.second["status"] != pm_component_status_inactive["load"] && x.second["load_bus"] in keys(ref[:bus])))
        ref[:shunt] = Dict(x for x in ref[:shunt] if (x.second["status"] != pm_component_status_inactive["shunt"] && x.second["shunt_bus"] in keys(ref[:bus])))
        ref[:gen] = Dict(x for x in ref[:gen] if (x.second["gen_status"] != pm_component_status_inactive["gen"] && x.second["gen_bus"] in keys(ref[:bus])))
        ref[:storage] = Dict(x for x in ref[:storage] if (x.second["status"] != pm_component_status_inactive["storage"] && x.second["storage_bus"] in keys(ref[:bus])))
        ref[:switch] = Dict(x for x in ref[:switch] if (x.second["status"] != pm_component_status_inactive["switch"] && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))
        ref[:branch] = Dict(x for x in ref[:branch] if (x.second["br_status"] != pm_component_status_inactive["branch"] && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))
        ref[:dcline] = Dict(x for x in ref[:dcline] if (x.second["br_status"] != pm_component_status_inactive["dcline"] && x.second["f_bus"] in keys(ref[:bus]) && x.second["t_bus"] in keys(ref[:bus])))


        ### setup arcs from edges ###
        ref[:arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in ref[:branch]]
        ref[:arcs] = [ref[:arcs_from]; ref[:arcs_to]]

        ref[:arcs_from_dc] = [(i,dcline["f_bus"],dcline["t_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_to_dc]   = [(i,dcline["t_bus"],dcline["f_bus"]) for (i,dcline) in ref[:dcline]]
        ref[:arcs_dc]      = [ref[:arcs_from_dc]; ref[:arcs_to_dc]]

        ref[:arcs_from_sw] = [(i,switch["f_bus"],switch["t_bus"]) for (i,switch) in ref[:switch]]
        ref[:arcs_to_sw]   = [(i,switch["t_bus"],switch["f_bus"]) for (i,switch) in ref[:switch]]
        ref[:arcs_sw] = [ref[:arcs_from_sw]; ref[:arcs_to_sw]]


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

        bus_arcs_sw = Dict((i, Tuple{Int,Int,Int}[]) for (i,bus) in ref[:bus])
        for (l,i,j) in ref[:arcs_sw]
            push!(bus_arcs_sw[i], (l,i,j))
        end
        ref[:bus_arcs_sw] = bus_arcs_sw



        ### reference bus lookup (a set to support multiple connected components) ###
        ref_buses = Dict{Int,Any}()
        for (k,v) in ref[:bus]
            if v["bus_type"] == 3
                ref_buses[k] = v
            end
        end

        ref[:ref_buses] = ref_buses

        if length(ref_buses) > 1
            Memento.warn(_LOGGER, "multiple reference buses found, $(keys(ref_buses)), this can cause infeasibility if they are in the same connected component")
        end


        ### aggregate info for pairs of connected buses ###
        if !haskey(ref, :buspairs)
            ref[:buspairs] = calc_buspair_parameters(ref[:bus], ref[:branch], ref[:conductor_ids], haskey(ref, :conductors))
        end
    end
end


"checks of any of the given keys are missing from the given dict"
function _check_missing_keys(dict, keys, type)
    missing = []
    for key in keys
        if !haskey(dict, key)
            push!(missing, key)
        end
    end
    if length(missing) > 0
        error(_LOGGER, "the formulation $(type) requires the following varible(s) $(keys) but the $(missing) variable(s) were not found in the model")
    end
end

