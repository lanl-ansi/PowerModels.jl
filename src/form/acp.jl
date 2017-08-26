### polar form of the non-convex AC equations

export
    ACPPowerModel, StandardACPForm,
    APIACPPowerModel, APIACPForm

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

"`vm - epsilon <= v[i] <= vm + epsilon`"
function constraint_voltage_magnitude_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    v = pm.var[:vm][i]

    if epsilon == 0.0
        @constraint(pm.model, v == vm)
    else
        @constraint(pm.model, v <= vm + epsilon)
        @constraint(pm.model, v >= vm - epsilon)
    end
end

"""
'''
vm_from  - epsilon <= v[i] <= vm_from + epsilon
vm_to  - epsilon <= v[i] <= vm_to + epsilon
'''
"""
function constraint_voltage_dcline_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, vf, vt, epsilon)
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]

    if epsilon == 0.0
        @constraint(pm.model, vm_fr == vf)
        @constraint(pm.model, vm_to == vt)
    else
        @constraint(pm.model, vm_fr <= vf + epsilon)
        @constraint(pm.model, vm_fr >= vf - epsilon)
        @constraint(pm.model, vm_to <= vt + epsilon)
        @constraint(pm.model, vm_to >= vt - epsilon)
    end
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
Creates Ohms constraints for shiftable PSTs / OLTCs

```
p[f_idx] == g*vm_tap[f_idx]^2 + (-g)*(vm_tap[f_idx]*vm_tap[t_idx]*cos((va[f_bus] - va_shift[f_idx]) - (va[t_bus] - va_shift[t_idx]))) + (-b)*(vm_tap[f_idx]*vm_tap[t_idx]*sin((va[f_bus] - va_shift[f_idx]) - (va[t_bus] - va_shift[t_idx]))))
q[f_idx] == -(b+c/2)*vm_tap[f_idx]^2 - (-b)*(vm_tap[f_idx]*vm_tap[t_idx]*cos((va[f_bus] - va_shift[f_idx]) - (va[t_bus] - va_shift[t_idx]))) + (-g)*(vm_tap[f_idx]*vm_tap[t_idx]*sin((va[f_bus] - va_shift[f_idx]) - (va[t_bus] - va_shift[t_idx]))))
vm_tap[f_idx] * tap_min <= vm[f_bus] <= vm_tap[f_idx] * tap_max
```
"""
function constraint_variable_transformer_y_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, g_shunt, tap_min, tap_max)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    va_shift_fr = pm.var[:va_shift][f_idx]
    va_shift_to = pm.var[:va_shift][t_idx]
    vm_tap_fr = pm.var[:vm_tap][f_idx]
    vm_tap_to = pm.var[:vm_tap][t_idx]

    @NLconstraint(pm.model, p_fr == (g + g_shunt / 2)*vm_tap_fr^2 + (-g)*(vm_tap_fr*vm_tap_to*cos((va_fr - va_shift_fr) - (va_to - va_shift_to))) + (-b)*(vm_tap_fr*vm_tap_to*sin((va_fr - va_shift_fr) - (va_to - va_shift_to))))
    @NLconstraint(pm.model, q_fr == -(b+c/2)*vm_tap_fr^2 - (-b)*(vm_tap_fr*vm_tap_to*cos((va_fr - va_shift_fr) - (va_to - va_shift_to))) + (-g)*(vm_tap_fr*vm_tap_to*sin((va_fr - va_shift_fr) - (va_to - va_shift_to))))
    @constraint(pm.model, vm_tap_fr * tap_min <= vm_fr)
    @constraint(pm.model, vm_fr <= vm_tap_fr * tap_max)
end

"""
Creates Ohms constraints for shiftable PSTs / OLTCs

```
p[t_idx] == g*vm_tap[t_idx]^2 + (-g)*(vm_tap[t_idx]*vm_tap[f_idx]*cos((va[t_bus] - va_shift[t_idx]) - (va[f_bus] - va_shift[f_idx]))) + (-b)*(vm_tap[t_idx]*vm_tap[f_idx]*sin((va[t_bus] - va_shift[t_idx]) - (va[f_bus] - va_shift[f_idx]))))
q[t_idx] == -(b+c/2)*vm_tap[t_idx]^2 - (-b)*(vm_tap[t_idx]*vm_tap[f_idx]*cos((va[t_bus] - va_shift[t_idx]) - (va[f_bus] - va_shift[f_idx]))) + (-g)*(vm_tap[t_idx]*vm_tap[f_idx]*sin((va[t_bus] - va_shift[t_idx]) - (va[f_bus] - va_shift[f_idx]))))
vm_tap[t_idx] * tap_min <= vm[t_bus] <= vm_tap[t_idx] * tap_max
```
"""
function constraint_variable_transformer_y_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, g_shunt, tap_min, tap_max)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    va_fr = pm.var[:va][f_bus]
    va_to = pm.var[:va][t_bus]
    va_shift_fr = pm.var[:va_shift][f_idx]
    va_shift_to = pm.var[:va_shift][t_idx]
    vm_tap_fr = pm.var[:vm_tap][f_idx]
    vm_tap_to = pm.var[:vm_tap][t_idx]

    @NLconstraint(pm.model, p_to == (g + g_shunt / 2)*vm_tap_to^2 + (-g)*(vm_tap_to*vm_tap_fr*cos((va_to - va_shift_to) - (va_fr - va_shift_fr))) + (-b)*(vm_tap_to*vm_tap_fr*sin((va_to - va_shift_to) - (va_fr - va_shift_fr))))
    @NLconstraint(pm.model, q_to == -(b+c/2)*vm_tap_to^2 - (-b)*(vm_tap_to*vm_tap_fr*cos((va_to - va_shift_to) - (va_fr - va_shift_fr))) + (-g)*(vm_tap_to*vm_tap_fr*sin((va_to - va_shift_to) - (va_fr - va_shift_fr))))
    @constraint(pm.model, vm_tap_to * tap_min <= vm_to)
    @constraint(pm.model, vm_to <= vm_tap_to * tap_max)
end

"""
Links voltage magnitudes of not tappable transformers with node voltage magnitudes

