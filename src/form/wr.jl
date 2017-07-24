export
    SOCWRPowerModel, SOCWRForm,
    QCWRPowerModel, QCWRForm

""
@compat abstract type AbstractWRForm <: AbstractPowerFormulation end

""
@compat abstract type SOCWRForm <: AbstractWRForm end

""
const SOCWRPowerModel = GenericPowerModel{SOCWRForm}

"default SOC constructor"
SOCWRPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SOCWRForm; kwargs...)

""
function variable_voltage_product{T <: AbstractWRForm}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

        @variable(pm.model, wr_min[bp] <= wr[bp in keys(pm.ref[:buspairs])] <= wr_max[bp], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi_min[bp] <= wi[bp in keys(pm.ref[:buspairs])] <= wi_max[bp], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    else
        @variable(pm.model, wr[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    end
    return wr, wi
end

""
function variable_voltage_product_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr[b in keys(pm.ref[:branch])] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi[b in keys(pm.ref[:branch])] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wi_start"))

    return wr, wi
end

""
function variable_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

""
function constraint_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = getindex(pm.model, :w)
    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)

    for (i,j) in keys(pm.ref[:buspairs])
        relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

"Do nothing, no way to represent this in these variables"
constraint_theta_ref{T <: AbstractWRForm}(pm::GenericPowerModel{T}, ref_bus::Int) = Set()

function constraint_voltage_magnitude_setpoint{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    w = getindex(pm.model, :w)[i]

    if epsilon == 0.0
        c = @constraint(pm.model, w == vm^2)
        return Set([c])
    else
        @assert epsilon > 0.0
        c1 = @constraint(pm.model, w <= (vm + epsilon)^2)
        c2 = @constraint(pm.model, w >= (vm - epsilon)^2)
        return Set([c1, c2])
    end
end

""
function constraint_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    w = getindex(pm.model, :w)[i]
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)
    p_dc = getindex(pm.model, :p_dc)
    q_dc = getindex(pm.model, :q_dc)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c1, c2])
end

"""
```
sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*w[i]
sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*w[i]
```
"""
function constraint_kcl_shunt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    w = getindex(pm.model, :w)[i]
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    p_ne = getindex(pm.model, :p_ne)
    q_ne = getindex(pm.model, :q_ne)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w[f_bus] + (-g*tr+b*ti)/tm*(wr[f_bus,t_bus]) + (-b*tr-g*ti)/tm*(wi[f_bus,t_bus])
q[f_idx] == -(b+c/2)/tm*w[f_bus] - (-b*tr-g*ti)/tm*(wr[f_bus,t_bus]) + (-g*tr+b*ti)/tm*(wi[f_bus,t_bus])
```
"""
function constraint_ohms_yt_from{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    w_fr = getindex(pm.model, :w)[f_bus]
    wr = getindex(pm.model, :wr)[(f_bus, t_bus)]
    wi = getindex(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*w[t_bus] + (-g*tr-b*ti)/tm*(wr[f_bus,t_bus]) + (-b*tr+g*ti)/tm*(-wi[f_bus,t_bus])
q[t_idx] == -(b+c/2)*w[t_bus] - (-b*tr+g*ti)/tm*(wr[f_bus,t_bus]) + (-g*tr-b*ti)/tm*(-wi[f_bus,t_bus])
```
"""
function constraint_ohms_yt_to{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    q_to = getindex(pm.model, :q)[t_idx]
    p_to = getindex(pm.model, :p)[t_idx]
    w_to = getindex(pm.model, :w)[t_bus]
    wr = getindex(pm.model, :wr)[(f_bus, t_bus)]
    wi = getindex(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, p_to == g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints for DC Lines (yt post fix indicates that Y and T values are in rectangular form)

```
p_fr + p_to == loss0 + loss1 * p_fr
```
"""
function constraint_ohms_yt_dc{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, br_status, loss0, loss1)
    p_fr = getindex(pm.model, :p_dc)[f_idx]
    p_to = getindex(pm.model, :p_dc)[t_idx]

    c1 = @constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0 * br_status) == 0)
    return Set([c1])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w_from_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])
