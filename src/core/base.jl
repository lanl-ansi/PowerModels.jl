# stuff that is universal to all power models

"root of the power formulation type hierarchy"
abstract type AbstractPowerModel <: _IM.AbstractInfrastructureModel end

"a macro for adding the base PowerModels fields to a type definition"
_IM.@def pm_fields begin
    # this must be explicitly qualified, so that it works in downstream
    # packages that use import PowerModels and this command appears in the
    # downstream package's scope
    PowerModels.@im_fields
end


""
ismulticonductor(pm::AbstractPowerModel, nw::Int) = haskey(pm.ref[:nw][nw], :conductors)
ismulticonductor(pm::AbstractPowerModel; nw::Int=pm.cnw) = haskey(pm.ref[:nw][nw], :conductors)

""
conductor_ids(pm::AbstractPowerModel, nw::Int) = pm.ref[:nw][nw][:conductor_ids]
conductor_ids(pm::AbstractPowerModel; nw::Int=pm.cnw) = pm.ref[:nw][nw][:conductor_ids]


""
function run_model(file::String, model_type::Type, optimizer, build_method; kwargs...)
    data = PowerModels.parse_file(file)
    return run_model(data, model_type, optimizer, build_method; kwargs...)
end

""
function run_model(data::Dict{String,<:Any}, model_type::Type, optimizer, build_method;
        ref_extensions=[], solution_processors=[], relax_integrality=false,
        multinetwork=false, multiconductor=false, kwargs...)

    if multinetwork != _IM.ismultinetwork(data)
        model_requirement = multinetwork ? "multi-network" : "single-network"
        data_type = _IM.ismultinetwork(data) ? "multi-network" : "single-network"
        Memento.error(_LOGGER, "attempted to build a $(model_requirement) model with $(data_type) data")
    end

    if multiconductor != ismulticonductor(data)
        model_requirement = multiconductor ? "multi-conductor" : "single-conductor"
        data_type = ismulticonductor(data) ? "multi-conductor" : "single-conductor"
        Memento.error(_LOGGER, "attempted to build a $(model_requirement) model with $(data_type) data")
    end

    start_time = time()
    pm = instantiate_model(data, model_type, build_method; ref_extensions=ref_extensions, kwargs...)
    Memento.debug(_LOGGER, "pm model build time: $(time() - start_time)")

    start_time = time()
    result = optimize_model!(pm, relax_integrality=relax_integrality, optimizer=optimizer, solution_processors=solution_processors)
    Memento.debug(_LOGGER, "pm model solve and solution time: $(time() - start_time)")

    return result
end


""
function instantiate_model(file::String, model_type::Type, build_method; kwargs...)
    data = PowerModels.parse_file(file)
    return instantiate_model(data, model_type, build_method; kwargs...)
end

""
function instantiate_model(data::Dict{String,<:Any}, model_type::Type, build_method; kwargs...)
    return _IM.instantiate_model(data, model_type, build_method, ref_add_core!, _pm_global_keys; kwargs...)
end


