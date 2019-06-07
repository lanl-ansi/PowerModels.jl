######
#
# These are toy problem formulations used to test advanced features
# such as multi-network and multi-conductor models
#
######


"opf using current limits instead of thermal limits, tests constraint_current_limit"
function _run_cl_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_cl_opf; kwargs...)
end

""
function _post_cl_opf(pm::GenericPowerModel)
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
        constraint_power_balance_shunt(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_current_limit(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end


"opf with unit commitment, tests constraint_current_limit"
function _run_uc_opf(file, model_constructor, solver; kwargs...)
    return run_model(file, model_constructor, solver, _post_uc_opf; solution_builder = _solution_uc!, kwargs...)
end

""
function _post_uc_opf(pm::GenericPowerModel)
    variable_voltage(pm)

    variable_generation_indicator(pm)
    variable_generation_on_off(pm)

    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :gen)
        constraint_generation_on_off(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_shunt(pm, i)
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


""
function _run_uc_mc_opf(file, model_constructor, solver; kwargs...)
    return run_model(file, model_constructor, solver, _post_uc_mc_opf; solution_builder = _solution_uc!, multiconductor=true, kwargs...)
end

""
function _post_uc_mc_opf(pm::GenericPowerModel)
    variable_generation_indicator(pm)

    for c in conductor_ids(pm)
        variable_voltage(pm, cnd=c)
        variable_voltage(pm, cnd=c)

        variable_generation_on_off(pm, cnd=c)

        variable_branch_flow(pm, cnd=c)
        variable_dcline_flow(pm, cnd=c)

        constraint_model_voltage(pm, cnd=c)

        for i in ids(pm, :ref_buses)
            constraint_theta_ref(pm, i, cnd=c)
        end

        for i in ids(pm, :gen)
            constraint_generation_on_off(pm, i, cnd=c)
        end

        for i in ids(pm, :bus)
            constraint_power_balance_shunt(pm, i, cnd=c)
        end

        for i in ids(pm, :branch)
            constraint_ohms_yt_from(pm, i, cnd=c)
            constraint_ohms_yt_to(pm, i, cnd=c)

            constraint_voltage_angle_difference(pm, i, cnd=c)

            constraint_thermal_limit_from(pm, i, cnd=c)
            constraint_thermal_limit_to(pm, i, cnd=c)
        end

        for i in ids(pm, :dcline)
            constraint_dcline(pm, i, cnd=c)
        end
    end

    objective_min_fuel_and_flow_cost(pm)
end

""
function _solution_uc!(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_generator_status!(sol, pm)
    add_setpoint_storage!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_dcline_flow!(sol, pm)

    add_dual_kcl!(sol, pm)
    add_dual_sm!(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end


""
function _run_mn_opb(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_mn_opb; ref_extensions=[ref_add_connected_components!], multinetwork=true, kwargs...)
end

""
function _post_mn_opb(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_generation(pm, nw=n)

        for i in ids(pm, :components, nw=n)
            constraint_network_power_balance(pm, i, nw=n)
        end
    end

    objective_min_fuel_cost(pm)
end


""
function _run_mn_pf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_mn_pf; multinetwork=true, kwargs...)
end

""
function _post_mn_pf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n, bounded = false)
        variable_generation(pm, nw=n, bounded = false)
        variable_branch_flow(pm, nw=n, bounded = false)
        variable_dcline_flow(pm, nw=n, bounded = false)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
            constraint_voltage_magnitude_setpoint(pm, i, nw=n)
        end

        for (i,bus) in ref(pm, :bus, nw=n)
            constraint_power_balance_shunt(pm, i, nw=n)

            # PV Bus Constraints
            if length(ref(pm, :bus_gens, i, nw=n)) > 0 && !(i in ids(pm, :ref_buses, nw=n))
                @assert bus["bus_type"] == 2

                constraint_voltage_magnitude_setpoint(pm, i, nw=n)
                for j in ref(pm, :bus_gens, i, nw=n)
                    constraint_active_gen_setpoint(pm, j, nw=n)
                end
            end
        end

        for i in ids(pm, :branch, nw=n)
            constraint_ohms_yt_from(pm, i, nw=n)
            constraint_ohms_yt_to(pm, i, nw=n)
        end

        for (i,dcline) in ref(pm, :dcline, nw=n)
            constraint_active_dcline_setpoint(pm, i, nw=n)

            f_bus = ref(pm, :bus, nw=n)[dcline["f_bus"]]
            if f_bus["bus_type"] == 1
                constraint_voltage_magnitude_setpoint(pm, n, f_bus["index"])
            end

            t_bus = ref(pm, :bus, nw=n)[dcline["t_bus"]]
            if t_bus["bus_type"] == 1
                constraint_voltage_magnitude_setpoint(pm, n, t_bus["index"])
            end
        end
    end
end



""
function _run_mc_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_mc_opf; multiconductor=true, kwargs...)
end

""
function _post_mc_opf(pm::GenericPowerModel)
    for c in conductor_ids(pm)
        variable_voltage(pm, cnd=c)
        variable_generation(pm, cnd=c)
        variable_branch_flow(pm, cnd=c)
        variable_dcline_flow(pm, cnd=c)

        constraint_model_voltage(pm, cnd=c)

        for i in ids(pm, :ref_buses)
            constraint_theta_ref(pm, i, cnd=c)
        end

        for i in ids(pm, :bus)
            constraint_power_balance_shunt(pm, i, cnd=c)
        end

        for i in ids(pm, :branch)
            constraint_ohms_yt_from(pm, i, cnd=c)
            constraint_ohms_yt_to(pm, i, cnd=c)

            constraint_voltage_angle_difference(pm, i, cnd=c)

            constraint_thermal_limit_from(pm, i, cnd=c)
            constraint_thermal_limit_to(pm, i, cnd=c)
        end

        for i in ids(pm, :dcline)
            constraint_dcline(pm, i, cnd=c)
        end
    end

    objective_min_fuel_and_flow_cost(pm)
end



""
function _run_mn_mc_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_mn_mc_opf; multinetwork=true, multiconductor=true, kwargs...)
end

""
function _post_mn_mc_opf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        for c in conductor_ids(pm, nw=n)
            variable_voltage(pm, nw=n, cnd=c)
            variable_generation(pm, nw=n, cnd=c)
            variable_branch_flow(pm, nw=n, cnd=c)
            variable_dcline_flow(pm, nw=n, cnd=c)

            constraint_model_voltage(pm, nw=n, cnd=c)

            for i in ids(pm, :ref_buses, nw=n)
                constraint_theta_ref(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :bus, nw=n)
                constraint_power_balance_shunt(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :branch, nw=n)
                constraint_ohms_yt_from(pm, i, nw=n, cnd=c)
                constraint_ohms_yt_to(pm, i, nw=n, cnd=c)

                constraint_voltage_angle_difference(pm, i, nw=n, cnd=c)

                constraint_thermal_limit_from(pm, i, nw=n, cnd=c)
                constraint_thermal_limit_to(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :dcline, nw=n)
                constraint_dcline(pm, i, nw=n, cnd=c)
            end
        end
    end

    objective_min_fuel_and_flow_cost(pm)
end



"opf with storage"
function _run_strg_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_strg_opf; kwargs...)
end

