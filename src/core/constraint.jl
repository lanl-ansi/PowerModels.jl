###############################################################################
# This file defines commonly used constraints for power flow models
# These constraints generally assume that the model contains p and q values
# for branches flows and bus flow conservation
###############################################################################

# Generic thermal limit constraint
"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, c::Int, f_idx, rate_a)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::GenericPowerModel, n::Int, c::Int, t_idx, rate_a)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
end

"`norm([p[f_idx]; q[f_idx]]) <= rate_a`"
function constraint_thermal_limit_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, rate_a) where T <: AbstractConicForms
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    @constraint(pm.model, norm([p_fr; q_fr]) <= rate_a)
end

"`norm([p[t_idx]; q[t_idx]]) <= rate_a`"
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, c::Int, t_idx, rate_a) where T <: AbstractConicForms
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    @constraint(pm.model, norm([p_to; q_to]) <= rate_a)
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * branch_z[i])^2`"
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, n::Int, c::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    z = var(pm, n, c, :branch_z, i)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * branch_z[i])^2`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, n::Int, c::Int, i, t_idx, rate_a)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    z = var(pm, n, c, :branch_z, i)
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, n::Int, c::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, c, :p_ne, f_idx)
    q_fr = var(pm, n, c, :q_ne, f_idx)
    z = var(pm, n, c, :branch_ne, i)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, n::Int, c::Int, i, t_idx, rate_a)
    p_to = var(pm, n, c, :p_ne, t_idx)
    q_to = var(pm, n, c, :q_ne, t_idx)
    z = var(pm, n, c, :branch_ne, i)
    @constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`pg[i] == pg`"
function constraint_active_gen_setpoint(pm::GenericPowerModel, n::Int, c::Int, i, pg)
    pg_var = var(pm, n, c, :pg, i)
    @constraint(pm.model, pg_var == pg)
end

"`qq[i] == qq`"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, n::Int, c::Int, i, qg)
    qg_var = var(pm, n, c, :qg, i)
    @constraint(pm.model, qg_var == qg)
end

"""
Creates Line Flow constraint for DC Lines (Matpower Formulation)

```
p_fr + p_to == loss0 + p_fr * loss1
```
"""
function constraint_dcline(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1) where T
    p_fr = var(pm, n, c, :p_dc, f_idx)
    p_to = var(pm, n, c, :p_dc, t_idx)

    @constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0) == 0)
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_active_dcline_setpoint(pm::GenericPowerModel, n::Int, c::Int, f_idx, t_idx, pf, pt)
    p_fr = var(pm, n, c, :p_dc, f_idx)
    p_to = var(pm, n, c, :p_dc, t_idx)

    @constraint(pm.model, p_fr == pf)
    @constraint(pm.model, p_to == pt)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage(pm::GenericPowerModel, n::Int, c::Int)
end




function constraint_battery_limit(pm::GenericPowerModel, n::Int, c::Int, i, inv_rating)
    pb = var(pm, n, c, :pb, i)
    qb = var(pm, n, c, :qb, i)
    @constraint(pm.model, pb^2 + qb^2 <= inv_rating^2)
end

function constraint_battery_state(pm::GenericPowerModel, n::Int, i, energy, eff_charge, eff_discharge, time_passed)
    bc = var(pm, n, :bc, i)
    bd = var(pm, n, :bd, i)
    be = var(pm, n, :be, i)
    @constraint(pm.model, be - energy == time_passed*(eff_charge*bc - bd/eff_discharge))
end

function constraint_battery_complementarity(pm::GenericPowerModel, n::Int, i)
    bc = var(pm, n, :bc, i)
    bd = var(pm, n, :bd, i)
    @constraint(pm.model, bc*bd == 0.0)
end

function constraint_battery_loss(pm::GenericPowerModel, n::Int, i, bus, inv_r, inv_standby_loss)
    vm = var(pm, n, pm.ccnd, :vm, bus)
    pb = var(pm, n, pm.ccnd, :pb, i)
    qb = var(pm, n, pm.ccnd, :qb, i)
    bc = var(pm, n, :bc, i)
    bd = var(pm, n, :bd, i)
    @NLconstraint(pm.model, pb + (bc - bd) == inv_standby_loss + inv_r*(pb^2 + qb^2)/vm^2)
    #@constraint(pm.model, pb <= bd)
    #@constraint(pm.model, -pb <= bc)
end
