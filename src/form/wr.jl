export
    SOCWRPowerModel, SOCWRForm,
    QCWRPowerModel, QCWRForm,
    QCWRTriPowerModel, QCWRTriForm

""
abstract type AbstractWRForm <: AbstractPowerFormulation end

""
abstract type SOCWRForm <: AbstractWRForm end

""
const SOCWRPowerModel = GenericPowerModel{SOCWRForm}

"default SOC constructor"
SOCWRPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SOCWRForm; kwargs...)

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph; kwargs...) where T <: AbstractWRForm
    variable_voltage_magnitude_sqr(pm, n, h; kwargs...)
    variable_voltage_product(pm, n, h; kwargs...)
end

""
function constraint_voltage(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    w  = var(pm, n, h,  :w)
    wr = var(pm, n, h, :wr)
    wi = var(pm, n, h, :wi)

    for (i,j) in ids(pm, n, h, :buspairs)
        relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w_fr_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])
q[f_idx] == -(b+c/2)/tm*w_fr_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])
```
"""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractWRForm
    p_fr = var(pm, n, h,    :p_ne, f_idx)
    q_fr = var(pm, n, h,    :q_ne, f_idx)
    w_fr = var(pm, n, h, :w_fr_ne, i)
    wr   = var(pm, n, h,   :wr_ne, i)
    wi   = var(pm, n, h,   :wi_ne, i)

    @constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    @constraint(pm.model, q_fr == -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*w_to_ne[i] + (-g*tr-b*ti)/tm*(wr_ne[i]) + (-b*tr+g*ti)/tm*(-wi_ne[i])
q[t_idx] == -(b+c/2)*w_to_ne[i] - (-b*tr+g*ti)/tm*(wr_ne[i]) + (-g*tr-b*ti)/tm*(-wi_ne[i])
```
"""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractWRForm
    p_to = var(pm, n, h,    :p_ne, t_idx)
    q_to = var(pm, n, h,    :q_ne, t_idx)
    w_to = var(pm, n, h, :w_to_ne, i)
    wr   = var(pm, n, h,   :wr_ne, i)
    wi   = var(pm, n, h,   :wi_ne, i)

    @constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    @constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end

""
function variable_voltage_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph; kwargs...) where T <: AbstractWRForm
    variable_voltage_magnitude_sqr(pm, n, h; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm, n, h; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm, n, h; kwargs...)

    variable_voltage_product_on_off(pm, n, h; kwargs...)
end

""
function constraint_voltage_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    w  = var(pm, n, h, :w)
    wr = var(pm, n, h, :wr)
    wi = var(pm, n, h, :wi)
    z  = var(pm, n, h, :branch_z)

    w_fr = var(pm, n, h, :w_fr)
    w_to = var(pm, n, h, :w_to)

    constraint_voltage_magnitude_sqr_from_on_off(pm, n, h)
    constraint_voltage_magnitude_sqr_to_on_off(pm, n, h)
    constraint_voltage_product_on_off(pm, n, h)

    for (l,i,j) in ref(pm, n, h, :arcs_from)
        relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end

""
function constraint_voltage_ne(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :ne_branch)

    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, n, h, :ne_buspairs))
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in branches])

    w  = var(pm, n, h, :w)
    wr = var(pm, n, h, :wr_ne)
    wi = var(pm, n, h, :wi_ne)
    z  = var(pm, n, h, :branch_ne)

    w_fr = var(pm, n, h, :w_fr_ne)
    w_to = var(pm, n, h, :w_to_ne)

    for (l,i,j) in ref(pm, n, h, :ne_arcs_from)
        @constraint(pm.model, w_fr[l] <= z[l]*buses[branches[l]["f_bus"]]["vmax"]^2)
        @constraint(pm.model, w_fr[l] >= z[l]*buses[branches[l]["f_bus"]]["vmin"]^2)

        @constraint(pm.model, wr[l] <= z[l]*wr_max[bi_bp[l]])
        @constraint(pm.model, wr[l] >= z[l]*wr_min[bi_bp[l]])
        @constraint(pm.model, wi[l] <= z[l]*wi_max[bi_bp[l]])
        @constraint(pm.model, wi[l] >= z[l]*wi_min[bi_bp[l]])

        @constraint(pm.model, w_to[l] <= z[l]*buses[branches[l]["t_bus"]]["vmax"]^2)
        @constraint(pm.model, w_to[l] >= z[l]*buses[branches[l]["t_bus"]]["vmin"]^2)

        relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end


""
function constraint_voltage_magnitude_from_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    vm_fr = var(pm, n, h, :vm_fr)
    z = var(pm, n, h, :branch_z)

    for (i, branch) in ref(pm, n, h, :branch)
        @constraint(pm.model, vm_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"])
        @constraint(pm.model, vm_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"])
    end
end

""
function constraint_voltage_magnitude_to_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    vm_to = var(pm, n, h, :vm_to)
    z = var(pm, n, h, :branch_z)

    for (i, branch) in ref(pm, n, h, :branch)
        @constraint(pm.model, vm_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"])
        @constraint(pm.model, vm_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"])
    end
end


""
function constraint_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    w_fr = var(pm, n, h, :w_fr)
    z = var(pm, n, h, :branch_z)

    for (i, branch) in ref(pm, n, h, :branch)
        @constraint(pm.model, w_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        @constraint(pm.model, w_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :branch)

    w_to = var(pm, n, h, :w_to)
    z = var(pm, n, h, :branch_z)

    for (i, branch) in ref(pm, n, h, :branch)
        @constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        @constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_product_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: AbstractWRForm
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, n, h, :buspairs))

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, n, h, :branch)])

    wr = var(pm, n, h, :wr)
    wi = var(pm, n, h, :wi)
    z  = var(pm, n, h, :branch_z)

    for b in ids(pm, n, h, :branch)
        @constraint(pm.model, wr[b] <= z[b]*wr_max[bi_bp[b]])
        @constraint(pm.model, wr[b] >= z[b]*wr_min[bi_bp[b]])
        @constraint(pm.model, wi[b] <= z[b]*wi_max[bi_bp[b]])
        @constraint(pm.model, wi[b] >= z[b]*wi_min[bi_bp[b]])
    end
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] ==        g/tm*w_fr[i] + (-g*tr+b*ti)/tm*(wr[i]) + (-b*tr-g*ti)/tm*(wi[i])
q[f_idx] == -(b+c/2)/tm*w_fr[i] - (-b*tr-g*ti)/tm*(wr[i]) + (-g*tr+b*ti)/tm*(wi[i])
```
"""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max) where T <: AbstractWRForm
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    w_fr = var(pm, n, h, :w_fr, i)
    wr   = var(pm, n, h, :wr, i)
    wi   = var(pm, n, h, :wi, i)

    @constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*w_fr + (-g*tr+b*ti)/tm^2*wr + (-b*tr-g*ti)/tm^2*wi )
    @constraint(pm.model, q_fr == -(b+b_fr)/tm^2*w_fr - (-b*tr-g*ti)/tm^2*wr + (-g*tr+b*ti)/tm^2*wi )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] ==        g*w_to[i] + (-g*tr-b*ti)/tm*(wr[i]) + (-b*tr+g*ti)/tm*(-wi[i])
