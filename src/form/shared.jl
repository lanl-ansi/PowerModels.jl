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
AbstractBIMForms = Union{AbstractACPForm, AbstractACTForm, AbstractDCPForm, AbstractWRForm, AbstractWRMForm}
AbstractBFMForms = Union{AbstractDFForm}

"compatibility of BFM formulations with opf problem type (implicit BIM)"
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, i::Int) where T <: AbstractBFMForms
    warn(LOGGER, "you're using the BIM problem type to solve a BFM formulation, is this really what you want to accomplish?")
    constraint_power_flow_losses(pm, i)
    constraint_kvl(pm, i)
    constraint_series_current(pm, i)
end

"compatibility of BFM formulations with opf problem type (implicit BIM)"
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, i::Int) where T <: AbstractBFMForms
end

"compatibility of BIM formulations with opf_bf problem type"
function constraint_power_flow_losses(pm::GenericPowerModel{T}, i::Int) where {T <: AbstractBIMForms}
    warn(LOGGER, "you're using the BFM problem type to solve a BIM formulation, is this really what you want to accomplish?")
    constraint_ohms_yt_from(pm, i)
    constraint_ohms_yt_to(pm, i)
end

"compatibility of BIM formulations with opf_bf problem type"
function constraint_kvl(pm::GenericPowerModel{T}, i::Int) where {T <: AbstractBIMForms}
end

"compatibility of BIM formulations with opf_bf problem type"
function constraint_series_current(pm::GenericPowerModel{T}, i::Int) where {T <: AbstractBIMForms}
end

"compatibility of BIM formulations with opf_bf problem type"
function constraint_kvl(pm::GenericPowerModel{T}, i::Int) where {T <: AbstractBIMForms}
end

AbstractWRForms = Union{AbstractACTForm, AbstractWRForm, AbstractWRMForm}
AbstractWForms = Union{AbstractWRForms, AbstractDFForm}
AbstractPForms = Union{AbstractACPForm, AbstractACTForm, AbstractDCPForm}

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, i::Int) where T <: AbstractPForms
    @constraint(pm.model, pm.var[:nw][n][:va][i] == 0)
end

"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, arc_from, f_bus, t_bus, angmin, angmax) where T <: AbstractPForms
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]

    @constraint(pm.model, va_fr - va_to <= angmax)
    @constraint(pm.model, va_fr - va_to >= angmin)
end


function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel{T}, n::Int, i, vm) where T <: AbstractWForms
    w = pm.var[:nw][n][:w][i]

    @constraint(pm.model, w == vm^2)
end

"Do nothing, no way to represent this in these variables"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, ref_bus::Int) where T <: AbstractWForms
end


"""
```
sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w[i]
sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w[i]
```
"""
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs) where T <: AbstractWForms
    w = pm.var[:nw][n][:w][i]
    pg = pm.var[:nw][n][:pg]
    qg = pm.var[:nw][n][:qg]
    p = pm.var[:nw][n][:p]
    q = pm.var[:nw][n][:q]
    p_dc = pm.var[:nw][n][:p_dc]
    q_dc = pm.var[:nw][n][:q_dc]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
end


"""
```
sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w[i]
sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w[i]
```
"""
function constraint_kcl_shunt_ne(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, pd, qd, gs, bs) where T <: AbstractWRForms
    w = pm.var[:nw][n][:w][i]
    pg = pm.var[:nw][n][:pg]
    qg = pm.var[:nw][n][:qg]
    p = pm.var[:nw][n][:p]
    q = pm.var[:nw][n][:q]
    p_ne = pm.var[:nw][n][:p_ne]
    q_ne = pm.var[:nw][n][:q_ne]
    p_dc = pm.var[:nw][n][:p_dc]
    q_dc = pm.var[:nw][n][:q_dc]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm) where T <: AbstractWRForms
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    w_fr = pm.var[:nw][n][:w][f_bus]
    wr = pm.var[:nw][n][:wr][(f_bus, t_bus)]
    wi = pm.var[:nw][n][:wi][(f_bus, t_bus)]

    @constraint(pm.model, p_fr ==        g/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    @constraint(pm.model, q_fr == -(b+c/2)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm) where T <: AbstractWRForms
    q_to = pm.var[:nw][n][:q][t_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    w_to = pm.var[:nw][n][:w][t_bus]
    wr = pm.var[:nw][n][:wr][(f_bus, t_bus)]
    wi = pm.var[:nw][n][:wi][(f_bus, t_bus)]

    @constraint(pm.model, p_to ==        g*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end


""
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, arc_from, f_bus, t_bus, angmin, angmax) where T <: AbstractWRForms
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]
    wr = pm.var[:nw][n][:wr][(f_bus, t_bus)]
    wi = pm.var[:nw][n][:wi][(f_bus, t_bus)]

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)
    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end


""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractWForms
    add_setpoint(sol, pm, "bus", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "va", :va; default_value = 0)
end
