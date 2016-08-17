export post_pf, run_pf

function run_pf(file, model_constructor, solver)
    data = PowerModels.parse_file(file)

    pm = model_constructor(data; solver = solver)

    post_pf(pm)
    return solve(pm)
end


function post_pf{T}(pm::GenericPowerModel{T})
    complex_voltage_variables(pm)

    active_generation_variables(pm)
    reactive_generation_variables(pm)

    active_line_flow_variables(pm)
    reactive_line_flow_variables(pm)

    free_bounded_variables(pm)


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