q[t_idx] == -(b+c/2)*w_to[i] - (-b*tr+g*ti)/tm*(wr[i]) + (-g*tr-b*ti)/tm*(-wi[i])
```
"""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max) where T <: AbstractWRForm
    p_to = var(pm, n, h, :p, t_idx)
    q_to = var(pm, n, h, :q, t_idx)
    w_to = var(pm, n, h, :w_to, i)
    wr = var(pm, n, h, :wr, i)
    wi = var(pm, n, h, :wi, i)

    @constraint(pm.model, p_to ==  (g+g_to)*w_to + (-g*tr-b*ti)/tm^2*wr + (-b*tr+g*ti)/tm^2*-wi )
    @constraint(pm.model, q_to == -(b+b_to)*w_to - (-b*tr+g*ti)/tm^2*wr + (-g*tr-b*ti)/tm^2*-wi )
end

"`angmin*wr[i] <= wi[i] <= angmax*wr[i]`"
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractWRForm
    i, f_bus, t_bus = f_idx
    wr = var(pm, n, h, :wr, i)
    wi = var(pm, n, h, :wi, i)

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)
end

"`angmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]`"
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, angmin, angmax, vad_min, vad_max) where T <: AbstractWRForm
    i, f_bus, t_bus = f_idx
    wr = var(pm, n, h, :wr_ne, i)
    wi = var(pm, n, h, :wi_ne, i)

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)
end

""
function variable_voltage_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph; kwargs...) where T <: AbstractWRForm
    variable_voltage_magnitude_sqr_from_ne(pm, n, h; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm, n, h; kwargs...)
    variable_voltage_product_ne(pm, n, h; kwargs...)
end

""
function variable_voltage_magnitude_sqr_from_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :ne_branch)

    var(pm, n, h)[:w_fr_ne] = @variable(pm.model,
        [i in ids(pm, n, h, :ne_branch)], basename="$(n)_$(h)_w_fr_ne",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(ref(pm, n, h, :bus), i, "w_fr_start", 1.001)
    )
end

""
function variable_voltage_magnitude_sqr_to_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T <: AbstractWRForm
    buses = ref(pm, n, h, :bus)
    branches = ref(pm, n, h, :ne_branch)

    var(pm, n, h)[:w_to_ne] = @variable(pm.model,
        [i in ids(pm, n, h, :ne_branch)], basename="$(n)_$(h)_w_to_ne",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"]^2,
        start = getstart(ref(pm, n, h, :bus), i, "w_to", 1.001)
    )
end

""
function variable_voltage_product_ne(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T <: AbstractWRForm
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, n, h, :ne_buspairs))
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, n, h, :ne_branch)])

    var(pm, n, h)[:wr_ne] = @variable(pm.model,
        [b in ids(pm, n, h, :ne_branch)], basename="$(n)_$(h)_wr_ne",
        lowerbound = min(0, wr_min[bi_bp[b]]),
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getstart(ref(pm, n, h, :ne_buspairs), bi_bp[b], "wr_start", 1.0)
    )

    var(pm, n, h)[:wi_ne] = @variable(pm.model,
        [b in ids(pm, n, h, :ne_branch)], basename="$(n)_$(h)_wi_ne",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]),
        start = getstart(ref(pm, n, h, :ne_buspairs), bi_bp[b], "wi_start")
    )
end





""
abstract type QCWRForm <: AbstractWRForm end

""
const QCWRPowerModel = GenericPowerModel{QCWRForm}

"default QC constructor"
function QCWRPowerModel(data::Dict{String,Any}; kwargs...)
    return GenericPowerModel(data, QCWRForm; kwargs...)
end


"Creates variables associated with differences in phase angles"
function variable_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    var(pm, n, h)[:td] = @variable(pm.model,
        [bp in ids(pm, n, h, :buspairs)], basename="$(n)_$(h)_td",
        lowerbound = ref(pm, n, h, :buspairs, bp)["angmin"],
        upperbound = ref(pm, n, h, :buspairs, bp)["angmax"],
        start = getstart(ref(pm, n, h, :buspairs), bp, "td_start")
    )
end

"Creates the voltage magnitude product variables"
function variable_voltage_magnitude_product(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    buspairs = ref(pm, n, h, :buspairs)
    var(pm, n, h)[:vv] = @variable(pm.model,
        [bp in keys(buspairs)], basename="$(n)_$(h)_vv",
        lowerbound = buspairs[bp]["vm_fr_min"]*buspairs[bp]["vm_to_min"],
        upperbound = buspairs[bp]["vm_fr_max"]*buspairs[bp]["vm_to_max"],
        start = getstart(buspairs, bp, "vv_start", 1.0)
    )
end

""
function variable_cosine(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    cos_min = Dict([(bp, -Inf) for bp in ids(pm, n, h, :buspairs)])
    cos_max = Dict([(bp,  Inf) for bp in ids(pm, n, h, :buspairs)])

    for (bp, buspair) in ref(pm, n, h, :buspairs)
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

    var(pm, n, h)[:cs] = @variable(pm.model,
        [bp in ids(pm, n, h, :buspairs)], basename="$(n)_$(h)_cs",
        lowerbound = cos_min[bp],
        upperbound = cos_max[bp],
        start = getstart(ref(pm, n, h, :buspairs), bp, "cs_start", 1.0)
    )
end

""
function variable_sine(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    var(pm, n, h)[:si] = @variable(pm.model,
        [bp in ids(pm, n, h, :buspairs)], basename="$(n)_$(h)_si",
        lowerbound = sin(ref(pm, n, h, :buspairs, bp)["angmin"]),
        upperbound = sin(ref(pm, n, h, :buspairs, bp)["angmax"]),
        start = getstart(ref(pm, n, h, :buspairs), bp, "si_start")
    )
end

""
function variable_current_magnitude_sqr(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    buspairs = ref(pm, n, h, :buspairs)
    var(pm, n, h)[:cm] = @variable(pm.model,
        cm[bp in ids(pm, n, h, :buspairs)], basename="$(n)_$(h)_cm",
        lowerbound = 0,
        upperbound = (buspairs[bp]["rate_a"]*buspairs[bp]["tap"]/buspairs[bp]["vm_fr_min"])^2,
        start = getstart(buspairs, bp, "cm_start")
    )
end

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph; kwargs...) where T <: QCWRForm
    variable_voltage_angle(pm, n, h; kwargs...)
    variable_voltage_magnitude(pm, n, h; kwargs...)

    variable_voltage_magnitude_sqr(pm, n, h; kwargs...)
    variable_voltage_product(pm, n, h; kwargs...)

    variable_voltage_angle_difference(pm, n, h; kwargs...)
    variable_voltage_magnitude_product(pm, n, h; kwargs...)
    variable_cosine(pm, n, h; kwargs...)
    variable_sine(pm, n, h; kwargs...)
    variable_current_magnitude_sqr(pm, n, h; kwargs...)
end

""
function constraint_voltage(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: QCWRForm
    v = var(pm, n, h, :vm)
    t = var(pm, n, h, :va)

    td = var(pm, n, h, :td)
    si = var(pm, n, h, :si)
    cs = var(pm, n, h, :cs)
    vv = var(pm, n, h, :vv)

    w  = var(pm, n, h, :w)
    wr = var(pm, n, h, :wr)
    wi = var(pm, n, h, :wi)

    for (i,b) in ref(pm, n, h, :bus)
        relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in ids(pm, n, h, :buspairs)
        i,j = bp
        @constraint(pm.model, t[i] - t[j] == td[bp])

        relaxation_sin(pm.model, td[bp], si[bp])
        relaxation_cos(pm.model, td[bp], cs[bp])
        relaxation_product(pm.model, v[i], v[j], vv[bp])
        relaxation_product(pm.model, vv[bp], cs[bp], wr[bp])
        relaxation_product(pm.model, vv[bp], si[bp], wi[bp])

        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in ref(pm, n, h, :branch)
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = ref(pm, n, h, :buspairs, pair)

        # to prevent this constraint from being posted on multiple parallel branches
        if buspair["branch"] == i
            constraint_power_magnitude_sqr(pm, i, nw=n, ph=h)
            constraint_power_magnitude_link(pm, i, nw=n, ph=h)
        end
    end

end

"`p[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]`"
function constraint_power_magnitude_sqr(pm::GenericPowerModel{T}, n::Int, h::Int, f_bus, t_bus, arc_from, tm) where T <: QCWRForm
    w_i  = var(pm, n, h, :w, f_bus)
    p_fr = var(pm, n, h, :p, arc_from)
    q_fr = var(pm, n, h, :q, arc_from)
    cm   = var(pm, n, h, :cm, (f_bus, t_bus))

    @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm^2*cm)
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link(pm::GenericPowerModel{T}, n::Int, h::Int, f_bus, t_bus, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm) where T <: QCWRForm
    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)
    q_fr = var(pm, n, h, :q, arc_from)
    wr = var(pm, n, h, :wr, (f_bus, t_bus))
    wi = var(pm, n, h, :wi, (f_bus, t_bus))
    cm = var(pm, n, h, :cm, (f_bus, t_bus))

    assert(g_fr == 0 && g_to == 0)
    c = b_fr + b_to

    # TODO: Derive updated constraint from first principles
    @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm^2 + w_to - 2*(tr*wr + ti*wi)/tm^2) - c*q_fr - ((c/2)/tm^2)^2*w_fr)
end

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, h::Int, i::Int) where T <: QCWRForm
    @constraint(pm.model, var(pm, n, h, :va)[i] == 0)
end

""
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, angmin, angmax) where T <: QCWRForm
    i, f_bus, t_bus = f_idx

    td = var(pm, n, h, :td, (f_bus, t_bus))

    if getlowerbound(td) < angmin
        setlowerbound(td, angmin)
    end

    if getupperbound(td) > angmax
        setupperbound(td, angmax)
    end

    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)
    wr   = var(pm, n, h, :wr, (f_bus, t_bus))
    wi   = var(pm, n, h, :wi, (f_bus, t_bus))

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)

    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end

""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: QCWRForm
    add_setpoint(sol, pm, "bus", "vm", :vm)
    add_setpoint(sol, pm, "bus", "va", :va)
end



""
function variable_voltage_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph; kwargs...) where T <: QCWRForm
    variable_voltage_angle(pm, n, h; kwargs...)
    variable_voltage_magnitude(pm, n, h; kwargs...)
    variable_voltage_magnitude_from_on_off(pm, n, h; kwargs...)
    variable_voltage_magnitude_to_on_off(pm, n, h; kwargs...)

    variable_voltage_magnitude_sqr(pm, n, h; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm, n, h; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm, n, h; kwargs...)

    variable_voltage_product_on_off(pm, n, h; kwargs...)

    variable_voltage_angle_difference_on_off(pm, n, h; kwargs...)
    variable_voltage_magnitude_product_on_off(pm, n, h; kwargs...)
    variable_cosine_on_off(pm, n, h; kwargs...)
    variable_sine_on_off(pm, n, h; kwargs...)
    variable_current_magnitude_sqr_on_off(pm, n, h; kwargs...) # includes 0, but needs new indexs
end

""
function variable_voltage_angle_difference_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    var(pm, n, h)[:td] = @variable(pm.model,
        [l in ids(pm, n, h, :branch)], basename="$(n)_$(h)_td",
        lowerbound = min(0, ref(pm, n, h, :branch, l)["angmin"]),
        upperbound = max(0, ref(pm, n, h, :branch, l)["angmax"]),
        start = getstart(ref(pm, n, h, :branch), l, "td_start")
    )
end

""
function variable_voltage_magnitude_product_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    branch = ref(pm, n, h, :branch)
    bus = ref(pm, n, h, :bus)

    vv_min = Dict([(l, bus[branch["f_bus"]]["vmin"]*bus[branch["t_bus"]]["vmin"]) for (l, branch) in branch])
    vv_max = Dict([(l, bus[branch["f_bus"]]["vmax"]*bus[branch["t_bus"]]["vmax"]) for (l, branch) in branch])

    var(pm, n, h)[:vv] = @variable(pm.model,
        [l in ids(pm, n, h, :branch)], basename="$(n)_$(h)_vv",
        lowerbound = min(0, vv_min[l]),
        upperbound = max(0, vv_max[l]),
        start = getstart(ref(pm, n, h, :branch), l, "vv_start", 1.0)
    )
end


""
function variable_cosine_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    cos_min = Dict([(l, -Inf) for l in ids(pm, n, h, :branch)])
    cos_max = Dict([(l,  Inf) for l in ids(pm, n, h, :branch)])

    for (l, branch) in ref(pm, n, h, :branch)
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

    var(pm, n, h)[:cs] = @variable(pm.model,
        [l in ids(pm, n, h, :branch)], basename="$(n)_$(h)_cs",
        lowerbound = min(0, cos_min[l]),
        upperbound = max(0, cos_max[l]),
        start = getstart(ref(pm, n, h, :branch), l, "cs_start", 1.0)
    )
end

""
function variable_sine_on_off(pm::GenericPowerModel, n::Int=pm.cnw, h::Int=pm.cph)
    var(pm, n, h)[:si] = @variable(pm.model,
        [l in ids(pm, n, h, :branch)], basename="$(n)_$(h)_si",
        lowerbound = min(0, sin(ref(pm, n, h, :branch, l)["angmin"])),
        upperbound = max(0, sin(ref(pm, n, h, :branch, l)["angmax"])),
        start = getstart(ref(pm, n, h, :branch), l, "si_start")
    )
end


""
function variable_current_magnitude_sqr_on_off(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T
    cm_min = Dict([(l, 0) for l in ids(pm, n, h, :branch)])
    cm_max = Dict([(l, (branch["rate_a"]*branch["tap"]/ref(pm, n, h, :bus)[branch["f_bus"]]["vmin"])^2) for (l, branch) in ref(pm, n, h, :branch)])

    var(pm, n, h)[:cm] = @variable(pm.model,
        [l in ids(pm, n, h, :branch)], basename="$(n)_$(h)_cm",
        lowerbound = cm_min[l],
        upperbound = cm_max[l],
        start = getstart(ref(pm, n, h, :branch), l, "cm_start")
    )
end


""
function constraint_voltage_on_off(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: QCWRForm
    v = var(pm, n, h, :vm)
    t = var(pm, n, h, :va)
    vm_fr = var(pm, n, h, :vm_fr)
    vm_to = var(pm, n, h, :vm_to)

    td = var(pm, n, h, :td)
    si = var(pm, n, h, :si)
    cs = var(pm, n, h, :cs)
    vv = var(pm, n, h, :vv)

    w = var(pm, n, h, :w)
    w_fr = var(pm, n, h, :w_fr)
    w_to = var(pm, n, h, :w_to)

    wr = var(pm, n, h, :wr)
    wi = var(pm, n, h, :wi)

    z = var(pm, n, h, :branch_z)

    td_lb = ref(pm, n, h, :off_angmin)
    td_ub = ref(pm, n, h, :off_angmax)
    td_max = max(abs(td_lb), abs(td_ub))

    for i in ids(pm, n, h, :bus)
        relaxation_sqr(pm.model, v[i], w[i])
    end

    constraint_voltage_magnitude_from_on_off(pm, n, h) # bounds on vm_fr
    constraint_voltage_magnitude_to_on_off(pm, n, h) # bounds on vm_to
    constraint_voltage_magnitude_sqr_from_on_off(pm, n, h) # bounds on w_fr
    constraint_voltage_magnitude_sqr_to_on_off(pm, n, h) # bounds on w_to
    constraint_voltage_product_on_off(pm, n, h) # bounds on wr, wi

    for (l, branch) in ref(pm, n, h, :branch)
        i = branch["f_bus"]
        j = branch["t_bus"]

        @constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        @constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))

        relaxation_sin_on_off(pm.model, td[l], si[l], z[l], td_max)
        relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)
        relaxation_product_on_off(pm.model, vm_fr[l], vm_to[l], vv[l], z[l])
        relaxation_product_on_off(pm.model, vv[l], cs[l], wr[l], z[l])
        relaxation_product_on_off(pm.model, vv[l], si[l], wi[l], z[l])

        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])

        #cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        relaxation_equality_on_off(pm.model, v[i], vm_fr[l], z[l])
        relaxation_equality_on_off(pm.model, v[j], vm_to[l], z[l])
        relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])

        # to prevent this constraint from being posted on multiple parallel branchs
        # TODO needs on/off variant
        constraint_power_magnitude_sqr_on_off(pm, l, nw=n, ph=h)
        constraint_power_magnitude_link_on_off(pm, l, nw=n, ph=h) # different index set
    end
end


"`p[arc_from]^2 + q[arc_from]^2 <= w[f_bus]/tm*cm[i]`"
function constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, arc_from, tm) where T <: QCWRForm
    w    = var(pm, n, h, :w, f_bus)
    p_fr = var(pm, n, h, :p, arc_from)
    q_fr = var(pm, n, h, :q, arc_from)
    cm   = var(pm, n, h, :cm, i)
    z    = var(pm, n, h, :branch_z, i)

    # TODO see if there is a way to leverage relaxation_complex_product_on_off here
    w_ub = getupperbound(w)
    cm_ub = getupperbound(cm)
    z_ub = getupperbound(z)

    @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm*z_ub/tm^2)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= w_ub*cm*z/tm^2)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm_ub*z/tm^2)
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link_on_off(pm::GenericPowerModel{T}, n::Int, h::Int, i, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm) where T <: QCWRForm
    w_fr = var(pm, n, h, :w_fr, i)
    w_to = var(pm, n, h, :w_to, i)
    q_fr = var(pm, n, h, :q, arc_from)
    wr   = var(pm, n, h, :wr, i)
    wi   = var(pm, n, h, :wi, i)
    cm   = var(pm, n, h, :cm, i)

    assert(g_fr == 0.0 && g_to == 0.0)
    c = b_fr + b_to

    # TODO: Derive updated constraint from first principles
    @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm^2 + w_to - 2*(tr*wr + ti*wi)/tm^2) - c*q_fr - ((c/2)/tm^2)^2*w_fr)
end


""
abstract type QCWRTriForm <: QCWRForm end

""
const QCWRTriPowerModel = GenericPowerModel{QCWRTriForm}

"default QC trilinear model constructor"
function QCWRTriPowerModel(data::Dict{String,Any}; kwargs...)
    return GenericPowerModel(data, QCWRTriForm; kwargs...)
end

""
function variable_voltage_magnitude_product(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T <: QCWRTriForm
    # do nothing - no lifted variables required for voltage variable product
end

"creates lambda variables for convex combination model"
function variable_multipliers(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph) where T <: QCWRTriForm
    var(pm, n, h)[:lambda_wr] = @variable(pm.model,
        [bp in ids(pm, n, h, :buspairs), i=1:8], basename="$(n)_lambda",
        lowerbound = 0, upperbound = 1)

    var(pm, n, h)[:lambda_wi] = @variable(pm.model,
        [bp in ids(pm, n, h, :buspairs), i=1:8], basename="$(n)_lambda",
        lowerbound = 0, upperbound = 1)
end

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw, h::Int=pm.cph; kwargs...) where T <: QCWRTriForm
    variable_voltage_angle(pm, n, h; kwargs...)
    variable_voltage_magnitude(pm, n, h; kwargs...)

    variable_voltage_magnitude_sqr(pm, n, h; kwargs...)
    variable_voltage_product(pm, n, h; kwargs...)

    variable_voltage_angle_difference(pm, n, h; kwargs...)
    variable_voltage_magnitude_product(pm, n, h; kwargs...)
    variable_multipliers(pm, n, h; kwargs...)
    variable_cosine(pm, n, h; kwargs...)
    variable_sine(pm, n, h; kwargs...)
    variable_current_magnitude_sqr(pm, n, h; kwargs...)
end

""
function constraint_voltage(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: QCWRTriForm
    v = var(pm, n, h, :vm)
    t = var(pm, n, h, :va)

    td = var(pm, n, h, :td)
    si = var(pm, n, h, :si)
    cs = var(pm, n, h, :cs)

    w = var(pm, n, h, :w)
    wr = var(pm, n, h, :wr)
    lambda_wr = var(pm, n, h, :lambda_wr)
    wi = var(pm, n, h, :wi)
    lambda_wi = var(pm, n, h, :lambda_wi)

    for (i,b) in ref(pm, n, h, :bus)
        relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in ids(pm, n, h, :buspairs)
        i,j = bp
        @constraint(pm.model, t[i] - t[j] == td[bp])

        relaxation_sin(pm.model, td[bp], si[bp])
        relaxation_cos(pm.model, td[bp], cs[bp])
        relaxation_trilinear(pm.model, v[i], v[j], cs[bp], wr[bp], lambda_wr[bp,:])
        relaxation_trilinear(pm.model, v[i], v[j], si[bp], wi[bp], lambda_wi[bp,:])

        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in ref(pm, n, h, :branch)
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = ref(pm, n, h, :buspairs, pair)

        # to prevent this constraint from being posted on multiple parallel branchs
        if buspair["branch"] == i
            constraint_power_magnitude_sqr(pm, i, nw=n, ph=h)
            constraint_power_magnitude_link(pm, i, nw=n, ph=h)
        end
    end

end
