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
function constraint_thermal_limit_from(pm::AbstractPowerModel, n::Int, f_idx, rate_a; constraint_name=nothing)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "thermal_limit_from[$f_idx]" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), p_fr^2 + q_fr^2 <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::AbstractPowerModel, n::Int, t_idx, rate_a; constraint_name=nothing)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "thermal_limit_to[$t_idx]" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), p_to^2 + q_to^2 <= rate_a^2)
end

"`[rate_a, p[f_idx], q[f_idx]] in SecondOrderCone`"
function constraint_thermal_limit_from(pm::AbstractConicModels, n::Int, f_idx, rate_a; constraint_name=nothing)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "thermal_limit_from[$f_idx]_SOC" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), [rate_a, p_fr, q_fr] in JuMP.SecondOrderCone())
end

"`[rate_a, p[t_idx], q[t_idx]] in SecondOrderCone`"
function constraint_thermal_limit_to(pm::AbstractConicModels, n::Int, t_idx, rate_a; constraint_name=nothing)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "thermal_limit_to[$t_idx]_SOC" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), [rate_a, p_to, q_to] in JuMP.SecondOrderCone())
end

# Generic on/off thermal limit constraint

"`p[f_idx]^2 + q[f_idx]^2 <= (rate_a * z_branch[i])^2`"
function constraint_thermal_limit_from_on_off(pm::AbstractPowerModel, n::Int, i, f_idx, rate_a; constraint_name=nothing)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    z = var(pm, n, :z_branch, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "thermal_limit_from[$f_idx]_on_off" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= (rate_a * z_branch[i])^2`"
function constraint_thermal_limit_to_on_off(pm::AbstractPowerModel, n::Int, i, t_idx, rate_a; constraint_name=nothing)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)
    z = var(pm, n, :z_branch, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "thermal_limit_to[$t_idx]_on_off" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`p_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_ne_thermal_limit_from(pm::AbstractPowerModel, n::Int, i, f_idx, rate_a; constraint_name=nothing)
    p_fr = var(pm, n, :p_ne, f_idx)
    q_fr = var(pm, n, :q_ne, f_idx)
    z = var(pm, n, :branch_ne, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "ne_thermal_limit_from[$f_idx]" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), p_fr^2 + q_fr^2 <= rate_a^2*z^2)
end

"`p_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * branch_ne[i])^2`"
function constraint_ne_thermal_limit_to(pm::AbstractPowerModel, n::Int, i, t_idx, rate_a; constraint_name=nothing)
    p_to = var(pm, n, :p_ne, t_idx)
    q_to = var(pm, n, :q_ne, t_idx)
    z = var(pm, n, :branch_ne, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "ne_thermal_limit_to[$t_idx]" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), p_to^2 + q_to^2 <= rate_a^2*z^2)
end

"`pg[i] == pg`"
function constraint_gen_setpoint_active(pm::AbstractPowerModel, n::Int, i, pg; constraint_name=nothing)
    pg_var = var(pm, n, :pg, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "gen_setpoint_active[$i]" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), pg_var == pg)
end

"`qq[i] == qq`"
function constraint_gen_setpoint_reactive(pm::AbstractPowerModel, n::Int, i, qg; constraint_name=nothing)
    qg_var = var(pm, n, :qg, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "gen_setpoint_reactive[$i]" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), qg_var == qg)
end

"on/off constraint for generators"
function constraint_gen_power_on_off(pm::AbstractPowerModel, n::Int, i::Int, pmin, pmax, qmin, qmax; constraint_name=nothing)
    pg = var(pm, n, :pg, i)
    qg = var(pm, n, :qg, i)
    z = var(pm, n, :z_gen, i)

    #Initialize default constraint names if none are provided
    if isnothing(constraint_name)
        constraint_name = [nothing, nothing, nothing, nothing]
    end

    #Generate default name if none is provided
    constraint_name[1] = isnothing(constraint_name[1]) ? "gen_active_ub[$i]_on_off" : constraint_name[1]
    constraint_name[2] = isnothing(constraint_name[2]) ? "gen_active_lb[$i]_on_off" : constraint_name[2]
    constraint_name[3] = isnothing(constraint_name[3]) ? "gen_reactive_ub[$i]_on_off" : constraint_name[3]
    constraint_name[4] = isnothing(constraint_name[4]) ? "gen_reactive_lb[$i]_on_off" : constraint_name[4]

    JuMP.@constraint(pm.model, Symbol(constraint_name[1]), pg <= pmax*z)
    JuMP.@constraint(pm.model, Symbol(constraint_name[2]), pg >= pmin*z)
    JuMP.@constraint(pm.model, Symbol(constraint_name[3]), qg <= qmax*z)
    JuMP.@constraint(pm.model, Symbol(constraint_name[4]), qg >= qmin*z)
