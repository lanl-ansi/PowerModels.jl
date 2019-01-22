### polar form of the non-convex AC equations

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACPForm
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

""
function variable_voltage_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACPForm
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACPForm
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACPForm
end


"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel{T}, n::Int, k::Int, i::Int, vm) where T <: AbstractACPForm
    v = var(pm, n, k, :vm, i)
    JuMP.@constraint(pm.model, v == vm)
end


function constraint_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, c_rating_a) where T <: AbstractACPForm
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


"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2
sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*v^2
```
"""
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractACPForm
    vm = var(pm, n, c, :vm, i)
    p = var(pm, n, c, :p)
    q = var(pm, n, c, :q)
    pg = var(pm, n, c, :pg)
    qg = var(pm, n, c, :qg)
    p_dc = var(pm, n, c, :p_dc)
    q_dc = var(pm, n, c, :q_dc)

    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*vm^2)
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*vm^2)
end


""
function constraint_kcl_shunt_storage(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractACPForm
    vm = var(pm, n, c, :vm, i)
    p = var(pm, n, c, :p)
    q = var(pm, n, c, :q)
    pg = var(pm, n, c, :pg)
    qg = var(pm, n, c, :qg)
    ps = var(pm, n, c, :ps)
    qs = var(pm, n, c, :qs)
    p_dc = var(pm, n, c, :p_dc)
    q_dc = var(pm, n, c, :q_dc)

    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*vm^2)
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - sum(qs[s] for s in bus_storage) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*vm^2)
end


"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*vm^2
sum(q[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*vm^2
```
"""
function constraint_kcl_shunt_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractACPForm
    vm   = var(pm, n, c, :vm, i)
    p    = var(pm, n, c, :p)
    q    = var(pm, n, c, :q)
    p_ne = var(pm, n, c, :p_ne)
    q_ne = var(pm, n, c, :q_ne)
    pg   = var(pm, n, c, :pg)
    qg   = var(pm, n, c, :qg)
    p_dc = var(pm, n, c, :p_dc)
    q_dc = var(pm, n, c, :q_dc)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)  + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*vm^2)
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)  + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*vm^2)
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] ==  (g+g_fr)/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
q[f_idx] == -(b+b_fr)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
```
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractACPForm
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
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractACPForm
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
function constraint_ohms_y_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tm, ta) where T <: AbstractACPForm
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
function constraint_ohms_y_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tm, ta) where T <: AbstractACPForm
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
function variable_voltage_on_off(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACPForm
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage_on_off(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACPForm
end

"""
```
p[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractACPForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    q_fr  = var(pm, n, c,  :q, f_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    JuMP.@NLconstraint(pm.model, p_fr == z*( (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
    JuMP.@NLconstraint(pm.model, q_fr == z*(-(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
end

"""
```
p[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractACPForm
    p_to  = var(pm, n, c,  :p, t_idx)
    q_to  = var(pm, n, c,  :q, t_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    JuMP.@NLconstraint(pm.model, p_to == z*( (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
    JuMP.@NLconstraint(pm.model, q_to == z*(-(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
end

"""
```
p_ne[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q_ne[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractACPForm
    p_fr  = var(pm, n, c, :p_ne, f_idx)
    q_fr  = var(pm, n, c, :q_ne, f_idx)
    vm_fr = var(pm, n, c,   :vm, f_bus)
    vm_to = var(pm, n, c,   :vm, t_bus)
    va_fr = var(pm, n, c,   :va, f_bus)
    va_to = var(pm, n, c,   :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    JuMP.@NLconstraint(pm.model, p_fr == z*( (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
    JuMP.@NLconstraint(pm.model, q_fr == z*(-(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to))) )
end

"""
```
p_ne[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q_ne[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractACPForm
    p_to = var(pm, n, c, :p_ne, t_idx)
    q_to = var(pm, n, c, :q_ne, t_idx)
    vm_fr = var(pm, n, c, :vm, f_bus)
    vm_to = var(pm, n, c, :vm, t_bus)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    JuMP.@NLconstraint(pm.model, p_to == z*( (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
    JuMP.@NLconstraint(pm.model, q_to == z*(-(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr))) )
end

"`angmin <= branch_z[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractACPForm
    i, f_bus, t_bus = f_idx
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    JuMP.@constraint(pm.model, z*(va_fr - va_to) <= angmax)
    JuMP.@constraint(pm.model, z*(va_fr - va_to) >= angmin)
end

"`angmin <= branch_ne[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractACPForm
    i, f_bus, t_bus = f_idx
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    JuMP.@constraint(pm.model, z*(va_fr - va_to) <= angmax)
    JuMP.@constraint(pm.model, z*(va_fr - va_to) >= angmin)
end

"""
```
p[f_idx] + p[t_idx] >= 0
q[f_idx] + q[t_idx] >= -c/2*(v[f_bus]^2/tr^2 + v[t_bus]^2)
```
"""
function constraint_loss_lb(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g_fr, b_fr, g_to, b_to, tr) where T <: AbstractACPForm
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
