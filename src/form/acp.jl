### polar form of the non-convex AC equations

""
function variable_voltage(pm::AbstractACPModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

""
function variable_voltage_ne(pm::AbstractACPModel; kwargs...)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_model_voltage_ne(pm::AbstractACPModel; kwargs...)
end


"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint(pm::AbstractACPModel, n::Int, k::Int, i::Int, vm)
    v = var(pm, n, k, :vm, i)
    JuMP.@constraint(pm.model, v == vm)
end


function constraint_current_limit(pm::AbstractACPModel, n::Int, c::Int, f_idx, c_rating_a)
    l,i,j = f_idx
    t_idx = (l,j,i)

    vm_fr = var(pm, n, c, :vm, i)
    vm_to = var(pm, n, c, :vm, j)

    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= vm_fr^2*c_rating_a^2)

    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= vm_to^2*c_rating_a^2)
end


""
function constraint_power_balance(pm::AbstractACPModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    vm   = var(pm, n, c, :vm, i)
    p    = get(var(pm, n, c),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n, c),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n, c),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n, c),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n, c),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n, c),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n, c),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n, c),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n, c), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n, c), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")


    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*vm^2
    )
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*vm^2
    )
end


""
function constraint_power_balance_ne(pm::AbstractACPModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_arcs_ne, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    vm   = var(pm, n, c, :vm, i)
    p    = get(var(pm, n, c),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n, c),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n, c),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n, c),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n, c),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n, c),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n, c),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n, c),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n, c), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n, c), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")
    p_ne = get(var(pm, n, c), :p_ne, Dict()); _check_var_keys(p_ne, bus_arcs_ne, "active power", "ne_branch")
    q_ne = get(var(pm, n, c), :q_ne, Dict()); _check_var_keys(q_ne, bus_arcs_ne, "reactive power", "ne_branch")

    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        + sum(p_ne[a] for a in bus_arcs_ne)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*vm^2
    )
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        + sum(q_ne[a] for a in bus_arcs_ne)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*vm^2
    )
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] ==  (g+g_fr)/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
q[f_idx] == -(b+b_fr)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
```
"""
function constraint_ohms_yt_from(pm::AbstractACPModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr  = var(pm, n, c,  :p, f_idx)
    q_fr  = var(pm, n, c,  :q, f_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@NLconstraint(pm.model, p_fr ==  (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to)) )
    JuMP.@NLconstraint(pm.model, q_fr == -(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to)) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] ==  (g+g_to)*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))
q[t_idx] == -(b+b_to)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))
```
"""
function constraint_ohms_yt_to(pm::AbstractACPModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    p_to  = var(pm, n, c,  :p, t_idx)
    q_to  = var(pm, n, c,  :q, t_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@NLconstraint(pm.model, p_to ==  (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr)) )
    JuMP.@NLconstraint(pm.model, q_to == -(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr)) )
end

"""
Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)

```
p[f_idx] ==  (g+g_fr)*(v[f_bus]/tr)^2 + -g*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -b*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)
q[f_idx] == -(b+b_fr)*(v[f_bus]/tr)^2 + b*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -g*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)
```
"""
function constraint_ohms_y_from(pm::AbstractACPModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tm, ta)
    p_fr  = var(pm, n, c,  :p, f_idx)
    q_fr  = var(pm, n, c,  :q, f_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@NLconstraint(pm.model, p_fr ==  (g+g_fr)*(vm_fr/tm)^2 - g*vm_fr/tm*vm_to*cos(va_fr-va_to-ta) + -b*vm_fr/tm*vm_to*sin(va_fr-va_to-ta) )
    JuMP.@NLconstraint(pm.model, q_fr == -(b+b_fr)*(vm_fr/tm)^2 + b*vm_fr/tm*vm_to*cos(va_fr-va_to-ta) + -g*vm_fr/tm*vm_to*sin(va_fr-va_to-ta) )
end

"""
Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)

