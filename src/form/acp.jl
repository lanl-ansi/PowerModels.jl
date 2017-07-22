export 
    ACPPowerModel, StandardACPForm,
    ACRPowerModel, StandardACRForm,
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
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

""
variable_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...) = nothing

"do nothing, this model does not have complex voltage constraints"
constraint_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T}) = Set()

"do nothing, this model does not have complex voltage constraints"
constraint_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}) = nothing

"`t[ref_bus] == 0`"
constraint_theta_ref{T <: AbstractACPForm}(pm::GenericPowerModel{T}, ref_bus::Int) =
    Set([@constraint(pm.model, getindex(pm.model, :t)[ref_bus] == 0)])

"`vm - epsilon <= v[i] <= vm + epsilon`"
function constraint_voltage_magnitude_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    v = getindex(pm.model, :v)[i]

    if epsilon == 0.0
        c = @constraint(pm.model, v == vm)
        return Set([c])
    else
        c1 = @constraint(pm.model, v <= vm + epsilon)
        c2 = @constraint(pm.model, v >= vm - epsilon)
        return Set([c1, c2])
    end
end

"""
```
sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*v^2
sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*v^2
```
"""
function constraint_kcl_shunt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    v = getindex(pm.model, :v)[i]
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*v^2)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*v^2)
    return Set([c1, c2])
end

"""
```
sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2
```
"""
function constraint_kcl_shunt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    v = getindex(pm.model, :v)[i]
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    p_ne = getindex(pm.model, :p_ne)
    q_ne = getindex(pm.model, :q_ne)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2)
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
q[f_idx] == -(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))
```
"""
function constraint_ohms_yt_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_fr == g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))
q[t_idx] == -(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))
```
"""
function constraint_ohms_yt_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_to == g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)

```
p[f_idx] == g*(v[f_bus]/tr)^2 + -g*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -b*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)
q[f_idx] == -(b+c/2)*(v[f_bus]/tr)^2 + b*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -g*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)
```
"""
function constraint_ohms_y_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_fr == g*(v_fr/tr)^2 + -g*v_fr/tr*v_to*cos(t_fr-t_to-as) + -b*v_fr/tr*v_to*sin(t_fr-t_to-as) )
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)*(v_fr/tr)^2 + b*v_fr/tr*v_to*cos(t_fr-t_to-as) + -g*v_fr/tr*v_to*sin(t_fr-t_to-as) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)

```
p[t_idx] == g*v[t_bus]^2 + -g*v[t_bus]*v[f_bus]/tr*cos(t[t_bus]-t[f_bus]+as) + -b*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)
q_to == -(b+c/2)*v[t_bus]^2 + b*v[t_bus]*v[f_bus]/tr*cos(t[f_bus]-t[t_bus]+as) + -g*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)
```
"""
function constraint_ohms_y_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_to == g*v_to^2 + -g*v_to*v_fr/tr*cos(t_to-t_fr+as) + -b*v_to*v_fr/tr*sin(t_to-t_fr+as) )
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*v_to^2 + b*v_to*v_fr/tr*cos(t_fr-t_to+as) + -g*v_to*v_fr/tr*sin(t_to-t_fr+as) )
    return Set([c1, c2])
end

"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_phase_angle_difference{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax)
    c2 = @constraint(pm.model, t_fr - t_to >= angmin)
    return Set([c1, c2])
end

""
function variable_voltage_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
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
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]
    z = getindex(pm.model, :line_z)[i]

    c1 = @NLconstraint(pm.model, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    c2 = @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    return Set([c1, c2])
end

"""
```
p[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]
    z = getindex(pm.model, :line_z)[i]

    c1 = @NLconstraint(pm.model, p_to == z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    c2 = @NLconstraint(pm.model, q_to == z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end

"""
```
p_ne[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
q_ne[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))
```
"""
function constraint_ohms_yt_from_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getindex(pm.model, :p_ne)[f_idx]
    q_fr = getindex(pm.model, :q_ne)[f_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]
    z = getindex(pm.model, :line_ne)[i]

    c1 = @NLconstraint(pm.model, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    c2 = @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    return Set([c1, c2])
end

"""
```
p_ne[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
q_ne[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))
```
"""
function constraint_ohms_yt_to_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = getindex(pm.model, :p_ne)[t_idx]
    q_to = getindex(pm.model, :q_ne)[t_idx]
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]
    z = getindex(pm.model, :line_ne)[i]

    c1 = @NLconstraint(pm.model, p_to == z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    c2 = @NLconstraint(pm.model, q_to == z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end

"`angmin <= line_z[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_phase_angle_difference_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]
    z = getindex(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= angmax)
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= angmin)
    return Set([c1, c2])
