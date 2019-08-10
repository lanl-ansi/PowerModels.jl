### simple active power only approximations (e.g. DC Power Flow)


######## AbstractDCPForm Models (has va but assumes vm is 1.0) ########

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
    variable_voltage_angle(pm; kwargs...)
end

"nothing to add, there are no voltage variables on branches"
function variable_voltage_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"do nothing, this model does not have complex voltage variables"
function constraint_model_voltage_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"do nothing, this model does not have voltage variables"
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel{T}, n::Int, c::Int, i, vm) where T <: AbstractDCPForm
end


"do nothing, this model does not have voltage variables"
function variable_bus_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end


""
function constraint_power_balance_shunt(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    pg   = var(pm, n, c, :pg)
    p    = var(pm, n, c, :p)
    p_dc = var(pm, n, c, :p_dc)

    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
    # omit reactive constraint
end

""
function constraint_power_balance_shunt_storage(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    p = var(pm, n, c, :p)
    pg = var(pm, n, c, :pg)
    ps = var(pm, n, c, :ps)
    p_dc = var(pm, n, c, :p_dc)

    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
    # omit reactive constraint
end

""
function constraint_power_balance_shunt_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    pg   = var(pm, n, c, :pg)
    p    = var(pm, n, c, :p)
    p_ne = var(pm, n, c, :p_ne)
    p_dc = var(pm, n, c, :p_dc)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == -b*(t[f_bus] - t[t_bus])
```
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractDCPForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    JuMP.@constraint(pm.model, p_fr == -b*(va_fr - va_to))
    # omit reactive constraint
end

function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
    p_fr  = var(pm, n, c, :p_ne, f_idx)
    va_fr = var(pm, n, c,   :va, f_bus)
    va_to = var(pm, n, c,   :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    JuMP.@constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    JuMP.@constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end



""
function add_setpoint_bus_voltage!(sol, pm::GenericPowerModel{T}) where T <: AbstractDCPForm
    add_setpoint_fixed!(sol, pm, "bus", "vm"; default_value = (item) -> 1)
    add_setpoint!(sol, pm, "bus", "va", :va, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"])
end


""
function variable_voltage_on_off(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
    variable_voltage_angle(pm; kwargs...)
end

"do nothing, this model does not have complex voltage variables"
function constraint_model_voltage_on_off(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"`-b*(t[f_bus] - t[t_bus] + vad_min*(1-branch_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + vad_max*(1-branch_z[i]))`"
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    JuMP.@constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    JuMP.@constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end


"`angmin*branch_z[i] + vad_min*(1-branch_z[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_z[i] + vad_max*(1-branch_z[i])`"
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractDCPForm
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

"`angmin*branch_ne[i] + vad_min*(1-branch_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_ne[i] + vad_max*(1-branch_ne[i])`"
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractDCPForm
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

""
function constraint_storage_on_off(pm::GenericPowerModel{T}, n::Int, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub) where T <: DCPlosslessForm
    z_storage = var(pm, n, :z_storage, i)
    ps = var(pm, n, pm.ccnd, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    JuMP.@constraint(pm.model, ps <= z_storage*pmax)
    JuMP.@constraint(pm.model, ps >= z_storage*pmin)
    JuMP.@constraint(pm.model, sc <= z_storage*charge_ub)
    JuMP.@constraint(pm.model, sd <= z_storage*discharge_ub)
end

""
function constraint_storage_loss(pm::GenericPowerModel{T}, n::Int, i, bus, r, x, standby_loss) where T <: DCPlosslessForm
    ps = var(pm, n, pm.ccnd, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    JuMP.@constraint(pm.model, ps == sc - sd)
end









######## Lossless Models ########

""
function variable_active_branch_flow(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: DCPlosslessForm
    if bounded
        flow_lb, flow_ub = ref_calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)
        p = var(pm, nw, cnd)[:p] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_$(cnd)_p",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = comp_start_value(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    else
        p = var(pm, nw, cnd)[:p] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_$(cnd)_p",
            start = comp_start_value(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    end

    for (l,branch) in ref(pm, nw, :branch)
        if haskey(branch, "pf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(p[f_idx], branch["pf_start"])
        end
    end

    # this explicit type erasure is necessary
    p_expr = Dict{Any,Any}( ((l,i,j), p[(l,i,j)]) for (l,i,j) in ref(pm, nw, :arcs_from) )
    p_expr = merge(p_expr, Dict( ((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in ref(pm, nw, :arcs_from)))
    var(pm, nw, cnd)[:p] = p_expr
end

""
function variable_active_branch_flow_ne(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd) where T <: DCPlosslessForm
    var(pm, nw, cnd)[:p_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs_from)], base_name="$(nw)_$(cnd)_p_ne",
        lower_bound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upper_bound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "p_start", cnd)
    )

    # this explicit type erasure is necessary
    p_ne_expr = Dict{Any,Any}([((l,i,j), 1.0*var(pm, nw, cnd, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)])
    p_ne_expr = merge(p_ne_expr, Dict(((l,j,i), -1.0*var(pm, nw, cnd, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)))
    var(pm, nw, cnd)[:p_ne] = p_ne_expr
end

""
function constraint_network_power_balance(pm::GenericPowerModel{T}, n::Int, c::Int, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b) where T <: DCPlosslessForm
    pg = var(pm, n, c, :pg)

    JuMP.@constraint(pm.model, sum(pg[g] for g in comp_gen_ids) == sum(pd for (i,pd) in values(comp_pd)) + sum(gs*1.0^2 for (i,gs) in values(comp_gs)))
    # omit reactive constraint
end

"nothing to do, this model is symetric"
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, c::Int, t_idx, rate_a) where T <: DCPlosslessForm
    l,i,j = t_idx
    p_fr = var(pm, n, c, :p, (l,j,i))
    con(pm, n, c, :sm_to)[l] = JuMP.UpperBoundRef(p_fr)
end

"nothing to do, this model is symetric"
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: DCPlosslessForm
end

"nothing to do, this model is symetric"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: DCPlosslessForm
end

"nothing to do, this model is symetric"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: DCPlosslessForm
end

"nothing to do, this model is symetric"
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: DCPlosslessForm
end

"nothing to do, this model is symetric"
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: DCPlosslessForm
end







######## Network Flow Approximation ########


"nothing to do, no voltage angle variables"
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: NFAForm
end

"nothing to do, no voltage angle variables"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int) where T <: NFAForm
end

"nothing to do, no voltage angle variables"
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax) where T <: NFAForm
end

"nothing to do, no voltage angle variables"
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: NFAForm
end

#""
#function add_setpoint_bus_voltage!(sol, pm::GenericPowerModel{T}) where T <: NFAForm
#    add_setpoint_fixed!(sol, pm, "bus", "vm")
#    add_setpoint_fixed!(sol, pm, "bus", "va")
#end







######## DC with Line Losses ########

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractDCPLLForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    p_to  = var(pm, n, c,  :p, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    r = g/(g^2 + b^2)
    JuMP.@constraint(pm.model, p_fr + p_to >= r*(p_fr^2))
end

""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    p_to  = var(pm, n, c,  :p, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    JuMP.@constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    JuMP.@constraint(pm.model, p_fr + p_to >= 0)
end

""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = var(pm, n, c, :p_ne, f_idx)
    p_to = var(pm, n, c, :p_ne, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    JuMP.@constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    JuMP.@constraint(pm.model, p_fr + p_to >= 0)
end
