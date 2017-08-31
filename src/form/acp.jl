### polar form of the non-convex AC equations

export
    ACPPowerModel, StandardACPForm

""
@compat abstract type AbstractACPForm <: AbstractPowerFormulation end

""
@compat abstract type StandardACPForm <: AbstractACPForm end

""
const ACPPowerModel = GenericPowerModel{StandardACPForm}

"default AC constructor"
ACPPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, StandardACPForm; kwargs...)

""
function variable_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

""
function variable_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T})
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T})
end

"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, vm)
    v = pm.var[:vm][i]
    
    @constraint(pm.model, v == vm)
end


"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*v^2
```
"""
function constraint_kcl_shunt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    vm = pm.var[:vm][i]
    p = pm.var[:p]
    q = pm.var[:q]
    pg = pm.var[:pg]
    qg = pm.var[:qg]
    p_dc = pm.var[:p_dc]
    q_dc = pm.var[:q_dc]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*vm^2)
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*vm^2)
end

"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2
```
"""
function constraint_kcl_shunt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    vm = pm.var[:vm][i]
    p = pm.var[:p]
    q = pm.var[:q]
    p_ne = pm.var[:p_ne]
    q_ne = pm.var[:q_ne]
    pg = pm.var[:pg]
    qg = pm.var[:qg]
    p_dc = pm.var[:p_dc]
    q_dc = pm.var[:q_dc]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)  + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*vm^2)
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)  + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*vm^2)
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
q[f_idx] == -(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
```
"""
function constraint_ohms_yt_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]

    @NLconstraint(pm.model, p_fr == g/tm*vm_fr^2 + (-g*tr+b*ti)/tm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm*(vm_fr*vm_to*sin(va_fr-va_to)) )
    @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*vm_fr^2 - (-b*tr-g*ti)/tm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm*(vm_fr*vm_to*sin(va_fr-va_to)) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))
q[t_idx] == -(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))
```
"""
function constraint_ohms_yt_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]

    @NLconstraint(pm.model, p_to == g*vm_to^2 + (-g*tr-b*ti)/tm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm*(vm_to*vm_fr*sin(va_to-va_fr)) )
    @NLconstraint(pm.model, q_to == -(b+c/2)*vm_to^2 - (-b*tr+g*ti)/tm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm*(vm_to*vm_fr*sin(va_to-va_fr)) )
end

"""
Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)

```
p[f_idx] == g*(v[f_bus]/tr)^2 + -g*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -b*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)
q[f_idx] == -(b+c/2)*(v[f_bus]/tr)^2 + b*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -g*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)
```
"""
function constraint_ohms_y_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]

    @NLconstraint(pm.model, p_fr == g*(vm_fr/tr)^2 + -g*vm_fr/tr*vm_to*cos(va_fr-va_to-as) + -b*vm_fr/tr*vm_to*sin(va_fr-va_to-as) )
    @NLconstraint(pm.model, q_fr == -(b+c/2)*(vm_fr/tr)^2 + b*vm_fr/tr*vm_to*cos(va_fr-va_to-as) + -g*vm_fr/tr*vm_to*sin(va_fr-va_to-as) )
end

"""
Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)

```
p[t_idx] == g*v[t_bus]^2 + -g*v[t_bus]*v[f_bus]/tr*cos(t[t_bus]-t[f_bus]+as) + -b*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)
q_to == -(b+c/2)*v[t_bus]^2 + b*v[t_bus]*v[f_bus]/tr*cos(t[f_bus]-t[t_bus]+as) + -g*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)
```
"""
function constraint_ohms_y_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]

    @NLconstraint(pm.model, p_to == g*vm_to^2 + -g*vm_to*vm_fr/tr*cos(va_to-va_fr+as) + -b*vm_to*vm_fr/tr*sin(va_to-va_fr+as) )
    @NLconstraint(pm.model, q_to == -(b+c/2)*vm_to^2 + b*vm_to*vm_fr/tr*cos(va_to-va_fr+as) + -g*vm_to*vm_fr/tr*sin(va_to-va_fr+as) )
end


""
function variable_voltage_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

"do nothing, this model does not have complex voltage constraints"
constraint_voltage_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}) = Set()

"""
```
p[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    z = pm.var[:line_z][i]

    @NLconstraint(pm.model, p_fr == z*(g/tm*vm_fr^2 + (-g*tr+b*ti)/tm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm*(vm_fr*vm_to*sin(va_fr-va_to))) )
    @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*vm_fr^2 - (-b*tr-g*ti)/tm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm*(vm_fr*vm_to*sin(va_fr-va_to))) )
end

"""
```
p[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    z = pm.var[:line_z][i]

    @NLconstraint(pm.model, p_to == z*(g*vm_to^2 + (-g*tr-b*ti)/tm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm*(vm_to*vm_fr*sin(va_to-va_fr))) )
    @NLconstraint(pm.model, q_to == z*(-(b+c/2)*vm_to^2 - (-b*tr+g*ti)/tm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm*(vm_to*vm_fr*sin(va_to-va_fr))) )
end

"""
```
p_ne[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q_ne[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p_ne][f_idx]
    q_fr = pm.var[:q_ne][f_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    z = pm.var[:line_ne][i]

    @NLconstraint(pm.model, p_fr == z*(g/tm*vm_fr^2 + (-g*tr+b*ti)/tm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/tm*(vm_fr*vm_to*sin(va_fr-va_to))) )
    @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*vm_fr^2 - (-b*tr-g*ti)/tm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/tm*(vm_fr*vm_to*sin(va_fr-va_to))) )
end

"""
```
p_ne[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q_ne[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = pm.var[:p_ne][t_idx]
    q_to = pm.var[:q_ne][t_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    z = pm.var[:line_ne][i]

    @NLconstraint(pm.model, p_to == z*(g*vm_to^2 + (-g*tr-b*ti)/tm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/tm*(vm_to*vm_fr*sin(va_to-va_fr))) )
    @NLconstraint(pm.model, q_to == z*(-(b+c/2)*vm_to^2 - (-b*tr+g*ti)/tm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/tm*(vm_to*vm_fr*sin(va_to-va_fr))) )
end

"`angmin <= line_z[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_voltage_angle_difference_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    z = pm.var[:line_z][i]

    @constraint(pm.model, z*(va_fr - va_to) <= angmax)
    @constraint(pm.model, z*(va_fr - va_to) >= angmin)
end

"`angmin <= line_ne[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_voltage_angle_difference_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    z = pm.var[:line_ne][i]

    @constraint(pm.model, z*(va_fr - va_to) <= angmax)
    @constraint(pm.model, z*(va_fr - va_to) >= angmin)
end

"""
```
p[f_idx] + p[t_idx] >= 0
q[f_idx] + q[t_idx] >= -c/2*(v[f_bus]^2/tr^2 + v[t_bus]^2)
```
"""
function constraint_loss_lb{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, c, tr)
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]

    @constraint(m, p_fr + p_to >= 0)
    @constraint(m, q_fr + q_to >= -c/2*(vm_fr^2/tr^2 + vm_to^2))
end


