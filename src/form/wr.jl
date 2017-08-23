export
    SOCWRPowerModel, SOCWRForm,
    QCWRPowerModel, QCWRForm

""
@compat abstract type AbstractWRForm <: AbstractPowerFormulation end

""
@compat abstract type SOCWRForm <: AbstractWRForm end

""
const SOCWRPowerModel = GenericPowerModel{SOCWRForm}

"default SOC constructor"
SOCWRPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SOCWRForm; kwargs...)

""
function variable_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

""
function constraint_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = pm.var[:w]
    wr = pm.var[:wr]
    wi = pm.var[:wi]

    for (i,j) in keys(pm.ref[:buspairs])
        relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

"Do nothing, no way to represent this in these variables"
constraint_theta_ref{T <: AbstractWRForm}(pm::GenericPowerModel{T}, ref_bus::Int) = Set()


"""
```
sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w[i]
sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w[i]
```
"""
function constraint_kcl_shunt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    w = pm.var[:w][i]
    p = pm.var[:p]
    q = pm.var[:q]
    p_ne = pm.var[:p_ne]
    q_ne = pm.var[:q_ne]
    pg = pm.var[:pg]
    qg = pm.var[:qg]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
end



"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w_fr_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])
q[f_idx] == -(b+c/2)/tm*w_fr_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])
```
"""
function constraint_ohms_yt_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p_ne][f_idx]
    q_fr = pm.var[:q_ne][f_idx]
    w_fr = pm.var[:w_fr_ne][i]
    wr = pm.var[:wr_ne][i]
    wi = pm.var[:wi_ne][i]

    @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] == g*w_to_ne[i] + (-g*tr-b*ti)/tm*(wr_ne[i]) + (-b*tr+g*ti)/tm*(-wi_ne[i])
q[t_idx] == -(b+c/2)*w_to_ne[i] - (-b*tr+g*ti)/tm*(wr_ne[i]) + (-g*tr-b*ti)/tm*(-wi_ne[i])
```
"""
function constraint_ohms_yt_to_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = pm.var[:p_ne][t_idx]
    q_to = pm.var[:q_ne][t_idx]
    w_to = pm.var[:w_to_ne][i]
    wr = pm.var[:wr_ne][i]
    wi = pm.var[:wi_ne][i]

    @constraint(pm.model, p_to == g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

""
function constraint_voltage_angle_difference{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    w_fr = pm.var[:w][f_bus]
    w_to = pm.var[:w][t_bus]
    wr = pm.var[:wr][(f_bus, t_bus)]
    wi = pm.var[:wi][(f_bus, t_bus)]

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)
    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end

""
function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :va; default_value = 0)
end

""
function variable_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_voltage_product_on_off(pm; kwargs...)
end

""
function constraint_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = pm.var[:w]
    wr = pm.var[:wr]
    wi = pm.var[:wi]
    z = pm.var[:line_z]

    w_fr = pm.var[:w_fr]
    w_to = pm.var[:w_to]

    constraint_voltage_magnitude_sqr_from_on_off(pm)
    constraint_voltage_magnitude_sqr_to_on_off(pm)
    constraint_voltage_product_on_off(pm)

    for (l,i,j) in pm.ref[:arcs_from]
        relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
    end
end

""
function constraint_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]

    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:ne_buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in branches])

    w = pm.var[:w]
    wr = pm.var[:wr_ne]
    wi = pm.var[:wi_ne]
    z = pm.var[:line_ne]

    w_fr = pm.var[:w_fr_ne]
    w_to = pm.var[:w_to_ne]

    for (l,i,j) in pm.ref[:ne_arcs_from]
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
function constraint_voltage_magnitude_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    vm_fr = pm.var[:vm_fr]
    z = pm.var[:line_z]

    for (i, branch) in pm.ref[:branch]
        @constraint(pm.model, vm_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"])
        @constraint(pm.model, vm_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"])
    end
end

""
function constraint_voltage_magnitude_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    vm_to = pm.var[:vm_to]
    z = pm.var[:line_z]

    for (i, branch) in pm.ref[:branch]
        @constraint(pm.model, vm_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"])
        @constraint(pm.model, vm_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"])
    end
end


""
function constraint_voltage_magnitude_sqr_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_fr = pm.var[:w_fr]
    z = pm.var[:line_z]

    for (i, branch) in pm.ref[:branch]
        @constraint(pm.model, w_fr[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        @constraint(pm.model, w_fr[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_magnitude_sqr_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_to = pm.var[:w_to]
    z = pm.var[:line_z]

    for (i, branch) in pm.ref[:branch]
        @constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        @constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
    end
end

""
function constraint_voltage_product_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    wr = pm.var[:wr]
    wi = pm.var[:wi]
    z = pm.var[:line_z]

    for b in keys(pm.ref[:branch])
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
function constraint_ohms_yt_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    w_fr = pm.var[:w_fr][i]
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]

    @constraint(pm.model, p_fr ==        g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[t_idx] ==        g*w_to[i] + (-g*tr-b*ti)/tm*(wr[i]) + (-b*tr+g*ti)/tm*(-wi[i])
q[t_idx] == -(b+c/2)*w_to[i] - (-b*tr+g*ti)/tm*(wr[i]) + (-g*tr-b*ti)/tm*(-wi[i])
```
"""
function constraint_ohms_yt_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    w_to = pm.var[:w_to][i]
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]

    @constraint(pm.model, p_to ==        g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

"`angmin*wr[i] <= wi[i] <= angmax*wr[i]`"
function constraint_voltage_angle_difference_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)
end