""
function _post_strg_opf(pm::GenericPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_storage(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_shunt_storage(pm, i)
    end

    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity(pm, i)
        constraint_storage_loss(pm, i)
        constraint_storage_thermal_limit(pm, i)
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


"multi-network opf with storage"
function _run_mn_strg_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_mn_strg_opf; multinetwork=true, kwargs...)
end

""
function _post_mn_strg_opf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n)
        variable_generation(pm, nw=n)
        variable_storage(pm, nw=n)
        variable_branch_flow(pm, nw=n)
        variable_dcline_flow(pm, nw=n)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_power_balance_shunt_storage(pm, i, nw=n)
        end

        for i in ids(pm, :storage, nw=n)
            constraint_storage_complementarity(pm, i, nw=n)
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


""
function _run_mn_mc_strg_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_mn_mc_strg_opf; multinetwork=true, multiconductor=true, kwargs...)
end

"warning: this model is not realistic or physically reasonable, it is only for test coverage"
function _post_mn_mc_strg_opf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_storage_energy(pm, nw=n)
        variable_storage_charge(pm, nw=n)
        variable_storage_discharge(pm, nw=n)

        for c in conductor_ids(pm, nw=n)
            variable_voltage(pm, nw=n, cnd=c)
            variable_generation(pm, nw=n, cnd=c)
            variable_active_storage(pm, nw=n, cnd=c)
            variable_reactive_storage(pm, nw=n, cnd=c)
            variable_branch_flow(pm, nw=n, cnd=c)
            variable_dcline_flow(pm, nw=n, cnd=c)

            constraint_model_voltage(pm, nw=n, cnd=c)

            for i in ids(pm, :ref_buses, nw=n)
                constraint_theta_ref(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :bus, nw=n)
                constraint_power_balance_shunt_storage(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :storage, nw=n)
                constraint_storage_thermal_limit(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :branch, nw=n)
                constraint_ohms_yt_from(pm, i, nw=n, cnd=c)
                constraint_ohms_yt_to(pm, i, nw=n, cnd=c)

                constraint_voltage_angle_difference(pm, i, nw=n, cnd=c)

                constraint_thermal_limit_from(pm, i, nw=n, cnd=c)
                constraint_thermal_limit_to(pm, i, nw=n, cnd=c)
            end

            for i in ids(pm, :dcline, nw=n)
                constraint_dcline(pm, i, nw=n, cnd=c)
            end
        end

        for i in ids(pm, :storage, nw=n)
            constraint_storage_complementarity(pm, i, nw=n)
            constraint_storage_loss(pm, i, nw=n)
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
