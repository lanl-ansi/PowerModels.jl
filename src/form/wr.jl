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

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c1, c2])
end



"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] == g/tm*w_from_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])
q[f_idx] == -(b+c/2)/tm*w_from_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])
```
"""
function constraint_ohms_yt_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p_ne][f_idx]
    q_fr = pm.var[:q_ne][f_idx]
    w_fr = pm.var[:w_from_ne][i]
    wr = pm.var[:wr_ne][i]
    wi = pm.var[:wi_ne][i]

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    return Set([c1, c2])
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

    c1 = @constraint(pm.model, p_to == g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

""
function constraint_phase_angle_difference{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    w_fr = pm.var[:w][f_bus]
    w_to = pm.var[:w][t_bus]
    wr = pm.var[:wr][(f_bus, t_bus)]
    wi = pm.var[:wi][(f_bus, t_bus)]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)
    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    return Set([c1, c2, c3])
end

""
function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
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

    w_from = pm.var[:w_from]
    w_to = pm.var[:w_to]

    cs = Set()
    cs1 = constraint_voltage_magnitude_sqr_from_on_off(pm)
    cs2 = constraint_voltage_magnitude_sqr_to_on_off(pm)
    cs3 = constraint_voltage_product_on_off(pm)
    cs = union(cs, cs1, cs2, cs3)

    for (l,i,j) in pm.ref[:arcs_from]
        cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        cs5 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        cs6 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        cs = union(cs, cs4, cs5, cs6)
    end

    return cs
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

    w_from = pm.var[:w_from_ne]
    w_to = pm.var[:w_to_ne]

    cs = Set()
    for (l,i,j) in pm.ref[:ne_arcs_from]
        c1 = @constraint(pm.model, w_from[l] <= z[l]*buses[branches[l]["f_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_from[l] >= z[l]*buses[branches[l]["f_bus"]]["vmin"]^2)

        c3 = @constraint(pm.model, wr[l] <= z[l]*wr_max[bi_bp[l]])
        c4 = @constraint(pm.model, wr[l] >= z[l]*wr_min[bi_bp[l]])
        c5 = @constraint(pm.model, wi[l] <= z[l]*wi_max[bi_bp[l]])
        c6 = @constraint(pm.model, wi[l] >= z[l]*wi_min[bi_bp[l]])

        c7 = @constraint(pm.model, w_to[l] <= z[l]*buses[branches[l]["t_bus"]]["vmax"]^2)
        c8 = @constraint(pm.model, w_to[l] >= z[l]*buses[branches[l]["t_bus"]]["vmin"]^2)

        c9 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        c10 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        c11 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        cs = Set([cs, c1, c2, c3, c4, c5, c6, c7, c8,c9, c10, c11])
    end
    return cs
end


""
function constraint_voltage_magnitude_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    v_from = pm.var[:v_from]
    z = pm.var[:line_z]

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, v_from[i] <= z[i]*buses[branch["f_bus"]]["vmax"])
        c2 = @constraint(pm.model, v_from[i] >= z[i]*buses[branch["f_bus"]]["vmin"])
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

""
function constraint_voltage_magnitude_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    v_to = pm.var[:v_to]
    z = pm.var[:line_z]

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, v_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"])
        c2 = @constraint(pm.model, v_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"])
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end


""
function constraint_voltage_magnitude_sqr_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_from = pm.var[:w_from]
    z = pm.var[:line_z]

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, w_from[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_from[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

""
function constraint_voltage_magnitude_sqr_to_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_to = pm.var[:w_to]
    z = pm.var[:line_z]

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

""
function constraint_voltage_product_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    wr = pm.var[:wr]
    wi = pm.var[:wi]
    z = pm.var[:line_z]

    cs = Set()
    for b in keys(pm.ref[:branch])
        c1 = @constraint(pm.model, wr[b] <= z[b]*wr_max[bi_bp[b]])
        c2 = @constraint(pm.model, wr[b] >= z[b]*wr_min[bi_bp[b]])
        c3 = @constraint(pm.model, wi[b] <= z[b]*wi_max[bi_bp[b]])
        c4 = @constraint(pm.model, wi[b] >= z[b]*wi_min[bi_bp[b]])
        push!(cs, c1)
        push!(cs, c2)
        push!(cs, c3)
        push!(cs, c4)
    end
    return cs
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)

```
p[f_idx] ==        g/tm*w_from[i] + (-g*tr+b*ti)/tm*(wr[i]) + (-b*tr-g*ti)/tm*(wi[i])
q[f_idx] == -(b+c/2)/tm*w_from[i] - (-b*tr-g*ti)/tm*(wr[i]) + (-g*tr+b*ti)/tm*(wi[i])
```
"""
function constraint_ohms_yt_from_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    w_fr = pm.var[:w_from][i]
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]

    c1 = @constraint(pm.model, p_fr ==        g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    return Set([c1, c2])
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

    c1 = @constraint(pm.model, p_to ==        g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to == -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

"`angmin*wr[i] <= wi[i] <= angmax*wr[i]`"
function constraint_phase_angle_difference_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)
    return Set([c1, c2])
end

"`angmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]`"
function constraint_phase_angle_difference_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = pm.var[:wr_ne][i]
    wi = pm.var[:wi_ne][i]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)
    return Set([c1, c2])
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

    pm.var[:w_from_ne] = @variable(pm.model,
        [i in keys(pm.ref[:ne_branch])], basename="w_from_ne",
        lowerbound = 0,
        upperbound = buses[branches[i]["f_bus"]]["vmax"]^2,
        start = getstart(pm.ref[:bus], i, "w_from_start", 1.001)
    )

    return pm.var[:w_from_ne]
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

    return pm.var[:w_to_ne]
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

    return pm.var[:wr_ne], pm.var[:wi_ne]
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
function variable_phase_angle_difference{T}(pm::GenericPowerModel{T})
    pm.var[:td] = @variable(pm.model,
        [bp in keys(pm.ref[:buspairs])], basename="td",
        lowerbound = pm.ref[:buspairs][bp]["angmin"],
        upperbound = pm.ref[:buspairs][bp]["angmax"], 
        start = getstart(pm.ref[:buspairs], bp, "td_start")
    )
    return pm.var[:td]
end

"Creates the voltage magnitude product variables"
function variable_voltage_magnitude_product{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    pm.var[:vv] = @variable(pm.model, 
        [bp in keys(pm.ref[:buspairs])], basename="vv",
        lowerbound = buspairs[bp]["v_from_min"]*buspairs[bp]["v_to_min"],
        upperbound = buspairs[bp]["v_from_max"]*buspairs[bp]["v_to_max"],
        start = getstart(pm.ref[:buspairs], bp, "vv_start", 1.0)
    )
    return pm.var[:vv]
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
    return pm.var[:cs]
end

""
function variable_sine(pm::GenericPowerModel)
    pm.var[:si] = @variable(pm.model, 
        [bp in keys(pm.ref[:buspairs])], basename="si",
        lowerbound = sin(pm.ref[:buspairs][bp]["angmin"]),
        upperbound = sin(pm.ref[:buspairs][bp]["angmax"]), 
        start = getstart(pm.ref[:buspairs], bp, "si_start")
    )
    return pm.var[:si]
end

""
function variable_current_magnitude_sqr{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    pm.var[:cm] = @variable(pm.model,
        cm[bp in keys(pm.ref[:buspairs])], basename="cm",
        lowerbound = 0,
        upperbound = (buspairs[bp]["rate_a"]*buspairs[bp]["tap"]/buspairs[bp]["v_from_min"])^2,
        start = getstart(pm.ref[:buspairs], bp, "cm_start")
    )
    return pm.var[:cm]
end

""
function variable_voltage(pm::QCWRPowerModel; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)

    variable_phase_angle_difference(pm; kwargs...)
    variable_voltage_magnitude_product(pm; kwargs...)
    variable_cosine(pm; kwargs...)
    variable_sine(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

""
function constraint_voltage(pm::QCWRPowerModel)
    v = pm.var[:v]
    t = pm.var[:t]

    td = pm.var[:td]
    si = pm.var[:si]
    cs = pm.var[:cs]
    vv = pm.var[:vv]

    w = pm.var[:w]
    wr = pm.var[:wr]
    wi = pm.var[:wi]

    const_set = Set()
    for (i,b) in pm.ref[:bus]
        cs1 = relaxation_sqr(pm.model, v[i], w[i])
        const_set = union(const_set, cs1)
    end

    for bp in keys(pm.ref[:buspairs])
        i,j = bp
        c1 = @constraint(pm.model, t[i] - t[j] == td[bp])
        push!(const_set, c1)

        cs1 = relaxation_sin(pm.model, td[bp], si[bp])
        cs2 = relaxation_cos(pm.model, td[bp], cs[bp])
        cs3 = relaxation_product(pm.model, v[i], v[j], vv[bp])
        cs4 = relaxation_product(pm.model, vv[bp], cs[bp], wr[bp])
        cs5 = relaxation_product(pm.model, vv[bp], si[bp], wi[bp])

        const_set = union(const_set, cs1, cs2, cs3, cs4, cs5)
        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in pm.ref[:branch]
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = pm.ref[:buspairs][pair]

        # to prevent this constraint from being posted on multiple parallel lines
        if buspair["line"] == i
            cs1 = constraint_power_magnitude_sqr(pm, branch)
            cs2 = constraint_power_magnitude_link(pm, branch)
            const_set = union(const_set, cs1, cs2)
        end
    end

    return const_set
end

"`p[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]`"
function constraint_power_magnitude_sqr(pm::QCWRPowerModel, f_bus, t_bus, arc_from, tm)
    w_i = pm.var[:w][f_bus]
    p_fr = pm.var[:p][arc_from]
    q_fr = pm.var[:q][arc_from]
    cm = pm.var[:cm][(f_bus, t_bus)]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm*cm)
    return Set([c])
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link(pm::QCWRPowerModel, f_bus, t_bus, arc_from, g, b, c, tr, ti, tm)
    w_fr = pm.var[:w][f_bus]
    w_to = pm.var[:w][t_bus]
    q_fr = pm.var[:q][arc_from]
    wr = pm.var[:wr][(f_bus, t_bus)]
    wi = pm.var[:wi][(f_bus, t_bus)]
    cm = pm.var[:cm][(f_bus, t_bus)]

    c = @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
    return Set([c])
end

"`t[ref_bus] == 0`"
constraint_theta_ref(pm::QCWRPowerModel, ref_bus::Int) =
    Set([@constraint(pm.model, pm.var[:t][ref_bus] == 0)])

""
function constraint_phase_angle_difference(pm::QCWRPowerModel, f_bus, t_bus, angmin, angmax)
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

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)

    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    return Set([c1, c2, c3])
end

""
function add_bus_voltage_setpoint(sol, pm::QCWRPowerModel)
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end




""
function variable_voltage_on_off(pm::QCWRPowerModel; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
    variable_voltage_magnitude_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_to_on_off(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_voltage_product_on_off(pm; kwargs...)

    variable_phase_angle_difference_on_off(pm; kwargs...)
    variable_voltage_magnitude_product_on_off(pm; kwargs...)
    variable_cosine_on_off(pm; kwargs...)
    variable_sine_on_off(pm; kwargs...)
    variable_current_magnitude_sqr_on_off(pm; kwargs...) # includes 0, but needs new indexs
end

""
function variable_phase_angle_difference_on_off{T}(pm::GenericPowerModel{T})
    pm.var[:td] = @variable(pm.model,
        td[l in keys(pm.ref[:branch])], basename="td",
        lowerbound = min(0, pm.ref[:branch][l]["angmin"]),
        upperbound = max(0, pm.ref[:branch][l]["angmax"]),
        start = getstart(pm.ref[:branch], l, "td_start")
    )
    return pm.var[:td]
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

    return pm.var[:vv]
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

    return pm.var[:cs]
end

""
function variable_sine_on_off(pm::GenericPowerModel)
    pm.var[:si] = @variable(pm.model, 
        [l in keys(pm.ref[:branch])], basename="si",
        lowerbound = min(0, sin(pm.ref[:branch][l]["angmin"])),
        upperbound = max(0, sin(pm.ref[:branch][l]["angmax"])),
        start = getstart(pm.ref[:branch], l, "si_start")
    )
    return pm.var[:si]
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

    return pm.var[:cm]
end


""
function constraint_voltage_on_off(pm::QCWRPowerModel)
    v = pm.var[:v]
    t = pm.var[:t]
    v_from = pm.var[:v_from]
    v_to = pm.var[:v_to]

    td = pm.var[:td]
    si = pm.var[:si]
    cs = pm.var[:cs]
    vv = pm.var[:vv]

    w = pm.var[:w]
    w_from = pm.var[:w_from]
    w_to = pm.var[:w_to]

    wr = pm.var[:wr]
    wi = pm.var[:wi]

    z = pm.var[:line_z]

    td_lb = pm.ref[:off_angmin]
    td_ub = pm.ref[:off_angmax]
    td_max = max(abs(td_lb), abs(td_ub))

    #cs = Set()
    for (i,b) in pm.ref[:bus]
        cs1 = relaxation_sqr(pm.model, v[i], w[i])
        #cs = union(cs, cs1)
    end

    cs1 = constraint_voltage_magnitude_from_on_off(pm) # bounds on v_from
    cs2 = constraint_voltage_magnitude_to_on_off(pm) # bounds on v_to
    cs3 = constraint_voltage_magnitude_sqr_from_on_off(pm) # bounds on w_from
    cs4 = constraint_voltage_magnitude_sqr_to_on_off(pm) # bounds on w_to
    cs5 = constraint_voltage_product_on_off(pm) # bounds on wr, wi
    #cs = union(cs, cs1, cs2, cs3, cs4, cs5)

    for (l,branch) in pm.ref[:branch]
        i = branch["f_bus"]
        j = branch["t_bus"]

        c1 = @constraint(pm.model, t[i] - t[j] >= td[l] + td_lb*(1-z[l]))
        c2 = @constraint(pm.model, t[i] - t[j] <= td[l] + td_ub*(1-z[l]))
        #cs = union(cs, Set([c1, c2]))

        cs1 = relaxation_sin_on_off(pm.model, td[l], si[l], z[l], td_max)
        cs2 = relaxation_cos_on_off(pm.model, td[l], cs[l], z[l], td_max)
        cs3 = relaxation_product_on_off(pm.model, v_from[i], v_to[j], vv[l], z[l])
        cs4 = relaxation_product_on_off(pm.model, vv[l], cs[l], wr[l], z[l])
        cs5 = relaxation_product_on_off(pm.model, vv[l], si[l], wi[l], z[l])
        #const_set = union(const_set, cs1, cs2, cs3, cs4, cs5)

        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])

        #cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        cs6 = relaxation_equality_on_off(pm.model, v[i], v_from[l], z[l])
        cs7 = relaxation_equality_on_off(pm.model, v[j], v_to[l], z[l])
        cs8 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        cs9 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        #cs = union(cs, cs6, cs7, cs8, cs9)

        # to prevent this constraint from being posted on multiple parallel lines
        # TODO needs on/off variant
        cs1 = constraint_power_magnitude_sqr_on_off(pm, branch)
        cs2 = constraint_power_magnitude_link_on_off(pm, branch) # different index set
        #cs = union(cs, cs1, cs2)
    end

    return Set()
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

    c1 = @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm*z_ub/tm)
    c2 = @constraint(pm.model, p_fr^2 + q_fr^2 <= w_ub*cm*z/tm)
    c3 = @constraint(pm.model, p_fr^2 + q_fr^2 <= w*cm_ub*z/tm)

    return Set([c1, c2, c3])
end

"`cm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]`"
function constraint_power_magnitude_link_on_off(pm::QCWRPowerModel, i, arc_from, g, b, c, tr, ti, tm)
    w_fr = pm.var[:w_from][i]
    w_to = pm.var[:w_to][i]
    q_fr = pm.var[:q][arc_from]
    wr = pm.var[:wr][i]
    wi = pm.var[:wi][i]
    cm = pm.var[:cm][i]

    c = @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
    return Set([c])
end
