###############################################################################
# This file defines commonly used constraints for power flow models
# These constraints generally assume that the model contains p and q values
# for branches line flows and bus flow conservation
###############################################################################

# Generic thermal limit constraint
"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, f_idx, rate_a)
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::GenericPowerModel, n::Int, t_idx, rate_a)
    p_to = pm.var[:nw][n][:p][t_idx]
    q_to = pm.var[:nw][n][:q][t_idx]
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
end

"`norm([p[f_idx]; q[f_idx]]) <= rate_a`"
function constraint_thermal_limit_from{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, n::Int, f_idx, rate_a)
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    @constraint(pm.model, norm([p_fr; q_fr]) <= rate_a)
end

"`norm([p[t_idx]; q[t_idx]]) <= rate_a`"
function constraint_thermal_limit_to{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, n::Int, t_idx, rate_a)
    p_to = pm.var[:nw][n][:p][t_idx]
    q_to = pm.var[:nw][n][:q][t_idx]
    @constraint(pm.model, norm([p_to; q_to]) <= rate_a)
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * line_z[i])^2`"
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i, f_idx, rate_a)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    z = pm.var[:line_z][i]
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * line_z[i])^2`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i, t_idx, rate_a)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    z = pm.var[:line_z][i]
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * line_ne[i])^2`"
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, i, f_idx, rate_a)
    p_fr = pm.var[:p_ne][f_idx]
    q_fr = pm.var[:q_ne][f_idx]
    z = pm.var[:line_ne][i]
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * line_ne[i])^2`"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, i, t_idx, rate_a)
    p_to = pm.var[:p_ne][t_idx]
    q_to = pm.var[:q_ne][t_idx]
    z = pm.var[:line_ne][i]
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`pg[i] == pg`"
function constraint_active_gen_setpoint(pm::GenericPowerModel, i, pg)
    pg_var = pm.var[:pg][i]
    @constraint(pm.model, pg_var == pg)
end

"`qq[i] == qq`"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, i, qg)
    qg_var = pm.var[:qg][i]
    @constraint(pm.model, qg_var == qg)
end

"""
Creates Line Flow constraint for DC Lines (Matpower Formulation)

```
p_fr + p_to == loss0 + p_fr * loss1
```
"""
function constraint_dcline{T}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
    p_fr = pm.var[:nw][n][:p_dc][f_idx]
    p_to = pm.var[:nw][n][:p_dc][t_idx]

    @constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0) == 0)
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_active_dcline_setpoint(pm::GenericPowerModel, i, f_idx, t_idx, pf, pt, epsilon)
    p_fr = pm.var[:p_dc][f_idx]
    p_to = pm.var[:p_dc][t_idx]

    if epsilon == 0.0
        @constraint(pm.model, p_fr == pf)
        @constraint(pm.model, p_to == pt)
    else
        @constraint(pm.model, p_fr >= pf - epsilon)
        @constraint(pm.model, p_to >= pt - epsilon)
        @constraint(pm.model, p_fr <= pf + epsilon)
        @constraint(pm.model, p_to <= pt + epsilon)
    end
end
