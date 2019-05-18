#### General Assumptions of these TNEP Models ####
#
#

export run_tnep

""
function run_tnep(file, model_constructor, optimizer; kwargs...)
    return run_generic_model(file, model_constructor, optimizer, post_tnep; ref_extensions=[on_off_va_bounds_ref!,ne_branch_ref!], solution_builder = get_tnep_solution, kwargs...)
end

"the general form of the tnep optimization model"
function post_tnep(pm::GenericPowerModel)
    variable_branch_ne(pm)
    variable_voltage(pm)
    variable_voltage_ne(pm)
    variable_generation(pm)
    variable_branch_flow(pm)
    variable_dcline_flow(pm)
    variable_branch_flow_ne(pm)

    objective_tnep_cost(pm)

    constraint_voltage(pm)
    constraint_voltage_ne(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_kcl_shunt_ne(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :ne_branch)
        constraint_ohms_yt_from_ne(pm, i)
        constraint_ohms_yt_to_ne(pm, i)

        constraint_voltage_angle_difference_ne(pm, i)

        constraint_thermal_limit_from_ne(pm, i)
        constraint_thermal_limit_to_ne(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline(pm, i)
    end
end


"Cost of building branches"
function objective_tnep_cost(pm::GenericPowerModel)
    return JuMP.@objective(pm.model, Min,
        sum(
            sum(
                sum( branch["construction_cost"]*var(pm, n, c, :branch_ne, i) for (i,branch) in nw_ref[:ne_branch] )
            for c in conductor_ids(pm, n))
        for (n, nw_ref) in nws(pm))
    )
end


""
function ne_branch_ref!(pm::GenericPowerModel)
    for (nw, nw_ref) in pm.ref[:nw]
        if !haskey(nw_ref, :ne_branch)
            error(LOGGER, "required ne_branch data not found")
        end

        nw_ref[:ne_branch] = Dict(x for x in nw_ref[:ne_branch] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(nw_ref[:bus]) && x.second["t_bus"] in keys(nw_ref[:bus])))

        nw_ref[:ne_arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in nw_ref[:ne_branch]]
        nw_ref[:ne_arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in nw_ref[:ne_branch]]
        nw_ref[:ne_arcs] = [nw_ref[:ne_arcs_from]; nw_ref[:ne_arcs_to]]

        ne_bus_arcs = Dict((i, []) for (i,bus) in nw_ref[:bus])
        for (l,i,j) in nw_ref[:ne_arcs]
            push!(ne_bus_arcs[i], (l,i,j))
        end
        nw_ref[:ne_bus_arcs] = ne_bus_arcs

        nw_ref[:ne_buspairs] = buspair_parameters(nw_ref[:ne_arcs_from], nw_ref[:ne_branch], nw_ref[:bus], nw_ref[:conductor_ids], haskey(nw_ref, :conductors))
    end
end


""
function get_tnep_solution(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_flow_setpoint_ne(sol, pm)
    add_branch_ne_setpoint(sol, pm)
end
