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
function constraint_thermal_limit_from(pm::AbstractPowerModel, n::Int, f_idx, rate_a; name="thermal_limit_from[$f_idx]")
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)

    c = JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2, base_name=name)
    pm.model[Symbol(name)] = c
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::AbstractPowerModel, n::Int, t_idx, rate_a; name="thermal_limit_to[$t_idx]")
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    c = JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2, base_name=name)
    pm.model[Symbol(name)] = c
end

"`[rate_a, p[f_idx], q[f_idx]] in SecondOrderCone`"
function constraint_thermal_limit_from(pm::AbstractConicModels, n::Int, f_idx, rate_a; name="thermal_limit_from[$f_idx]_SOC")
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)

    c = JuMP.@constraint(pm.model, [rate_a, p_fr, q_fr] in JuMP.SecondOrderCone(), base_name=name)
    pm.model[Symbol(name)] = c
end

"`[rate_a, p[t_idx], q[t_idx]] in SecondOrderCone`"
function constraint_thermal_limit_to(pm::AbstractConicModels, n::Int, t_idx, rate_a; name="thermal_limit_to[$t_idx]_SOC")
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    c = JuMP.@constraint(pm.model, [rate_a, p_to, q_to] in JuMP.SecondOrderCone(), base_name=name)
    pm.model[Symbol(name)] = c
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * z_branch[i])^2`"
function constraint_thermal_limit_from_on_off(pm::AbstractPowerModel, n::Int, i, f_idx, rate_a; name="thermal_limit_from[$f_idx]_on_off")
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    z = var(pm, n, :z_branch, i)

    c = JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2, base_name=name)
    pm.model[Symbol(name)] = c
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * z_branch[i])^2`"
function constraint_thermal_limit_to_on_off(pm::AbstractPowerModel, n::Int, i, t_idx, rate_a; name="thermal_limit_to[$t_idx]_on_off")
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)
    z = var(pm, n, :z_branch, i)

    c = JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2, base_name=name)
    pm.model[Symbol(name)] = c
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_ne_thermal_limit_from(pm::AbstractPowerModel, n::Int, i, f_idx, rate_a; name="ne_thermal_limit_from[$f_idx]")
    p_fr = var(pm, n, :p_ne, f_idx)
    q_fr = var(pm, n, :q_ne, f_idx)
    z = var(pm, n, :branch_ne, i)

    c = JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2*z^2, base_name=name)
    pm.model[Symbol(name)] = c
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_ne_thermal_limit_to(pm::AbstractPowerModel, n::Int, i, t_idx, rate_a; name="ne_thermal_limit_to[$t_idx]")
    p_to = var(pm, n, :p_ne, t_idx)
    q_to = var(pm, n, :q_ne, t_idx)
    z = var(pm, n, :branch_ne, i)

    c = JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2*z^2, base_name=name)
    pm.model[Symbol(name)] = c
end

"`pg[i] == pg`"
function constraint_gen_setpoint_active(pm::AbstractPowerModel, n::Int, i, pg; name="gen_setpoint_active[$i]")
    pg_var = var(pm, n, :pg, i)

    c = JuMP.@constraint(pm.model, pg_var == pg, base_name=name)
    pm.model[Symbol(name)] = c
end

"`qq[i] == qq`"
function constraint_gen_setpoint_reactive(pm::AbstractPowerModel, n::Int, i, qg; name="gen_setpoint_reactive[$i]")
    qg_var = var(pm, n, :qg, i)

    c = JuMP.@constraint(pm.model, qg_var == qg, base_name=name)
    pm.model[Symbol(name)] = c
end

