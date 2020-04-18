######
#
# These are toy problem formulations used to test advanced features
# such as multi-network and multi-conductor models
#
######


"opf using current limits instead of thermal limits, tests constraint_current_limit"
function _run_opf_cl(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _build_opf_cl; kwargs...)
end

""
function _build_opf_cl(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_dcline_power_losses(pm, i)
    end
end


"opf with fixed switches"
function _run_opf_sw(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _build_opf_sw; kwargs...)
end

""
function _build_opf_sw(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_switch_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_dcline_power_losses(pm, i)
    end
end


"opf with controlable switches"
function _run_oswpf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _build_oswpf; ref_extensions=[ref_add_on_off_va_bounds!], kwargs...)
end

""
function _build_oswpf(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)

    variable_switch_indicator(pm)
    variable_switch_power(pm)

    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_dcline_power_losses(pm, i)
    end
end


"opf with controlable switches, node breaker"
function _run_oswpf_nb(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, _build_oswpf_nb; ref_extensions=[ref_add_on_off_va_bounds!], kwargs...)
end

""
function _build_oswpf_nb(pm::AbstractPowerModel)
    variable_bus_voltage_on_off(pm)
    variable_gen_power(pm)

    variable_switch_indicator(pm)
    variable_switch_power(pm)

    variable_branch_indicator(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_dcline_power_losses(pm, i)
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
            JuMP.@constraint(pm.model, branch_z >= switch_z[sw])
        end
        JuMP.@constraint(pm.model, branch_z <= sum(switch_z[sw] for sw in bus_switches))
    end
end


# a simple maximum loadability problem
function _run_mld(file, model_constructor, solver; kwargs...)
    return run_model(file, model_constructor, solver, _build_mld; kwargs...)
end

function _build_mld(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

    variable_load_power_factor(pm, relax=true)
    variable_shunt_admittance_factor(pm, relax=true)

    objective_max_loadability(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_ls(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline_power_losses(pm, i)
    end
end


"opf with unit commitment, tests constraint_current_limit"
function _run_ucopf(file, model_type::Type, solver; kwargs...)
    return run_model(file, model_type, solver, _build_ucopf; kwargs...)
end

""
function _build_ucopf(pm::AbstractPowerModel)
    variable_bus_voltage(pm)

    variable_gen_indicator(pm)
    variable_gen_power_on_off(pm)

    variable_storage_indicator(pm)
    variable_storage_power_mi_on_off(pm)

    variable_branch_power(pm)
    variable_dcline_power(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :gen)
        constraint_gen_power_on_off(pm, i)
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
        constraint_storage_losses(pm, i)
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
        constraint_dcline_power_losses(pm, i)
    end
end


""
function _run_mn_opb(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _build_mn_opb; ref_extensions=[ref_add_connected_components!], multinetwork=true, kwargs...)
end

""
function _build_mn_opb(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_gen_power(pm, nw=n)

        for i in ids(pm, :components, nw=n)
            constraint_network_power_balance(pm, i, nw=n)
        end
    end

    objective_min_fuel_cost(pm)
end


""
function _run_mn_pf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _build_mn_pf; multinetwork=true, kwargs...)
end

""
function _build_mn_pf(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_bus_voltage(pm, nw=n, bounded = false)
        variable_gen_power(pm, nw=n, bounded = false)
        variable_branch_power(pm, nw=n, bounded = false)
        variable_dcline_power(pm, nw=n, bounded = false)

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
                    constraint_gen_setpoint_active(pm, j, nw=n)
                end
            end
        end

        for i in ids(pm, :branch, nw=n)
            constraint_ohms_yt_from(pm, i, nw=n)
            constraint_ohms_yt_to(pm, i, nw=n)
        end

        for (i,dcline) in ref(pm, :dcline, nw=n)
            constraint_dcline_setpoint_active(pm, i, nw=n)

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


"opf with storage"
function _run_opf_strg(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _build_opf_strg; kwargs...)
end

""
function _build_opf_strg(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_storage_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_storage_losses(pm, i)
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
        constraint_dcline_power_losses(pm, i)
    end
end


"opf with mi storage variables"
function _run_opf_strg_mi(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _build_opf_strg_mi; kwargs...)
end

""
function _build_opf_strg_mi(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_storage_power_mi(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

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
        constraint_storage_losses(pm, i)
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
        constraint_dcline_power_losses(pm, i)
    end
end


"opf with tap magnitude and angle as optimization variables"
function _run_opf_oltc_pst(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, _build_opf_oltc_pst; kwargs...)
end

""
function _build_opf_oltc_pst(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)

    variable_branch_transform(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_y_oltc_pst_from(pm, i)
        constraint_ohms_y_oltc_pst_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline_power_losses(pm, i)
    end
end
