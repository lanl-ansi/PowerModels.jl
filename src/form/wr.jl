### quadratic relaxations in the rectangular W-space (e.g. SOC and QC relaxations)


""
function variable_bus_voltage(pm::AbstractWRModel; kwargs...)
    variable_bus_voltage_magnitude_sqr(pm; kwargs...)
    variable_buspair_voltage_product(pm; kwargs...)
end

""
function variable_bus_voltage(pm::AbstractWRConicModel; kwargs...)
    variable_bus_voltage_magnitude_sqr(pm; kwargs...)
    variable_buspair_voltage_product(pm; kwargs...)
end

""
function constraint_model_voltage(pm::AbstractWRModel, n::Int)
    _check_missing_keys(var(pm, n), [:w,:wr,:wi], typeof(pm))

    w  = var(pm, n,  :w)
    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)

    for (i,j) in ids(pm, n, :buspairs)
        _IM.relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

""
function constraint_model_voltage(pm::AbstractWRConicModel, n::Int)
    _check_missing_keys(var(pm, n), [:w,:wr,:wi], typeof(pm))

    w  = var(pm, n,  :w)
    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)

    for (i,j) in ids(pm, n, :buspairs)
        _IM.relaxation_complex_product_conic(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w_fr_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])
q[f_idx] == -(b+c/2)/tm*w_fr_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])
```
"""
function constraint_ne_ohms_yt_from(pm::AbstractWRModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n,    :p_ne, f_idx)
    q_fr = var(pm, n,    :q_ne, f_idx)
    w_fr = var(pm, n, :w_fr_ne, i)
    wr   = var(pm, n,   :wr_ne, i)
    wi   = var(pm, n,   :wi_ne, i)

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*w_to_ne[i] + (-g*tr-b*ti)/tm*(wr_ne[i]) + (-b*tr+g*ti)/tm*(-wi_ne[i])
q[t_idx] == -(b+c/2)*w_to_ne[i] - (-b*tr+g*ti)/tm*(wr_ne[i]) + (-g*tr-b*ti)/tm*(-wi_ne[i])
```
"""
function constraint_ne_ohms_yt_to(pm::AbstractWRModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n,    :p_ne, t_idx)
    q_to = var(pm, n,    :q_ne, t_idx)
    w_to = var(pm, n, :w_to_ne, i)
    wr   = var(pm, n,   :wr_ne, i)
    wi   = var(pm, n,   :wi_ne, i)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end

""
function variable_bus_voltage_on_off(pm::AbstractWRModel; kwargs...)
    variable_bus_voltage_magnitude_sqr(pm; kwargs...)

    variable_branch_voltage_magnitude_fr_sqr_on_off(pm; kwargs...)
    variable_branch_voltage_magnitude_to_sqr_on_off(pm; kwargs...)
    variable_branch_voltage_product_on_off(pm; kwargs...)
end

""
function constraint_model_voltage_on_off(pm::AbstractWRModel, n::Int)
    w  = var(pm, n, :w)
    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)
    z  = var(pm, n, :z_branch)

    w_fr = var(pm, n, :w_fr)
    w_to = var(pm, n, :w_to)

    constraint_voltage_magnitude_sqr_from_on_off(pm, n)
    constraint_voltage_magnitude_sqr_to_on_off(pm, n)
    constraint_voltage_product_on_off(pm, n)

    for (l,i,j) in ref(pm, n, :arcs_from)
        _IM.relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end

""
function constraint_ne_model_voltage(pm::AbstractWRModel, n::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :ne_branch)

    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, n, :ne_buspairs))
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in branches)

    w  = var(pm, n, :w)
    wr = var(pm, n, :wr_ne)
    wi = var(pm, n, :wi_ne)
    z  = var(pm, n, :branch_ne)

    w_fr = var(pm, n, :w_fr_ne)
    w_to = var(pm, n, :w_to_ne)

    for (l,i,j) in ref(pm, n, :ne_arcs_from)
        JuMP.@constraint(pm.model, w_fr[l] <= z[l]*buses[branches[l]["f_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_fr[l] >= z[l]*buses[branches[l]["f_bus"]]["vmin"]^2)

        JuMP.@constraint(pm.model, wr[l] <= z[l]*wr_max[bi_bp[l]])
        JuMP.@constraint(pm.model, wr[l] >= z[l]*wr_min[bi_bp[l]])
        JuMP.@constraint(pm.model, wi[l] <= z[l]*wi_max[bi_bp[l]])
        JuMP.@constraint(pm.model, wi[l] >= z[l]*wi_min[bi_bp[l]])

        JuMP.@constraint(pm.model, w_to[l] <= z[l]*buses[branches[l]["t_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_to[l] >= z[l]*buses[branches[l]["t_bus"]]["vmin"]^2)

        _IM.relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end


""
function constraint_voltage_magnitude_from_on_off(pm::AbstractWRModel, n::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    vm_fr = var(pm, n, :vm_fr)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, vm_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"])
        JuMP.@constraint(pm.model, vm_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"])
    end
end

""
function constraint_voltage_magnitude_to_on_off(pm::AbstractWRModel, n::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    vm_to = var(pm, n, :vm_to)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, vm_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"])
        JuMP.@constraint(pm.model, vm_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"])
    end
end


""
function constraint_voltage_magnitude_sqr_from_on_off(pm::AbstractWRModel, n::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    w_fr = var(pm, n, :w_fr)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, w_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_magnitude_sqr_to_on_off(pm::AbstractWRModel, n::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    w_to = var(pm, n, :w_to)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_product_on_off(pm::AbstractWRModel, n::Int)
    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, n, :buspairs))

    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, n, :branch))

    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)
    z  = var(pm, n, :z_branch)

    for b in ids(pm, n, :branch)
        JuMP.@constraint(pm.model, wr[b] <= z[b]*wr_max[bi_bp[b]])
        JuMP.@constraint(pm.model, wr[b] >= z[b]*wr_min[bi_bp[b]])
        JuMP.@constraint(pm.model, wi[b] <= z[b]*wi_max[bi_bp[b]])
        JuMP.@constraint(pm.model, wi[b] >= z[b]*wi_min[bi_bp[b]])
    end
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] ==        g/tm*w_fr[i] + (-g*tr+b*ti)/tm*(wr[i]) + (-b*tr-g*ti)/tm*(wi[i])
q[f_idx] == -(b+c/2)/tm*w_fr[i] - (-b*tr-g*ti)/tm*(wr[i]) + (-g*tr+b*ti)/tm*(wi[i])
```
"""
function constraint_ohms_yt_from_on_off(pm::AbstractWRModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    w_fr = var(pm, n, :w_fr, i)
    wr   = var(pm, n, :wr, i)
    wi   = var(pm, n, :wi, i)

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] ==        g*w_to[i] + (-g*tr-b*ti)/tm*(wr[i]) + (-b*tr+g*ti)/tm*(-wi[i])
q[t_idx] == -(b+c/2)*w_to[i] - (-b*tr+g*ti)/tm*(wr[i]) + (-g*tr-b*ti)/tm*(-wi[i])
```
"""
function constraint_ohms_yt_to_on_off(pm::AbstractWRModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)
    w_to = var(pm, n, :w_to, i)
    wr = var(pm, n, :wr, i)
    wi = var(pm, n, :wi, i)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end

"`angmin*wr[i] <= wi[i] <= angmax*wr[i]`"
function constraint_voltage_angle_difference_on_off(pm::AbstractWRModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx
    wr = var(pm, n, :wr, i)
    wi = var(pm, n, :wi, i)

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)
end

"`angmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]`"
function constraint_ne_voltage_angle_difference(pm::AbstractWRModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx
    wr = var(pm, n, :wr_ne, i)
    wi = var(pm, n, :wi_ne, i)

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)
end

""
function variable_ne_branch_voltage(pm::AbstractWRModel; kwargs...)
    variable_ne_branch_voltage_magnitude_fr_sqr(pm; kwargs...)
    variable_ne_branch_voltage_magnitude_to_sqr(pm; kwargs...)
    variable_ne_branch_voltage_product(pm; kwargs...)
end

""
function variable_ne_branch_voltage_magnitude_fr_sqr(pm::AbstractWRModel; nw::Int=nw_id_default, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    w_fr_ne = var(pm, nw)[:w_fr_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_w_fr_ne",
        lower_bound = 0,
        upper_bound = (buses[branches[i]["f_bus"]]["vmax"])^2,
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["f_bus"]), "w_fr_start", 1.001)
    )

    report && sol_component_value(pm, nw, :ne_branch, :w_fr, ids(pm, nw, :ne_branch), w_fr_ne)
end

""
function variable_ne_branch_voltage_magnitude_to_sqr(pm::AbstractWRModel; nw::Int=nw_id_default, report::Bool=true)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    w_to_ne = var(pm, nw)[:w_to_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_w_to_ne",
        lower_bound = 0,
        upper_bound = (buses[branches[i]["t_bus"]]["vmax"])^2,
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["t_bus"]), "w_to_start", 1.001)
    )

    report && sol_component_value(pm, nw, :ne_branch, :w_to, ids(pm, nw, :ne_branch), w_to_ne)
end

""
function variable_ne_branch_voltage_product(pm::AbstractWRModel; nw::Int=nw_id_default, report::Bool=true)
    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, nw, :ne_buspairs))
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :ne_branch))

    wr_ne = var(pm, nw)[:wr_ne] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :ne_branch)], base_name="$(nw)_wr_ne",
        lower_bound = min(0, wr_min[bi_bp[b]]),
        upper_bound = max(0, wr_max[bi_bp[b]]),
        start = comp_start_value(ref(pm, nw, :ne_buspairs, bi_bp[b]), "wr_start", 1.0)
    )

    wi_ne = var(pm, nw)[:wi_ne] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :ne_branch)], base_name="$(nw)_wi_ne",
        lower_bound = min(0, wi_min[bi_bp[b]]),
        upper_bound = max(0, wi_max[bi_bp[b]]),
        start = comp_start_value(ref(pm, nw, :ne_buspairs, bi_bp[b]), "wi_start")
    )

    report && sol_component_value(pm, nw, :ne_branch, :wr, ids(pm, nw, :ne_branch), wr_ne)
    report && sol_component_value(pm, nw, :ne_branch, :wi, ids(pm, nw, :ne_branch), wi_ne)
end


###### QC Relaxations ######


"Creates variables associated with differences in voltage angles"
function variable_buspair_voltage_product_angle(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    td = var(pm, nw)[:td] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_td",
        start = comp_start_value(ref(pm, nw, :buspairs, bp), "td_start")
    )

    if bounded
        for (bp, buspair) in ref(pm, nw, :buspairs)
            JuMP.set_lower_bound(td[bp], buspair["angmin"])
            JuMP.set_upper_bound(td[bp], buspair["angmax"])
        end
    end

    report && sol_component_value_buspair(pm, nw, :buspairs, :td, ids(pm, nw, :buspairs), td)
end

"Creates the voltage magnitude product variables"
function variable_buspair_voltage_product_magnitude(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    buspairs = ref(pm, nw, :buspairs)
    vv = var(pm, nw)[:vv] = JuMP.@variable(pm.model,
        [bp in keys(buspairs)], base_name="$(nw)_vv",
        start = comp_start_value(buspairs[bp], "vv_start", 1.0)
    )

    if bounded
        for (bp, buspair) in ref(pm, nw, :buspairs)
            JuMP.set_lower_bound(vv[bp], buspair["vm_fr_min"]*buspair["vm_to_min"])
            JuMP.set_upper_bound(vv[bp], buspair["vm_fr_max"]*buspair["vm_to_max"])
        end
    end

    report && sol_component_value_buspair(pm, nw, :buspairs, :vv, ids(pm, nw, :buspairs), vv)
end


""
function variable_buspair_current_magnitude_sqr(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    ccm = var(pm, nw)[:ccm] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_ccm",
        start = comp_start_value(ref(pm, nw, :buspairs, bp), "ccm_start")
    )

    if bounded
        for (bp, buspair) in ref(pm, nw, :buspairs)
            ub = Inf
            if haskey(buspair, "rate_a")
                ub = ((buspair["rate_a"]*buspair["tap"])/buspair["vm_fr_min"])^2
            end

            JuMP.set_lower_bound(ccm[bp], 0.0)
            if !isinf(ub)
                JuMP.set_upper_bound(ccm[bp], ub)
            end
        end
    end

    report && sol_component_value_buspair(pm, nw, :buspairs, :ccm, ids(pm, nw, :buspairs), ccm)
end

""
function variable_bus_voltage(pm::AbstractQCWRModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)

    variable_bus_voltage_magnitude_sqr(pm; kwargs...)
    variable_buspair_voltage_product(pm; kwargs...)

    variable_buspair_voltage_product_angle(pm; kwargs...)
    variable_buspair_voltage_product_magnitude(pm; kwargs...)
    variable_buspair_cosine(pm; kwargs...)
    variable_buspair_sine(pm; kwargs...)
    variable_buspair_current_magnitude_sqr(pm; kwargs...)
end

""
function constraint_model_voltage(pm::AbstractQCWRModel, n::Int)
    _check_missing_keys(var(pm, n), [:vm,:va,:td,:si,:cs,:vv,:w,:wr,:wi], typeof(pm))

    v = var(pm, n, :vm)
    t = var(pm, n, :va)

    td = var(pm, n, :td)
    si = var(pm, n, :si)
    cs = var(pm, n, :cs)
    vv = var(pm, n, :vv)

    w  = var(pm, n, :w)
    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)

    for (i,b) in ref(pm, n, :bus)
        _IM.relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in ids(pm, n, :buspairs)
        i,j = bp
        JuMP.@constraint(pm.model, t[i] - t[j] == td[bp])

        relaxation_sin(pm.model, td[bp], si[bp])
        relaxation_cos(pm.model, td[bp], cs[bp])
        _IM.relaxation_product(pm.model, v[i], v[j], vv[bp])
        _IM.relaxation_product(pm.model, vv[bp], cs[bp], wr[bp])
        _IM.relaxation_product(pm.model, vv[bp], si[bp], wi[bp])

        # this constraint is redudant and useful for debugging
        #_IM.relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in ref(pm, n, :branch)
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = ref(pm, n, :buspairs, pair)

        # to prevent this constraint from being posted on multiple parallel branches
        if buspair["branch"] == i
            constraint_power_magnitude_sqr(pm, i, nw=n)
            constraint_power_magnitude_link(pm, i, nw=n)
        end
    end

end

"`p[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]`"
function constraint_power_magnitude_sqr(pm::AbstractQCWRModel, n::Int, f_bus, t_bus, arc_from, tm)
    w_i  = var(pm, n, :w, f_bus)
    p_fr = var(pm, n, :p, arc_from)
    q_fr = var(pm, n, :q, arc_from)
    ccm   = var(pm, n, :ccm, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm^2*ccm)
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link(pm::AbstractQCWRModel, n::Int, f_bus, t_bus, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    p_fr = var(pm, n, :p, arc_from)
    q_fr = var(pm, n, :q, arc_from)
    wr = var(pm, n, :wr, (f_bus, t_bus))
    wi = var(pm, n, :wi, (f_bus, t_bus))
    ccm = var(pm, n, :ccm, (f_bus, t_bus))

    ym_sh_sqr = g_fr^2 + b_fr^2

    JuMP.@constraint(pm.model, ccm == (g^2 + b^2)*(w_fr/tm^2 + w_to - 2*(tr*wr + ti*wi)/tm^2) - ym_sh_sqr*(w_fr/tm^2) + 2*(g_fr*p_fr - b_fr*q_fr))
end

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::AbstractQCWRModel, n::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, :va)[i] == 0)
end

""
function constraint_voltage_angle_difference(pm::AbstractQCWRModel, n::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    td = var(pm, n, :td, (f_bus, t_bus))

    if JuMP.lower_bound(td) < angmin
        set_lower_bound(td, angmin)
    end

    if JuMP.upper_bound(td) > angmax
        set_upper_bound(td, angmax)
    end

    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    wr   = var(pm, n, :wr, (f_bus, t_bus))
    wi   = var(pm, n, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)

    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end


""
function variable_bus_voltage_on_off(pm::AbstractQCWRModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)
    variable_branch_voltage_magnitude_fr_on_off(pm; kwargs...)
    variable_branch_voltage_magnitude_to_on_off(pm; kwargs...)

    variable_bus_voltage_magnitude_sqr(pm; kwargs...)
    variable_branch_voltage_magnitude_fr_sqr_on_off(pm; kwargs...)
    variable_branch_voltage_magnitude_to_sqr_on_off(pm; kwargs...)

    variable_branch_voltage_product_on_off(pm; kwargs...)

    variable_branch_voltage_product_angle_on_off(pm; kwargs...)
    variable_buspair_voltage_product_magnitude_on_off(pm; kwargs...)
    variable_branch_cosine_on_off(pm; kwargs...)
    variable_branch_sine_on_off(pm; kwargs...)
    variable_branch_current_magnitude_sqr_on_off(pm; kwargs...) # includes 0, but needs new indexs
end

""
function variable_branch_voltage_product_angle_on_off(pm::AbstractPowerModel; nw::Int=nw_id_default, report::Bool=true)
    td = var(pm, nw)[:td] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_td",
        lower_bound = min(0, ref(pm, nw, :branch, l, "angmin")),
        upper_bound = max(0, ref(pm, nw, :branch, l, "angmax")),
        start = comp_start_value(ref(pm, nw, :branch, l), "td_start")
    )

    report && sol_component_value(pm, nw, :branch, :td, ids(pm, nw, :branch), td)
end

""
function variable_buspair_voltage_product_magnitude_on_off(pm::AbstractPowerModel; nw::Int=nw_id_default, report::Bool=true)
    branches = ref(pm, nw, :branch)
    buses = ref(pm, nw, :bus)

    vv_min = Dict((l, buses[branch["f_bus"]]["vmin"]*buses[branch["t_bus"]]["vmin"]) for (l, branch) in branches)
    vv_max = Dict((l, buses[branch["f_bus"]]["vmax"]*buses[branch["t_bus"]]["vmax"]) for (l, branch) in branches)

    vv = var(pm, nw)[:vv] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_vv",
        lower_bound = min(0, vv_min[l]),
        upper_bound = max(0, vv_max[l]),
        start = comp_start_value(ref(pm, nw, :branch, l), "vv_start", 1.0)
    )

    report && sol_component_value(pm, nw, :branch, :vv, ids(pm, nw, :branch), vv)
end


""
function variable_branch_cosine_on_off(pm::AbstractPowerModel; nw::Int=nw_id_default, report::Bool=true)
    cos_min = Dict((l, -Inf) for l in ids(pm, nw, :branch))
    cos_max = Dict((l,  Inf) for l in ids(pm, nw, :branch))

    for (l, branch) in ref(pm, nw, :branch)
        angmin = branch["angmin"]
        angmax = branch["angmax"]
        if angmin >= 0
            cos_max[l] = cos(angmin)
            cos_min[l] = cos(angmax)
        end
        if angmax <= 0
            cos_max[l] = cos(angmax)
            cos_min[l] = cos(angmin)
        end
        if angmin < 0 && angmax > 0
            cos_max[l] = 1.0
            cos_min[l] = min(cos(angmin), cos(angmax))
        end
    end

    cs = var(pm, nw)[:cs] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_cs",
        lower_bound = min(0, cos_min[l]),
        upper_bound = max(0, cos_max[l]),
        start = comp_start_value(ref(pm, nw, :branch, l), "cs_start", 1.0)
    )

    report && sol_component_value(pm, nw, :branch, :cs, ids(pm, nw, :branch), cs)
end

""
function variable_branch_sine_on_off(pm::AbstractPowerModel; nw::Int=nw_id_default, report::Bool=true)
    si = var(pm, nw)[:si] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_si",
        lower_bound = min(0, sin(ref(pm, nw, :branch, l, "angmin"))),
        upper_bound = max(0, sin(ref(pm, nw, :branch, l, "angmax"))),
        start = comp_start_value(ref(pm, nw, :branch, l), "si_start")
    )

    report && sol_component_value(pm, nw, :branch, :si, ids(pm, nw, :branch), si)
end


""
function variable_branch_current_magnitude_sqr_on_off(pm::AbstractPowerModel; nw::Int=nw_id_default, report::Bool=true)
    ccm_min = Dict((l, 0) for l in ids(pm, nw, :branch))

    branches = ref(pm, nw, :branch)
    ccm_max = Dict()
    for (l, branch) in branches
        vm_fr_min = ref(pm, nw, :bus, branch["f_bus"], "vmin")
        ccm_max[l] = ((branch["rate_a"]*branch["tap"])/vm_fr_min)^2
    end

    ccm = var(pm, nw)[:ccm] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_ccm",
        lower_bound = ccm_min[l],
        upper_bound = ccm_max[l],
        start = comp_start_value(ref(pm, nw, :branch, l), "ccm_start")
    )

    report && sol_component_value(pm, nw, :branch, :ccm, ids(pm, nw, :branch), ccm)
end


""
function constraint_model_voltage_on_off(pm::AbstractQCWRModel, n::Int)
    v = var(pm, n, :vm)
    t = var(pm, n, :va)
    vm_fr = var(pm, n, :vm_fr)
    vm_to = var(pm, n, :vm_to)

    td = var(pm, n, :td)
    si = var(pm, n, :si)
    cs = var(pm, n, :cs)
    vv = var(pm, n, :vv)

    w = var(pm, n, :w)
    w_fr = var(pm, n, :w_fr)
    w_to = var(pm, n, :w_to)

    wr = var(pm, n, :wr)
    wi = var(pm, n, :wi)

    z = var(pm, n, :z_branch)

    td_lb = ref(pm, n, :off_angmin)
    td_ub = ref(pm, n, :off_angmax)
    td_max = max(abs(td_lb), abs(td_ub))

    for i in ids(pm, n, :bus)
        _IM.relaxation_sqr(pm.model, v[i], w[i])
    end

    constraint_voltage_magnitude_from_on_off(pm, n) # bounds on vm_fr
    constraint_voltage_magnitude_to_on_off(pm, n) # bounds on vm_to
    constraint_voltage_magnitude_sqr_from_on_off(pm, n) # bounds on w_fr
    constraint_voltage_magnitude_sqr_to_on_off(pm, n) # bounds on w_to
    constraint_voltage_product_on_off(pm, n) # bounds on wr, wi

    for (l, branch) in ref(pm, n, :branch)
        i = branch["f_bus"]
        j = branch["t_bus"]

        JuMP.@constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        JuMP.@constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))

        relaxation_sin_on_off(pm.model, td[l], si[l], z[l], td_max)
        relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)
        _IM.relaxation_product_on_off(pm.model, vm_fr[l], vm_to[l], vv[l], z[l])
        _IM.relaxation_product_on_off(pm.model, vv[l], cs[l], wr[l], z[l])
        _IM.relaxation_product_on_off(pm.model, vv[l], si[l], wi[l], z[l])

        # this constraint is redudant and useful for debugging
        #_IM.relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])

        #cs4 = _IM.relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, v[i], vm_fr[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, v[j], vm_to[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        _IM.relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])

        # to prevent this constraint from being posted on multiple parallel branchs
        # TODO needs on/off variant
        constraint_power_magnitude_sqr_on_off(pm, l, nw=n)
        constraint_power_magnitude_link_on_off(pm, l, nw=n) # different index set
    end
end


"`p[arc_from]^2 + q[arc_from]^2 <= w[f_bus]/tm*cm[i]`"
function constraint_power_magnitude_sqr_on_off(pm::AbstractQCWRModel, n::Int, i, f_bus, arc_from, tm)
    w    = var(pm, n, :w, f_bus)
    p_fr = var(pm, n, :p, arc_from)
    q_fr = var(pm, n, :q, arc_from)
    ccm   = var(pm, n, :ccm, i)
    z    = var(pm, n, :z_branch, i)

    # TODO see if there is a way to leverage relaxation_complex_product_on_off here
    w_lb, w_ub = _IM.variable_domain(w)
    ccm_lb, ccm_ub = _IM.variable_domain(ccm)
    z_lb, z_ub = _IM.variable_domain(z)

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w*ccm*z_ub/tm^2)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w_ub*ccm*z/tm^2)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w*ccm_ub*z/tm^2)
end

"`ccm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link_on_off(pm::AbstractQCWRModel, n::Int, i, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
    w_fr = var(pm, n, :w_fr, i)
    w_to = var(pm, n, :w_to, i)
    p_fr = var(pm, n, :p, arc_from)
    q_fr = var(pm, n, :q, arc_from)
    wr   = var(pm, n, :wr, i)
    wi   = var(pm, n, :wi, i)
    ccm   = var(pm, n, :ccm, i)

    ym_sh_sqr = g_fr^2 + b_fr^2

    JuMP.@constraint(pm.model, ccm == (g^2 + b^2)*(w_fr/tm^2 + w_to - 2*(tr*wr + ti*wi)/tm^2) - ym_sh_sqr*(w_fr/tm^2) + 2*(g_fr*p_fr - b_fr*q_fr))
end




""
function variable_buspair_voltage_product_magnitude(pm::AbstractQCLSModel; nw::Int=nw_id_default, report::Bool=true)
    # do nothing - no lifted variables required for voltage variable product
end

"creates lambda variables for convex combination model"
function variable_buspair_voltage_product_magnitude_multipliers(pm::AbstractQCLSModel; nw::Int=nw_id_default, report::Bool=true)
    lambda_wr = var(pm, nw)[:lambda_wr] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs), i=1:8], base_name="$(nw)_lambda",
        lower_bound = 0, upper_bound = 1, start = 0.0)

    lambda_wi = var(pm, nw)[:lambda_wi] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs), i=1:8], base_name="$(nw)_lambda",
        lower_bound = 0, upper_bound = 1, start = 0.0)

    if report
        for (bp, buspair) in ref(pm, nw, :buspairs)
            l = buspair["branch"]
            @assert !haskey(sol(pm, nw, :branch, l), :lambda_wr)
            sol(pm, nw, :branch, l)[:lambda_wr] = [lambda_wr[bp,i] for i in 1:8]
            sol(pm, nw, :branch, l)[:lambda_wi] = [lambda_wi[bp,i] for i in 1:8]
        end
    end
