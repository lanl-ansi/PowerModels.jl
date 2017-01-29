export
    SOCWRPowerModel, SOCWRForm,
    QCWRPowerModel, QCWRForm

abstract AbstractWRForm <: AbstractPowerFormulation

type SOCWRForm <: AbstractWRForm end
typealias SOCWRPowerModel GenericPowerModel{SOCWRForm}

# default SOC constructor
function SOCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, SOCWRForm(); kwargs...)
end



function variable_complex_voltage_product{T}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

        @variable(pm.model, wr_min[bp] <= wr[bp in keys(pm.ref[:buspairs])] <= wr_max[bp], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi_min[bp] <= wi[bp in keys(pm.ref[:buspairs])] <= wi_max[bp], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    else
        @variable(pm.model, wr[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wr_start", 1.0))
        @variable(pm.model, wi[bp in keys(pm.ref[:buspairs])], start = getstart(pm.ref[:buspairs], bp, "wi_start"))
    end
    return wr, wi
end

function variable_complex_voltage_product_on_off{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr[b in keys(pm.ref[:branch])] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi[b in keys(pm.ref[:branch])] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ref[:buspairs], bi_bp[b], "wi_start"))

    return wr, wi
end


function variable_complex_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_complex_voltage_product(pm; kwargs...)
end

function constraint_complex_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)

    for (i,j) in keys(pm.ref[:buspairs])
        relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

function constraint_theta_ref{T <: AbstractWRForm}(pm::GenericPowerModel{T}, ref_bus)
    # Do nothing, no way to represent this in these variables
    return Set()
end

function constraint_voltage_magnitude_setpoint{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    w = getvariable(pm.model, :w)[i]

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

function constraint_active_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    w = getvariable(pm.model, :w)[i]
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    return Set([c])
end

function constraint_active_kcl_shunt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    w = getvariable(pm.model, :w)[i]
    p = getvariable(pm.model, :p)
    p_ne = getvariable(pm.model, :p_ne)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    return Set([c])
end

function constraint_reactive_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    w = getvariable(pm.model, :w)[i]
    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c])
end

function constraint_reactive_kcl_shunt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    w = getvariable(pm.model, :w)[i]
    q = getvariable(pm.model, :q)
    q_ne = getvariable(pm.model, :q_ne)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c])
end


# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_active_ohms_yt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    w_fr = getvariable(pm.model, :w_from_ne)[i]
    w_to = getvariable(pm.model, :w_to_ne)[i]
    wr = getvariable(pm.model, :wr_ne)[i]
    wi = getvariable(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    
    return Set([c1, c2])
end


function constraint_reactive_ohms_yt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end


function constraint_reactive_ohms_yt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    w_fr = getvariable(pm.model, :w_from_ne)[i]
    w_to = getvariable(pm.model, :w_to_ne)[i]
    wr = getvariable(pm.model, :wr_ne)[i]
    wi = getvariable(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_phase_angle_difference{T <: AbstractWRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    cs = Set()

    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, wi <= angmax*wr)
    c2 = @constraint(pm.model, wi >= angmin*wr)
    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    push!(cs, c1)
    push!(cs, c2)
    push!(cs, c3)

    return cs
end


function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end




function variable_complex_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_complex_voltage_product_on_off(pm; kwargs...)
end

function constraint_complex_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    z = getvariable(pm.model, :line_z)

    w_from = getvariable(pm.model, :w_from)
    w_to = getvariable(pm.model, :w_to)

    cs = Set()
    cs1 = constraint_voltage_magnitude_sqr_from_on_off(pm)
    cs2 = constraint_voltage_magnitude_sqr_to_on_off(pm)
    cs3 = constraint_complex_voltage_product_on_off(pm)
    cs = union(cs, cs1, cs2, cs3)

    for (l,i,j) in pm.ref[:arcs_from]
        cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        cs5 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        cs6 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        cs = union(cs, cs4, cs5, cs6)
    end

    return cs
end

function constraint_complex_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]
    
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:ne_buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in branches])
          
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr_ne)
    wi = getvariable(pm.model, :wi_ne)
    z = getvariable(pm.model, :line_ne)

    w_from = getvariable(pm.model, :w_from_ne)
    w_to = getvariable(pm.model, :w_to_ne)

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


function constraint_voltage_magnitude_sqr_from_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_from = getvariable(pm.model, :w_from)
    z = getvariable(pm.model, :line_z)

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, w_from[i] <= z[i]*buses[branch["f_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_from[i] >= z[i]*buses[branch["f_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

function constraint_voltage_magnitude_sqr_to_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:branch]

    w_to = getvariable(pm.model, :w_to)
    z = getvariable(pm.model, :line_z)

    cs = Set()
    for (i, branch) in pm.ref[:branch]
        c1 = @constraint(pm.model, w_to[i] <= z[i]*buses[branch["t_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_to[i] >= z[i]*buses[branch["t_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

function constraint_complex_voltage_product_on_off{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:branch]])

    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    z = getvariable(pm.model, :line_z)

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

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    w_fr = getvariable(pm.model, :w_from)[i]
    w_to = getvariable(pm.model, :w_to)[i]
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_reactive_ohms_yt_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    w_fr = getvariable(pm.model, :w_from)[i]
    w_to = getvariable(pm.model, :w_to)[i]
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    c1 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_phase_angle_difference_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    c1 = @constraint(pm.model, wi <= angmax*wr)
    c2 = @constraint(pm.model, wi >= angmin*wr)
    return Set([c1, c2])
end

function constraint_phase_angle_difference_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    wr = getvariable(pm.model, :wr_ne)[i]
    wi = getvariable(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, wi <= angmax*wr)
    c2 = @constraint(pm.model, wi >= angmin*wr)
    return Set([c1, c2])
end



function variable_complex_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr_from_ne(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm; kwargs...)
    variable_complex_voltage_product_ne(pm; kwargs...)
end

function variable_voltage_magnitude_sqr_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]
    @variable(pm.model, 0 <= w_from_ne[i in keys(pm.ref[:ne_branch])] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_from_start", 1.001))
    return w_from_ne
end

function variable_voltage_magnitude_sqr_to_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.ref[:bus]
    branches = pm.ref[:ne_branch]
    @variable(pm.model, 0 <= w_to_ne[i in keys(pm.ref[:ne_branch])] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.ref[:bus], i, "w_to", 1.001))
    return w_to_ne
end

function variable_complex_voltage_product_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:ne_buspairs])
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ref[:ne_branch]])
    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr_ne[b in keys(pm.ref[:ne_branch])] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ref[:ne_buspairs], bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi_ne[b in keys(pm.ref[:ne_branch])] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ref[:ne_buspairs], bi_bp[b], "wi_start"))
    return wr_ne, wi_ne
