export
    DCPPowerModel, StandardDCPForm,
    DCPLLPowerModel, StandardDCPLLForm

""
abstract type AbstractDCPForm <: AbstractPowerFormulation end

""
abstract type StandardDCPForm <: AbstractDCPForm end

""
const DCPPowerModel = GenericPowerModel{StandardDCPForm}

"default DC constructor"
DCPPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, StandardDCPForm; kwargs...)

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDCPForm
    variable_voltage_angle(pm, n; kwargs...)
end


"nothing to add, there are no voltage variables on branches"
function variable_voltage_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_generation(pm::GenericPowerModel{T}, n::Int=pm.cnw; bounded = true) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_branch_flow(pm::GenericPowerModel{T}, n::Int=pm.cnw; bounded = true) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw) where T <: AbstractDCPForm
end


""
function variable_active_branch_flow(pm::GenericPowerModel{T}, n::Int=pm.cnw; bounded = true) where T <: StandardDCPForm
    if bounded
        pm.var[:nw][n][:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs_from]], basename="$(n)_p",
            lowerbound = -pm.ref[:nw][n][:branch][l]["rate_a"],
            upperbound =  pm.ref[:nw][n][:branch][l]["rate_a"],
            start = getstart(pm.ref[:nw][n][:branch], l, "p_start")
        )
    else
        pm.var[:nw][n][:p] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs_from]], basename="$(n)_p",
            start = getstart(pm.ref[:nw][n][:branch], l, "p_start")
        )
    end

    # this explicit type erasure is necessary
    p_expr = Dict{Any,Any}([((l,i,j), pm.var[:nw][n][:p][(l,i,j)]) for (l,i,j) in pm.ref[:nw][n][:arcs_from]])
    p_expr = merge(p_expr, Dict([((l,j,i), -1.0*pm.var[:nw][n][:p][(l,i,j)]) for (l,i,j) in pm.ref[:nw][n][:arcs_from]]))
    pm.var[:nw][n][:p] = p_expr
end

""
function variable_active_branch_flow_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw) where T <: StandardDCPForm
    pm.var[:nw][n][:p_ne] = @variable(pm.model,
        [(l,i,j) in pm.ref[:nw][n][:ne_arcs_from]], basename="$(n)_p_ne",
        lowerbound = -pm.ref[:nw][n][:ne_branch][l]["rate_a"],
        upperbound =  pm.ref[:nw][n][:ne_branch][l]["rate_a"],
        start = getstart(pm.ref[:nw][n][:ne_branch], l, "p_start")
    )

    # this explicit type erasure is necessary
    p_ne_expr = Dict{Any,Any}([((l,i,j), 1.0*pm.var[:nw][n][:p_ne][(l,i,j)]) for (l,i,j) in pm.ref[:nw][n][:ne_arcs_from]])
    p_ne_expr = merge(p_ne_expr, Dict([((l,j,i), -1.0*pm.var[:nw][n][:p_ne][(l,i,j)]) for (l,i,j) in pm.ref[:nw][n][:ne_arcs_from]]))
    pm.var[:nw][n][:p_ne] = p_ne_expr
end

"do nothing, this model does not have complex voltage variables"
function constraint_voltage(pm::GenericPowerModel{T}, n::Int) where T <: AbstractDCPForm
end

"do nothing, this model does not have complex voltage variables"
function constraint_voltage_ne(pm::GenericPowerModel{T}, n::Int) where T <: AbstractDCPForm
end

"do nothing, this model does not have voltage variables"
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel{T}, n::Int, i, vm) where T <: AbstractDCPForm
end

"do nothing, this model does not have reactive variables"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel{T}, n::Int, i, qg) where T <: AbstractDCPForm
end


""
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    pg = pm.var[:nw][n][:pg]
    p = pm.var[:nw][n][:p]
    p_dc = pm.var[:nw][n][:p_dc]
    load = pm.ref[:nw][n][:load]
    shunt = pm.ref[:nw][n][:shunt]

    pm.con[:nw][n][:kcl_p][i] = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
    # omit reactive constraint
end


