### simple active power only approximations (e.g. DC Power Flow)


######## AbstractDCPForm Models (has va but assumes vm is 1.0) ########

""
function variable_bus_voltage(pm::AbstractDCPModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)
end

""
function variable_bus_voltage_magnitude(pm::AbstractDCPModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    report && sol_component_fixed(pm, nw, :bus, :vm, ids(pm, nw, :bus), 1.0)
end

""
function sol_data_model!(pm::AbstractDCPModel, solution::Dict)
    # nothing to do, this is in the data model space by default
end


"nothing to add, there are no voltage variables on branches"
function variable_ne_branch_voltage(pm::AbstractDCPModel; kwargs...)
end

"do nothing, this model does not have complex voltage variables"
function constraint_ne_model_voltage(pm::AbstractDCPModel; kwargs...)
end

"do nothing, this model does not have voltage variables"
function constraint_voltage_magnitude_setpoint(pm::AbstractDCPModel, n::Int, i, vm)
end


"do nothing, this model does not have voltage variables"
function variable_bus_voltage_magnitude_only(pm::AbstractDCPModel; kwargs...)
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == -b*(t[f_bus] - t[t_bus])
```
"""
function constraint_ohms_yt_from(pm::AbstractDCPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr  = var(pm, n,  :p, f_idx)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    JuMP.@constraint(pm.model, p_fr == -b*(va_fr - va_to))
    # omit reactive constraint
end

""
function expression_branch_power_ohms_yt_from(pm::AbstractDCPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    var(pm, n, :p)[f_idx] = -b*(va_fr - va_to)
    # omit reactive constraint
end

""
function expression_branch_power_ohms_yt_to(pm::AbstractDCPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    var(pm, n, :p)[t_idx] = -b*(va_to - va_fr)
    # omit reactive constraint
end

function constraint_ne_ohms_yt_from(pm::AbstractDCPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr  = var(pm, n, :p_ne, f_idx)
    va_fr = var(pm, n,   :va, f_bus)
    va_to = var(pm, n,   :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
    JuMP.@constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
end


function constraint_ne_ohms_yt_from(pm::AbstractDCMPPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr  = var(pm, n, :p_ne, f_idx)
    va_fr = var(pm, n,   :va, f_bus)
    va_to = var(pm, n,   :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    # get b only based on br_x (b = -1 / br_x) and take tap + shift into account
    x = -b / (g^2 + b^2)
    ta = atan(ti, tr)

    JuMP.@constraint(pm.model, p_fr <= (va_fr - va_to - ta + vad_max*(1-z)) / (x*tm))
    JuMP.@constraint(pm.model, p_fr >= (va_fr - va_to - ta + vad_min*(1-z)) / (x*tm))
end


""
function expression_branch_power_ohms_yt_from(pm::AbstractDCMPPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    # get b only based on br_x (b = -1 / br_x) and take tap + shift into account
    x = -b / (g^2 + b^2)
    ta = atan(ti, tr)
    var(pm, n, :p)[f_idx] = (va_fr - va_to - ta)/(x*tm)
    # omit reactive constraint
end

""
function expression_branch_power_ohms_yt_to(pm::AbstractDCMPPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    # get b only based on br_x (b = -1 / br_x) and take tap + shift into account
    x = -b / (g^2 + b^2)
    ta = atan(ti, tr)
    var(pm, n, :p)[t_idx] = -(va_fr - va_to - ta)/(x*tm)
    # omit reactive constraint
end

""
function constraint_ohms_yt_from(pm::AbstractDCMPPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr  = var(pm, n,  :p, f_idx)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    # get b only based on br_x (b = -1 / br_x) and take tap + shift into account
    x = -b / (g^2 + b^2)
    ta = atan(ti, tr)
    JuMP.@constraint(pm.model, p_fr == (va_fr - va_to - ta)/(x*tm))
end

""
function constraint_switch_state_closed(pm::AbstractDCPModel, n::Int, f_bus, t_bus)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    JuMP.@constraint(pm.model, va_fr == va_to)
end

""
function constraint_switch_voltage_on_off(pm::AbstractDCPModel, n::Int, i, f_bus, t_bus, vad_min, vad_max)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :z_switch, i)

    JuMP.@constraint(pm.model, 0 <= (va_fr - va_to) + vad_max*(1-z))
    JuMP.@constraint(pm.model, 0 >= (va_fr - va_to) + vad_min*(1-z))
end


""
function variable_bus_voltage_on_off(pm::AbstractDCPModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
end

"do nothing, this model does not have complex voltage variables"
function constraint_model_voltage_on_off(pm::AbstractDCPModel; kwargs...)
end

"`-b*(t[f_bus] - t[t_bus] + vad_min*(1-z_branch[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + vad_max*(1-z_branch[i]))`"
function constraint_ohms_yt_from_on_off(pm::AbstractDCPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr  = var(pm, n,  :p, f_idx)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    if b <= 0
        JuMP.@constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*(1-z)) )
        JuMP.@constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*(1-z)) )
    else # account for bound reversal when b is positive
        JuMP.@constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_max*(1-z)) )
        JuMP.@constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_min*(1-z)) )
    end
end


"`angmin*z_branch[i] + vad_min*(1-z_branch[i]) <= t[f_bus] - t[t_bus] <= angmax*z_branch[i] + vad_max*(1-z_branch[i])`"
function constraint_voltage_angle_difference_on_off(pm::AbstractDCPModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end

"`angmin*branch_ne[i] + vad_min*(1-branch_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*branch_ne[i] + vad_max*(1-branch_ne[i])`"
function constraint_ne_voltage_angle_difference(pm::AbstractDCPModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*(1-z))
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*(1-z))
end


""
function expression_bus_voltage(pm::AbstractPowerModel, n::Int, i, am::AdmittanceMatrix)
    ref_bus = collect(ids(pm, n, :ref_buses))[1]
    inj_factors = injection_factors_va(am, ref_bus, i)
    inj_p = var(pm, n, :inj_p)

    var(pm, n, :va)[i] = JuMP.@expression(pm.model, sum(f*inj_p[j] for (j,f) in inj_factors))
end

""
function expression_bus_voltage(pm::AbstractPowerModel, n::Int, i, am::AdmittanceMatrixInverse)
    inj_factors = injection_factors_va(am, i)
    inj_p = var(pm, n, :inj_p)

    var(pm, n, :va)[i] = JuMP.@expression(pm.model, sum(f*inj_p[j] for (j,f) in inj_factors))
end


######## Lossless Models ########

""
function variable_branch_power_real(pm::AbstractAPLossLessModels; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    p = var(pm, nw)[:p] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_p",
        start = comp_start_value(ref(pm, nw, :branch, l), "p_start")
    )

    if bounded
        flow_lb, flow_ub = ref_calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus))

        for arc in ref(pm, nw, :arcs_from)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(p[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(p[arc], flow_ub[l])
            end
        end
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
    var(pm, nw)[:p] = p_expr

    report && sol_component_value_edge(pm, nw, :branch, :pf, :pt, ref(pm, nw, :arcs_from), ref(pm, nw, :arcs_to), p_expr)
end

""
function variable_ne_branch_power_real(pm::AbstractAPLossLessModels; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    p_ne = var(pm, nw)[:p_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs_from)], base_name="$(nw)_p_ne",
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "p_start")
    )

    if bounded
        ne_branch = ref(pm, nw, :ne_branch)
        for (l,i,j) in ref(pm, nw, :ne_arcs_from)
            JuMP.set_lower_bound(p_ne[(l,i,j)], -ne_branch[l]["rate_a"])
            JuMP.set_upper_bound(p_ne[(l,i,j)],  ne_branch[l]["rate_a"])
        end
    end

    # this explicit type erasure is necessary
    p_ne_expr = Dict{Any,Any}([((l,i,j), 1.0*var(pm, nw, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)])
    p_ne_expr = merge(p_ne_expr, Dict(((l,j,i), -1.0*var(pm, nw, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)))
    var(pm, nw)[:p_ne] = p_ne_expr

    report && sol_component_value_edge(pm, nw, :ne_branch, :pf, :pt, ref(pm, nw, :ne_arcs_from), ref(pm, nw, :ne_arcs_to), p_ne_expr)
end

""
function constraint_network_power_balance(pm::AbstractAPLossLessModels, n::Int, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b)
    pg = var(pm, n, :pg)

    JuMP.@constraint(pm.model, sum(pg[g] for g in comp_gen_ids) == sum(pd for (i,pd) in values(comp_pd)) + sum(gs*1.0^2 for (i,gs) in values(comp_gs)))
    # omit reactive constraint
end

"nothing to do, this model is symetric"
function constraint_thermal_limit_to(pm::AbstractAPLossLessModels, n::Int, t_idx, rate_a)
    # NOTE correct?
    l,i,j = t_idx
    p_fr = var(pm, n, :p, (l,j,i))
    if isa(p_fr, JuMP.VariableRef) && JuMP.has_upper_bound(p_fr)
        cstr = JuMP.UpperBoundRef(p_fr)
    else
        p_to = var(pm, n, :p, t_idx)
        cstr = JuMP.@constraint(pm.model, p_to <= rate_a)
    end

    if _IM.report_duals(pm)
        sol(pm, n, :branch, t_idx[1])[:mu_sm_to] = cstr
    end
end

"nothing to do, this model is symetric"
function constraint_ohms_yt_to_on_off(pm::AbstractAPLossLessModels, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end

"nothing to do, this model is symetric"
function constraint_thermal_limit_to_on_off(pm::AbstractAPLossLessModels, n::Int, i, t_idx, rate_a)
end

"nothing to do, this model is symetric"
function constraint_ne_thermal_limit_to(pm::AbstractAPLossLessModels, n::Int, i, t_idx, rate_a)
end

"nothing to do, this model is symetric"
function constraint_ohms_yt_to(pm::AbstractAPLossLessModels, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end

"nothing to do, this model is symetric"
function constraint_ne_ohms_yt_to(pm::AbstractAPLossLessModels, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end

""
function constraint_storage_on_off(pm::AbstractAPLossLessModels, n::Int, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub)
    z_storage = var(pm, n, :z_storage, i)
    ps = var(pm, n, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    JuMP.@constraint(pm.model, ps <= z_storage*pmax)
    JuMP.@constraint(pm.model, ps >= z_storage*pmin)
    JuMP.@constraint(pm.model, sc <= z_storage*charge_ub)
    JuMP.@constraint(pm.model, sd <= z_storage*discharge_ub)
end

""
function constraint_storage_losses(pm::AbstractAPLossLessModels, n::Int, i, bus, r, x, p_loss, q_loss; conductors=[1])
    ps = var(pm, n, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    JuMP.@constraint(pm.model, sum(ps[c] for c in conductors) + (sd - sc) == p_loss)
end



######## Network Flow Approximation ########


"nothing to do, no voltage angle variables"
function variable_bus_voltage(pm::AbstractNFAModel; kwargs...)
end

"nothing to do, no voltage angle variables"
function constraint_theta_ref(pm::AbstractNFAModel, n::Int, i::Int)
end

"nothing to do, no voltage angle variables"
function constraint_voltage_angle_difference(pm::AbstractNFAModel, n::Int, f_idx, angmin, angmax)
end

"nothing to do, no voltage angle variables"
function constraint_ohms_yt_from(pm::AbstractNFAModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end





######## DC with Line Losses ########

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::AbstractDCPLLModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    p_fr  = var(pm, n,  :p, f_idx)
    p_to  = var(pm, n,  :p, t_idx)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)

    r = g/(g^2 + b^2)
    JuMP.@constraint(pm.model, p_fr + p_to >= r*(p_fr^2))
end

""
function constraint_ohms_yt_to_on_off(pm::AbstractDCPLLModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_fr  = var(pm, n,  :p, f_idx)
    p_to  = var(pm, n,  :p, t_idx)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :z_branch, i)

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    JuMP.@constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    JuMP.@constraint(pm.model, p_fr + p_to >= 0)
end

""
function constraint_ne_ohms_yt_to(pm::AbstractDCPLLModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n, :p_ne, f_idx)
    p_to = var(pm, n, :p_ne, t_idx)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    z = var(pm, n, :branch_ne, i)

    r = g/(g^2 + b^2)
    t_m = max(abs(vad_min),abs(vad_max))
    JuMP.@constraint(pm.model, p_fr + p_to >= r*( (-b*(va_fr - va_to))^2 - (-b*(t_m))^2*(1-z) ) )
    JuMP.@constraint(pm.model, p_fr + p_to >= 0)
end