"`angmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]`"
function constraint_voltage_angle_difference_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = pm.var[:wr_ne][i]
    wi = pm.var[:wi_ne][i]

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)
end

""
function variable_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr_from_ne(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm; kwargs...)
    variable_voltage_product_ne(pm; kwargs...)
end

""
function variable_voltage_magnitude_sqr_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]

    pm.var[:w_fr_ne] = @variable(pm.model,
        [i in keys(pm.ref[:ne_branch])], basename="w_fr_ne",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:bus], i, "w_fr_start", 1.001)
    )
end

""
function variable_voltage_magnitude_sqr_to_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]
    
    pm.var[:w_to_ne] = @variable(pm.model,
        [i in keys(pm.ref[:ne_branch])], basename="w_to_ne",
        lowerbound = 0,
        upperbound = buses[branches[i]["t_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:bus], i, "w_to", 1.001)
    )
end

""
function variable_voltage_product_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:ne_buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:ne_branch]])
    
    pm.var[:wr_ne] = @variable(pm.model,
        [b in keys(pm.ref[:ne_branch])], basename="wr_ne",
        lowerbound = min(0, wr_min[bi_bp[b]]), 
        upperbound = max(0, wr_max[bi_bp[b]]),
        start = getstart(pm.ref[:ne_buspairs], bi_bp[b], "wr_start", 1.0)
    )
    
    pm.var[:wi_ne] = @variable(pm.model,
        [b in keys(pm.ref[:ne_branch])], basename="wi_ne",
        lowerbound = min(0, wi_min[bi_bp[b]]),
        upperbound = max(0, wi_max[bi_bp[b]]), 
        start = getstart(pm.ref[:ne_buspairs], bi_bp[b], "wi_start")
    )
end

""
@compat abstract type QCWRForm <: AbstractWRForm end

""
const QCWRPowerModel = GenericPowerModel{QCWRForm}

"default QC constructor"
function QCWRPowerModel(data::Dict{String,Any}; kwargs...)
    return GenericPowerModel(data, QCWRForm; kwargs...)
end




