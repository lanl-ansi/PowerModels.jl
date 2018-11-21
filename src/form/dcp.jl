export
    DCPPowerModel, DCPlosslessForm,
    NFAPowerModel, NFAForm,
    DCPLLPowerModel, StandardDCPLLForm

""
abstract type AbstractDCPForm <: AbstractPowerFormulation end

"active power only formulations where p[(i,j)] = -p[(j,i)]"
abstract type DCPlosslessForm <: AbstractDCPForm end

const StandardDCPForm = DCPlosslessForm

"""
Linearized 'DC' power flow formulation with polar voltage variables.

```
@ARTICLE{4956966,
  author={B. Stott and J. Jardim and O. Alsac},
  journal={IEEE Transactions on Power Systems},
  title={DC Power Flow Revisited},
  year={2009},
  month={Aug},
  volume={24},
  number={3},
  pages={1290-1300},
  doi={10.1109/TPWRS.2009.2021235},
  ISSN={0885-8950}
}
```
"""
const DCPPowerModel = GenericPowerModel{DCPlosslessForm}

"default DC constructor"
DCPPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, DCPlosslessForm; kwargs...)

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
    variable_voltage_angle(pm; kwargs...)
end


"nothing to add, there are no voltage variables on branches"
function variable_voltage_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_generation(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_storage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_branch_flow(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"dc models ignore reactive power flows"
function variable_reactive_dcline_flow(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end


""
function variable_active_branch_flow(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: DCPlosslessForm
    if bounded
        flow_lb, flow_ub = calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)

        var(pm, nw, cnd)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], basename="$(nw)_$(cnd)_p",
            lowerbound = flow_lb[l],
            upperbound = flow_ub[l],
            start = getval(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    else
        var(pm, nw, cnd)[:p] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], basename="$(nw)_$(cnd)_p",
            start = getval(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    end

    # this explicit type erasure is necessary
    p_expr = Dict{Any,Any}([((l,i,j), var(pm, nw, cnd, :p, (l,i,j))) for (l,i,j) in ref(pm, nw, :arcs_from)])
    p_expr = merge(p_expr, Dict(((l,j,i), -1.0*var(pm, nw, cnd, :p, (l,i,j))) for (l,i,j) in ref(pm, nw, :arcs_from)))
    var(pm, nw, cnd)[:p] = p_expr
end

""
function variable_active_branch_flow_ne(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd) where T <: DCPlosslessForm
    var(pm, nw, cnd)[:p_ne] = @variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs_from)], basename="$(nw)_$(cnd)_p_ne",
        lowerbound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upperbound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = getval(ref(pm, nw, :ne_branch, l), "p_start", cnd)
    )

    # this explicit type erasure is necessary
    p_ne_expr = Dict{Any,Any}([((l,i,j), 1.0*var(pm, nw, cnd, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)])
    p_ne_expr = merge(p_ne_expr, Dict(((l,j,i), -1.0*var(pm, nw, cnd, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)))
    var(pm, nw, cnd)[:p_ne] = p_ne_expr
end

"do nothing, this model does not have complex voltage variables"
function constraint_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"do nothing, this model does not have complex voltage variables"
function constraint_voltage_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"do nothing, this model does not have voltage variables"
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel{T}, n::Int, c::Int, i, vm) where T <: AbstractDCPForm
end

"do nothing, this model does not have reactive variables"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel{T}, n::Int, c::Int, i, qg) where T <: AbstractDCPForm
end


"do nothing, this model does not have voltage variables"
function variable_bus_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: DCPlosslessForm
end

""
function constraint_power_balance(pm::GenericPowerModel{T}, n::Int, c::Int, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b) where T <: DCPlosslessForm
    pg = var(pm, n, c, :pg)

    @constraint(pm.model, sum(pg[g] for g in comp_gen_ids) == sum(pd for (i,pd) in values(comp_pd)) + sum(gs*1.0^2 for (i,gs) in values(comp_gs)))
    # omit reactive constraint