end

""
function variable_bus_voltage(pm::AbstractQCLSModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)

    variable_bus_voltage_magnitude_sqr(pm; kwargs...)
    variable_buspair_voltage_product(pm; kwargs...)

    variable_buspair_voltage_product_angle(pm; kwargs...)
    variable_buspair_voltage_product_magnitude(pm; kwargs...)
    variable_buspair_voltage_product_magnitude_multipliers(pm; kwargs...)
    variable_buspair_cosine(pm; kwargs...)
    variable_buspair_sine(pm; kwargs...)
    variable_buspair_current_magnitude_sqr(pm; kwargs...)
end


""
function constraint_model_voltage(pm::AbstractQCLSModel, n::Int)
    _check_missing_keys(var(pm, n), [:vm,:va,:td,:si,:cs,:w,:wr,:wi,:lambda_wr,:lambda_wi], typeof(pm))

    v = var(pm, n, :vm)
    t = var(pm, n, :va)

    td = var(pm, n, :td)
    si = var(pm, n, :si)
    cs = var(pm, n, :cs)

    w = var(pm, n, :w)
    wr = var(pm, n, :wr)
    lambda_wr = var(pm, n, :lambda_wr)
    wi = var(pm, n, :wi)
    lambda_wi = var(pm, n, :lambda_wi)

    for (i,b) in ref(pm, n, :bus)
        _IM.relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in ids(pm, n, :buspairs)
        i,j = bp
        JuMP.@constraint(pm.model, t[i] - t[j] == td[bp])

        relaxation_sin(pm.model, td[bp], si[bp])
        relaxation_cos(pm.model, td[bp], cs[bp])
        _IM.relaxation_trilinear(pm.model, v[i], v[j], cs[bp], wr[bp], lambda_wr[bp,:])
        _IM.relaxation_trilinear(pm.model, v[i], v[j], si[bp], wi[bp], lambda_wi[bp,:])
        cut_product_replicates(pm.model, v[i], v[j], lambda_wr[bp,:], lambda_wi[bp,:])

        # this constraint is redudant and useful for debugging
        #_IM.relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in ref(pm, n, :branch)
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = ref(pm, n, :buspairs, pair)

        # to prevent this constraint from being posted on multiple parallel branchs
        if buspair["branch"] == i
            constraint_power_magnitude_sqr(pm, i, nw=n)
            constraint_power_magnitude_link(pm, i, nw=n)
        end
    end

end