"Creates variables associated with differences in phase angles"
function variable_voltage_angle_difference{T}(pm::GenericPowerModel{T})
    pm.var[:td] = @variable(pm.model,
        [bp in keys(pm.ref[:buspairs])], basename="td",
        lowerbound = pm.ref[:buspairs][bp]["angmin"],
        upperbound = pm.ref[:buspairs][bp]["angmax"], 
        start = getstart(pm.ref[:buspairs], bp, "td_start")
    )
end

"Creates the voltage magnitude product variables"
function variable_voltage_magnitude_product{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    pm.var[:vv] = @variable(pm.model, 
        [bp in keys(pm.ref[:buspairs])], basename="vv",
        lowerbound = buspairs[bp]["vm_fr_min"]*buspairs[bp]["vm_to_min"],
        upperbound = buspairs[bp]["vm_fr_max"]*buspairs[bp]["vm_to_max"],
        start = getstart(pm.ref[:buspairs], bp, "vv_start", 1.0)
    )
end

""
function variable_cosine{T}(pm::GenericPowerModel{T})
    cos_min = Dict([(bp, -Inf) for bp in keys(pm.ref[:buspairs])])
    cos_max = Dict([(bp,  Inf) for bp in keys(pm.ref[:buspairs])])

    for (bp, buspair) in pm.ref[:buspairs]
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

    pm.var[:cs] = @variable(pm.model,
        [bp in keys(pm.ref[:buspairs])], basename="cs",
        lowerbound = cos_min[bp],
        upperbound = cos_max[bp],
        start = getstart(pm.ref[:buspairs], bp, "cs_start", 1.0)
    )
end

""
function variable_sine(pm::GenericPowerModel)
    pm.var[:si] = @variable(pm.model, 
        [bp in keys(pm.ref[:buspairs])], basename="si",
        lowerbound = sin(pm.ref[:buspairs][bp]["angmin"]),
        upperbound = sin(pm.ref[:buspairs][bp]["angmax"]), 
        start = getstart(pm.ref[:buspairs], bp, "si_start")
    )
end

""
function variable_current_magnitude_sqr{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    pm.var[:cm] = @variable(pm.model,
        cm[bp in keys(pm.ref[:buspairs])], basename="cm",
        lowerbound = 0,
        upperbound = (buspairs[bp]["rate_a"]*buspairs[bp]["tap"]/buspairs[bp]["vm_fr_min"])^2,
        start = getstart(pm.ref[:buspairs], bp, "cm_start")
    )
end

""
function variable_voltage(pm::QCWRPowerModel; kwargs...)
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
function constraint_voltage(pm::QCWRPowerModel)
    v = pm.var[:vm]
    t = pm.var[:va]

    td = pm.var[:td]
    si = pm.var[:si]
    cs = pm.var[:cs]
    vv = pm.var[:vv]

    w = pm.var[:w]
    wr = pm.var[:wr]
    wi = pm.var[:wi]

    for (i,b) in pm.ref[:bus]
        relaxation_sqr(pm.model, v[i], w[i])
    end

    for bp in keys(pm.ref[:buspairs])
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

   for (i,branch) in pm.ref[:branch]
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = pm.ref[:buspairs][pair]

        # to prevent this constraint from being posted on multiple parallel lines
        if buspair["line"] == i
            constraint_power_magnitude_sqr(pm, branch)
            constraint_power_magnitude_link(pm, branch)
        end
    end

end

"`p[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]`"
function constraint_power_magnitude_sqr(pm::QCWRPowerModel, f_bus, t_bus, arc_from, tm)
    w_i = pm.var[:w][f_bus]
    p_fr = pm.var[:p][arc_from]
    q_fr = pm.var[:q][arc_from]
    cm = pm.var[:cm][(f_bus, t_bus)]

    @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm*cm)
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link(pm::QCWRPowerModel, f_bus, t_bus, arc_from, g, b, c, tr, ti, tm)
    w_fr = pm.var[:w][f_bus]
    w_to = pm.var[:w][t_bus]
    q_fr = pm.var[:q][arc_from]
    wr = pm.var[:wr][(f_bus, t_bus)]
    wi = pm.var[:wi][(f_bus, t_bus)]
    cm = pm.var[:cm][(f_bus, t_bus)]

    @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
end

"`t[ref_bus] == 0`"
constraint_theta_ref(pm::QCWRPowerModel, ref_bus::Int) =
    Set([@constraint(pm.model, pm.var[:va][ref_bus] == 0)])

""
function constraint_voltage_angle_difference(pm::QCWRPowerModel, f_bus, t_bus, angmin, angmax)
    td = pm.var[:td][(f_bus, t_bus)]

    if getlowerbound(td) < angmin
        setlowerbound(td, angmin)
    end

    if getupperbound(td) > angmax
        setupperbound(td, angmax)
    end

    w_fr = pm.var[:w][f_bus]
    w_to = pm.var[:w][t_bus]
    wr = pm.var[:wr][(f_bus, t_bus)]
    wi = pm.var[:wi][(f_bus, t_bus)]

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)

    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end

