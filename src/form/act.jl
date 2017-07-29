### W-Theta form non-convex AC equations

export 
    ACTPowerModel, StandardACTForm

""
@compat abstract type AbstractACTForm <: AbstractPowerFormulation end

""
@compat abstract type StandardACTForm <: AbstractACTForm end

""
const ACTPowerModel = GenericPowerModel{StandardACTForm}

"default AC constructor"
ACTPowerModel(data::Dict{String,Any}; kwargs...) = 
    GenericPowerModel(data, StandardACTForm; kwargs...)

""
function variable_voltage{T <: AbstractACTForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_voltage{T <: StandardACTForm}(pm::GenericPowerModel{T})
    t = getindex(pm.model, :t)
    w = getindex(pm.model, :w)
    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)

    for (i,j) in keys(pm.ref[:buspairs])
        @NLconstraint(pm.model, wr[(i,j)]^2 + wi[(i,j)]^2 == w[i]*w[j])
        @NLconstraint(pm.model, wi[(i,j)]/wr[(i,j)] == tan(t[i] - t[j]))
    end
end

"`t[ref_bus] == 0`"
constraint_theta_ref{T <: AbstractACTForm}(pm::GenericPowerModel{T}, ref_bus::Int) =
    Set([@constraint(pm.model, getindex(pm.model, :t)[ref_bus] == 0)])


function constraint_voltage_magnitude_setpoint{T <: AbstractACTForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
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


"""
"""
function constraint_kcl_shunt{T <: AbstractACTForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    w = getindex(pm.model, :w)[i]
    p = getindex(pm.model, :p)
    q = getindex(pm.model, :q)
    pg = getindex(pm.model, :pg)
    qg = getindex(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c1, c2])
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from{T <: AbstractACTForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
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
"""
function constraint_ohms_yt_to{T <: AbstractACTForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
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
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_phase_angle_difference{T <: AbstractACTForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax)
    c2 = @constraint(pm.model, t_fr - t_to >= angmin)
    return Set([c1, c2])
end

""
function add_bus_voltage_setpoint{T <: AbstractACTForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end
