""
function run_ac_opf(file, optimizer; kwargs...)
    return run_opf(file, ACPPowerModel, optimizer; kwargs...)
end

""
function run_dc_opf(file, optimizer; kwargs...)
    return run_opf(file, DCPPowerModel, optimizer; kwargs...)
end

""
function run_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, post_opf; kwargs...)
end

""
function post_opf(pm::AbstractPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end



"a toy example of how to model with multi-networks"
function run_mn_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, post_mn_opf; multinetwork=true, kwargs...)
end

""
function post_mn_opf(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n)
        variable_generation(pm, nw=n)
        variable_branch_flow(pm, nw=n)
        variable_dcline_flow(pm, nw=n)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_power_balance(pm, i, nw=n)
        end

        for i in ids(pm, :branch, nw=n)
            constraint_ohms_yt_from(pm, i, nw=n)
            constraint_ohms_yt_to(pm, i, nw=n)

            constraint_voltage_angle_difference(pm, i, nw=n)

            constraint_thermal_limit_from(pm, i, nw=n)
            constraint_thermal_limit_to(pm, i, nw=n)
        end

        for i in ids(pm, :dcline, nw=n)
            constraint_dcline(pm, i, nw=n)
        end
    end

    objective_min_fuel_and_flow_cost(pm)
end


"a toy example of how to model with multi-networks and storage"
function run_mn_strg_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, post_mn_strg_opf; multinetwork=true, kwargs...)
end

""
function post_mn_strg_opf(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n)
        variable_generation(pm, nw=n)
        variable_storage_mi(pm, nw=n)
        variable_branch_flow(pm, nw=n)
        variable_dcline_flow(pm, nw=n)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_power_balance(pm, i, nw=n)
        end

        for i in ids(pm, :storage, nw=n)
            constraint_storage_complementarity_mi(pm, i, nw=n)
            constraint_storage_loss(pm, i, nw=n)
            constraint_storage_thermal_limit(pm, i, nw=n)
        end

        for i in ids(pm, :branch, nw=n)
            constraint_ohms_yt_from(pm, i, nw=n)
            constraint_ohms_yt_to(pm, i, nw=n)

            constraint_voltage_angle_difference(pm, i, nw=n)

            constraint_thermal_limit_from(pm, i, nw=n)
            constraint_thermal_limit_to(pm, i, nw=n)
        end

        for i in ids(pm, :dcline, nw=n)
            constraint_dcline(pm, i, nw=n)
        end
    end

    network_ids = sort(collect(nw_ids(pm)))

    n_1 = network_ids[1]
    for i in ids(pm, :storage, nw=n_1)
        constraint_storage_state(pm, i, nw=n_1)
    end

    for n_2 in network_ids[2:end]
        for i in ids(pm, :storage, nw=n_2)
            constraint_storage_state(pm, i, n_1, n_2)
        end
        n_1 = n_2
    end

    objective_min_fuel_and_flow_cost(pm)
end




"""
Solves an opf using ptdfs with no explicit voltage or line flow variables.

This formulation is most often used when a small subset of the line flow
constraints are active in the data model.
"""
function run_ptdf_opf(file, model_type::Type, optimizer; full_inverse=false, kwargs...)
    if !full_inverse
        return run_model(file, model_type, optimizer, post_ptdf_opf; ref_extensions=[ref_add_connected_components!,ref_add_sm!], solution_builder=solution_ptdf_opf!, kwargs...)
    else
        return run_model(file, model_type, optimizer, post_ptdf_opf; ref_extensions=[ref_add_connected_components!,ref_add_sm_inv!], solution_builder=solution_ptdf_opf!, kwargs...)
    end
end

""
function post_ptdf_opf(pm::AbstractPowerModel)
    variable_generation(pm)

    for i in ids(pm, :bus)
        expression_power_injection(pm, i)
    end
    for i in ids(pm, :branch)
        expression_branch_flow_from(pm, i)
        expression_branch_flow_to(pm, i)
    end

    objective_min_fuel_cost(pm)

    constraint_model_voltage(pm)

    # this constraint is implicit in this model
    #for i in ids(pm, :ref_buses)
    #    constraint_theta_ref(pm, i)
    #end

    for i in ids(pm, :components)
        constraint_network_power_balance(pm, i)
    end

    for i in ids(pm, :branch)
        # requires optional vad parameters
        #constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end
end

""
function solution_ptdf_opf!(pm::AbstractPowerModel, sol::Dict{String,<:Any})
    add_setpoint_generator_power!(sol, pm)
end


""
function ref_add_sm!(pm::AbstractPowerModel)
    Memento.error(_LOGGER, "ref_add_sm! is only valid for DCPPowerModels")
end

""
function ref_add_sm_inv!(pm::AbstractPowerModel)
    Memento.error(_LOGGER, "ref_add_sm_inv! is only valid for DCPPowerModels")
end