end










type QCWRForm <: AbstractWRForm end
typealias QCWRPowerModel GenericPowerModel{QCWRForm}

# default QC constructor
function QCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, QCWRForm(); kwargs...)
end

# Creates variables associated with differences in phase angles
function variable_phase_angle_difference{T}(pm::GenericPowerModel{T})
    @variable(pm.model, pm.ref[:buspairs][bp]["angmin"] <= td[bp in keys(pm.ref[:buspairs])] <= pm.ref[:buspairs][bp]["angmax"], start = getstart(pm.ref[:buspairs], bp, "td_start"))
    return td
end

# Creates the voltage magnitude product variables
function variable_voltage_magnitude_product{T}(pm::GenericPowerModel{T})
    vv_min = Dict([(bp, buspair["v_from_min"]*buspair["v_to_min"]) for (bp, buspair) in pm.ref[:buspairs]])
    vv_max = Dict([(bp, buspair["v_from_max"]*buspair["v_to_max"]) for (bp, buspair) in pm.ref[:buspairs]])

    @variable(pm.model,  vv_min[bp] <= vv[bp in keys(pm.ref[:buspairs])] <=  vv_max[bp], start = getstart(pm.ref[:buspairs], bp, "vv_start", 1.0))
    return vv
end

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

    @variable(pm.model, cos_min[bp] <= cs[bp in keys(pm.ref[:buspairs])] <= cos_max[bp], start = getstart(pm.ref[:buspairs], bp, "cs_start", 1.0))
    return cs
end

function variable_sine{T}(pm::GenericPowerModel{T})
    @variable(pm.model, sin(pm.ref[:buspairs][bp]["angmin"]) <= si[bp in keys(pm.ref[:buspairs])] <= sin(pm.ref[:buspairs][bp]["angmax"]), start = getstart(pm.ref[:buspairs], bp, "si_start"))
    return si
end

function variable_current_magnitude_sqr{T}(pm::GenericPowerModel{T})
    buspairs = pm.ref[:buspairs]
    cm_min = Dict([(bp, 0) for bp in keys(pm.ref[:buspairs])])
    cm_max = Dict([(bp, (buspair["rate_a"]*buspair["tap"]/buspair["v_from_min"])^2) for (bp, buspair) in pm.ref[:buspairs]])

    @variable(pm.model, cm_min[bp] <= cm[bp in keys(pm.ref[:buspairs])] <=  cm_max[bp], start = getstart(pm.ref[:buspairs], bp, "cm_start"))
    return cm
end


function variable_complex_voltage(pm::QCWRPowerModel; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_complex_voltage_product(pm; kwargs...)

    variable_phase_angle_difference(pm; kwargs...)
    variable_voltage_magnitude_product(pm; kwargs...)
    variable_cosine(pm; kwargs...)
    variable_sine(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

function constraint_complex_voltage(pm::QCWRPowerModel)
    v = getvariable(pm.model, :v)
    t = getvariable(pm.model, :t)

    td = getvariable(pm.model, :td)
    si = getvariable(pm.model, :si)
    cs = getvariable(pm.model, :cs)
    vv = getvariable(pm.model, :vv)

    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)

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




function constraint_power_magnitude_sqr(pm::QCWRPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    f_idx = (i, f_bus, t_bus)

    w_i = getvariable(pm.model, :w)[f_bus]
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    cm = getvariable(pm.model, :cm)[pair]

    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm*cm)
    return Set([c])
end

function constraint_power_magnitude_link(pm::QCWRPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    f_idx = (i, f_bus, t_bus)

    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    q_fr = getvariable(pm.model, :q)[f_idx]
    wr = getvariable(pm.model, :wr)[pair]
    wi = getvariable(pm.model, :wi)[pair]
    cm = getvariable(pm.model, :cm)[pair]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c = @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
    return Set([c])
end


function constraint_theta_ref(pm::QCWRPowerModel, ref_bus)
    @constraint(pm.model, getvariable(pm.model, :t)[ref_bus] == 0)
end

function constraint_phase_angle_difference(pm::QCWRPowerModel, f_bus, t_bus, angmin, angmax)
    td = getvariable(pm.model, :td)[(f_bus, t_bus)]

    if getlowerbound(td) < angmin
        setlowerbound(td, angmin)
    end

    if getupperbound(td) > angmax
        setupperbound(td, angmax)
    end

    cs = Set()

    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

    c1 = @constraint(pm.model, wi <= angmax*wr)
    c2 = @constraint(pm.model, wi >= angmin*wr)

    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    push!(cs, c1)
    push!(cs, c2)
    push!(cs, c3)

    return cs
end

function add_bus_voltage_setpoint(sol, pm::QCWRPowerModel)
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end