end


"""
Creates Line Flow constraint for DC Lines (Matpower Formulation)

```
p_fr + p_to == loss0 + p_fr * loss1
```
"""
function constraint_dcline_power_losses(pm::AbstractPowerModel, n::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1; constraint_name=nothing)
    p_fr = var(pm, n, :p_dc, f_idx)
    p_to = var(pm, n, :p_dc, t_idx)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "dcline_power_losses_from[$f_idx]_to[$t_idx]" : constraint_name
    
    JuMP.@constraint(pm.model, Symbol(constraint_name), (1-loss1) * p_fr + (p_to - loss0) == 0)
end

"`pf[i] == pf, pt[i] == pt`"
function constraint_dcline_setpoint_active(pm::AbstractPowerModel, n::Int, f_idx, t_idx, pf, pt; constraint_name=nothing)
    p_fr = var(pm, n, :p_dc, f_idx)
    p_to = var(pm, n, :p_dc, t_idx)

    #Initialize default constraint names if none are provided
    if isnothing(constraint_name)
        constraint_name = [nothing, nothing]
    end

    #Generate default name if none is provided
    constraint_name[1] = isnothing(constraint_name[1]) ? "dcline_setpoint_active_from[$f_idx]" : constraint_name[1]
    constraint_name[2] = isnothing(constraint_name[2]) ? "dcline_setpoint_active_to[$t_idx]" : constraint_name[2]

    JuMP.@constraint(pm.model, Symbol(constraint_name[1]), p_fr == pf)
    JuMP.@constraint(pm.model, Symbol(constraint_name[2]), p_to == pt)
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
function constraint_switch_state_open(pm::AbstractPowerModel, n::Int, f_idx; constraint_name=nothing)
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)

    #Initialize default constraint names if none are provided
    if isnothing(constraint_name)
        constraint_name = [nothing, nothing]
    end

    #Generate default name if none is provided
    constraint_name[1] = isnothing(constraint_name[1]) ? "switch[$f_idx]_state_open_active" : constraint_name[1]
    constraint_name[2] = isnothing(constraint_name[2]) ? "switch[$f_idx]_state_open_reactive" : constraint_name[2]

    JuMP.@constraint(pm.model, Symbol(constraint_name[1]), psw == 0.0)
    JuMP.@constraint(pm.model, Symbol(constraint_name[2]), qsw == 0.0)
end

""
function constraint_switch_thermal_limit(pm::AbstractPowerModel, n::Int, f_idx, rating; constraint_name=nothing)
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "switch[$f_idx]_thermal_limit" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), psw^2 + qsw^2 <= rating^2)
end

""
function constraint_switch_power_on_off(pm::AbstractPowerModel, n::Int, i, f_idx; constraint_name=nothing)
    psw = var(pm, n, :psw, f_idx)
    qsw = var(pm, n, :qsw, f_idx)
    z = var(pm, n, :z_switch, i)

    psw_lb, psw_ub = _IM.variable_domain(psw)
    qsw_lb, qsw_ub = _IM.variable_domain(qsw)

    #Initialize default constraint names if none are provided
    if isnothing(constraint_name)
        constraint_name = [nothing, nothing, nothing, nothing]
    end

    #Generate default name if none is provided
    constraint_name[1] = isnothing(constraint_name[1]) ? "switch[$f_idx]_active_ub_on_off" : constraint_name[1]
    constraint_name[2] = isnothing(constraint_name[2]) ? "switch[$f_idx]_active_lb_on_off" : constraint_name[2]
    constraint_name[3] = isnothing(constraint_name[3]) ? "switch[$f_idx]_reactive_ub_on_off" : constraint_name[3]
    constraint_name[4] = isnothing(constraint_name[4]) ? "switch[$f_idx]_reactive_lb_on_off" : constraint_name[4]

    JuMP.@constraint(pm.model, Symbol(constraint_name[1]), psw <= psw_ub*z)
    JuMP.@constraint(pm.model, Symbol(constraint_name[2]), psw >= psw_lb*z)
    JuMP.@constraint(pm.model, Symbol(constraint_name[3]), qsw <= qsw_ub*z)
    JuMP.@constraint(pm.model, Symbol(constraint_name[4]), qsw >= qsw_lb*z)
