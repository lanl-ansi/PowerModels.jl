###############################################################################
# This file defines commonly used constraints for power flow models
# These constraints generally assume that the model contains p and q values
# for branches flows and bus flow conservation
###############################################################################

"checks if a sufficient number of variables exist for the given keys collection"
function _check_var_keys(vars, keys, var_name, comp_name)
    if length(vars) < length(keys)
        error(_LOGGER, "$(var_name) decision variables appear to be missing for $(comp_name) components")
    end
end


# Generic thermal limit constraint
"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::AbstractPowerModel, n::Int, f_idx, rate_a)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::AbstractPowerModel, n::Int, t_idx, rate_a)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2)
end

"`[rate_a, p[f_idx], q[f_idx]] in SecondOrderCone`"
function constraint_thermal_limit_from(pm::AbstractConicModels, n::Int, f_idx, rate_a)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)

    JuMP.@constraint(pm.model, [rate_a, p_fr, q_fr] in JuMP.SecondOrderCone())
end

"`[rate_a, p[t_idx], q[t_idx]] in SecondOrderCone`"
function constraint_thermal_limit_to(pm::AbstractConicModels, n::Int, t_idx, rate_a)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    JuMP.@constraint(pm.model, [rate_a, p_to, q_to] in JuMP.SecondOrderCone())
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * z_branch[i])^2`"
function constraint_thermal_limit_from_on_off(pm::AbstractPowerModel, n::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * z_branch[i])^2`"
function constraint_thermal_limit_to_on_off(pm::AbstractPowerModel, n::Int, i, t_idx, rate_a)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_ne_thermal_limit_from(pm::AbstractPowerModel, n::Int, i, f_idx, rate_a)
    p_fr = var(pm, n, :p_ne, f_idx)
    q_fr = var(pm, n, :q_ne, f_idx)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_ne_thermal_limit_to(pm::AbstractPowerModel, n::Int, i, t_idx, rate_a)
    p_to = var(pm, n, :p_ne, t_idx)
    q_to = var(pm, n, :q_ne, t_idx)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`pg[i] == pg`"
function constraint_gen_setpoint_active(pm::AbstractPowerModel, n::Int, i, pg)
    pg_var = var(pm, n, :pg, i)

    JuMP.@constraint(pm.model, pg_var == pg)
end

"`qq[i] == qq`"
function constraint_gen_setpoint_reactive(pm::AbstractPowerModel, n::Int, i, qg)
    qg_var = var(pm, n, :qg, i)

    JuMP.@constraint(pm.model, qg_var == qg)
end

"on/off constraint for generators"
function constraint_gen_power_on_off(pm::AbstractPowerModel, n::Int, i::Int, pmin, pmax, qmin, qmax)
    pg = var(pm, n, :pg, i)
    qg = var(pm, n, :qg, i)
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
function constraint_dcline_power_losses(pm::AbstractPowerModel, n::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
    p_fr = var(pm, n, :p_dc, f_idx)
    p_to = var(pm, n, :p_dc, t_idx)

    JuMP.@constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0) == 0)
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_dcline_setpoint_active(pm::AbstractPowerModel, n::Int, f_idx, t_idx, pf, pt)
    p_fr = var(pm, n, :p_dc, f_idx)
    p_to = var(pm, n, :p_dc, t_idx)

    JuMP.@constraint(pm.model, p_fr == pf)
    JuMP.@constraint(pm.model, p_to == pt)
end


"""
do nothing, most models to not require any model-specific voltage constraints
"""
function constraint_model_voltage(pm::AbstractPowerModel, n::Int)
end

"""
do nothing, most models to not require any model-specific on/off voltage constraints
"""
function constraint_model_voltage_on_off(pm::AbstractPowerModel, n::Int)
end

"""
do nothing, most models to not require any model-specific network expansion voltage constraints
"""
function constraint_ne_model_voltage(pm::AbstractPowerModel, n::Int)
end

"""
do nothing, most models to not require any model-specific current constraints
"""
function constraint_model_current(pm::AbstractPowerModel, n::Int)
end


""
function constraint_switch_state_open(pm::AbstractPowerModel, n::Int, f_idx)
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)

    JuMP.@constraint(pm.model, psw == 0.0)
    JuMP.@constraint(pm.model, qsw == 0.0)
end

""
function constraint_switch_thermal_limit(pm::AbstractPowerModel, n::Int, f_idx, rating)
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)

    JuMP.@constraint(pm.model, psw^2 + qsw^2 <= rating^2)
end

""
function constraint_switch_power_on_off(pm::AbstractPowerModel, n::Int, i, f_idx)
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)
    z = var(pm, n, :z_switch, i)

    psw_lb, psw_ub = _IM.variable_domain(psw)
    qsw_lb, qsw_ub = _IM.variable_domain(qsw)

    JuMP.@constraint(pm.model, psw <= psw_ub*z)
    JuMP.@constraint(pm.model, psw >= psw_lb*z)
    JuMP.@constraint(pm.model, qsw <= qsw_ub*z)
    JuMP.@constraint(pm.model, qsw >= qsw_lb*z)
end



""
function constraint_storage_thermal_limit(pm::AbstractPowerModel, n::Int, i, rating)
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)

    JuMP.@constraint(pm.model, ps^2 + qs^2 <= rating^2)
end

""
function constraint_storage_state_initial(pm::AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, time_elapsed)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    se = var(pm, n, :se, i)

    JuMP.@constraint(pm.model, se - energy == time_elapsed*(charge_eff*sc - sd/discharge_eff))
end

""
function constraint_storage_state(pm::AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, time_elapsed)
    sc_2 = var(pm, n_2, :sc, i)
    sd_2 = var(pm, n_2, :sd, i)
    se_2 = var(pm, n_2, :se, i)
    se_1 = var(pm, n_1, :se, i)

    JuMP.@constraint(pm.model, se_2 - se_1 == time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff))
end

""
function constraint_storage_complementarity_nl(pm::AbstractPowerModel, n::Int, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    JuMP.@constraint(pm.model, sc*sd == 0.0)
end

""
function constraint_storage_complementarity_mi(pm::AbstractPowerModel, n::Int, i, charge_ub, discharge_ub)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    sc_on = var(pm, n, :sc_on, i)
    sd_on = var(pm, n, :sd_on, i)

    JuMP.@constraint(pm.model, sc_on + sd_on == 1)
    JuMP.@constraint(pm.model, sc_on*charge_ub >= sc)
    JuMP.@constraint(pm.model, sd_on*discharge_ub >= sd)
end


""
function constraint_storage_on_off(pm::AbstractPowerModel, n::Int, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub)
    z_storage = var(pm, n, :z_storage, i)
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)
    qsc = var(pm, n, :qsc, i)

    JuMP.@constraint(pm.model, ps <= z_storage*pmax)
    JuMP.@constraint(pm.model, ps >= z_storage*pmin)
    JuMP.@constraint(pm.model, qs <= z_storage*qmax)
    JuMP.@constraint(pm.model, qs >= z_storage*qmin)
    JuMP.@constraint(pm.model, qsc <= z_storage*qmax)
    JuMP.@constraint(pm.model, qsc >= z_storage*qmin)
end