"on/off constraint for generators"
function constraint_gen_power_on_off(pm::AbstractPowerModel, n::Int, i::Int, pmin, pmax, qmin, qmax; name=
    ["gen_active_ub[$i]_on_off", "gen_active_lb[$i]_on_off", "gen_reactive_ub[$i]_on_off", "gen_reactive_lb[$i]_on_off"])
    pg = var(pm, n, :pg, i)
    qg = var(pm, n, :qg, i)
    z = var(pm, n, :z_gen, i)

    c1 = JuMP.@constraint(pm.model, pg <= pmax*z, base_name=name[1])
    c2 = JuMP.@constraint(pm.model, pg >= pmin*z, base_name=name[2])
    c3 = JuMP.@constraint(pm.model, qg <= qmax*z, base_name=name[3])
    c4 = JuMP.@constraint(pm.model, qg >= qmin*z, base_name=name[4])
    pm.model[Symbol(name[1])] = c1
    pm.model[Symbol(name[2])] = c2
    pm.model[Symbol(name[3])] = c3
    pm.model[Symbol(name[4])] = c4
end


"""
Creates Line Flow constraint for DC Lines (Matpower Formulation)

```
p_fr + p_to == loss0 + p_fr * loss1
```
"""
function constraint_dcline_power_losses(pm::AbstractPowerModel, n::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1; name=
    "dcline_power_losses_from[$f_idx]_to[$t_idx]")
    p_fr = var(pm, n, :p_dc, f_idx)
    p_to = var(pm, n, :p_dc, t_idx)
    
    c = JuMP.@constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0) == 0, base_name=name)
    pm.model[Symbol(name)] = c
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_dcline_setpoint_active(pm::AbstractPowerModel, n::Int, f_idx, t_idx, pf, pt; name=
    ["dcline_setpoint_active_from[$f_idx]", "dcline_setpoint_active_to[$t_idx]"])
    p_fr = var(pm, n, :p_dc, f_idx)
    p_to = var(pm, n, :p_dc, t_idx)
 
    c1 = JuMP.@constraint(pm.model, p_fr == pf, base_name=name[1])
    c2 = JuMP.@constraint(pm.model, p_to == pt, base_name=name[2])
    pm.model[Symbol(name[1])] = c1
    pm.model[Symbol(name[2])] = c2
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
function constraint_switch_state_open(pm::AbstractPowerModel, n::Int, f_idx; name=
    ["switch[$f_idx]_state_open_active", "switch[$f_idx]_state_open_reactive"])
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)

    c1 = JuMP.@constraint(pm.model, psw == 0.0, base_name=name[1])
    c2 = JuMP.@constraint(pm.model, qsw == 0.0, base_name=name[2])
    pm.model[Symbol(name[1])] = c1
    pm.model[Symbol(name[2])] = c2
end

""
function constraint_switch_thermal_limit(pm::AbstractPowerModel, n::Int, f_idx, rating; name=
    "switch[$f_idx]_thermal_limit")
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)

    c = JuMP.@constraint(pm.model, psw^2 + qsw^2 <= rating^2, base_name=name)
    pm.model[Symbol(name)] = c
end

""
function constraint_switch_power_on_off(pm::AbstractPowerModel, n::Int, i, f_idx; name=
    ["switch[$f_idx]_active_ub_on_off", "switch[$f_idx]_active_lb_on_off", "switch[$f_idx]_reactive_ub_on_off", "switch[$f_idx]_reactive_lb_on_off"])
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)
    z = var(pm, n, :z_switch, i)

    psw_lb, psw_ub = _IM.variable_domain(psw)
    qsw_lb, qsw_ub = _IM.variable_domain(qsw)

    c1 = JuMP.@constraint(pm.model, psw <= psw_ub*z, base_name=name[1])
    c2 = JuMP.@constraint(pm.model, psw >= psw_lb*z, base_name=name[2])
    c3 = JuMP.@constraint(pm.model, qsw <= qsw_ub*z, base_name=name[3])
    c4 = JuMP.@constraint(pm.model, qsw >= qsw_lb*z, base_name=name[4])
    pm.model[Symbol(name[1])] = c1
    pm.model[Symbol(name[2])] = c2
    pm.model[Symbol(name[3])] = c3
    pm.model[Symbol(name[4])] = c4