q[f_idx] == -(b+c/2)/tm*w_from_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])
```
"""
function constraint_ohms_yt_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getindex(pm.model, :p_ne)[f_idx]
    q_fr = getindex(pm.model, :q_ne)[f_idx]
    w_fr = getindex(pm.model, :w_from_ne)[i]
    wr = getindex(pm.model, :wr_ne)[i]
    wi = getindex(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*w_to_ne[i] + (-g*tr-b*ti)/tm*(wr_ne[i]) + (-b*tr+g*ti)/tm*(-wi_ne[i])
q[t_idx] == -(b+c/2)*w_to_ne[i] - (-b*tr+g*ti)/tm*(wr_ne[i]) + (-g*tr-b*ti)/tm*(-wi_ne[i])
```
"""
function constraint_ohms_yt_to_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = getindex(pm.model, :p_ne)[t_idx]
    q_to = getindex(pm.model, :q_ne)[t_idx]
    w_to = getindex(pm.model, :w_to_ne)[i]
    wr = getindex(pm.model, :wr_ne)[i]
    wi = getindex(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, p_to == g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

""
function constraint_phase_angle_difference{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    w_fr = getindex(pm.model, :w)[f_bus]
    w_to = getindex(pm.model, :w)[t_bus]
    wr = getindex(pm.model, :wr)[(f_bus, t_bus)]
    wi = getindex(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)
    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    return Set([c1, c2, c3])
end

""
function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end

""
function variable_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_voltage_product_on_off(pm; kwargs...)
end

""
function constraint_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = getindex(pm.model, :w)
    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)
    z = getindex(pm.model, :line_z)

    w_from = getindex(pm.model, :w_from)
    w_to = getindex(pm.model, :w_to)

    cs = Set()
    cs1 = constraint_voltage_magnitude_sqr_from_on_off(pm)
    cs2 = constraint_voltage_magnitude_sqr_to_on_off(pm)
    cs3 = constraint_voltage_product_on_off(pm)
    cs = union(cs, cs1, cs2, cs3)

    for (l,i,j) in pm.ref[:arcs_from]
        cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        cs5 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        cs6 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        cs = union(cs, cs4, cs5, cs6)
    end

    return cs
end

""
function constraint_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]

    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:ne_buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in branches])

    w = getindex(pm.model, :w)
    wr = getindex(pm.model, :wr_ne)
    wi = getindex(pm.model, :wi_ne)
    z = getindex(pm.model, :line_ne)

    w_from = getindex(pm.model, :w_from_ne)
    w_to = getindex(pm.model, :w_to_ne)

    cs = Set()
    for (l,i,j) in pm.ref[:ne_arcs_from]
        c1 = @constraint(pm.model, w_from[l] <= z[l]*buses[branches[l]["f_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_from[l] >= z[l]*buses[branches[l]["f_bus"]]["vmin"]^2)

        c3 = @constraint(pm.model, wr[l] <= z[l]*wr_max[bi_bp[l]])
        c4 = @constraint(pm.model, wr[l] >= z[l]*wr_min[bi_bp[l]])
        c5 = @constraint(pm.model, wi[l] <= z[l]*wi_max[bi_bp[l]])
        c6 = @constraint(pm.model, wi[l] >= z[l]*wi_min[bi_bp[l]])

        c7 = @constraint(pm.model, w_to[l] <= z[l]*buses[branches[l]["t_bus"]]["vmax"]^2)
        c8 = @constraint(pm.model, w_to[l] >= z[l]*buses[branches[l]["t_bus"]]["vmin"]^2)

        c9 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        c10 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        c11 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        cs = Set([cs, c1, c2, c3, c4, c5, c6, c7, c8,c9, c10, c11])
    end
    return cs
end


""
function constraint_voltage_magnitude_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    v_from = getindex(pm.model, :v_from)
    z = getindex(pm.model, :line_z)

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, v_from[i] <= z[i]*buses[branch["f_bus"]]["vmax"])
        c2 = @constraint(pm.model, v_from[i] >= z[i]*buses[branch["f_bus"]]["vmin"])
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

""
function constraint_voltage_magnitude_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    v_to = getindex(pm.model, :v_to)
    z = getindex(pm.model, :line_z)

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, v_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"])
        c2 = @constraint(pm.model, v_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"])
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end


""
function constraint_voltage_magnitude_sqr_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_from = getindex(pm.model, :w_from)
    z = getindex(pm.model, :line_z)

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, w_from[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_from[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

""
function constraint_voltage_magnitude_sqr_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_to = getindex(pm.model, :w_to)
    z = getindex(pm.model, :line_z)

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

""
function constraint_voltage_product_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)
    z = getindex(pm.model, :line_z)

    cs = Set()
    for b in keys(pm.ref[:branch])
        c1 = @constraint(pm.model, wr[b] <= z[b]*wr_max[bi_bp[b]])
        c2 = @constraint(pm.model, wr[b] >= z[b]*wr_min[bi_bp[b]])
        c3 = @constraint(pm.model, wi[b] <= z[b]*wi_max[bi_bp[b]])
        c4 = @constraint(pm.model, wi[b] >= z[b]*wi_min[bi_bp[b]])
        push!(cs, c1)
        push!(cs, c2)
        push!(cs, c3)
        push!(cs, c4)
    end
    return cs
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] ==        g/tm*w_from[i] + (-g*tr+b*ti)/tm*(wr[i]) + (-b*tr-g*ti)/tm*(wi[i])
q[f_idx] == -(b+c/2)/tm*w_from[i] - (-b*tr-g*ti)/tm*(wr[i]) + (-g*tr+b*ti)/tm*(wi[i])
```
"""
function constraint_ohms_yt_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getindex(pm.model, :p)[f_idx]
    q_fr = getindex(pm.model, :q)[f_idx]
    w_fr = getindex(pm.model, :w_from)[i]
    wr = getindex(pm.model, :wr)[i]
    wi = getindex(pm.model, :wi)[i]

    c1 = @constraint(pm.model, p_fr ==        g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] ==        g*w_to[i] + (-g*tr-b*ti)/tm*(wr[i]) + (-b*tr+g*ti)/tm*(-wi[i])
