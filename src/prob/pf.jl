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

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
        constraint_voltage_magnitude_setpoint(pm, i)
    end

    for (i,bus) in ref(pm, :bus)
        constraint_kcl_shunt(pm, i)

        # PV Bus Constraints
        if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            # soft equality needed becouse v in file is not precice enough to ensure feasiblity
            constraint_voltage_magnitude_setpoint(pm, i; epsilon = 0.00001)
            for j in ref(pm, :bus_gens, i)
                constraint_active_gen_setpoint(pm, j)
            end
        end
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)
    end

    for i in ids(pm, :dcline)
        #constraint_dcline(pm, i) not needed, active power flow fully defined by dc line setpoints
        constraint_active_dcline_setpoint(pm, i)
        constraint_voltage_dcline_setpoint(pm, i; epsilon = 0.00001)
    end
end