""
function add_bus_voltage_setpoint(sol, pm::QCWRPowerModel)
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :vm)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :va)
end




""
function variable_voltage_on_off(pm::QCWRPowerModel; kwargs...)
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
function variable_voltage_angle_difference_on_off{T}(pm::GenericPowerModel{T})
    pm.var[:td] = @variable(pm.model,
        td[l in keys(pm.ref[:branch])], basename="td",
        lowerbound = min(0, pm.ref[:branch][l]["angmin"]),
        upperbound = max(0, pm.ref[:branch][l]["angmax"]),
        start = getstart(pm.ref[:branch], l, "td_start")
    )
end

""
function variable_voltage_magnitude_product_on_off{T}(pm::GenericPowerModel{T})
    vv_min = Dict([(l, pm.ref[:bus][branch["f_bus"]]["vmin"]*pm.ref[:bus][branch["t_bus"]]["vmin"]) for (l, branch) in pm.ref[:branch]])
    vv_max = Dict([(l, pm.ref[:bus][branch["f_bus"]]["vmax"]*pm.ref[:bus][branch["t_bus"]]["vmax"]) for (l, branch) in pm.ref[:branch]])

    pm.var[:vv] = @variable(pm.model,
        [l in keys(pm.ref[:branch])], basename="vv",
        lowerbound = min(0, vv_min[l]),
        upperbound = max(0, vv_max[l]),
        start = getstart(pm.ref[:branch], l, "vv_start", 1.0)
    )
end


""
function variable_cosine_on_off{T}(pm::GenericPowerModel{T})
    cos_min = Dict([(l, -Inf) for l in keys(pm.ref[:branch])])
    cos_max = Dict([(l,  Inf) for l in keys(pm.ref[:branch])])

    for (l, branch) in pm.ref[:branch]
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

    pm.var[:cs] = @variable(pm.model, 
        [l in keys(pm.ref[:branch])], basename="cs",
        lowerbound = min(0, cos_min[l]),
        upperbound = max(0, cos_max[l]), 
        start = getstart(pm.ref[:branch], l, "cs_start", 1.0)
    )
end

""
function variable_sine_on_off(pm::GenericPowerModel)
    pm.var[:si] = @variable(pm.model, 
        [l in keys(pm.ref[:branch])], basename="si",
        lowerbound = min(0, sin(pm.ref[:branch][l]["angmin"])),
        upperbound = max(0, sin(pm.ref[:branch][l]["angmax"])),
        start = getstart(pm.ref[:branch], l, "si_start")
    )
end


