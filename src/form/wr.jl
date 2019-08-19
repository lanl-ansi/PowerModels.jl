### quadratic relaxations in the rectangular W-space (e.g. SOC and QC relaxations)


""
function variable_voltage(pm::AbstractWRModel; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

""
function variable_voltage(pm::AbstractWRConicModel; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

""
function constraint_model_voltage(pm::AbstractWRModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:w,:wr,:wi], typeof(pm))

    w  = var(pm, n, c,  :w)
    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)

    for (i,j) in ids(pm, n, :buspairs)
        InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

""
function constraint_model_voltage(pm::AbstractWRConicModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:w,:wr,:wi], typeof(pm))

    w  = var(pm, n, c,  :w)
    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)

    for (i,j) in ids(pm, n, :buspairs)
        InfrastructureModels.relaxation_complex_product_conic(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w_fr_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])
q[f_idx] == -(b+c/2)/tm*w_fr_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])
```
"""
function constraint_ohms_yt_from_ne(pm::AbstractWRModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n, c,    :p_ne, f_idx)
    q_fr = var(pm, n, c,    :q_ne, f_idx)
    w_fr = var(pm, n, c, :w_fr_ne, i)
    wr   = var(pm, n, c,   :wr_ne, i)
    wi   = var(pm, n, c,   :wi_ne, i)

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
function constraint_ohms_yt_to_ne(pm::AbstractWRModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n, c,    :p_ne, t_idx)
    q_to = var(pm, n, c,    :q_ne, t_idx)
    w_to = var(pm, n, c, :w_to_ne, i)
    wr   = var(pm, n, c,   :wr_ne, i)
    wi   = var(pm, n, c,   :wi_ne, i)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end

""
function variable_voltage_on_off(pm::AbstractWRModel; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_voltage_product_on_off(pm; kwargs...)
end

""
function constraint_model_voltage_on_off(pm::AbstractWRModel, n::Int, c::Int)
    w  = var(pm, n, c, :w)
    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)
    z  = var(pm, n, :z_branch)

    w_fr = var(pm, n, c, :w_fr)
    w_to = var(pm, n, c, :w_to)

    constraint_voltage_magnitude_sqr_from_on_off(pm, n, c)
    constraint_voltage_magnitude_sqr_to_on_off(pm, n, c)
    constraint_voltage_product_on_off(pm, n, c)

    for (l,i,j) in ref(pm, n, :arcs_from)
        InfrastructureModels.relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end

""
function constraint_model_voltage_ne(pm::AbstractWRModel, n::Int, c::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :ne_branch)

    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, n, :ne_buspairs))
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in branches)

    w  = var(pm, n, c, :w)
    wr = var(pm, n, c, :wr_ne)
    wi = var(pm, n, c, :wi_ne)
    z  = var(pm, n, :branch_ne)

    w_fr = var(pm, n, c, :w_fr_ne)
    w_to = var(pm, n, c, :w_to_ne)

    for (l,i,j) in ref(pm, n, :ne_arcs_from)
        JuMP.@constraint(pm.model, w_fr[l] <= z[l]*buses[branches[l]["f_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_fr[l] >= z[l]*buses[branches[l]["f_bus"]]["vmin"]^2)

        JuMP.@constraint(pm.model, wr[l] <= z[l]*wr_max[bi_bp[l]])
        JuMP.@constraint(pm.model, wr[l] >= z[l]*wr_min[bi_bp[l]])
        JuMP.@constraint(pm.model, wi[l] <= z[l]*wi_max[bi_bp[l]])
        JuMP.@constraint(pm.model, wi[l] >= z[l]*wi_min[bi_bp[l]])

        JuMP.@constraint(pm.model, w_to[l] <= z[l]*buses[branches[l]["t_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_to[l] >= z[l]*buses[branches[l]["t_bus"]]["vmin"]^2)

        InfrastructureModels.relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end


""
function constraint_voltage_magnitude_from_on_off(pm::AbstractWRModel, n::Int, c::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    vm_fr = var(pm, n, c, :vm_fr)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, vm_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"])
        JuMP.@constraint(pm.model, vm_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"])
    end
end

""
function constraint_voltage_magnitude_to_on_off(pm::AbstractWRModel, n::Int, c::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    vm_to = var(pm, n, c, :vm_to)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, vm_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"])
        JuMP.@constraint(pm.model, vm_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"])
    end
end


""
function constraint_voltage_magnitude_sqr_from_on_off(pm::AbstractWRModel, n::Int, c::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    w_fr = var(pm, n, c, :w_fr)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, w_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_magnitude_sqr_to_on_off(pm::AbstractWRModel, n::Int, c::Int)
    buses = ref(pm, n, :bus)
    branches = ref(pm, n, :branch)

    w_to = var(pm, n, c, :w_to)
    z = var(pm, n, :z_branch)

    for (i, branch) in ref(pm, n, :branch)
        JuMP.@constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        JuMP.@constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_product_on_off(pm::AbstractWRModel, n::Int, c::Int)
    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, n, :buspairs), c)

    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, n, :branch))

    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)
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
function constraint_ohms_yt_from_on_off(pm::AbstractWRModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    w_fr = var(pm, n, c, :w_fr, i)
    wr   = var(pm, n, c, :wr, i)
    wi   = var(pm, n, c, :wi, i)

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
function constraint_ohms_yt_to_on_off(pm::AbstractWRModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    w_to = var(pm, n, c, :w_to, i)
    wr = var(pm, n, c, :wr, i)
    wi = var(pm, n, c, :wi, i)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end

"`angmin*wr[i] <= wi[i] <= angmax*wr[i]`"
function constraint_voltage_angle_difference_on_off(pm::AbstractWRModel, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx
    wr = var(pm, n, c, :wr, i)
    wi = var(pm, n, c, :wi, i)

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)
end

"`angmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]`"
function constraint_voltage_angle_difference_ne(pm::AbstractWRModel, n::Int, c::Int, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx
    wr = var(pm, n, c, :wr_ne, i)
    wi = var(pm, n, c, :wi_ne, i)

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)
end

""
function variable_voltage_ne(pm::AbstractWRModel; kwargs...)
    variable_voltage_magnitude_sqr_from_ne(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm; kwargs...)
    variable_voltage_product_ne(pm; kwargs...)
end

""
function variable_voltage_magnitude_sqr_from_ne(pm::AbstractWRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    var(pm, nw, cnd)[:w_fr_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_$(cnd)_w_fr_ne",
        lower_bound = 0,
        upper_bound = (buses[branches[i]["f_bus"]]["vmax"][cnd])^2,
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["f_bus"]), "w_fr_start", cnd, 1.001)
    )
end

""
function variable_voltage_magnitude_sqr_to_ne(pm::AbstractWRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :ne_branch)

    var(pm, nw, cnd)[:w_to_ne] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :ne_branch)], base_name="$(nw)_$(cnd)_w_to_ne",
        lower_bound = 0,
        upper_bound = (buses[branches[i]["t_bus"]]["vmax"][cnd])^2,
        start = comp_start_value(ref(pm, nw, :bus, branches[i]["t_bus"]), "w_to_start", cnd, 1.001)
    )
end

""
function variable_voltage_product_ne(pm::AbstractWRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, nw, :ne_buspairs), cnd)
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :ne_branch))

    var(pm, nw, cnd)[:wr_ne] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :ne_branch)], base_name="$(nw)_$(cnd)_wr_ne",
        lower_bound = min(0, wr_min[bi_bp[b]]),
        upper_bound = max(0, wr_max[bi_bp[b]]),
        start = comp_start_value(ref(pm, nw, :ne_buspairs, bi_bp[b]), "wr_start", cnd, 1.0)
    )

    var(pm, nw, cnd)[:wi_ne] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :ne_branch)], base_name="$(nw)_$(cnd)_wi_ne",
        lower_bound = min(0, wi_min[bi_bp[b]]),
        upper_bound = max(0, wi_max[bi_bp[b]]),
        start = comp_start_value(ref(pm, nw, :ne_buspairs, bi_bp[b]), "wi_start", cnd)
    )
end



###### QC Relaxations ######


"Creates variables associated with differences in voltage angles"
function variable_voltage_angle_difference(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:td] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_td",
        lower_bound = ref(pm, nw, :buspairs, bp, "angmin", cnd),
        upper_bound = ref(pm, nw, :buspairs, bp, "angmax", cnd),
        start = comp_start_value(ref(pm, nw, :buspairs, bp), "td_start", cnd)
    )
end

"Creates the voltage magnitude product variables"
function variable_voltage_magnitude_product(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buspairs = ref(pm, nw, :buspairs)
    var(pm, nw, cnd)[:vv] = JuMP.@variable(pm.model,
        [bp in keys(buspairs)], base_name="$(nw)_$(cnd)_vv",
        lower_bound = buspairs[bp]["vm_fr_min"][cnd]*buspairs[bp]["vm_to_min"][cnd],
        upper_bound = buspairs[bp]["vm_fr_max"][cnd]*buspairs[bp]["vm_to_max"][cnd],
        start = comp_start_value(buspairs[bp], "vv_start", cnd, 1.0)
    )
end


""
function variable_current_magnitude_sqr(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buspairs = ref(pm, nw, :buspairs)
    ub = Dict()
    for (bp, buspair) in buspairs
        if haskey(buspair, "rate_a")
            ub[bp] = ((buspair["rate_a"][cnd]*buspair["tap"][cnd])/buspair["vm_fr_min"][cnd])^2
        else
            ub[bp] = Inf
        end
    end
    var(pm, nw, cnd)[:ccm] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_ccm",
        lower_bound = 0,
        upper_bound = ub[bp],
        start = comp_start_value(buspairs[bp], "ccm_start", cnd)
    )
end

""
function variable_voltage(pm::AbstractQCWRModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)

    variable_voltage_angle_difference(pm; kwargs...)
    variable_voltage_magnitude_product(pm; kwargs...)
    variable_cosine(pm; kwargs...)
    variable_sine(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

""
function constraint_model_voltage(pm::AbstractQCWRModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:vm,:va,:td,:si,:cs,:vv,:w,:wr,:wi], typeof(pm))

    v = var(pm, n, c, :vm)
    t = var(pm, n, c, :va)

    td = var(pm, n, c, :td)
    si = var(pm, n, c, :si)
    cs = var(pm, n, c, :cs)
    vv = var(pm, n, c, :vv)

    w  = var(pm, n, c, :w)
    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)

    for (i,b) in ref(pm, n, :bus)
        InfrastructureModels.relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in ids(pm, n, :buspairs)
        i,j = bp
        JuMP.@constraint(pm.model, t[i] - t[j] == td[bp])

        relaxation_sin(pm.model, td[bp], si[bp])
        relaxation_cos(pm.model, td[bp], cs[bp])
        InfrastructureModels.relaxation_product(pm.model, v[i], v[j], vv[bp])
        InfrastructureModels.relaxation_product(pm.model, vv[bp], cs[bp], wr[bp])
        InfrastructureModels.relaxation_product(pm.model, vv[bp], si[bp], wi[bp])

        # this constraint is redudant and useful for debugging
        #InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in ref(pm, n, :branch)
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = ref(pm, n, :buspairs, pair)

        # to prevent this constraint from being posted on multiple parallel branches
        if buspair["branch"] == i
            constraint_power_magnitude_sqr(pm, i, nw=n, cnd=c)
            constraint_power_magnitude_link(pm, i, nw=n, cnd=c)
        end
    end

end

"`p[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]`"
function constraint_power_magnitude_sqr(pm::AbstractQCWRModel, n::Int, c::Int, f_bus, t_bus, arc_from, tm)
    w_i  = var(pm, n, c, :w, f_bus)
    p_fr = var(pm, n, c, :p, arc_from)
    q_fr = var(pm, n, c, :q, arc_from)
    ccm   = var(pm, n, c, :ccm, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm^2*ccm)
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link(pm::AbstractQCWRModel, n::Int, c::Int, f_bus, t_bus, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    p_fr = var(pm, n, c, :p, arc_from)
    q_fr = var(pm, n, c, :q, arc_from)
    wr = var(pm, n, c, :wr, (f_bus, t_bus))
    wi = var(pm, n, c, :wi, (f_bus, t_bus))
    ccm = var(pm, n, c, :ccm, (f_bus, t_bus))

    ym_sh_sqr = g_fr^2 + b_fr^2

    JuMP.@constraint(pm.model, ccm == (g^2 + b^2)*(w_fr/tm^2 + w_to - 2*(tr*wr + ti*wi)/tm^2) - ym_sh_sqr*(w_fr/tm^2) + 2*(g_fr*p_fr - b_fr*q_fr))
end

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::AbstractQCWRModel, n::Int, c::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, c, :va)[i] == 0)
end

""
function constraint_voltage_angle_difference(pm::AbstractQCWRModel, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    td = var(pm, n, c, :td, (f_bus, t_bus))

    if JuMP.lower_bound(td) < angmin
        set_lower_bound(td, angmin)
    end

    if JuMP.upper_bound(td) > angmax
        set_upper_bound(td, angmax)
    end

    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    wr   = var(pm, n, c, :wr, (f_bus, t_bus))
    wi   = var(pm, n, c, :wi, (f_bus, t_bus))

    JuMP.@constraint(pm.model, wi <= tan(angmax)*wr)
    JuMP.@constraint(pm.model, wi >= tan(angmin)*wr)

    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end

""
function add_setpoint_bus_voltage!(sol, pm::AbstractQCWRModel)
    add_setpoint!(sol, pm, "bus", "vm", :vm, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"])
    add_setpoint!(sol, pm, "bus", "va", :va, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"])
end



""
function variable_voltage_on_off(pm::AbstractQCWRModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
    variable_voltage_magnitude_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_to_on_off(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_voltage_product_on_off(pm; kwargs...)

    variable_voltage_angle_difference_on_off(pm; kwargs...)
    variable_voltage_magnitude_product_on_off(pm; kwargs...)
    variable_cosine_on_off(pm; kwargs...)
    variable_sine_on_off(pm; kwargs...)
    variable_current_magnitude_sqr_on_off(pm; kwargs...) # includes 0, but needs new indexs
end

""
function variable_voltage_angle_difference_on_off(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:td] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_td",
        lower_bound = min(0, ref(pm, nw, :branch, l, "angmin", cnd)),
        upper_bound = max(0, ref(pm, nw, :branch, l, "angmax", cnd)),
        start = comp_start_value(ref(pm, nw, :branch, l), "td_start", cnd)
    )
end

""
function variable_voltage_magnitude_product_on_off(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branches = ref(pm, nw, :branch)
    buses = ref(pm, nw, :bus)

    vv_min = Dict((l, buses[branch["f_bus"]]["vmin"][cnd]*buses[branch["t_bus"]]["vmin"][cnd]) for (l, branch) in branches)
    vv_max = Dict((l, buses[branch["f_bus"]]["vmax"][cnd]*buses[branch["t_bus"]]["vmax"][cnd]) for (l, branch) in branches)

    var(pm, nw, cnd)[:vv] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_vv",
        lower_bound = min(0, vv_min[l]),
        upper_bound = max(0, vv_max[l]),
        start = comp_start_value(ref(pm, nw, :branch, l), "vv_start", cnd, 1.0)
    )
end


""
function variable_cosine_on_off(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    cos_min = Dict((l, -Inf) for l in ids(pm, nw, :branch))
    cos_max = Dict((l,  Inf) for l in ids(pm, nw, :branch))

    for (l, branch) in ref(pm, nw, :branch)
        angmin = branch["angmin"][cnd]
        angmax = branch["angmax"][cnd]
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

    var(pm, nw, cnd)[:cs] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_cs",
        lower_bound = min(0, cos_min[l]),
        upper_bound = max(0, cos_max[l]),
        start = comp_start_value(ref(pm, nw, :branch, l), "cs_start", cnd, 1.0)
    )
end

""
function variable_sine_on_off(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:si] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_si",
        lower_bound = min(0, sin(ref(pm, nw, :branch, l, "angmin", cnd))),
        upper_bound = max(0, sin(ref(pm, nw, :branch, l, "angmax", cnd))),
        start = comp_start_value(ref(pm, nw, :branch, l), "si_start", cnd)
    )
end


""
function variable_current_magnitude_sqr_on_off(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    ccm_min = Dict((l, 0) for l in ids(pm, nw, :branch))

    branches = ref(pm, nw, :branch)
    ccm_max = Dict()
    for (l, branch) in branches
        vm_fr_min = ref(pm, nw, :bus, branch["f_bus"], "vmin", cnd)
        ccm_max[l] = ((branch["rate_a"][cnd]*branch["tap"][cnd])/vm_fr_min)^2
    end

    var(pm, nw, cnd)[:ccm] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_ccm",
        lower_bound = ccm_min[l],
        upper_bound = ccm_max[l],
        start = comp_start_value(ref(pm, nw, :branch, l), "ccm_start", cnd)
    )
end


""
function constraint_model_voltage_on_off(pm::AbstractQCWRModel, n::Int, c::Int)
    v = var(pm, n, c, :vm)
    t = var(pm, n, c, :va)
    vm_fr = var(pm, n, c, :vm_fr)
    vm_to = var(pm, n, c, :vm_to)

    td = var(pm, n, c, :td)
    si = var(pm, n, c, :si)
    cs = var(pm, n, c, :cs)
    vv = var(pm, n, c, :vv)

    w = var(pm, n, c, :w)
    w_fr = var(pm, n, c, :w_fr)
    w_to = var(pm, n, c, :w_to)

    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)

    z = var(pm, n, :z_branch)

    td_lb = ref(pm, n, :off_angmin, c)
    td_ub = ref(pm, n, :off_angmax, c)
    td_max = max(abs(td_lb), abs(td_ub))

    for i in ids(pm, n, :bus)
        InfrastructureModels.relaxation_sqr(pm.model, v[i], w[i])
    end

    constraint_voltage_magnitude_from_on_off(pm, n, c) # bounds on vm_fr
    constraint_voltage_magnitude_to_on_off(pm, n, c) # bounds on vm_to
    constraint_voltage_magnitude_sqr_from_on_off(pm, n, c) # bounds on w_fr
    constraint_voltage_magnitude_sqr_to_on_off(pm, n, c) # bounds on w_to
    constraint_voltage_product_on_off(pm, n, c) # bounds on wr, wi

    for (l, branch) in ref(pm, n, :branch)
        i = branch["f_bus"]
        j = branch["t_bus"]

        JuMP.@constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        JuMP.@constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))

        relaxation_sin_on_off(pm.model, td[l], si[l], z[l], td_max)
        relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)
        InfrastructureModels.relaxation_product_on_off(pm.model, vm_fr[l], vm_to[l], vv[l], z[l])
        InfrastructureModels.relaxation_product_on_off(pm.model, vv[l], cs[l], wr[l], z[l])
        InfrastructureModels.relaxation_product_on_off(pm.model, vv[l], si[l], wi[l], z[l])

        # this constraint is redudant and useful for debugging
        #InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])

        #cs4 = InfrastructureModels.relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, v[i], vm_fr[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, v[j], vm_to[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        InfrastructureModels.relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])

        # to prevent this constraint from being posted on multiple parallel branchs
        # TODO needs on/off variant
        constraint_power_magnitude_sqr_on_off(pm, l, nw=n, cnd=c)
        constraint_power_magnitude_link_on_off(pm, l, nw=n, cnd=c) # different index set
    end
end


"`p[arc_from]^2 + q[arc_from]^2 <= w[f_bus]/tm*cm[i]`"
function constraint_power_magnitude_sqr_on_off(pm::AbstractQCWRModel, n::Int, c::Int, i, f_bus, arc_from, tm)
    w    = var(pm, n, c, :w, f_bus)
    p_fr = var(pm, n, c, :p, arc_from)
    q_fr = var(pm, n, c, :q, arc_from)
    ccm   = var(pm, n, c, :ccm, i)
    z    = var(pm, n, :z_branch, i)

    # TODO see if there is a way to leverage relaxation_complex_product_on_off here
    w_lb, w_ub = InfrastructureModels.variable_domain(w)
    ccm_lb, ccm_ub = InfrastructureModels.variable_domain(ccm)
    z_lb, z_ub = InfrastructureModels.variable_domain(z)

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w*ccm*z_ub/tm^2)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w_ub*ccm*z/tm^2)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= w*ccm_ub*z/tm^2)
end

"`ccm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link_on_off(pm::AbstractQCWRModel, n::Int, c::Int, i, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
    w_fr = var(pm, n, c, :w_fr, i)
    w_to = var(pm, n, c, :w_to, i)
    p_fr = var(pm, n, c, :p, arc_from)
    q_fr = var(pm, n, c, :q, arc_from)
    wr   = var(pm, n, c, :wr, i)
    wi   = var(pm, n, c, :wi, i)
    ccm   = var(pm, n, c, :ccm, i)

    ym_sh_sqr = g_fr^2 + b_fr^2

    JuMP.@constraint(pm.model, ccm == (g^2 + b^2)*(w_fr/tm^2 + w_to - 2*(tr*wr + ti*wi)/tm^2) - ym_sh_sqr*(w_fr/tm^2) + 2*(g_fr*p_fr - b_fr*q_fr))
end




""
function variable_voltage_magnitude_product(pm::AbstractQCLSModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    # do nothing - no lifted variables required for voltage variable product
end

"creates lambda variables for convex combination model"
function variable_voltage_magnitude_product_multipliers(pm::AbstractQCLSModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:lambda_wr] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs), i=1:8], base_name="$(nw)_$(cnd)_lambda",
        lower_bound = 0, upper_bound = 1, start = 0.0)

    var(pm, nw, cnd)[:lambda_wi] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs), i=1:8], base_name="$(nw)_$(cnd)_lambda",
        lower_bound = 0, upper_bound = 1, start = 0.0)
