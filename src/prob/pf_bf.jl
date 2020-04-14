""
function run_pf_bf(file, model_type::Type, optimizer; kwargs...)
    return run_model(file, model_type, optimizer, build_pf_bf; kwargs...)
end

""
function build_pf_bf(pm::AbstractPowerModel)
    variable_bus_voltage(pm, bounded = false)
    variable_gen_power(pm, bounded = false)
    variable_branch_power(pm, bounded = false)
    variable_branch_current(pm, bounded = false)
    variable_dcline_power(pm, bounded = false)

    constraint_model_current(pm)

    for (i,bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_theta_ref(pm, i)
        constraint_voltage_magnitude_setpoint(pm, i)
    end

    for (i,bus) in ref(pm, :bus)
        constraint_power_balance(pm, i)

        # PV Bus Constraints
        if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            constraint_voltage_magnitude_setpoint(pm, i)
            for j in ref(pm, :bus_gens, i)
                constraint_gen_setpoint_active(pm, j)
            end
        end
    end

    for i in ids(pm, :branch)
        constraint_power_losses(pm, i)
        constraint_voltage_magnitude_difference(pm, i)
    end

    for (i,dcline) in ref(pm, :dcline)
        #constraint_dcline_power_losses(pm, i) not needed, active power flow fully defined by dc line setpoints
        constraint_dcline_setpoint_active(pm, i)

        f_bus = ref(pm, :bus)[dcline["f_bus"]]
        if f_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, f_bus["index"])
        end

        t_bus = ref(pm, :bus)[dcline["t_bus"]]
        if t_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, t_bus["index"])
        end
    end
end
