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
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::GenericPowerModel, n::Int, c::Int, t_idx, rate_a)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
end

"`[rate_a, p[f_idx], q[f_idx]] in SecondOrderCone`"
function constraint_thermal_limit_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, rate_a) where T <: AbstractConicForms
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    JuMP.@constraint(pm.model, [rate_a, p_fr, q_fr] in JuMP.SecondOrderCone())
end

"`[rate_a, p[t_idx], q[t_idx]] in SecondOrderCone`"
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, c::Int, t_idx, rate_a) where T <: AbstractConicForms
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    JuMP.@constraint(pm.model, [rate_a, p_to, q_to] in JuMP.SecondOrderCone())
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * branch_z[i])^2`"
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, n::Int, c::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    z = var(pm, n, c, :branch_z, i)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * branch_z[i])^2`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, n::Int, c::Int, i, t_idx, rate_a)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    z = var(pm, n, c, :branch_z, i)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, n::Int, c::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, c, :p_ne, f_idx)
    q_fr = var(pm, n, c, :q_ne, f_idx)
    z = var(pm, n, c, :branch_ne, i)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, n::Int, c::Int, i, t_idx, rate_a)
    p_to = var(pm, n, c, :p_ne, t_idx)
    q_to = var(pm, n, c, :q_ne, t_idx)
    z = var(pm, n, c, :branch_ne, i)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`pg[i] == pg`"
function constraint_active_gen_setpoint(pm::GenericPowerModel, n::Int, c::Int, i, pg)
    pg_var = var(pm, n, c, :pg, i)
    JuMP.@constraint(pm.model, pg_var == pg)
end

"`qq[i] == qq`"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, n::Int, c::Int, i, qg)
    qg_var = var(pm, n, c, :qg, i)
    JuMP.@constraint(pm.model, qg_var == qg)
end

"on/off constraint for generators"
function constraint_generation_on_off(pm::GenericPowerModel, n::Int, c::Int, i::Int, pmin, pmax, qmin, qmax)
    pg = var(pm, n, c, :pg, i)
    qg = var(pm, n, c, :qg, i)
    z = var(pm, n, :z_gen, i)

    JuMP.@constraint(pm.model, pg <= pmax*z)
    JuMP.@constraint(pm.model, pg >= pmin*z)
    JuMP.@constraint(pm.model, qg <= qmax*z)
    JuMP.@constraint(pm.model, qg >= qmin*z)
end


"""
Creates Line Flow constraint for DC Lines (Matpower Formulation)

```
p_fr + p_to == loss0 + p_fr * loss1
```
"""
function constraint_dcline(pm::GenericPowerModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
    p_fr = var(pm, n, c, :p_dc, f_idx)
    p_to = var(pm, n, c, :p_dc, t_idx)

    JuMP.@constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0) == 0)
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_active_dcline_setpoint(pm::GenericPowerModel, n::Int, c::Int, f_idx, t_idx, pf, pt)
    p_fr = var(pm, n, c, :p_dc, f_idx)
    p_to = var(pm, n, c, :p_dc, t_idx)

    JuMP.@constraint(pm.model, p_fr == pf)
    JuMP.@constraint(pm.model, p_to == pt)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage(pm::GenericPowerModel, n::Int, c::Int)
end



""
function constraint_storage_thermal_limit(pm::GenericPowerModel, n::Int, c::Int, i, rating)
    ps = var(pm, n, c, :ps, i)
    qs = var(pm, n, c, :qs, i)
    JuMP.@constraint(pm.model, ps^2 + qs^2 <= rating^2)
end

""
function constraint_storage_current_limit(pm::GenericPowerModel, n::Int, c::Int, i, bus, rating)
    vm = var(pm, n, pm.ccnd, :vm, bus)
    ps = var(pm, n, c, :ps, i)
    qs = var(pm, n, c, :qs, i)
    JuMP.@constraint(pm.model, ps^2 + qs^2 <= rating^2*vm^2)
end

""
function constraint_storage_state_initial(pm::GenericPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, time_elapsed)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    se = var(pm, n, :se, i)
    JuMP.@constraint(pm.model, se - energy == time_elapsed*(charge_eff*sc - sd/discharge_eff))
end

""
function constraint_storage_state(pm::GenericPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, time_elapsed)
    sc_2 = var(pm, n_2, :sc, i)
    sd_2 = var(pm, n_2, :sd, i)
    se_2 = var(pm, n_2, :se, i)
    se_1 = var(pm, n_1, :se, i)
    JuMP.@constraint(pm.model, se_2 - se_1 == time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff))
end

""
function constraint_storage_complementarity(pm::GenericPowerModel, n::Int, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    JuMP.@constraint(pm.model, sc*sd == 0.0)
end

""
function constraint_storage_loss(pm::GenericPowerModel, n::Int, i, bus, r, x, standby_loss)
    vm = var(pm, n, pm.ccnd, :vm, bus)
    ps = var(pm, n, pm.ccnd, :ps, i)
    qs = var(pm, n, pm.ccnd, :qs, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    JuMP.@NLconstraint(pm.model, ps + (sd - sc) == standby_loss + r*(ps^2 + qs^2)/vm^2)
end
