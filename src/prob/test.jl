######
#
# These are toy problem formulations used to test advanced features
# such as multi-network and multi-conductor models
#
######


"opf using current limits instead of thermal limits, tests constraint_current_limit"
function _run_cl_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_cl_opf; kwargs...)
end

""
function _post_cl_opf(pm::AbstractPowerModel)
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

        constraint_current_limit(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end


"opf with fixed switches"
function _run_sw_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_sw_opf; kwargs...)
end

""
function _post_sw_opf(pm::AbstractPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_switch_flow(pm)
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

    for i in ids(pm, :switch)
        constraint_switch_state(pm, i)
        constraint_switch_thermal_limit(pm, i)
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


"opf with controlable switches"
function _run_oswpf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_oswpf; ref_extensions=[ref_add_on_off_va_bounds!], solution_builder = _solution_osw!, kwargs...)
end

""
function _post_oswpf(pm::AbstractPowerModel)
    variable_voltage(pm)
    variable_generation(pm)

    variable_switch_indicator(pm)
    variable_switch_flow(pm)

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

    for i in ids(pm, :switch)
        constraint_switch_on_off(pm, i)
        constraint_switch_thermal_limit(pm, i)
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
function _solution_osw!(pm::AbstractPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_storage!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_dcline_flow!(sol, pm)
    add_setpoint_switch_flow!(sol, pm)
    add_setpoint_switch_status!(sol, pm)

    add_dual_kcl!(sol, pm)
    add_dual_sm!(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end



"opf with controlable switches, node breaker"
function _run_oswpf_nb(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _post_oswpf_nb; ref_extensions=[ref_add_on_off_va_bounds!], solution_builder = _solution_osw_nb!, kwargs...)
end

""
function _post_oswpf_nb(pm::AbstractPowerModel)
    variable_voltage_on_off(pm)
    variable_generation(pm)

    variable_switch_indicator(pm)
    variable_switch_flow(pm)

    variable_branch_indicator(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage_on_off(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :switch)
        constraint_switch_on_off(pm, i)
        constraint_switch_thermal_limit(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from_on_off(pm, i)
        constraint_ohms_yt_to_on_off(pm, i)

        constraint_voltage_angle_difference_on_off(pm, i)

        constraint_thermal_limit_from_on_off(pm, i)
        constraint_thermal_limit_to_on_off(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end

    # link branch and switch variables
    # branch indicator should only be zero iff,
    # it has two swtiches and they are both zero
    for (br, branch) in ref(pm, :branch)
        bus_fr = branch["f_bus"]
        bus_to = branch["t_bus"]
        bus_switches = []

        bus_arcs_sw_fr = ref(pm, :bus_arcs_sw, bus_fr)
        if length(bus_arcs_sw_fr) == 1
            for (sw,i,j) in bus_arcs_sw_fr
                push!(bus_switches, sw)
            end
        end

        bus_arcs_sw_to = ref(pm, :bus_arcs_sw, bus_to)
        if length(bus_arcs_sw_to) == 1
            for (sw,i,j) in bus_arcs_sw_to
                push!(bus_switches, sw)
            end
        end

        branch_z = var(pm, pm.cnw, :z_branch, br)
        switch_z = var(pm, pm.cnw, :z_switch)
        for sw in bus_switches
            JuMP.@NLconstraint(pm.model, branch_z >= switch_z[sw])
        end
        JuMP.@NLconstraint(pm.model, branch_z <= sum(switch_z[sw] for sw in bus_switches))
    end
end

""
function _solution_osw_nb!(pm::AbstractPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_storage!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_branch_status!(sol, pm)
    add_setpoint_dcline_flow!(sol, pm)
    add_setpoint_switch_flow!(sol, pm)
    add_setpoint_switch_status!(sol, pm)

    add_dual_kcl!(sol, pm)
    add_dual_sm!(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end


"opf with unit commitment, tests constraint_current_limit"
function _run_uc_opf(file, model_type::Type, solver; kwargs...)
    return run_model(file, model_type, solver, _post_uc_opf; solution_builder = _solution_uc!, kwargs...)
end

""
function _post_uc_opf(pm::AbstractPowerModel)
    variable_voltage(pm)

    variable_generation_indicator(pm)
    variable_generation_on_off(pm)

    variable_storage_indicator(pm)
    variable_storage_mi_on_off(pm)
    
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

    for i in ids(pm, :storage)
        constraint_storage_on_off(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end
    
    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity_mi(pm, i)
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

""
function _run_uc_mc_opf(file, model_type::Type, solver; kwargs...)
    return run_model(file, model_type, solver, _post_uc_mc_opf; solution_builder = _solution_uc!, multiconductor=true, kwargs...)
end

""
function _post_uc_mc_opf(pm::AbstractPowerModel)
    variable_generation_indicator(pm)

    variable_storage_indicator(pm)
    variable_storage_energy(pm)
    variable_storage_charge(pm)
    variable_storage_discharge(pm)
    variable_storage_complementary_indicator(pm)

    for c in conductor_ids(pm)
        variable_voltage(pm, cnd=c)
        
        variable_generation_on_off(pm, cnd=c)
        
        variable_active_storage(pm, cnd=c)
        variable_reactive_storage(pm, cnd=c)
        
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
            constraint_power_balance(pm, i, cnd=c)
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

    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity_mi(pm, i)
        constraint_storage_loss(pm, i, conductors=conductor_ids(pm))

        for c in conductor_ids(pm)
            constraint_storage_on_off(pm, i, cnd=c)
            constraint_storage_thermal_limit(pm, i, cnd=c)
        end
    end

    objective_min_fuel_and_flow_cost(pm)
end

""
function _solution_uc!(pm::AbstractPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_generator_status!(sol, pm)
    add_setpoint_storage!(sol, pm)
    add_setpoint_storage_status!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_dcline_flow!(sol, pm)

    add_dual_kcl!(sol, pm)
    add_dual_sm!(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end


""
function _run_mn_opb(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_mn_opb; ref_extensions=[ref_add_connected_components!], multinetwork=true, kwargs...)
end

""
function _post_mn_opb(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_generation(pm, nw=n)

        for i in ids(pm, :components, nw=n)
            constraint_network_power_balance(pm, i, nw=n)
        end
    end

    objective_min_fuel_cost(pm)
end


""
function _run_mn_pf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_mn_pf; multinetwork=true, kwargs...)
end

""
function _post_mn_pf(pm::AbstractPowerModel)
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
            constraint_power_balance(pm, i, nw=n)

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
function _run_mc_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_mc_opf; multiconductor=true, kwargs...)
end

""
function _post_mc_opf(pm::AbstractPowerModel)
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
            constraint_power_balance(pm, i, cnd=c)
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
function _run_mn_mc_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_mn_mc_opf; multinetwork=true, multiconductor=true, kwargs...)
end

""
function _post_mn_mc_opf(pm::AbstractPowerModel)
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
                constraint_power_balance(pm, i, nw=n, cnd=c)
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
function _run_strg_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_strg_opf; kwargs...)
end

""
function _post_strg_opf(pm::AbstractPowerModel)
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
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity_nl(pm, i)
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
function _run_mn_strg_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_mn_strg_opf; multinetwork=true, kwargs...)
end

""
function _post_mn_strg_opf(pm::AbstractPowerModel)
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
            constraint_power_balance(pm, i, nw=n)
        end

        for i in ids(pm, :storage, nw=n)
            constraint_storage_complementarity_nl(pm, i, nw=n)
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



"opf with mi storage variables"
function _run_strg_mi_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_strg_mi_opf; kwargs...)
end

""
function _post_strg_mi_opf(pm::AbstractPowerModel)
    variable_voltage(pm)
    variable_generation(pm)
    variable_storage_mi(pm)
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

    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity_mi(pm, i)
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


""
function _run_mn_mc_strg_opf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _post_mn_mc_strg_opf; multinetwork=true, multiconductor=true, kwargs...)
end

"warning: this model is not realistic or physically reasonable, it is only for test coverage"
function _post_mn_mc_strg_opf(pm::AbstractPowerModel)
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
                constraint_power_balance(pm, i, nw=n, cnd=c)
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
            constraint_storage_complementarity_nl(pm, i, nw=n)
            constraint_storage_loss(pm, i, nw=n, conductors=conductor_ids(pm, nw=n))
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
