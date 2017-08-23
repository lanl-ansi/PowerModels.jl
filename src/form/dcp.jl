export
    DCPPowerModel, StandardDCPForm,
    DCPLLPowerModel, StandardDCPLLForm

""
@compat abstract type AbstractDCPForm <: AbstractPowerFormulation end

""
@compat abstract type StandardDCPForm <: AbstractDCPForm end

""
const DCPPowerModel = GenericPowerModel{StandardDCPForm}

"default DC constructor"
DCPPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, StandardDCPForm; kwargs...)

""
variable_voltage{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...) =
    variable_voltage_angle(pm; kwargs...)

"nothing to add, there are no voltage variables on branches"
variable_voltage_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...) = Set([])

"dc models ignore reactive power flows"
variable_reactive_generation{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; bounded = true) = Set()

"dc models ignore reactive power flows"
variable_reactive_line_flow{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; bounded = true) = Set()

"dc models ignore reactive power flows"
variable_reactive_line_flow_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}) = Set([])


""
function variable_active_line_flow{T <: StandardDCPForm}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        pm.var[:p] = @variable(pm.model, 
            [(l,i,j) in pm.ref[:arcs_from]], basename="p",
            lowerbound = -pm.ref[:branch][l]["rate_a"],
            upperbound =  pm.ref[:branch][l]["rate_a"],
            start = getstart(pm.ref[:branch], l, "p_start")
        )
    else
        pm.var[:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:arcs_from]], basename="p",
            start = getstart(pm.ref[:branch], l, "p_start")
        )
    end

    # this explicit type erasure is necessary 
    p_expr = Dict{Any,Any}([((l,i,j), pm.var[:p][(l,i,j)]) for (l,i,j) in pm.ref[:arcs_from]])
    p_expr = merge(p_expr, Dict([((l,j,i), -1.0*pm.var[:p][(l,i,j)]) for (l,i,j) in pm.ref[:arcs_from]]))
    pm.var[:p] = p_expr

    return pm.var[:p]
end

""
function variable_active_line_flow_ne{T <: StandardDCPForm}(pm::GenericPowerModel{T})
    pm.var[:p_ne] = @variable(pm.model, 
        [(l,i,j) in pm.ref[:ne_arcs_from]], basename="p_ne",
        lowerbound = -pm.ref[:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:ne_branch], l, "p_start")
    )

    # this explicit type erasure is necessary 
    p_ne_expr = Dict{Any,Any}([((l,i,j), 1.0*pm.var[:p_ne][(l,i,j)]) for (l,i,j) in pm.ref[:ne_arcs_from]])
    p_ne_expr = merge(p_ne_expr, Dict([((l,j,i), -1.0*pm.var[:p_ne][(l,i,j)]) for (l,i,j) in pm.ref[:ne_arcs_from]]))
    pm.var[:p_ne] = p_ne_expr

    return pm.var[:p_ne]
end

"do nothing, this model does not have complex voltage variables"
constraint_voltage{T <: AbstractDCPForm}(pm::GenericPowerModel{T}) = nothing

"do nothing, this model does not have complex voltage variables"
constraint_voltage_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}) = nothing

"do nothing, this model does not have voltage variables"
constraint_voltage_magnitude_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, vm, epsilon) = Set()

"do nothing, this model does not have reactive variables"
constraint_reactive_gen_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, qg) = Set()

"do nothing, this model does not have voltage variables"
constraint_voltage_dcline_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, vf, vt, epsilon) = Set()

