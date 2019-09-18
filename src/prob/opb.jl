""
function run_nfa_opb(file, optimizer; kwargs...)
    return run_opb(file, NFAPowerModel, optimizer; kwargs...)
end

"the optimal power balance problem"
function run_opb(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, post_opb; ref_extensions=[ref_add_connected_components!], kwargs...)
end

""
function post_opb(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_generation(pm)

    objective_min_fuel_cost(pm)

    for i in ids(pm, :components)
        constraint_network_power_balance(pm, i)
    end
end


function ref_add_connected_components!(pm::AbstractPowerModel)
    if InfrastructureModels.ismultinetwork(pm.data)
        nws_data = pm.data["nw"]
    else
        nws_data = Dict("0" => pm.data)
    end

    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref(pm, nw_id)
        component_sets = PowerModels.calc_connected_components(nw_data)
        nw_ref[:components] = Dict(i => c for (i,c) in enumerate(sort(collect(component_sets); by=length)))
    end
end
