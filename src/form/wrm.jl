export 
    SDPWRMPowerModel, SDPWRMForm

abstract AbstractWRMForm <: AbstractConicPowerFormulation

type SDPWRMForm <: AbstractWRMForm end
typealias SDPWRMPowerModel GenericPowerModel{SDPWRMForm}

function SDPWRMPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, SDPWRMForm(); kwargs...)
end

function variable_complex_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_complex_voltage_product_matrix(pm; kwargs...)
end

function variable_complex_voltage_product_matrix{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ref[:buspairs])

    w_index = 1:length(keys(pm.ref[:bus]))
    lookup_w_index = Dict([(bi, i) for (i,bi) in enumerate(keys(pm.ref[:bus]))])

    @variable(pm.model, WR[1:length(keys(pm.ref[:bus])), 1:length(keys(pm.ref[:bus]))], Symmetric)
    @variable(pm.model, WI[1:length(keys(pm.ref[:bus])), 1:length(keys(pm.ref[:bus]))])

    # bounds on diagonal
    for (i, bus) in pm.ref[:bus]
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        setlowerbound(wr_ii, bus["vmin"]^2)
        setupperbound(wr_ii, bus["vmax"]^2)

        #this breaks SCS on the 3 bus exmple
        #setlowerbound(wi_ii, 0)
        #setupperbound(wi_ii, 0)
    end

    # bounds on off-diagonal
    for (i,j) in keys(pm.ref[:buspairs])
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
        setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

        setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
        setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
    end

    pm.model.ext[:lookup_w_index] = lookup_w_index
    return WR, WI
end

function constraint_complex_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T})
    WR = getvariable(pm.model, :WR)
    WI = getvariable(pm.model, :WI)

    c = @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in keys(pm.ref[:buspairs])
    #    relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
    return Set([c])
end

function constraint_theta_ref{T <: AbstractWRMForm}(pm::GenericPowerModel{T})
    # Do nothing, no way to represent this in these variables
    return Set()
end

function constraint_active_kcl_shunt{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    WR = getvariable(pm.model, :WR)
    w_index = pm.model.ext[:lookup_w_index][i]
    w_i = WR[w_index, w_index]

    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"] - bus["gs"]*w_i)
    return Set([c])
end

function constraint_reactive_kcl_shunt{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    WR = getvariable(pm.model, :WR)
    w_index = pm.model.ext[:lookup_w_index][i]
    w_i = WR[w_index, w_index]

    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - bus["qd"] + bus["bs"]*w_i)
    return Set([c])
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]

    WR = getvariable(pm.model, :WR)
    WI = getvariable(pm.model, :WI)
    w_fr_index = pm.model.ext[:lookup_w_index][f_bus]
    w_to_index = pm.model.ext[:lookup_w_index][t_bus]

    w_fr = WR[w_fr_index, w_fr_index]
    w_to = WR[w_to_index, w_to_index]
    wr   = WR[w_fr_index, w_to_index]
    wi   = WI[w_fr_index, w_to_index]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_reactive_ohms_yt{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    WR = getvariable(pm.model, :WR)
    WI = getvariable(pm.model, :WI)
    w_fr_index = pm.model.ext[:lookup_w_index][f_bus]
    w_to_index = pm.model.ext[:lookup_w_index][t_bus]

    w_fr = WR[w_fr_index, w_fr_index]
    w_to = WR[w_to_index, w_to_index]
    wr   = WR[w_fr_index, w_to_index]
    wi   = WI[w_fr_index, w_to_index]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    c1 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_phase_angle_difference{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.ref[:buspairs][pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        cs = Set()

        WR = getvariable(pm.model, :WR)
        WI = getvariable(pm.model, :WI)
        w_fr_index = pm.model.ext[:lookup_w_index][f_bus]
        w_to_index = pm.model.ext[:lookup_w_index][t_bus]

        w_fr = WR[w_fr_index, w_fr_index]
        w_to = WR[w_to_index, w_to_index]
        wr   = WR[w_fr_index, w_to_index]
        wi   = WI[w_fr_index, w_to_index]

        c1 = @constraint(pm.model, wi <= buspair["angmax"]*wr)
        c2 = @constraint(pm.model, wi >= buspair["angmin"]*wr)

        c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, buspair["angmin"], buspair["angmax"])

        push!(cs, c1)
        push!(cs, c2)
        push!(cs, c3)

        return cs
    end
    return Set()
end


function add_bus_voltage_setpoint{T <: AbstractWRMForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :WR; scale = (x,item) -> sqrt(x), extract_var = (var,idx,item) -> var[pm.model.ext[:lookup_w_index][idx], pm.model.ext[:lookup_w_index][idx]])

    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end