end

"`angmin <= line_ne[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_phase_angle_difference_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]
    z = getindex(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= angmax)
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= angmin)
    return Set([c1, c2])
end

"""
```
p[f_idx] + p[t_idx] >= 0
q[f_idx] + q[t_idx] >= -c/2*(v[f_bus]^2/tr^2 + v[t_bus]^2)
```
"""
function constraint_loss_lb{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, c, tr)
    v_fr = getindex(pm.model, :v)[f_bus]
    v_to = getindex(pm.model, :v)[t_bus]
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]

    c1 = @constraint(m, p_fr + p_to >= 0)
    c2 = @constraint(m, q_fr + q_to >= -c/2*(v_fr^2/tr^2 + v_to^2))
    return Set([c1, c2])
end




""
@compat abstract type AbstractACRForm <: AbstractPowerFormulation end

""
@compat abstract type StandardACRForm <: AbstractACRForm end

""
const ACRPowerModel = GenericPowerModel{StandardACRForm}

"default rectangular AC constructor"
ACRPowerModel(data::Dict{String,Any}; kwargs...) = 
    GenericPowerModel(data, StandardACRForm; kwargs...)


""
function variable_voltage{T <: AbstractACRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_real(pm; kwargs...)
    variable_voltage_imaginary(pm; kwargs...)
end


"add constraints for voltage magnitude"
function constraint_voltage{T <: AbstractACRForm}(pm::GenericPowerModel{T}; kwargs...)
    vr = getindex(pm.model, :vr)
    vi = getindex(pm.model, :vi)

    cs = Set([])
    for (i,bus) in pm.ref[:bus]
        c1 = @constraint(pm.model, bus["vmin"]^2 <= (vr[i]^2 + vi[i]^2))
        c2 = @constraint(pm.model, bus["vmax"]^2 >= (vr[i]^2 + vi[i]^2))
        push!(cs, Set([c1, c2]))
    end

    return cs
end


"`t[ref_bus] == 0`"
constraint_theta_ref{T <: AbstractACRForm}(pm::GenericPowerModel{T}, ref_bus::Int) =
    Set([@constraint(pm.model, getindex(pm.model, :vi)[ref_bus] == 0)])


""
function constraint_kcl_shunt{T <: AbstractACRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    vr = getindex(pm.model, :vr)[i]
    vi = getindex(pm.model, :vr)[i]
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*(vr^2 + vi^2))
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*(vr^2 + vi^2))
    return Set([c1, c2])
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from{T <: AbstractACRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    vr_fr = getindex(pm.model, :vr)[f_bus]
    vr_to = getindex(pm.model, :vr)[t_bus]
    vi_fr = getindex(pm.model, :vi)[f_bus]
    vi_to = getindex(pm.model, :vi)[t_bus]

    c1 = @NLconstraint(pm.model, p_fr == g/tm*(vr_fr^2 + vi_fr^2) + (-g*tr+b*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr-g*ti)/tm*(vi_fr*vr_to - vr_fr*vi_to) )
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*(vr_fr^2 + vi_fr^2) - (-b*tr-g*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr+b*ti)/tm*(vi_fr*vr_to - vr_fr*vi_to) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to{T <: AbstractACRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    vr_fr = getindex(pm.model, :vr)[f_bus]
    vr_to = getindex(pm.model, :vr)[t_bus]
    vi_fr = getindex(pm.model, :vi)[f_bus]
    vi_to = getindex(pm.model, :vi)[t_bus]

    c1 = @NLconstraint(pm.model, p_to == g*(vr_to^2 + vi_to^2) + (-g*tr-b*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr+g*ti)/tm*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*(vr_to^2 + vi_to^2) - (-b*tr+g*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr-b*ti)/tm*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    return Set([c1, c2])
end


"""
branch phase angle difference bounds
"""
function constraint_phase_angle_difference{T <: AbstractACRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    vr_fr = getindex(pm.model, :vr)[f_bus]
    vr_to = getindex(pm.model, :vr)[t_bus]
    vi_fr = getindex(pm.model, :vi)[f_bus]
    vi_to = getindex(pm.model, :vi)[t_bus]

    c1 = @NLconstraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) <= tan(angmax)*(vr_fr*vr_to + vi_fr*vi_to))
    c2 = @NLconstraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) >= tan(angmin)*(vr_fr*vr_to + vi_fr*vi_to))

    return Set([c1, c2])