end

""
function variable_voltage(pm::AbstractQCLSModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)

    variable_voltage_angle_difference(pm; kwargs...)
    variable_voltage_magnitude_product(pm; kwargs...)
    variable_voltage_magnitude_product_multipliers(pm; kwargs...)
    variable_cosine(pm; kwargs...)
    variable_sine(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end


""
function constraint_model_voltage(pm::AbstractQCLSModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:vm,:va,:td,:si,:cs,:w,:wr,:wi,:lambda_wr,:lambda_wi], typeof(pm))

    v = var(pm, n, c, :vm)
    t = var(pm, n, c, :va)

    td = var(pm, n, c, :td)
    si = var(pm, n, c, :si)
    cs = var(pm, n, c, :cs)

    w = var(pm, n, c, :w)
    wr = var(pm, n, c, :wr)
    lambda_wr = var(pm, n, c, :lambda_wr)
    wi = var(pm, n, c, :wi)
    lambda_wi = var(pm, n, c, :lambda_wi)

    for (i,b) in ref(pm, n, :bus)
        InfrastructureModels.relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in ids(pm, n, :buspairs)
        i,j = bp
        JuMP.@constraint(pm.model, t[i] - t[j] == td[bp])

        relaxation_sin(pm.model, td[bp], si[bp])
        relaxation_cos(pm.model, td[bp], cs[bp])
        InfrastructureModels.relaxation_trilinear(pm.model, v[i], v[j], cs[bp], wr[bp], lambda_wr[bp,:])
        InfrastructureModels.relaxation_trilinear(pm.model, v[i], v[j], si[bp], wi[bp], lambda_wi[bp,:])
        cut_product_replicates(pm.model, v[i], v[j], lambda_wr[bp,:], lambda_wi[bp,:])

        # this constraint is redudant and useful for debugging
        #InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in ref(pm, n, :branch)
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = ref(pm, n, :buspairs, pair)

        # to prevent this constraint from being posted on multiple parallel branchs
        if buspair["branch"] == i
            constraint_power_magnitude_sqr(pm, i, nw=n, cnd=c)
            constraint_power_magnitude_link(pm, i, nw=n, cnd=c)
        end
    end

end
