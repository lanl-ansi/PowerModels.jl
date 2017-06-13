###############################################################################
# This file defines commonly used constraints for power flow models
# These constraints generally assume that the model contains p and q values 
# for branches line flows and bus flow conservation
###############################################################################

# Generic thermal limit constraint
"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::GenericPowerModel, f_idx, rate_a)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
    return Set([c])
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::GenericPowerModel, t_idx, rate_a)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    c = @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
    return Set([c])
end

"`norm([p[f_idx]; q[f_idx]]) <= rate_a`"
function constraint_thermal_limit_from{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, f_idx, rate_a)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    c = @constraint(pm.model, norm([p_fr; q_fr]) <= rate_a)
    return Set([c])
end

"`norm([p[t_idx]; q[t_idx]]) <= rate_a`"
function constraint_thermal_limit_to{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, t_idx, rate_a)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    c = @constraint(pm.model, norm([p_to; q_to]) <= rate_a)
    return Set([c])
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * line_z[i])^2`"
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i, f_idx, rate_a)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    z = getindex(pm.model, :line_z)[i]
    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
    return Set([c])
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * line_z[i])^2`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i, t_idx, rate_a)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    z = getindex(pm.model, :line_z)[i]
    c = @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
    return Set([c])
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * line_ne[i])^2`"
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, i, f_idx, rate_a)
    p_fr = getindex(pm.model, :p_ne)[f_idx]
    q_fr = getindex(pm.model, :q_ne)[f_idx]
    z = getindex(pm.model, :line_ne)[i]
    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
    return Set([c])
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * line_ne[i])^2`"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, i, t_idx, rate_a)
    p_to = getindex(pm.model, :p_ne)[t_idx]
    q_to = getindex(pm.model, :q_ne)[t_idx]
    z = getindex(pm.model, :line_ne)[i]
    c = @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
    return Set([c])
end

"`pg[i] == pg`"
function constraint_active_gen_setpoint(pm::GenericPowerModel, i, pg)
    pg_var = getindex(pm.model, :pg)[i]
    c = @constraint(pm.model, pg_var == pg)
    return Set([c])
end

"`qq[i] == qq`"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, i, qg)
    qg_var = getindex(pm.model, :qg)[i]
    c = @constraint(pm.model, qg_var == qg)
    return Set([c])
end