""
function constraint_kcl_shunt_ne(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    pg = pm.var[:nw][n][:pg]
    p = pm.var[:nw][n][:p]
    p_ne = pm.var[:nw][n][:p_ne]
    p_dc = pm.var[:nw][n][:p_dc]
    load = pm.ref[:nw][n][:load]
    shunt = pm.ref[:nw][n][:shunt]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == -b*(t[f_bus] - t[t_bus])
```
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractDCPForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]

    @constraint(pm.model, p_fr == -b*(va_fr - va_to))
    # omit reactive constraint
end

"Do nothing, this model is symmetric"
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractDCPForm
end

function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
    p_fr = pm.var[:nw][n][:p_ne][f_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_ne][i]

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"Do nothing, this model is symmetric"
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
end

"`-rate_a <= p[f_idx] <= rate_a`"
function constraint_thermal_limit_from(pm::GenericPowerModel{T}, n::Int, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = pm.con[:nw][n][:sm_fr][f_idx[1]] = pm.var[:nw][n][:p][f_idx]
    getlowerbound(p_fr) < -rate_a && setlowerbound(p_fr, -rate_a)
    getupperbound(p_fr) > rate_a && setupperbound(p_fr, rate_a)
end

"Do nothing, this model is symmetric"
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, t_idx, rate_a) where T <: AbstractDCPForm
end

""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractDCPForm
    add_setpoint(sol, pm, "bus", "vm", :vm; default_value = (item) -> 1)
    add_setpoint(sol, pm, "bus", "va", :va)
end

""
function variable_voltage_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDCPForm
    variable_voltage_angle(pm, n; kwargs...)
end

"do nothing, this model does not have complex voltage variables"
function constraint_voltage_on_off(pm::GenericPowerModel{T}, n::Int) where T <: AbstractDCPForm
end

"`-b*(t[f_bus] - t[t_bus] + vad_min*(1-branch_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + vad_max*(1-branch_z[i]))`"
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_z][i]

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"Do nothing, this model is symmetric"
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
end

"""
Generic on/off thermal limit constraint

```
-rate_a*branch_z[i] <= p[f_idx] <=  rate_a*branch_z[i]
```
"""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel{T}, n::Int, i, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    z = pm.var[:nw][n][:branch_z][i]

    @constraint(pm.model, p_fr <=  rate_a*z)
    @constraint(pm.model, p_fr >= -rate_a*z)
end

"""
Generic on/off thermal limit constraint

```
-rate_a*branch_ne[i] <= p_ne[f_idx] <=  rate_a*branch_ne[i]
```
"""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel{T}, n::Int, i, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = pm.var[:nw][n][:p_ne][f_idx]
    z = pm.var[:nw][n][:branch_ne][i]

    @constraint(pm.model, p_fr <=  rate_a*z)
    @constraint(pm.model, p_fr >= -rate_a*z)
end

"nothing to do, from handles both sides"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel{T}, n::Int, i, t_idx, rate_a) where T <: AbstractDCPForm
end

"nothing to do, from handles both sides"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel{T}, n::Int, i, t_idx, rate_a) where T <: AbstractDCPForm
end

"`angmin*branch_z[i] + vad_min*(1-branch_z[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_z[i] + vad_max*(1-branch_z[i])`"
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel{T}, n::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractDCPForm
    i, f_bus, t_bus = f_idx

    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_z][i]

    @constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    @constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

"`angmin*branch_ne[i] + vad_min*(1-branch_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_ne[i] + vad_max*(1-branch_ne[i])`"
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel{T}, n::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractDCPForm
    i, f_bus, t_bus = f_idx

    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_ne][i]

    @constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    @constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end



""
abstract type AbstractDCPLLForm <: AbstractDCPForm end

""
abstract type StandardDCPLLForm <: AbstractDCPLLForm end

""
const DCPLLPowerModel = GenericPowerModel{StandardDCPLLForm}

"default DC constructor"
DCPLLPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, StandardDCPLLForm; kwargs...)


"`sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)== sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*1.0^2`"
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_loads, bus_shunts, pd, qd, gs, bs) where T <: AbstractDCPLLForm
    pg = pm.var[:nw][n][:pg]
    p = pm.var[:nw][n][:p]
    p_dc = pm.var[:nw][n][:p_dc]
    load = pm.ref[:nw][n][:load]
    shunt = pm.ref[:nw][n][:shunt]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*1.0^2)
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractDCPLLForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]

    @constraint(pm.model, p_fr == -b*(va_fr - va_to))
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractDCPLLForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]

    r = g/(g^2 + b^2)
    @constraint(pm.model, p_fr + p_to >= r*(p_fr^2))
end

"""
"""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_z][i]

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"""
"""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_z][i]

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    @constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    @constraint(pm.model, p_fr + p_to >= 0)
end


"""
"""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = pm.var[:nw][n][:p_ne][f_idx]
    p_to = pm.var[:nw][n][:p_ne][t_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_ne][i]

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"""
"""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = pm.var[:nw][n][:p_ne][f_idx]
    p_to = pm.var[:nw][n][:p_ne][t_idx]
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]
    z = pm.var[:nw][n][:branch_ne][i]

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    @constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    @constraint(pm.model, p_fr + p_to >= 0)
end


"`-rate_a*branch_z[i] <= p[t_idx] <= rate_a*branch_z[i]`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel{T}, n::Int, i, t_idx, rate_a) where T <: AbstractDCPLLForm
    p_to = pm.var[:nw][n][:p][t_idx]
    z = pm.var[:nw][n][:branch_z][i]

    @constraint(pm.model, p_to <=  rate_a*z)
    @constraint(pm.model, p_to >= -rate_a*z)
end