"used for building ref without the need to build a initialize an AbstractPowerModel"
function build_ref(data::Dict{String,<:Any}; ref_extensions=[])
    return _IM.build_ref(data, ref_add_core!, _pm_global_keys, ref_extensions=ref_extensions)
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
function ref_add_core!(ref::Dict{Symbol,Any})
    for (nw, nw_ref) in ref[:nw]
        if !haskey(nw_ref, :conductor_ids)
            if !haskey(nw_ref, :conductors)
                nw_ref[:conductor_ids] = 1:1
            else
                nw_ref[:conductor_ids] = 1:nw_ref[:conductors]
            end
        end

        ### filter out inactive components ###
        nw_ref[:bus] = Dict(x for x in nw_ref[:bus] if (x.second["bus_type"] != pm_component_status_inactive["bus"]))
        nw_ref[:load] = Dict(x for x in nw_ref[:load] if (x.second["status"] != pm_component_status_inactive["load"] && x.second["load_bus"] in keys(nw_ref[:bus])))
        nw_ref[:shunt] = Dict(x for x in nw_ref[:shunt] if (x.second["status"] != pm_component_status_inactive["shunt"] && x.second["shunt_bus"] in keys(nw_ref[:bus])))
        nw_ref[:gen] = Dict(x for x in nw_ref[:gen] if (x.second["gen_status"] != pm_component_status_inactive["gen"] && x.second["gen_bus"] in keys(nw_ref[:bus])))
        nw_ref[:storage] = Dict(x for x in nw_ref[:storage] if (x.second["status"] != pm_component_status_inactive["storage"] && x.second["storage_bus"] in keys(nw_ref[:bus])))
        nw_ref[:switch] = Dict(x for x in nw_ref[:switch] if (x.second["status"] != pm_component_status_inactive["switch"] && x.second["f_bus"] in keys(nw_ref[:bus]) && x.second["t_bus"] in keys(nw_ref[:bus])))
        nw_ref[:branch] = Dict(x for x in nw_ref[:branch] if (x.second["br_status"] != pm_component_status_inactive["branch"] && x.second["f_bus"] in keys(nw_ref[:bus]) && x.second["t_bus"] in keys(nw_ref[:bus])))
        nw_ref[:dcline] = Dict(x for x in nw_ref[:dcline] if (x.second["br_status"] != pm_component_status_inactive["dcline"] && x.second["f_bus"] in keys(nw_ref[:bus]) && x.second["t_bus"] in keys(nw_ref[:bus])))


        ### setup arcs from edges ###
        nw_ref[:arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in nw_ref[:branch]]
        nw_ref[:arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in nw_ref[:branch]]
        nw_ref[:arcs] = [nw_ref[:arcs_from]; nw_ref[:arcs_to]]

        nw_ref[:arcs_from_dc] = [(i,dcline["f_bus"],dcline["t_bus"]) for (i,dcline) in nw_ref[:dcline]]
        nw_ref[:arcs_to_dc]   = [(i,dcline["t_bus"],dcline["f_bus"]) for (i,dcline) in nw_ref[:dcline]]
        nw_ref[:arcs_dc]      = [nw_ref[:arcs_from_dc]; nw_ref[:arcs_to_dc]]

        nw_ref[:arcs_from_sw] = [(i,switch["f_bus"],switch["t_bus"]) for (i,switch) in nw_ref[:switch]]
        nw_ref[:arcs_to_sw]   = [(i,switch["t_bus"],switch["f_bus"]) for (i,switch) in nw_ref[:switch]]
        nw_ref[:arcs_sw] = [nw_ref[:arcs_from_sw]; nw_ref[:arcs_to_sw]]


        ### bus connected component lookups ###
        bus_loads = Dict((i, Int[]) for (i,bus) in nw_ref[:bus])
        for (i, load) in nw_ref[:load]
            push!(bus_loads[load["load_bus"]], i)
        end
        nw_ref[:bus_loads] = bus_loads

        bus_shunts = Dict((i, Int[]) for (i,bus) in nw_ref[:bus])
        for (i,shunt) in nw_ref[:shunt]
            push!(bus_shunts[shunt["shunt_bus"]], i)
        end
        nw_ref[:bus_shunts] = bus_shunts

        bus_gens = Dict((i, Int[]) for (i,bus) in nw_ref[:bus])
        for (i,gen) in nw_ref[:gen]
            push!(bus_gens[gen["gen_bus"]], i)
        end
        nw_ref[:bus_gens] = bus_gens

        bus_storage = Dict((i, Int[]) for (i,bus) in nw_ref[:bus])
        for (i,strg) in nw_ref[:storage]
            push!(bus_storage[strg["storage_bus"]], i)
        end
        nw_ref[:bus_storage] = bus_storage

        bus_arcs = Dict((i, Tuple{Int,Int,Int}[]) for (i,bus) in nw_ref[:bus])
        for (l,i,j) in nw_ref[:arcs]
            push!(bus_arcs[i], (l,i,j))
        end
        nw_ref[:bus_arcs] = bus_arcs

        bus_arcs_dc = Dict((i, Tuple{Int,Int,Int}[]) for (i,bus) in nw_ref[:bus])
        for (l,i,j) in nw_ref[:arcs_dc]
            push!(bus_arcs_dc[i], (l,i,j))
        end
        nw_ref[:bus_arcs_dc] = bus_arcs_dc

        bus_arcs_sw = Dict((i, Tuple{Int,Int,Int}[]) for (i,bus) in nw_ref[:bus])
        for (l,i,j) in nw_ref[:arcs_sw]
            push!(bus_arcs_sw[i], (l,i,j))
        end
        nw_ref[:bus_arcs_sw] = bus_arcs_sw



        ### reference bus lookup (a set to support multiple connected components) ###
        ref_buses = Dict{Int,Any}()
        for (k,v) in nw_ref[:bus]
            if v["bus_type"] == 3
                ref_buses[k] = v
            end
        end

        nw_ref[:ref_buses] = ref_buses

        if length(ref_buses) > 1
            Memento.warn(_LOGGER, "multiple reference buses found, $(keys(ref_buses)), this can cause infeasibility if they are in the same connected component")
        end

        ### aggregate info for pairs of connected buses ###
        if !haskey(nw_ref, :buspairs)
            nw_ref[:buspairs] = calc_buspair_parameters(nw_ref[:bus], nw_ref[:branch], nw_ref[:conductor_ids], haskey(nw_ref, :conductors))
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

