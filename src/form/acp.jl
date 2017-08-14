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
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

""
variable_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...) = nothing

"do nothing, this model does not have complex voltage constraints"
constraint_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T}) = Set()

"do nothing, this model does not have complex voltage constraints"
constraint_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}) = nothing

"`vm - epsilon <= v[i] <= vm + epsilon`"
function constraint_voltage_magnitude_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    v = pm.var[:v][i]

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
'''
v_from  - epsilon <= v[i] <= v_from + epsilon
v_to  - epsilon <= v[i] <= v_to + epsilon
'''
"""
function constraint_voltage_dcline_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, vf, vt, epsilon)
    v_f = pm.var[:v][f_bus]
    v_t = pm.var[:v][t_bus]

    if epsilon == 0.0
        c1 = @constraint(pm.model, v_f == vf)
        c2 = @constraint(pm.model, v_t == vt)
        return Set([c1, c2])
    else
        c1 = @constraint(pm.model, v_f <= vf + epsilon)
        c2 = @constraint(pm.model, v_f >= vf - epsilon)
        c3 = @constraint(pm.model, v_t <= vt + epsilon)
        c4 = @constraint(pm.model, v_t >= vt - epsilon)
        return Set([c1, c2, c3, c4])
    end
end

"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*v^2
```
"""
function constraint_kcl_shunt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    v = pm.var[:v][i]
    p = pm.var[:p]
    q = pm.var[:q]
    pg = pm.var[:pg]
    qg = pm.var[:qg]
    p_dc = pm.var[:p_dc]
    q_dc = pm.var[:q_dc]

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*v^2)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*v^2)
    return Set([c1, c2])
end

"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2
sum(q[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2
```
"""
function constraint_kcl_shunt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    v = pm.var[:v][i]
    p = pm.var[:p]
    q = pm.var[:q]
    p_ne = pm.var[:p_ne]
    q_ne = pm.var[:q_ne]
    pg = pm.var[:pg]
    qg = pm.var[:qg]
    p_dc = pm.var[:p_dc]
    q_dc = pm.var[:q_dc]

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)  + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)  + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2)
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
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    t_shift_fr = pm.var[:t_shift][f_idx]
    t_shift_to = pm.var[:t_shift][t_idx]

#    c1 = @NLconstraint(pm.model, p_fr == g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
#    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
    c1 = @NLconstraint(pm.model, p_fr == g*v_fr^2 + (-g)*(v_fr*v_to*cos((t_fr - t_shift_fr) - (t_to - t_shift_to))) + (-b)*(v_fr*v_to*sin((t_fr - t_shift_fr) - (t_to - t_shift_to))))
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)*v_fr^2 - (-b)*(v_fr*v_to*cos((t_fr - t_shift_fr) - (t_to - t_shift_to))) + (-g)*(v_fr*v_to*sin((t_fr - t_shift_fr) - (t_to - t_shift_to))))
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
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    t_shift_fr = pm.var[:t_shift][f_idx]
    t_shift_to = pm.var[:t_shift][t_idx]

    #c1 = @NLconstraint(pm.model, p_to == g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
    #c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
    c1 = @NLconstraint(pm.model, p_to == g*v_to^2 + (-g)*(v_to*v_fr*cos((t_to - t_shift_to) - (t_fr - t_shift_fr))) + (-b)*(v_to*v_fr*sin((t_to - t_shift_to) - (t_fr - t_shift_fr))))
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*v_to^2 - (-b)*(v_to*v_fr*cos((t_to - t_shift_to) - (t_fr - t_shift_fr))) + (-g)*(v_to*v_fr*sin((t_to - t_shift_to) - (t_fr - t_shift_fr))))
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
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]

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
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]

    c1 = @NLconstraint(pm.model, p_to == g*v_to^2 + -g*v_to*v_fr/tr*cos(t_to-t_fr+as) + -b*v_to*v_fr/tr*sin(t_to-t_fr+as) )
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*v_to^2 + b*v_to*v_fr/tr*cos(t_fr-t_to+as) + -g*v_to*v_fr/tr*sin(t_to-t_fr+as) )
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
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

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
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

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
    p_fr = pm.var[:p_ne][f_idx]
    q_fr = pm.var[:q_ne][f_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

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
    p_to = pm.var[:p_ne][t_idx]
    q_to = pm.var[:q_ne][t_idx]
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

    c1 = @NLconstraint(pm.model, p_to == z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    c2 = @NLconstraint(pm.model, q_to == z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end

"`angmin <= line_z[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_phase_angle_difference_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= angmax)
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= angmin)
    return Set([c1, c2])
end

"`angmin <= line_ne[i]*(t[f_bus] - t[t_bus]) <= angmax`"
function constraint_phase_angle_difference_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

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
    v_fr = pm.var[:v][f_bus]
    v_to = pm.var[:v][t_bus]
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]

    c1 = @constraint(m, p_fr + p_to >= 0)
    c2 = @constraint(m, q_fr + q_to >= -c/2*(v_fr^2/tr^2 + v_to^2))
    return Set([c1, c2])
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
    return pm.var[:load_factor]
end

"objective: Max. load_factor"
objective_max_loading(pm::GenericPowerModel) =
    @objective(pm.model, Max, pm.var[:load_factor])

""
function objective_max_loading_voltage_norm(pm::GenericPowerModel)
    # Seems to create too much reactive power and makes even small models hard to converge
    load_factor = pm.var[:load_factor]

    scale = length(pm.ref[:bus])
    v = pm.var[:v]

    return @objective(pm.model, Max, 10*scale*load_factor - sum(((bus["vmin"] + bus["vmax"])/2 - v[i])^2 for (i,bus) in pm.ref[:bus]))
end

""
function objective_max_loading_gen_output(pm::GenericPowerModel)
    # Works but adds unnecessary runtime
    load_factor = pm.var[:load_factor]

    scale = length(pm.ref[:gen])
    pg = pm.var[:pg]
    qg = pm.var[:qg]

    return @NLobjective(pm.model, Max, 100*scale*load_factor - sum( (pg[i]^2 - (2*qg[i])^2)^2 for (i,gen) in pm.ref[:gen] ))
end

""
function bounds_tighten_voltage(pm::APIACPPowerModel; epsilon = 0.001)
    for (i,bus) in pm.ref[:bus]
        v = pm.var[:v][i]
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
    v = pm.var[:v]
    p = pm.var[:p]
    q = pm.var[:q]
    pg = pm.var[:pg]
    qg = pm.var[:qg]

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
