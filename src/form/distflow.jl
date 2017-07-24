export
    SOCDistflowPowerModel, SOCDistflowForm

""
@compat abstract type AbstractDistflowForm <: AbstractPowerFormulation end

""
@compat abstract type SOCDistflowForm <: AbstractDistflowForm end

""
const SOCDistflowPowerModel = GenericPowerModel{SOCDistflowForm}

"default SOC constructor"
SOCDistflowPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SOCDistflowForm; kwargs...)

""
function variable_voltage{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
#    variable_voltage_product(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

""
function constraint_voltage{T <: AbstractDistflowForm}(pm::GenericPowerModel{T})
    w = getindex(pm.model, :w)
end

"Do nothing, no way to represent this in these variables"
constraint_theta_ref{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, ref_bus::Int) = Set()

function constraint_voltage_magnitude_setpoint{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
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
function constraint_kcl_shunt{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
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

"Do nothing, this model is symmetric"
constraint_ohms_yt_from{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm) = Set()


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*w[t_bus] + (-g*tr-b*ti)/tm*(wr[f_bus,t_bus]) + (-b*tr+g*ti)/tm*(-wi[f_bus,t_bus])
q[t_idx] == -(b+c/2)*w[t_bus] - (-b*tr+g*ti)/tm*(wr[f_bus,t_bus]) + (-g*tr-b*ti)/tm*(-wi[f_bus,t_bus])
```
"""
function constraint_ohms_yt_to{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    q_fr = getindex(pm.model, :q)[f_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    p_fr = getindex(pm.model, :p)[f_idx]
    p_to = getindex(pm.model, :p)[t_idx]
    w_fr = getindex(pm.model, :w)[f_bus]
    w_to = getindex(pm.model, :w)[t_bus]
    i_sq = getindex(pm.model, :i_sq)[f_idx[1]]
    r = g/(g^2 + b^2)
    x = -b/(g^2 + b^2)
    g_sh = 0
    b_sh = c/2

    c1 = @constraint(pm.model, p_to + p_fr ==  g_sh*w_fr  +r*i_sq + g_sh*w_to)
    c2 = @constraint(pm.model, q_to + p_fr == -b_sh*w_fr + x*i_sq - b_sh*w_to)
    c3 = @constraint(pm.model, (p_fr - g_sh*w_fr)^2 + (q_fr - b_sh*w_fr)^2 <= i_sq*w_fr)
    c4 = @constraint(pm.model, w_to - w_fr == -2*(r*(p_fr - g_sh*w_fr) +x*(q_fr - b_sh*w_fr)) +(r^2+x^2)*i_sq)
    return Set([c1, c2, c3, c4])
end


function constraint_ohms_yt_from_on_off{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    q_fr = getindex(pm.model, :q)[f_idx]
    q_to = getindex(pm.model, :q)[t_idx]
    p_fr = getindex(pm.model, :p)[f_idx]
    p_to = getindex(pm.model, :p)[t_idx]
    w_fr = getindex(pm.model, :w)[f_bus]
    w_to = getindex(pm.model, :w)[t_bus]
    i_sq = getindex(pm.model, :i_sq)[f_idx[1]]
    z = getindex(pm.model, :line_z)

    r = g/(g^2 + b^2)
    x = -b/(g^2 + b^2)
    g_sh = 0
    b_sh = c/2

    c1 = @constraint(pm.model, p_to + p_fr ==  g_sh*w_fr  +r*i_sq + g_sh*w_to)
    c2 = @constraint(pm.model, q_to + p_fr == -b_sh*w_fr + x*i_sq - b_sh*w_to)
    c3 = @constraint(pm.model, (p_fr - g_sh*w_fr)^2 + (q_fr - b_sh*w_fr)^2 <= i_sq*w_fr)
    c4 = @constraint(pm.model, w_to - w_fr == -2*(r*(p_fr - g_sh*w_fr) +x*(q_fr - b_sh*w_fr)) +(r^2+x^2)*i_sq)
    return Set([c1, c2, c3, c4])
end


"""
Creates Ohms constraints for DC Lines (yt post fix indicates that Y and T values are in rectangular form)

```
p_fr + p_to == loss0 + loss1 * p_fr
```
"""
function constraint_ohms_yt_dc{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, br_status, loss0, loss1)
    p_fr = getindex(pm.model, :p_dc)[f_idx]
    p_to = getindex(pm.model, :p_dc)[t_idx]

    c1 = @constraint(pm.model, (1-loss1) * p_fr + (p_to - loss0 * br_status) == 0)
    return Set([c1])
end


""
function add_bus_voltage_setpoint{T <: AbstractDistflowForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end


"Do nothing, this model doesn't have voltage angle variables"
constraint_phase_angle_difference{T <: AbstractDistflowForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax) = Set()