end


""
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    pg   = var(pm, n, c, :pg)
    p    = var(pm, n, c, :p)
    p_dc = var(pm, n, c, :p_dc)

    con(pm, n, c, :kcl_p)[i] = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
    # omit reactive constraint
end

""
function constraint_kcl_shunt_storage(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    p = var(pm, n, c, :p)
    pg = var(pm, n, c, :pg)
    ps = var(pm, n, c, :ps)
    p_dc = var(pm, n, c, :p_dc)
    
    con(pm, n, c, :kcl_p)[i] = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
    # omit reactive constraint
end

""
function constraint_kcl_shunt_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPForm
    pg   = var(pm, n, c, :pg)
    p    = var(pm, n, c, :p)
    p_ne = var(pm, n, c, :p_ne)
    p_dc = var(pm, n, c, :p_dc)

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
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

    @constraint(pm.model, p_fr == -b*(va_fr - va_to))
    # omit reactive constraint
end

"Do nothing, this model is symmetric"
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractDCPForm
end

function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
    p_fr  = var(pm, n, c, :p_ne, f_idx)
    va_fr = var(pm, n, c,   :va, f_bus)
    va_to = var(pm, n, c,   :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"Do nothing, this model is symmetric"
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
end

"`-rate_a <= p[f_idx] <= rate_a`"
function constraint_thermal_limit_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = con(pm, n, c, :sm_fr)[f_idx[1]] = var(pm, n, c, :p, f_idx)
    getlowerbound(p_fr) < -rate_a && setlowerbound(p_fr, -rate_a)
    getupperbound(p_fr) >  rate_a && setupperbound(p_fr,  rate_a)
end

"Do nothing, this model is symmetric"
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, c::Int, t_idx, rate_a) where T <: AbstractDCPForm
end

function constraint_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, c_rating_a) where T <: AbstractDCPForm
    p_fr = var(pm, n, c, :p, f_idx)

    getlowerbound(p_fr) < -c_rating_a && setlowerbound(p_fr, -c_rating_a)
    getupperbound(p_fr) >  c_rating_a && setupperbound(p_fr,  c_rating_a)
end


""
function constraint_storage_thermal_limit(pm::GenericPowerModel{T}, n::Int, c::Int, i, rating) where T <: AbstractDCPForm
    ps = var(pm, n, c, :ps, i)

    getlowerbound(ps) < -rating && setlowerbound(ps, -rating)
    getupperbound(ps) >  rating && setupperbound(ps,  rating)
end

""
function constraint_storage_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus, rating) where T <: AbstractDCPForm
    ps = var(pm, n, c, :ps, i)

    getlowerbound(ps) < -rating && setlowerbound(ps, -rating)
    getupperbound(ps) >  rating && setupperbound(ps,  rating)
end