q[t_idx] == -(b+c/2)*w_to[i] - (-b*tr+g*ti)/tm*(wr[i]) + (-g*tr-b*ti)/tm*(-wi[i])
```
"""
function constraint_ohms_yt_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = getindex(pm.model, :p)[t_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    w_to = getindex(pm.model, :w_to)[i]
    wr = getindex(pm.model, :wr)[i]
    wi = getindex(pm.model, :wi)[i]

    c1 = @constraint(pm.model, p_to ==        g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

"`angmin*wr[i] <= wi[i] <= angmax*wr[i]`"
function constraint_phase_angle_difference_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = getindex(pm.model, :wr)[i]
    wi = getindex(pm.model, :wi)[i]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)
    return Set([c1, c2])
end

"`angmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]`"
function constraint_phase_angle_difference_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = getindex(pm.model, :wr_ne)[i]
    wi = getindex(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)
    return Set([c1, c2])
end

""
function variable_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr_from_ne(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm; kwargs...)
    variable_voltage_product_ne(pm; kwargs...)
end

""
function variable_voltage_magnitude_sqr_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]
    @variable(pm.model, 0 <= w_from_ne[i in keys(pm.ref[:ne_branch])] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_from_start", 1.001))
    return w_from_ne
end

""
function variable_voltage_magnitude_sqr_to_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]
    @variable(pm.model, 0 <= w_to_ne[i in keys(pm.ref[:ne_branch])] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_to", 1.001))
    return w_to_ne
end

""
function variable_voltage_product_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:ne_buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:ne_branch]])
    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr_ne[b in keys(pm.ref[:ne_branch])] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ref[:ne_buspairs], bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi_ne[b in keys(pm.ref[:ne_branch])] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ref[:ne_buspairs], bi_bp[b], "wi_start"))
    return wr_ne, wi_ne
end

""
@compat abstract type QCWRForm <: AbstractWRForm end

""
const QCWRPowerModel = GenericPowerModel{QCWRForm}

"default QC constructor"
function QCWRPowerModel(data::Dict{String,Any}; kwargs...)
    return GenericPowerModel(data, QCWRForm; kwargs...)
end

"Creates variables associated with differences in phase angles"
function variable_phase_angle_difference{T}(pm::GenericPowerModel{T})
    @variable(pm.model, pm.ref[:buspairs][bp]["angmin"] <= td[bp in keys(pm.ref[:buspairs])] <= pm.ref[:buspairs][bp]["angmax"], start = getstart(pm.ref[:buspairs], bp, "td_start"))
    return td
end

"Creates the voltage magnitude product variables"
function variable_voltage_magnitude_product{T}(pm::GenericPowerModel{T})
    vv_min = Dict([(bp, buspair["v_from_min"]*buspair["v_to_min"]) for (bp, buspair) in pm.ref[:buspairs]])
    vv_max = Dict([(bp, buspair["v_from_max"]*buspair["v_to_max"]) for (bp, buspair) in pm.ref[:buspairs]])

    @variable(pm.model,  vv_min[bp] <= vv[bp in keys(pm.ref[:buspairs])] <=  vv_max[bp], start = getstart(pm.ref[:buspairs], bp, "vv_start", 1.0))
    return vv
end

""
function variable_cosine{T}(pm::GenericPowerModel{T})
    cos_min = Dict([(bp, -Inf) for bp in keys(pm.ref[:buspairs])])
    cos_max = Dict([(bp,  Inf) for bp in keys(pm.ref[:buspairs])])

    for (bp, buspair) in pm.ref[:buspairs]
        if buspair["angmin"] >= 0
            cos_max[bp] = cos(buspair["angmin"])
            cos_min[bp] = cos(buspair["angmax"])
        end
        if buspair["angmax"] <= 0
            cos_max[bp] = cos(buspair["angmax"])
            cos_min[bp] = cos(buspair["angmin"])
        end
        if buspair["angmin"] < 0 && buspair["angmax"] > 0
            cos_max[bp] = 1.0
            cos_min[bp] = min(cos(buspair["angmin"]), cos(buspair["angmax"]))
        end
    end

    @variable(pm.model, cos_min[bp] <= cs[bp in keys(pm.ref[:buspairs])] <= cos_max[bp], start = getstart(pm.ref[:buspairs], bp, "cs_start", 1.0))
    return cs
end

""
variable_sine(pm::GenericPowerModel) =
    @variable(pm.model, sin(pm.ref[:buspairs][bp]["angmin"]) <= si[bp in keys(pm.ref[:buspairs])] <= sin(pm.ref[:buspairs][bp]["angmax"]), start = getstart(pm.ref[:buspairs], bp, "si_start"))

""
function variable_current_magnitude_sqr{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    cm_min = Dict([(bp, 0) for bp in keys(pm.ref[:buspairs])])
    cm_max = Dict([(bp, (buspair["rate_a"]*buspair["tap"]/buspair["v_from_min"])^2) for (bp, buspair) in pm.ref[:buspairs]])

    @variable(pm.model, cm_min[bp] <= cm[bp in keys(pm.ref[:buspairs])] <=  cm_max[bp], start = getstart(pm.ref[:buspairs], bp, "cm_start"))
    return cm
end

""
function variable_voltage(pm::QCWRPowerModel; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)

    variable_phase_angle_difference(pm; kwargs...)
    variable_voltage_magnitude_product(pm; kwargs...)
    variable_cosine(pm; kwargs...)
    variable_sine(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

""
function constraint_voltage(pm::QCWRPowerModel)
    v = getindex(pm.model, :v)
    t = getindex(pm.model, :t)

    td = getindex(pm.model, :td)
    si = getindex(pm.model, :si)
    cs = getindex(pm.model, :cs)
    vv = getindex(pm.model, :vv)

    w = getindex(pm.model, :w)
    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)

    const_set = Set()
    for (i,b) in pm.ref[:bus]
        cs1 = relaxation_sqr(pm.model, v[i], w[i])
        const_set = union(const_set, cs1)
    end

    for bp in keys(pm.ref[:buspairs])
        i,j = bp
        c1 = @constraint(pm.model, t[i] - t[j] == td[bp])
        push!(const_set, c1)

        cs1 = relaxation_sin(pm.model, td[bp], si[bp])
        cs2 = relaxation_cos(pm.model, td[bp], cs[bp])
        cs3 = relaxation_product(pm.model, v[i], v[j], vv[bp])
        cs4 = relaxation_product(pm.model, vv[bp], cs[bp], wr[bp])
        cs5 = relaxation_product(pm.model, vv[bp], si[bp], wi[bp])

        const_set = union(const_set, cs1, cs2, cs3, cs4, cs5)
        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in pm.ref[:branch]
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = pm.ref[:buspairs][pair]

        # to prevent this constraint from being posted on multiple parallel lines
        if buspair["line"] == i
            cs1 = constraint_power_magnitude_sqr(pm, branch)
            cs2 = constraint_power_magnitude_link(pm, branch)
            const_set = union(const_set, cs1, cs2)
        end
    end

    return const_set
end

"`p[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]`"
function constraint_power_magnitude_sqr(pm::QCWRPowerModel, f_bus, t_bus, arc_from, tm)
    w_i = getindex(pm.model, :w)[f_bus]
    p_fr = getindex(pm.model, :p)[arc_from]
    q_fr = getindex(pm.model, :q)[arc_from]
    cm = getindex(pm.model, :cm)[(f_bus, t_bus)]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm*cm)
    return Set([c])
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link(pm::QCWRPowerModel, f_bus, t_bus, arc_from, g, b, c, tr, ti, tm)
    w_fr = getindex(pm.model, :w)[f_bus]
    w_to = getindex(pm.model, :w)[t_bus]
    q_fr = getindex(pm.model, :q)[arc_from]
    wr = getindex(pm.model, :wr)[(f_bus, t_bus)]
    wi = getindex(pm.model, :wi)[(f_bus, t_bus)]
    cm = getindex(pm.model, :cm)[(f_bus, t_bus)]

    c = @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
    return Set([c])
end

"`t[ref_bus] == 0`"
constraint_theta_ref(pm::QCWRPowerModel, ref_bus::Int) =
    @constraint(pm.model, getindex(pm.model, :t)[ref_bus] == 0)

""
function constraint_phase_angle_difference(pm::QCWRPowerModel, f_bus, t_bus, angmin, angmax)
    td = getindex(pm.model, :td)[(f_bus, t_bus)]

    if getlowerbound(td) < angmin
        setlowerbound(td, angmin)
    end

    if getupperbound(td) > angmax
        setupperbound(td, angmax)
    end

    w_fr = getindex(pm.model, :w)[f_bus]
    w_to = getindex(pm.model, :w)[t_bus]
    wr = getindex(pm.model, :wr)[(f_bus, t_bus)]
    wi = getindex(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)

    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    return Set([c1, c2, c3])
end

""
function add_bus_voltage_setpoint(sol, pm::QCWRPowerModel)
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end




""
function variable_voltage_on_off(pm::QCWRPowerModel; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
    variable_voltage_magnitude_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_to_on_off(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_voltage_product_on_off(pm; kwargs...)

    variable_phase_angle_difference_on_off(pm; kwargs...)
    variable_voltage_magnitude_product_on_off(pm; kwargs...)
    variable_cosine_on_off(pm; kwargs...)
    variable_sine_on_off(pm; kwargs...)
    variable_current_magnitude_sqr_on_off(pm; kwargs...) # includes 0, but needs new indexs
end

""
function variable_phase_angle_difference_on_off{T}(pm::GenericPowerModel{T})
    @variable(pm.model, min(0, pm.ref[:branch][l]["angmin"]) <= td[l in keys(pm.ref[:branch])] <= max(0, pm.ref[:branch][l]["angmax"]), start = getstart(pm.ref[:branch], l, "td_start"))
    return td
end

""
function variable_voltage_magnitude_product_on_off{T}(pm::GenericPowerModel{T})
    vv_min = Dict([(l, pm.ref[:bus][branch["f_bus"]]["vmin"]*pm.ref[:bus][branch["t_bus"]]["vmin"]) for (l, branch) in pm.ref[:branch]])
    vv_max = Dict([(l, pm.ref[:bus][branch["f_bus"]]["vmax"]*pm.ref[:bus][branch["t_bus"]]["vmax"]) for (l, branch) in pm.ref[:branch]])

    @variable(pm.model,  min(0, vv_min[l]) <= vv[l in keys(pm.ref[:branch])] <=  max(0, vv_max[l]), start = getstart(pm.ref[:branch], l, "vv_start", 1.0))
    return vv
end


""
function variable_cosine_on_off{T}(pm::GenericPowerModel{T})
    cos_min = Dict([(l, -Inf) for l in keys(pm.ref[:branch])])
    cos_max = Dict([(l,  Inf) for l in keys(pm.ref[:branch])])

    for (l, branch) in pm.ref[:branch]
        if branch["angmin"] >= 0
            cos_max[l] = cos(branch["angmin"])
            cos_min[l] = cos(branch["angmax"])
        end
        if branch["angmax"] <= 0
            cos_max[l] = cos(branch["angmax"])
            cos_min[l] = cos(branch["angmin"])
        end
        if branch["angmin"] < 0 && branch["angmax"] > 0
            cos_max[l] = 1.0
            cos_min[l] = min(cos(branch["angmin"]), cos(branch["angmax"]))
        end
    end

    @variable(pm.model, min(0, cos_min[l]) <= cs[l in keys(pm.ref[:branch])] <= max(0, cos_max[l]), start = getstart(pm.ref[:branch], l, "cs_start", 1.0))
    return cs
end

""
function variable_sine_on_off(pm::GenericPowerModel)
    @variable(pm.model, min(0, sin(pm.ref[:branch][l]["angmin"])) <= si[l in keys(pm.ref[:branch])] <= max(0, sin(pm.ref[:branch][l]["angmax"])), start = getstart(pm.ref[:branch], l, "si_start"))
    return si
end


""
function variable_current_magnitude_sqr_on_off{T}(pm::GenericPowerModel{T})
    cm_min = Dict([(l, 0) for l in keys(pm.ref[:branch])])
    cm_max = Dict([(l, (branch["rate_a"]*branch["tap"]/pm.ref[:bus][branch["f_bus"]]["vmin"])^2) for (l, branch) in pm.ref[:branch]])

    @variable(pm.model, cm_min[l] <= cm[l in keys(pm.ref[:branch])] <= cm_max[l], start = getstart(pm.ref[:branch], l, "cm_start"))
    return cm
end


""
function constraint_voltage_on_off(pm::QCWRPowerModel)
    v = getindex(pm.model, :v)
    t = getindex(pm.model, :t)
    v_from = getindex(pm.model, :v_from)
    v_to = getindex(pm.model, :v_to)

    td = getindex(pm.model, :td)
    si = getindex(pm.model, :si)
    cs = getindex(pm.model, :cs)
    vv = getindex(pm.model, :vv)

    w = getindex(pm.model, :w)
    w_from = getindex(pm.model, :w_from)
    w_to = getindex(pm.model, :w_to)

    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)

    z = getindex(pm.model, :line_z)

    td_lb = pm.ref[:off_angmin]
    td_ub = pm.ref[:off_angmax]
    td_max = max(abs(td_lb), abs(td_ub))

    #cs = Set()
    for (i,b) in pm.ref[:bus]
        cs1 = relaxation_sqr(pm.model, v[i], w[i])
        #cs = union(cs, cs1)
    end

    cs1 = constraint_voltage_magnitude_from_on_off(pm) # bounds on v_from
    cs2 = constraint_voltage_magnitude_to_on_off(pm) # bounds on v_to
    cs3 = constraint_voltage_magnitude_sqr_from_on_off(pm) # bounds on w_from
    cs4 = constraint_voltage_magnitude_sqr_to_on_off(pm) # bounds on w_to
    cs5 = constraint_voltage_product_on_off(pm) # bounds on wr, wi
    #cs = union(cs, cs1, cs2, cs3, cs4, cs5)

    for (l,branch) in pm.ref[:branch]
        i = branch["f_bus"]
        j = branch["t_bus"]

        c1 = @constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        c2 = @constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))
        #cs = union(cs, Set([c1, c2]))

        cs1 = relaxation_sin_on_off(pm.model, td[l], si[l], z[l], td_max)
        cs2 = relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)
        cs3 = relaxation_product_on_off(pm.model, v_from[i], v_to[j], vv[l], z[l])
        cs4 = relaxation_product_on_off(pm.model, vv[l], cs[l], wr[l], z[l])
        cs5 = relaxation_product_on_off(pm.model, vv[l], si[l], wi[l], z[l])
        #const_set = union(const_set, cs1, cs2, cs3, cs4, cs5)

        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])

        #cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        cs6 = relaxation_equality_on_off(pm.model, v[i], v_from[l], z[l])
        cs7 = relaxation_equality_on_off(pm.model, v[j], v_to[l], z[l])
        cs8 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        cs9 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        #cs = union(cs, cs6, cs7, cs8, cs9)

        # to prevent this constraint from being posted on multiple parallel lines
        # TODO needs on/off variant
        cs1 = constraint_power_magnitude_sqr_on_off(pm, branch)
        cs2 = constraint_power_magnitude_link_on_off(pm, branch) # different index set
        #cs = union(cs, cs1, cs2)
    end

    return Set()
end


"`p[arc_from]^2 + q[arc_from]^2 <= w[f_bus]/tm*cm[i]`"
function constraint_power_magnitude_sqr_on_off(pm::QCWRPowerModel, i, f_bus, arc_from, tm)
    w = getindex(pm.model, :w)[f_bus]
    p_fr = getindex(pm.model, :p)[arc_from]
    q_fr = getindex(pm.model, :q)[arc_from]
    cm = getindex(pm.model, :cm)[i]
    z = getindex(pm.model, :line_z)[i]

    # TODO see if there is a way to leverage relaxation_complex_product_on_off here
    w_ub = getupperbound(w)
    cm_ub = getupperbound(cm)
    z_ub = getupperbound(z)

    c1 = @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm*z_ub/tm)
    c2 = @constraint(pm.model, p_fr^2 + q_fr^2 <= w_ub*cm*z/tm)
    c3 = @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm_ub*z/tm)

    return Set([c1, c2, c3])
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link_on_off(pm::QCWRPowerModel, i, arc_from, g, b, c, tr, ti, tm)
    w_fr = getindex(pm.model, :w_from)[i]
    w_to = getindex(pm.model, :w_to)[i]
    q_fr = getindex(pm.model, :q)[arc_from]
    wr = getindex(pm.model, :wr)[i]
    wi = getindex(pm.model, :wi)[i]
    cm = getindex(pm.model, :cm)[i]

    c = @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
    return Set([c])
end