```
p[t_idx] == (g+g_to)*v[t_bus]^2 + -g*v[t_bus]*v[f_bus]/tr*cos(t[t_bus]-t[f_bus]+as) + -b*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)
q_to == -(b+b_to)*v[t_bus]^2 + b*v[t_bus]*v[f_bus]/tr*cos(t[f_bus]-t[t_bus]+as) + -g*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)
```
"""
function constraint_ohms_y_to(pm::AbstractACPModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tm, ta)
    p_to  = var(pm, n, c,  :p, t_idx)
    q_to  = var(pm, n, c,  :q, t_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@NLconstraint(pm.model, p_to ==  (g+g_to)*vm_to^2 - g*vm_to*vm_fr/tm*cos(va_to-va_fr+ta) + -b*vm_to*vm_fr/tm*sin(va_to-va_fr+ta) )
    JuMP.@NLconstraint(pm.model, q_to == -(b+b_to)*vm_to^2 + b*vm_to*vm_fr/tm*cos(va_to-va_fr+ta) + -g*vm_to*vm_fr/tm*sin(va_to-va_fr+ta) )
end


""
function constraint_switch_state_closed(pm::AbstractACPModel, n::Int, c::Int, f_bus, t_bus)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@constraint(pm.model, vm_fr == vm_to)
    JuMP.@constraint(pm.model, va_fr == va_to)
end

""
function constraint_switch_voltage_on_off(pm::AbstractACPModel, n::Int, c::Int, i, f_bus, t_bus, vad_min, vad_max)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, :z_switch, i)

    JuMP.@constraint(pm.model, z*vm_fr == z*vm_to)
    JuMP.@constraint(pm.model, z*va_fr == z*va_to)
end

""
function variable_voltage_on_off(pm::AbstractACPModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_model_voltage_on_off(pm::AbstractACPModel; kwargs...)
end

"""
```
p[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_on_off(pm::AbstractACPModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr  = var(pm, n, c,  :p, f_idx)
    q_fr  = var(pm, n, c,  :q, f_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    JuMP.@NLconstraint(pm.model, p_fr == z*( (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
    JuMP.@NLconstraint(pm.model, q_fr == z*(-(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
end

"""
```
p[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_on_off(pm::AbstractACPModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to  = var(pm, n, c,  :p, t_idx)
    q_to  = var(pm, n, c,  :q, t_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    JuMP.@NLconstraint(pm.model, p_to == z*( (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
    JuMP.@NLconstraint(pm.model, q_to == z*(-(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
end

"""
```
p_ne[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q_ne[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_ne(pm::AbstractACPModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr  = var(pm, n, c, :p_ne, f_idx)
    q_fr  = var(pm, n, c, :q_ne, f_idx)
    vm_fr = var(pm, n, c,   :vm, f_bus)
    vm_to = var(pm, n, c,   :vm, t_bus)
    va_fr = var(pm, n, c,   :va, f_bus)
    va_to = var(pm, n, c,   :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    JuMP.@NLconstraint(pm.model, p_fr == z*( (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
    JuMP.@NLconstraint(pm.model, q_fr == z*(-(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
end

"""
```
p_ne[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q_ne[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_ne(pm::AbstractACPModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n, c, :p_ne, t_idx)
    q_to = var(pm, n, c, :q_ne, t_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    JuMP.@NLconstraint(pm.model, p_to == z*( (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
    JuMP.@NLconstraint(pm.model, q_to == z*(-(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
end

"`angmin <= z_branch[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_voltage_angle_difference_on_off(pm::AbstractACPModel, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, z*(va_fr - va_to) <= z*angmax)
    JuMP.@constraint(pm.model, z*(va_fr - va_to) >= z*angmin)
end

"`angmin <= branch_ne[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_voltage_angle_difference_ne(pm::AbstractACPModel, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, z*(va_fr - va_to) <= angmax)
    JuMP.@constraint(pm.model, z*(va_fr - va_to) >= angmin)
end

"""
```
p[f_idx] + p[t_idx] >= 0
q[f_idx] + q[t_idx] >= -c/2*(v[f_bus]^2/tr^2 + v[t_bus]^2)
```
"""
function constraint_loss_lb(pm::AbstractACPModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g_fr, b_fr, g_to, b_to, tr)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)

    @assert(g_fr == 0 && g_to == 0)
    c = b_fr + b_to

    # TODO: Derive updated constraint from first principles
    JuMP.@constraint(m, p_fr + p_to >= 0)
    JuMP.@constraint(m, q_fr + q_to >= -c/2*(vm_fr^2/tr^2 + vm_to^2))
end