""
function constraint_storage_loss(pm::GenericPowerModel{T}, n::Int, i, bus, r, x, standby_loss) where T <: AbstractDCPForm
    ps = var(pm, n, pm.ccnd, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    @constraint(pm.model, ps + (sd - sc) == standby_loss + r*ps^2)
end


""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractDCPForm
    add_setpoint_fixed(sol, pm, "bus", "vm"; default_value = (item) -> 1)
    add_setpoint(sol, pm, "bus", "va", :va)
end

""
function add_storage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractDCPForm
    if haskey(pm.data, "storage") || (InfrastructureModels.ismultinetwork(pm.data) && haskey(pm.data["nw"]["$(pm.cnw)"], "storage"))
        add_setpoint(sol, pm, "storage", "ps", :ps)
        add_setpoint_fixed(sol, pm, "storage", "qs")
        add_setpoint(sol, pm, "storage", "se", :se, conductorless=true)
    end
end


""
function variable_voltage_on_off(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
    variable_voltage_angle(pm; kwargs...)
end

"do nothing, this model does not have complex voltage variables"
function constraint_voltage_on_off(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDCPForm
end

"`-b*(t[f_bus] - t[t_bus] + vad_min*(1-branch_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + vad_max*(1-branch_z[i]))`"
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"Do nothing, this model is symmetric"
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPForm
end

"""
Generic on/off thermal limit constraint

```
-rate_a*branch_z[i] <= p[f_idx] <=  rate_a*branch_z[i]
```
"""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = var(pm, n, c, :p, f_idx)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, p_fr <=  rate_a*z)
    @constraint(pm.model, p_fr >= -rate_a*z)
end

"""
Generic on/off thermal limit constraint

```
-rate_a*branch_ne[i] <= p_ne[f_idx] <=  rate_a*branch_ne[i]
```
"""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = var(pm, n, c, :p_ne, f_idx)
    z = var(pm, n, c, :branch_ne, i)

    @constraint(pm.model, p_fr <=  rate_a*z)
    @constraint(pm.model, p_fr >= -rate_a*z)
end

"nothing to do, from handles both sides"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: AbstractDCPForm
end

"nothing to do, from handles both sides"
function constraint_thermal_limit_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: AbstractDCPForm
end

"`angmin*branch_z[i] + vad_min*(1-branch_z[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_z[i] + vad_max*(1-branch_z[i])`"
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractDCPForm
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    @constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

"`angmin*branch_ne[i] + vad_min*(1-branch_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_ne[i] + vad_max*(1-branch_ne[i])`"
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractDCPForm
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    @constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    @constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end




abstract type NFAForm <: DCPlosslessForm end

"""
The an active power only network flow approximation, also known as the transportation model.
"""
const NFAPowerModel = GenericPowerModel{NFAForm}

"default DC constructor"
NFAPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, NFAForm; kwargs...)

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

""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: NFAForm
    add_setpoint_fixed(sol, pm, "bus", "vm")
    add_setpoint_fixed(sol, pm, "bus", "va")
end

""
function add_generator_power_setpoint(sol, pm::GenericPowerModel{T}) where T <: NFAForm
    add_setpoint(sol, pm, "gen", "pg", :pg)
    add_setpoint_fixed(sol, pm, "gen", "qg")
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
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractDCPLLForm
    pg   = var(pm, n, c, :pg)
    p    = var(pm, n, c, :p)
    p_dc = var(pm, n, c, :p_dc)

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*1.0^2)
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractDCPLLForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    p_to  = var(pm, n, c,  :p, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    @constraint(pm.model, p_fr == -b*(va_fr - va_to))
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractDCPLLForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    p_to  = var(pm, n, c,  :p, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)

    r = g/(g^2 + b^2)
    @constraint(pm.model, p_fr + p_to >= r*(p_fr^2))
end

"""
"""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    p_to  = var(pm, n, c,  :p, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"""
"""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr  = var(pm, n, c,  :p, f_idx)
    p_to  = var(pm, n, c,  :p, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_z, i)

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    @constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    @constraint(pm.model, p_fr + p_to >= 0)
end


"""
"""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = var(pm, n, c, :p_ne, f_idx)
    p_to = var(pm, n, c, :p_ne, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    @constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    @constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end

"""
"""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractDCPLLForm
    p_fr = var(pm, n, c, :p_ne, f_idx)
    p_to = var(pm, n, c, :p_ne, t_idx)
    va_fr = var(pm, n, c, :va, f_bus)
    va_to = var(pm, n, c, :va, t_bus)
    z = var(pm, n, c, :branch_ne, i)

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    @constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    @constraint(pm.model, p_fr + p_to >= 0)
end


"`-rate_a*branch_z[i] <= p[t_idx] <= rate_a*branch_z[i]`"
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: AbstractDCPLLForm
    p_to = var(pm, n, c, :p, t_idx)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, p_to <=  rate_a*z)
    @constraint(pm.model, p_to >= -rate_a*z)
end