""
function variable_current_magnitude_sqr_on_off{T}(pm::GenericPowerModel{T})
    cm_min = Dict([(l, 0) for l in keys(pm.ref[:branch])])
    cm_max = Dict([(l, (branch["rate_a"]*branch["tap"]/pm.ref[:bus][branch["f_bus"]]["vmin"])^2) for (l, branch) in pm.ref[:branch]])

    pm.var[:cm] = @variable(pm.model,
        [l in keys(pm.ref[:branch])], basename="cm",
        lowerbound = cm_min[l],
        upperbound = cm_max[l],
        start = getstart(pm.ref[:branch], l, "cm_start")
    )
end


""
function constraint_voltage_on_off(pm::QCWRPowerModel)
    v = pm.var[:vm]
    t = pm.var[:va]
    vm_fr = pm.var[:vm_fr]
    vm_to = pm.var[:vm_to]

    td = pm.var[:td]
    si = pm.var[:si]
    cs = pm.var[:cs]
    vv = pm.var[:vv]

    w = pm.var[:w]
    w_fr = pm.var[:w_fr]
    w_to = pm.var[:w_to]

    wr = pm.var[:wr]
    wi = pm.var[:wi]

    z = pm.var[:line_z]

    td_lb = pm.ref[:off_angmin]
    td_ub = pm.ref[:off_angmax]
    td_max = max(abs(td_lb), abs(td_ub))

    for (i,b) in pm.ref[:bus]
        relaxation_sqr(pm.model, v[i], w[i])
    end

    constraint_voltage_magnitude_from_on_off(pm) # bounds on vm_fr
    constraint_voltage_magnitude_to_on_off(pm) # bounds on vm_to
    constraint_voltage_magnitude_sqr_from_on_off(pm) # bounds on w_fr
    constraint_voltage_magnitude_sqr_to_on_off(pm) # bounds on w_to
    constraint_voltage_product_on_off(pm) # bounds on wr, wi

    for (l,branch) in pm.ref[:branch]
        i = branch["f_bus"]
        j = branch["t_bus"]

        @constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        @constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))

        relaxation_sin_on_off(pm.model, td[l], si[l], z[l], td_max)
        relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)
        relaxation_product_on_off(pm.model, vm_fr[i], vm_to[j], vv[l], z[l])
        relaxation_product_on_off(pm.model, vv[l], cs[l], wr[l], z[l])
        relaxation_product_on_off(pm.model, vv[l], si[l], wi[l], z[l])

        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])

        #cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        relaxation_equality_on_off(pm.model, v[i], vm_fr[l], z[l])
        relaxation_equality_on_off(pm.model, v[j], vm_to[l], z[l])
        relaxation_equality_on_off(pm.model, w[i], w_fr[l], z[l])
        relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])

        # to prevent this constraint from being posted on multiple parallel lines
        # TODO needs on/off variant
        constraint_power_magnitude_sqr_on_off(pm, branch)
        constraint_power_magnitude_link_on_off(pm, branch) # different index set
    end
end


"`p[arc_from]^2 + q[arc_from]^2 <= w[f_bus]/tm*cm[i]`"
function constraint_power_magnitude_sqr_on_off(pm::QCWRPowerModel, i, f_bus, arc_from, tm)
    w = pm.var[:w][f_bus]
    p_fr = pm.var[:p][arc_from]
    q_fr = pm.var[:q][arc_from]
    cm = pm.var[:cm][i]
    z = pm.var[:line_z][i]

    # TODO see if there is a way to leverage relaxation_complex_product_on_off here
    w_ub = getupperbound(w)
    cm_ub = getupperbound(cm)
    z_ub = getupperbound(z)

    @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm*z_ub/tm)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= w_ub*cm*z/tm)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm_ub*z/tm)
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link_on_off(pm::QCWRPowerModel, i, arc_from, g, b, c, tr, ti, tm)
    w_fr = pm.var[:w_fr][i]
    w_to = pm.var[:w_to][i]
    q_fr = pm.var[:q][arc_from]
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]
    cm = pm.var[:cm][i]

    @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
end
