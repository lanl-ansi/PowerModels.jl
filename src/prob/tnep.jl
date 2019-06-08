#### General Assumptions of these TNEP Models ####
#
#

""
function run_tnep(file, model_constructor, optimizer; kwargs...)
    return run_model(file, model_constructor, optimizer, post_tnep; ref_extensions=[ref_add_on_off_va_bounds!,ref_add_ne_branch!], solution_builder = solution_tnep!, kwargs...)
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

    constraint_model_voltage(pm)
    constraint_model_voltage_ne(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_shunt_ne(pm, i)
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
function ref_add_ne_branch!(pm::GenericPowerModel)
    for (nw, nw_ref) in pm.ref[:nw]
        if !haskey(nw_ref, :ne_branch)
            error(_LOGGER, "required ne_branch data not found")
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

        if !haskey(nw_ref, :ne_buspairs)
            nw_ref[:ne_buspairs] = calc_buspair_parameters(nw_ref[:bus], nw_ref[:ne_branch], nw_ref[:conductor_ids], haskey(nw_ref, :conductors))
        end
    end
end


""
function add_setpoint_branch_ne_flow!(sol, pm::GenericPowerModel)
    # check the branch flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "branch_flows") && pm.setting["output"]["branch_flows"] == true
        add_setpoint!(sol, pm, "ne_branch", "pf", :p_ne, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "ne_branch", "qf", :q_ne, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "ne_branch", "pt", :p_ne, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
        add_setpoint!(sol, pm, "ne_branch", "qt", :q_ne, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
    end
end


""
function add_setpoint_branch_ne_built!(sol, pm::GenericPowerModel)
    add_setpoint!(sol, pm, "ne_branch", "built", :branch_ne, status_name="br_status", default_value = (item) -> 1)
end


""
function solution_tnep!(pm::GenericPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_generator_power!(sol, pm)
    add_setpoint_branch_flow!(sol, pm)
    add_setpoint_branch_ne_flow!(sol, pm)
    add_setpoint_branch_ne_built!(sol, pm)
end
