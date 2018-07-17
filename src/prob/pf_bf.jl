export run_pf_bf, run_ac_pf_bf, run_dc_pf_bf

""
function run_pf_bf(file, model_constructor, solver; kwargs...)
    if model_constructor != SOCBFPowerModel
        error(LOGGER, "The problem type pf_bf at the moment only supports the SOCBFForm formulation")
    end
    return run_generic_model(file, model_constructor, solver, post_pf_bf; kwargs...)
end

""
function post_pf_bf(pm::GenericPowerModel)
    variable_voltage(pm, bounded = false)
    variable_generation(pm, bounded = false)
    variable_branch_flow(pm, bounded = false)
    variable_branch_current(pm, bounded = false)
    variable_dcline_flow(pm, bounded = false)

    for (i,bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_theta_ref(pm, i)
        constraint_voltage_magnitude_setpoint(pm, i)
    end

    for (i,bus) in ref(pm, :bus)
        constraint_kcl_shunt(pm, i)

        # PV Bus Constraints
        if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            constraint_voltage_magnitude_setpoint(pm, i)
            for j in ref(pm, :bus_gens, i)
                constraint_active_gen_setpoint(pm, j)
            end
        end
    end

    for i in ids(pm, :branch)
        constraint_flow_losses(pm, i)
        constraint_voltage_magnitude_difference(pm, i)
        constraint_branch_current(pm, i)
    end

    for (i,dcline) in ref(pm, :dcline)
        #constraint_dcline(pm, i) not needed, active power flow fully defined by dc line setpoints
        constraint_active_dcline_setpoint(pm, i)

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