end



""
function constraint_storage_thermal_limit(pm::AbstractPowerModel, n::Int, i, rating; constraint_name=nothing)
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "storage[$i]_thermal_limit" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), ps^2 + qs^2 <= rating^2)
end

""
function constraint_storage_state_initial(pm::AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, time_elapsed; constraint_name=nothing)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    se = var(pm, n, :se, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "storage[$i]_state_initial" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), se - energy == time_elapsed*(charge_eff*sc - sd/discharge_eff))
end

""
function constraint_storage_state(pm::AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, time_elapsed; constraint_name=nothing)
    sc_2 = var(pm, n_2, :sc, i)
    sd_2 = var(pm, n_2, :sd, i)
    se_2 = var(pm, n_2, :se, i)
    se_1 = var(pm, n_1, :se, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "storage[$i]_state" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), se_2 - se_1 == time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff))
end

""
function constraint_storage_complementarity_nl(pm::AbstractPowerModel, n::Int, i; constraint_name=nothing)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    #Generate default name if none is provided
    constraint_name = isnothing(constraint_name) ? "storage[$i]_complementarity_nl" : constraint_name

    JuMP.@constraint(pm.model, Symbol(constraint_name), sc*sd == 0.0)
end

""
function constraint_storage_complementarity_mi(pm::AbstractPowerModel, n::Int, i, charge_ub, discharge_ub; constraint_name=nothing)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    sc_on = var(pm, n, :sc_on, i)
    sd_on = var(pm, n, :sd_on, i)

    #Initialize default constraint names if none are provided
    if isnothing(constraint_name)
        constraint_name = [nothing, nothing, nothing]
    end

    #Generate default name if none is provided
    constraint_name[1] = isnothing(constraint_name[1]) ? "storage[$i]_complementarity_mi" : constraint_name[1]
    constraint_name[2] = isnothing(constraint_name[2]) ? "storage[$i]_charge_ub" : constraint_name[2]
    constraint_name[3] = isnothing(constraint_name[3]) ? "storage[$i]_discharge_ub" : constraint_name[3]

    JuMP.@constraint(pm.model, Symbol(constraint_name[1]), sc_on + sd_on == 1)
    JuMP.@constraint(pm.model, Symbol(constraint_name[2]), sc_on*charge_ub >= sc)
    JuMP.@constraint(pm.model, Symbol(constraint_name[3]), sd_on*discharge_ub >= sd)
end


""
function constraint_storage_on_off(pm::AbstractPowerModel, n::Int, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub; constraint_name=nothing)
    z_storage = var(pm, n, :z_storage, i)
    ps = var(pm, n, :ps, i)
    qs = var(pm, n, :qs, i)
    qsc = var(pm, n, :qsc, i)

    #Initialize default constraint names if none are provided
    if isnothing(constraint_name)
        constraint_name = [nothing, nothing, nothing, nothing, nothing, nothing]
    end

    #Generate default name if none is provided
    constraint_name[1] = isnothing(constraint_name[1]) ? "storage[$i]_active_ub_on_off" : constraint_name[1]
    constraint_name[2] = isnothing(constraint_name[2]) ? "storage[$i]_active_lb_on_off" : constraint_name[2]
    constraint_name[3] = isnothing(constraint_name[3]) ? "storage[$i]_reactive_ub_on_off" : constraint_name[3]
    constraint_name[4] = isnothing(constraint_name[4]) ? "storage[$i]_reactive_lb_on_off" : constraint_name[4]
    constraint_name[5] = isnothing(constraint_name[5]) ? "storage[$i]_reactive_charge_ub_on_off" : constraint_name[5]
    constraint_name[6] = isnothing(constraint_name[6]) ? "storage[$i]_reactive_charge_lb_on_off" : constraint_name[6]

    JuMP.@constraint(pm.model, Symbol(constraint_name[1]), ps <= z_storage*pmax)
    JuMP.@constraint(pm.model, Symbol(constraint_name[2]), ps >= z_storage*pmin)
    JuMP.@constraint(pm.model, Symbol(constraint_name[3]), qs <= z_storage*qmax)
    JuMP.@constraint(pm.model, Symbol(constraint_name[4]), qs >= z_storage*qmin)
    JuMP.@constraint(pm.model, Symbol(constraint_name[5]), qsc <= z_storage*qmax)
    JuMP.@constraint(pm.model, Symbol(constraint_name[6]), qsc >= z_storage*qmin)
end
