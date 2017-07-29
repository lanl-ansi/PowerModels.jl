#
# Shared Formulation Definitions
#################################
#
# This is the home of functions that are shared across multiple branches
# of the type hierarchy.  Hence all function in this file should be over 
# union types.
#
# The types defined in this file should not be exported because they exist 
# only to prevent code replication
#
# Note that Union types are discouraged in Julia, 
# https://docs.julialang.org/en/release-0.6/manual/style-guide/#Avoid-strange-type-Unions-1
# and should be used with discretion.
#
# If you are about to add a union type,
# first double check if a different type hierarchy can resolve the issue
# instead.
#

AbstractWRForms = Union{AbstractACTForm, AbstractWRForm}


function constraint_voltage_magnitude_setpoint{T <: AbstractWRForms}(pm::GenericPowerModel{T}, i, vm, epsilon)
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
function constraint_kcl_shunt{T <: AbstractWRForms}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
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
function constraint_ohms_yt_from{T <: AbstractWRForms}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
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
function constraint_ohms_yt_to{T <: AbstractWRForms}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    q_to = getindex(pm.model, :q)[t_idx]
    p_to = getindex(pm.model, :p)[t_idx]
    w_to = getindex(pm.model, :w)[t_bus]
    wr = getindex(pm.model, :wr)[(f_bus, t_bus)]
    wi = getindex(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, p_to == g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

