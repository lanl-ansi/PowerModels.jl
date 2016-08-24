export post_pf, run_pf

function run_pf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_pf; kwargs...) 
end

function post_pf{T}(pm::GenericPowerModel{T})
    variable_complex_voltage(pm, bounded = false)

    variable_active_generation(pm, bounded = false)
    variable_reactive_generation(pm, bounded = false)

    variable_active_line_flow(pm, bounded = false)
    variable_reactive_line_flow(pm, bounded = false)


    constraint_theta_ref(pm)
    constraint_voltage_magnitude_setpoint(pm, pm.set.buses[pm.set.ref_bus])
    constraint_complex_voltage(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)

        # PV Bus Constraints
        if length(pm.set.bus_gens[i]) > 0 && i != pm.set.ref_bus
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            # soft equality needed becouse v in file is not precice enough to ensure feasiblity
            constraint_voltage_magnitude_setpoint(pm, bus; epsilon = 0.00001)
            for j in pm.set.bus_gens[i]
                constraint_active_gen_setpoint(pm, pm.set.gens[j])
            end
        end
    end

    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)
    end
end