""
function constraint_kcl_shunt{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    pg = pm.var[:pg]
    p = pm.var[:p]
    p_dc = pm.var[:p_dc]

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    # omit reactive constraint
    return Set([c])
end

""
function constraint_kcl_shunt_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    pg = pm.var[:pg]
    p = pm.var[:p]
    p_ne = pm.var[:p_ne]
    p_dc = pm.var[:p_dc]

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    return Set([c])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == -b*(t[f_bus] - t[t_bus])
```
"""
function constraint_ohms_yt_from{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = pm.var[:p][f_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]

    c = @constraint(pm.model, p_fr == -b*(t_fr - t_to))
    # omit reactive constraint
    return Set([c])
end

"Do nothing, this model is symmetric"
constraint_ohms_yt_to{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm) = Set()

function constraint_ohms_yt_from_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p_ne][f_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

"Do nothing, this model is symmetric"
constraint_ohms_yt_to_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max) = Set()


"`-rate_a <= p[f_idx] <= rate_a`"
function constraint_thermal_limit_from{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_idx, rate_a)
    p_fr = pm.var[:p][f_idx]

    if getlowerbound(p_fr) < -rate_a
        setlowerbound(p_fr, -rate_a)
    end

    if getupperbound(p_fr) > rate_a
        setupperbound(p_fr, rate_a)
    end

    return Set()
end

"Do nothing, this model is symmetric"
constraint_thermal_limit_to{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, t_idx, rate_a) = Set()

""
function add_bus_voltage_setpoint{T <: AbstractDCPForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v; default_value = (item) -> 1)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end

""
variable_voltage_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...) = variable_voltage_angle(pm; kwargs...)

"do nothing, this model does not have complex voltage variables"
constraint_voltage_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}) = nothing

"`-b*(t[f_bus] - t[t_bus] + t_min*(1-line_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + t_max*(1-line_z[i]))`"
function constraint_ohms_yt_from_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p][f_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

"Do nothing, this model is symmetric"
constraint_ohms_yt_to_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max) = Set()

"""
Generic on/off thermal limit constraint

```
-rate_a*line_z[i] <= p[f_idx] <=  rate_a*line_z[i]
```
"""
function constraint_thermal_limit_from_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_idx, rate_a)
    p_fr = pm.var[:p][f_idx]
    z = pm.var[:line_z][i]

    c1 = @constraint(pm.model, p_fr <=  rate_a*z)
    c2 = @constraint(pm.model, p_fr >= -rate_a*z)
    return Set([c1, c2])
end

"""
Generic on/off thermal limit constraint

```
-rate_a*line_ne[i] <= p_ne[f_idx] <=  rate_a*line_ne[i]
```
"""
function constraint_thermal_limit_from_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_idx, rate_a)
    p_fr = pm.var[:p_ne][f_idx]
    z = pm.var[:line_ne][i]

    c1 = @constraint(pm.model, p_fr <=  rate_a*z)
    c2 = @constraint(pm.model, p_fr >= -rate_a*z)
    return Set([c1, c2])
end

"nothing to do, from handles both sides"
constraint_thermal_limit_to_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a) = Set()

"nothing to do, from handles both sides"
constraint_thermal_limit_to_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a) = Set()

"`angmin*line_z[i] + t_min*(1-line_z[i]) <= t[f_bus] - t[t_bus] <= angmax*line_z[i] + t_max*(1-line_z[i])`"
function constraint_voltage_angle_difference_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= angmin*z + t_min*(1-z))
    return Set([c1, c2])
end

"`angmin*line_ne[i] + t_min*(1-line_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*line_ne[i] + t_max*(1-line_ne[i])`"
function constraint_voltage_angle_difference_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= angmin*z + t_min*(1-z))
    return Set([c1, c2])
end

""
@compat abstract type AbstractDCPLLForm <: AbstractDCPForm end

""
@compat abstract type StandardDCPLLForm <: AbstractDCPLLForm end

""
const DCPLLPowerModel = GenericPowerModel{StandardDCPLLForm}

"default DC constructor"
DCPLLPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, StandardDCPLLForm; kwargs...)

"`sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)== sum(pg[g] for g in bus_gens) - pd - gs*1.0^2`"
function constraint_kcl_shunt{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    pg = pm.var[:pg]
    p = pm.var[:p]
    p_dc = pm.var[:p_dc]

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    return Set([c])
end

"`sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2`"
function constraint_kcl_shunt_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    p = pm.var[:p]
    p_ne = pm.var[:p_ne]
    p_dc = pm.var[:p_dc]
    pg = pm.var[:pg]

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    return Set([c])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
-b*(t[f_bus] - t[t_bus] + t_min*(1-line_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + t_max*(1-line_z[i]))
```
"""
function constraint_ohms_yt_from_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p][f_idx]
    p_to = pm.var[:p][t_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] + p[t_idx] >= r*( (-b*(t[f_bus] - t[t_bus]))^2 - (-b*(t_m))^2*(1-line_z[i]) )
```
where `r = g/(g^2 + b^2)` and `t_m = max(|t_min|, |t_max|)`
"""
function constraint_ohms_yt_to_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p][f_idx]
    p_to = pm.var[:p][t_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_z][i]

    r = g/(g^2 + b^2)
    t_m = max(abs(t_min),abs(t_max))
    c = @constraint(pm.model, p_fr + p_to >= r*( (-b*(t_fr - t_to))^2 - (-b*(t_m))^2*(1-z) ) )
    return Set([c])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
-b*(t[f_bus] - t[t_bus] + t_min*(1-line_ne[i])) <= p_ne[f_idx] <= -b*(t[f_bus] - t[t_bus] + t_max*(1-line_ne[i]))
```
"""
function constraint_ohms_yt_from_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p_ne][f_idx]
    p_to = pm.var[:p_ne][t_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p_ne[f_idx] + p_ne[t_idx] >= r*( (-b*(t[f_bus] - t[t_bus]))^2 - (-b*(t_m))^2*(1-line_ne[i]) )
```
where `r = g/(g^2 + b^2)` and `t_m = max(|t_min|, |t_max|)`
"""
function constraint_ohms_yt_to_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p_ne][f_idx]
    p_to = pm.var[:p_ne][t_idx]
    t_fr = pm.var[:t][f_bus]
    t_to = pm.var[:t][t_bus]
    z = pm.var[:line_ne][i]

    r = g/(g^2 + b^2)
    t_m = max(abs(t_min),abs(t_max))
    c = @constraint(pm.model, p_fr + p_to >= r*( (-b*(t_fr - t_to))^2 - (-b*(t_m))^2*(1-z) ) )
    return Set([c])
end

"`-rate_a*line_z[i] <= p[t_idx] <= rate_a*line_z[i]`"
function constraint_thermal_limit_to_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a)
    p_to = pm.var[:p][t_idx]
    z = pm.var[:line_z][i]

    c1 = @constraint(pm.model, p_to <=  rate_a*z)
    c2 = @constraint(pm.model, p_to >= -rate_a*z)
    return Set([c1, c2])
end

"`-rate_a*line_ne[i] <= p_ne[t_idx] <=  rate_a*line_ne[i]`"
function constraint_thermal_limit_to_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a)
    p_to = pm.var[:p_ne][t_idx]
    z = pm.var[:line_ne][i]

    c1 = @constraint(pm.model, p_to <=  rate_a*z)
    c2 = @constraint(pm.model, p_to >= -rate_a*z)
    return Set([c1, c2])
end
