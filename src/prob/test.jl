######
#
# These are toy problem formulations used to test advanced features
# such as multi-network and multi-phase models
#
######

""
function run_mn_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_mn_opf; multinetwork=true, kwargs...)
end

""
function post_mn_opf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n)
        variable_generation(pm, nw=n)
        variable_branch_flow(pm, nw=n)
        variable_dcline_flow(pm, nw=n)

        constraint_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_kcl_shunt(pm, i, nw=n)
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

    objective_min_fuel_cost(pm)
end

""
function run_mn_pf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_mn_pf; multinetwork=true, kwargs...)
end

function post_mn_pf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n, bounded = false)
        variable_generation(pm, nw=n, bounded = false)
        variable_branch_flow(pm, nw=n, bounded = false)
        variable_dcline_flow(pm, nw=n, bounded = false)

        constraint_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
            constraint_voltage_magnitude_setpoint(pm, i, nw=n)
        end

        for (i,bus) in ref(pm, :bus, nw=n)
            constraint_kcl_shunt(pm, i, nw=n)

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
function run_mp_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_mp_opf; multiphase=true, kwargs...)
end

""
function post_mp_opf(pm::GenericPowerModel)
    for h in phase_ids(pm)
        variable_voltage(pm, ph=h)
        variable_generation(pm, ph=h)
        variable_branch_flow(pm, ph=h)
        variable_dcline_flow(pm, ph=h)

        constraint_voltage(pm, ph=h)

        for i in ids(pm, :ref_buses)
            constraint_theta_ref(pm, i, ph=h)
        end

        for i in ids(pm, :bus)
            constraint_kcl_shunt(pm, i, ph=h)
        end

        for i in ids(pm, :branch)
            constraint_ohms_yt_from(pm, i, ph=h)
            constraint_ohms_yt_to(pm, i, ph=h)

            constraint_voltage_angle_difference(pm, i, ph=h)

            constraint_thermal_limit_from(pm, i, ph=h)
            constraint_thermal_limit_to(pm, i, ph=h)
        end

        for i in ids(pm, :dcline)
            constraint_dcline(pm, i, ph=h)
        end
    end

    objective_min_fuel_cost(pm)
end



""
function run_mn_mp_opf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_mn_mp_opf; multinetwork=true, multiphase=true, kwargs...)
end

""
function post_mn_mp_opf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        for h in phase_ids(pm, nw=n)
            variable_voltage(pm, nw=n, ph=h)
            variable_generation(pm, nw=n, ph=h)
            variable_branch_flow(pm, nw=n, ph=h)
            variable_dcline_flow(pm, nw=n, ph=h)

            constraint_voltage(pm, nw=n, ph=h)

            for i in ids(pm, :ref_buses, nw=n)
                constraint_theta_ref(pm, i, nw=n, ph=h)
            end

            for i in ids(pm, :bus, nw=n)
                constraint_kcl_shunt(pm, i, nw=n, ph=h)
            end

            for i in ids(pm, :branch, nw=n)
                constraint_ohms_yt_from(pm, i, nw=n, ph=h)
                constraint_ohms_yt_to(pm, i, nw=n, ph=h)

                constraint_voltage_angle_difference(pm, i, nw=n, ph=h)

                constraint_thermal_limit_from(pm, i, nw=n, ph=h)
                constraint_thermal_limit_to(pm, i, nw=n, ph=h)
            end

            for i in ids(pm, :dcline, nw=n)
                constraint_dcline(pm, i, nw=n, ph=h)
            end
        end
    end

    objective_min_fuel_cost(pm)
end