end



""
function constraint_storage_thermal_limit(pm::AbstractPowerModel, n::Int, i, rating; name="storage[$i]_thermal_limit")
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)

    c = JuMP.@constraint(pm.model, ps^2 + qs^2 <= rating^2, base_name=name)
    pm.model[Symbol(name)] = c
end

""
function constraint_storage_state_initial(pm::AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, time_elapsed; name=
    "storage[$i]_state_initial")
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    se = var(pm, n, :se, i)

    c = JuMP.@constraint(pm.model, se - energy == time_elapsed*(charge_eff*sc - sd/discharge_eff), base_name=name)
    pm.model[Symbol(name)] = c
end

""
function constraint_storage_state(pm::AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, time_elapsed; name=
    "storage[$i]_state")
    sc_2 = var(pm, n_2, :sc, i)
    sd_2 = var(pm, n_2, :sd, i)
    se_2 = var(pm, n_2, :se, i)
    se_1 = var(pm, n_1, :se, i)

    c = JuMP.@constraint(pm.model, se_2 - se_1 == time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff), base_name=name)
    pm.model[Symbol(name)] = c
end

""
function constraint_storage_complementarity_nl(pm::AbstractPowerModel, n::Int, i; name="storage[$i]_complementarity_nl")
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    c = JuMP.@constraint(pm.model, sc*sd == 0.0, base_name=name)
    pm.model[Symbol(name)] = c
end

""
function constraint_storage_complementarity_mi(pm::AbstractPowerModel, n::Int, i, charge_ub, discharge_ub; name=
    ["storage[$i]_complementarity_mi", "storage[$i]_charge_ub", "storage[$i]_discharge_ub"])
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    sc_on = var(pm, n, :sc_on, i)
    sd_on = var(pm, n, :sd_on, i)

    c1 = JuMP.@constraint(pm.model, sc_on + sd_on == 1, base_name=name[1])
    c2 = JuMP.@constraint(pm.model, sc_on*charge_ub >= sc, base_name=name[2])
    c3 = JuMP.@constraint(pm.model, sd_on*discharge_ub >= sd, base_name=name[3])
    pm.model[Symbol(name[1])] = c1
    pm.model[Symbol(name[2])] = c2
    pm.model[Symbol(name[3])] = c3
end


""
function constraint_storage_on_off(pm::AbstractPowerModel, n::Int, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub; name=
    ["storage[$i]_active_ub_on_off", "storage[$i]_active_lb_on_off", "storage[$i]_reactive_ub_on_off", "storage[$i]_reactive_lb_on_off",
    "storage[$i]_reactive_charge_ub_on_off", "storage[$i]_reactive_charge_lb_on_off"])
    z_storage = var(pm, n, :z_storage, i)
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)
    qsc = var(pm, n, :qsc, i)

    c1 = JuMP.@constraint(pm.model, ps <= z_storage*pmax, base_name=name[1])
    c2 = JuMP.@constraint(pm.model, ps >= z_storage*pmin, base_name=name[2])
    c3 = JuMP.@constraint(pm.model, qs <= z_storage*qmax, base_name=name[3])
    c4 = JuMP.@constraint(pm.model, qs >= z_storage*qmin, base_name=name[4])
    c5 = JuMP.@constraint(pm.model, qsc <= z_storage*qmax, base_name=name[5])
    c6 = JuMP.@constraint(pm.model, qsc >= z_storage*qmin, base_name=name[6])
    pm.model[Symbol(name[1])] = c1
    pm.model[Symbol(name[2])] = c2
    pm.model[Symbol(name[3])] = c3
    pm.model[Symbol(name[4])] = c4
    pm.model[Symbol(name[5])] = c5
    pm.model[Symbol(name[6])] = c6
end