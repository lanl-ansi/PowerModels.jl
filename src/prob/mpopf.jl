#
# NOTE: This is not a formulation of any particular problem
# It is only for testing and illustration purposes
#

""
function run_ac_mpopf(file, solver; kwargs...)
    return run_mpopf(file, ACPPowerModel, solver; kwargs...)
end

""
function run_dc_mpopf(file, solver; kwargs...)
    return run_mpopf(file, DCPPowerModel, solver; kwargs...)
end

""
function run_mpopf(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_mpopf; kwargs...)
end

""
function post_mpopf(pm::GenericPowerModel)
    for (n,network) in pm.ref
        variable_voltage(pm, n)
        variable_generation(pm, n)
        variable_line_flow(pm, n)
        variable_dcline_flow(pm, n)

        constraint_voltage(pm, n)

        for (i,bus) in getref(pm, n, :ref_buses)
            constraint_theta_ref(pm, n, bus)
        end

        for (i,bus) in getref(pm, n, :bus)
            constraint_kcl_shunt(pm, n, bus)
        end

        for (i,branch) in getref(pm, n, :branch)
            constraint_ohms_yt_from(pm, n, branch)
            constraint_ohms_yt_to(pm, n, branch)

            constraint_phase_angle_difference(pm, n, branch)

            constraint_thermal_limit_from(pm, n, branch)
            constraint_thermal_limit_to(pm, n, branch)
        end

        for (i,dcline) in getref(pm, n, :dcline)
            constraint_dcline(pm, n, dcline)
        end
    end

    # cross network constraint, just for illustration purposes
    # designed to be feasible with two copies of case5_asym.m 
    t1_pg = getvar(pm, :t1, :pg)
    t2_pg = getvar(pm, :t2, :pg)
    @constraint(pm.model, t1_pg[1] == t2_pg[4])

    objective_min_fuel_cost(pm)
end
