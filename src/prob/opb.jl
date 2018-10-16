export run_opb, run_cpa_opb

""
function run_cpa_opb(file, solver; kwargs...)
    return run_opb(file, CPAPowerModel, solver; kwargs...)
end

"the optimal power balance problem"
function run_opb(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_opb; kwargs...)
end

""
function post_opb(pm::GenericPowerModel)
    variable_bus_voltage(pm)
    variable_generation(pm)

    objective_min_gen_fuel_cost(pm)

    for i in ids(pm, :components)
        constraint_power_balance(pm, i)
    end
end