```
vm_tap[f_idx] * tap == vm[f_bus]
vm_tap[t_idx] * tap == vm[t_bus]
```
"""

function constraint_link_voltage_magnitudes{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, tap_fr, tap_to)
    vm_fr = pm.var[:vm][f_bus]
    vm_to = pm.var[:vm][t_bus]
    vm_tap_fr = pm.var[:vm_tap][f_idx]
    vm_tap_to = pm.var[:vm_tap][t_idx]
    @constraint(pm.model, vm_tap_fr * tap_fr == vm_fr)
    @constraint(pm.model, vm_tap_to * tap_to == vm_to)
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



""
@compat abstract type APIACPForm <: AbstractACPForm end

""
const APIACPPowerModel = GenericPowerModel{APIACPForm}

"default AC constructor"
APIACPPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, APIACPForm; kwargs...)

"variable: load_factor >= 1.0"
function variable_load_factor(pm::GenericPowerModel)
    pm.var[:load_factor] = @variable(pm.model,
        basename="load_factor",
        lowerbound=1.0,
        start = 1.0
    )
end

"objective: Max. load_factor"
function objective_max_loading(pm::GenericPowerModel)
    @objective(pm.model, Max, pm.var[:load_factor])
end

""
function objective_max_loading_voltage_norm(pm::GenericPowerModel)
    # Seems to create too much reactive power and makes even small models hard to converge
    load_factor = pm.var[:load_factor]

    scale = length(pm.ref[:bus])
    v = pm.var[:vm]

    @objective(pm.model, Max, 10*scale*load_factor - sum(((bus["vmin"] + bus["vmax"])/2 - v[i])^2 for (i,bus) in pm.ref[:bus]))
end

""
function objective_max_loading_gen_output(pm::GenericPowerModel)
    # Works but adds unnecessary runtime
    load_factor = pm.var[:load_factor]

    scale = length(pm.ref[:gen])
    pg = pm.var[:pg]
    qg = pm.var[:qg]

    @NLobjective(pm.model, Max, 100*scale*load_factor - sum( (pg[i]^2 - (2*qg[i])^2)^2 for (i,gen) in pm.ref[:gen] ))
end

""
function bounds_tighten_voltage(pm::APIACPPowerModel; epsilon = 0.001)
    for (i,bus) in pm.ref[:bus]
        v = pm.var[:vm][i]
        setupperbound(v, bus["vmax"]*(1.0-epsilon))
        setlowerbound(v, bus["vmin"]*(1.0+epsilon))
    end
end

""
function upperbound_negative_active_generation(pm::APIACPPowerModel)
    for (i,gen) in pm.ref[:gen]
        if gen["pmax"] <= 0
            pg = pm.var[:pg][i]
            setupperbound(pg, gen["pmax"])
        end
    end
end

""
function constraint_kcl_shunt_scaled(pm::APIACPPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    load_factor = pm.var[:load_factor]
    v = pm.var[:vm]
    p = pm.var[:p]
    q = pm.var[:q]
    pg = pm.var[:pg]
    qg = pm.var[:qg]

    if bus["pd"] > 0 && bus["qd"] > 0
        @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"]*load_factor - bus["gs"]*v[i]^2)
    else
        # super fallback impl
        @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"] - bus["gs"]*v[i]^2)
    end

    @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - bus["qd"] + bus["bs"]*v[i]^2)
end

""
function get_solution(pm::APIACPPowerModel)
    # super fallback
    sol = init_solution(pm)
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)

    # extension
    add_bus_demand_setpoint(sol, pm)

    return sol
end

""
function add_bus_demand_setpoint(sol, pm::APIACPPowerModel)
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "bus", "pd", :load_factor; default_value = (item) -> item["pd"], scale = (x,item) -> item["pd"] > 0 && item["qd"] > 0 ? x*item["pd"] : item["pd"], extract_var = (var,idx,item) -> var)
    add_setpoint(sol, pm, "bus", "qd", :load_factor; default_value = (item) -> item["qd"], scale = (x,item) -> item["qd"], extract_var = (var,idx,item) -> var)
end
