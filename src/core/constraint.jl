###############################################################################
# This file defines commonly used constraints for power flow models
# These constraints generally assume that the model contains p and q values 
# for branches line flows and bus flow conservation
###############################################################################

# Generic thermal limit constraint
""
function constraint_thermal_limit_from(pm::GenericPowerModel, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
    return Set([c])
end

""
function constraint_thermal_limit_to(pm::GenericPowerModel, t_idx, rate_a)
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
    return Set([c])
end

""
function constraint_thermal_limit_from{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]

    c = @constraint(pm.model, norm([p_fr; q_fr]) <= rate_a)
    return Set([c])
end

""
function constraint_thermal_limit_to{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, t_idx, rate_a)
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    c = @constraint(pm.model, norm([p_to; q_to]) <= rate_a)
    return Set([c])
end

# Generic on/off thermal limit constraint

""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    z = getvariable(pm.model, :line_z)[i]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
    return Set([c])
end

""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i, t_idx, rate_a)
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    z = getvariable(pm.model, :line_z)[i]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
    return Set([c])
end

""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, i, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
    return Set([c])
end

""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, i, t_idx, rate_a)
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
    return Set([c])
end

""
function constraint_active_gen_setpoint(pm::GenericPowerModel, i, pg)
    pg_var = getvariable(pm.model, :pg)[i]
    c = @constraint(pm.model, pg_var == pg)
    return Set([c]) 
end

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, i, qg)
    qg_var = getvariable(pm.model, :qg)[i]
    c = @constraint(pm.model, qg_var == qg)
    return Set([c])
end