end


"extracts voltage set points from rectangular voltage form and converts into polar voltage form"
function add_bus_voltage_setpoint{T <: AbstractACRForm}(sol, pm::GenericPowerModel{T})
    sol_dict = sol["bus"] = get(sol, "bus", Dict{String,Any}())
    for (i,item) in pm.data["bus"]
        idx = Int(item["bus_i"])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item["vm"] = NaN
        sol_item["va"] = NaN
        try
            vr = getvalue(getindex(pm.model, :vr)[idx])
            vi = getvalue(getindex(pm.model, :vi)[idx])
            
            vm = sqrt(vr^2 + vi^2)
            sol_item["vm"] = vm

            if vr == 0.0
                if vi >= 0
                    va = pi/2
                else
                    va = 3*pi/2
                end
            else
                va = atan(vi/vr)
            end
            sol_item["va"] = va
        catch
        end
    end
end




""
@compat abstract type APIACPForm <: AbstractACPForm end

""
const APIACPPowerModel = GenericPowerModel{APIACPForm}

"default AC constructor"
APIACPPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, APIACPForm; kwargs...)

"variable: load_factor >= 1.0"
variable_load_factor(pm::GenericPowerModel) =
    @variable(pm.model, load_factor >= 1.0, start = 1.0)

"objective: Max. load_factor"
objective_max_loading(pm::GenericPowerModel) = 
    @objective(pm.model, Max, getindex(pm.model, :load_factor))

""
function objective_max_loading_voltage_norm(pm::GenericPowerModel)
    # Seems to create too much reactive power and makes even small models hard to converge
    load_factor = getindex(pm.model, :load_factor)

    scale = length(pm.ref[:bus])
    v = getindex(pm.model, :v)

    return @objective(pm.model, Max, 10*scale*load_factor - sum(((bus["vmin"] + bus["vmax"])/2 - v[i])^2 for (i,bus) in pm.ref[:bus] ))
end

""
function objective_max_loading_gen_output(pm::GenericPowerModel)
    # Works but adds unnecessary runtime
    load_factor = getindex(pm.model, :load_factor)

    scale = length(pm.ref[:gen])
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    return @NLobjective(pm.model, Max, 100*scale*load_factor - sum( (pg[i]^2 - (2*qg[i])^2)^2 for (i,gen) in pm.ref[:gen] ))
end

""
function bounds_tighten_voltage(pm::APIACPPowerModel; epsilon = 0.001)
    for (i,bus) in pm.ref[:bus]
        v = getindex(pm.model, :v)[i]
        setupperbound(v, bus["vmax"]*(1.0-epsilon))
        setlowerbound(v, bus["vmin"]*(1.0+epsilon))
    end
end

""
function upperbound_negative_active_generation(pm::APIACPPowerModel)
    for (i,gen) in pm.ref[:gen]
        if gen["pmax"] <= 0 
            pg = getindex(pm.model, :pg)[i]
            setupperbound(pg, gen["pmax"])
        end
    end
end

""
function constraint_kcl_shunt_scaled(pm::APIACPPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    load_factor = getindex(pm.model, :load_factor)
    v = getindex(pm.model, :v)
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    if bus["pd"] > 0 && bus["qd"] > 0
        c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"]*load_factor - bus["gs"]*v[i]^2)
    else
        # super fallback impl
        c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"] - bus["gs"]*v[i]^2)
    end

    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - bus["qd"] + bus["bs"]*v[i]^2)

    return Set([c1, c2])
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
    add_setpoint(sol, pm, "bus", "bus_i", "pd", :load_factor; default_value = (item) -> item["pd"], scale = (x,item) -> item["pd"] > 0 && item["qd"] > 0 ? x*item["pd"] : item["pd"], extract_var = (var,idx,item) -> var)
    add_setpoint(sol, pm, "bus", "bus_i", "qd", :load_factor; default_value = (item) -> item["qd"], scale = (x,item) -> item["qd"], extract_var = (var,idx,item) -> var)
end
