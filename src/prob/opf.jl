""
function run_ac_opf(file, optimizer; kwargs...)
    return run_opf(file, ACPPowerModel, optimizer; kwargs...)
end

""
function run_dc_opf(file, optimizer; kwargs...)
    return run_opf(file, DCPPowerModel, optimizer; kwargs...)
end

""
function run_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, post_opf; kwargs...)
end

""
function post_opf(pm::GenericPowerModel)
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
        constraint_power_balance_shunt(pm, i)
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



"a toy example of how to model with multi-networks"
function run_mn_opf(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, post_mn_opf; multinetwork=true, kwargs...)
end

""
function post_mn_opf(pm::GenericPowerModel)
    for (n, network) in nws(pm)
        variable_voltage(pm, nw=n)
        variable_generation(pm, nw=n)
        variable_branch_flow(pm, nw=n)
        variable_dcline_flow(pm, nw=n)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_power_balance_shunt(pm, i, nw=n)
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

    objective_min_fuel_and_flow_cost(pm)
end

