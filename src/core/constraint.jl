###############################################################################
# This file defines commonly used constraints for power flow models
# These constraints generally assume that the model contains p and q values
# for branches flows and bus flow conservation
###############################################################################

# Generic thermal limit constraint
"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, h::Int, f_idx, rate_a)
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::GenericPowerModel, n::Int, h::Int, t_idx, rate_a)
    p_to = var(pm, n, h, :p, t_idx)
    q_to = var(pm, n, h, :q, t_idx)
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
end

"`norm([p[f_idx]; q[f_idx]]) <= rate_a`"
function constraint_thermal_limit_from(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, rate_a) where T<:AbstractConicPowerFormulation
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    @constraint(pm.model, norm([p_fr; q_fr]) <= rate_a)
end

"`norm([p[t_idx]; q[t_idx]]) <= rate_a`"
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, h::Int, t_idx, rate_a) where T<:AbstractConicPowerFormulation
    p_to = var(pm, n, h, :p, t_idx)
    q_to = var(pm, n, h, :q, t_idx)
    @constraint(pm.model, norm([p_to; q_to]) <= rate_a)
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * branch_z[i])^2`"
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, n::Int, h::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    z = var(pm, n, h, :branch_z, i)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * branch_z[i])^2`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, n::Int, h::Int, i, t_idx, rate_a)
    p_to = var(pm, n, h, :p, t_idx)
    q_to = var(pm, n, h, :q, t_idx)
    z = var(pm, n, h, :branch_z, i)
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, n::Int, h::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, h, :p_ne, f_idx)
    q_fr = var(pm, n, h, :q_ne, f_idx)
    z = var(pm, n, h, :branch_ne, i)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, n::Int, h::Int, i, t_idx, rate_a)
    p_to = var(pm, n, h, :p_ne, t_idx)
    q_to = var(pm, n, h, :q_ne, t_idx)
    z = var(pm, n, h, :branch_ne, i)
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`pg[i] == pg`"
function constraint_active_gen_setpoint(pm::GenericPowerModel, n::Int, h::Int, i, pg)
    pg_var = var(pm, n, h, :pg, i)
    @constraint(pm.model, pg_var == pg)
end

"`qq[i] == qq`"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, n::Int, h::Int, i, qg)
    qg_var = var(pm, n, h, :qg, i)
    @constraint(pm.model, qg_var == qg)
end

"""
Creates Line Flow constraint for DC Lines (Matpower Formulation)

```
p_fr + p_to == loss0 + p_fr * loss1
```
"""
function constraint_dcline(pm::GenericPowerModel{T}, n::Int, h::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1) where T
    p_fr = var(pm, n, h, :p_dc, f_idx)
    p_to = var(pm, n, h, :p_dc, t_idx)

    @constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0) == 0)
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_active_dcline_setpoint(pm::GenericPowerModel, n::Int, h::Int, f_idx, t_idx, pf, pt)
    p_fr = var(pm, n, h, :p_dc, f_idx)
    p_to = var(pm, n, h, :p_dc, t_idx)

    @constraint(pm.model, p_fr == pf)
    @constraint(pm.model, p_to == pt)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage(pm::GenericPowerModel, n::Int, h::Int)
end
