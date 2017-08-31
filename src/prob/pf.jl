export run_pf, run_ac_pf, run_dc_pf

""
function run_ac_pf(file, solver; kwargs...)
    return run_pf(file, ACPPowerModel, solver; kwargs...)
end

""
function run_dc_pf(file, solver; kwargs...)
    return run_pf(file, DCPPowerModel, solver; kwargs...)
end

""
function run_pf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_pf; kwargs...)
end

""
function post_pf(pm::GenericPowerModel)
    variable_voltage(pm, bounded = false)
    variable_generation(pm, bounded = false)
    variable_line_flow(pm, bounded = false)
    variable_dcline_flow(pm, bounded = false)

    constraint_voltage(pm)

    for (i,bus) in pm.ref[:ref_buses]
        constraint_theta_ref(pm, bus)
        constraint_voltage_magnitude_setpoint(pm, bus)
    end

    for (i,bus) in pm.ref[:bus]
        constraint_kcl_shunt(pm, bus)

        # PV Bus Constraints
        if length(pm.ref[:bus_gens][i]) > 0 && !(i in keys(pm.ref[:ref_buses]))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            constraint_voltage_magnitude_setpoint(pm, bus)
            for j in pm.ref[:bus_gens][i]
                constraint_active_gen_setpoint(pm, pm.ref[:gen][j])
            end
        end
    end

    for (i,branch) in pm.ref[:branch]
        constraint_ohms_yt_from(pm, branch)
        constraint_ohms_yt_to(pm, branch)
    end

    for (i,dcline) in pm.ref[:dcline]
        #constraint_dcline(pm, dcline) not needed, active power flow fully defined by dc line setpoints
        constraint_active_dcline_setpoint(pm, dcline)
        #constraint_voltage_dcline_setpoint(pm, dcline)

        f_bus = pm.ref[:bus][dcline["f_bus"]]
        if f_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, f_bus)
        end

        t_bus = pm.ref[:bus][dcline["t_bus"]]
        if t_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, t_bus)
        end
    end
end
