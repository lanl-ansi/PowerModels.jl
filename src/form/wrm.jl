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

function constraint_complex_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T})
    WR = getvariable(pm.model, :WR)
    WI = getvariable(pm.model, :WI)

    c = @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in keys(pm.set.buspairs)
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
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    WR = getvariable(pm.model, :WR)
    w_index = pm.model.ext[:lookup_w_index][i]
    w_i = WR[w_index, w_index]

    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum(p[a] for a in bus_branches) == sum(pg[g] for g in bus_gens) - bus["pd"] - bus["gs"]*w_i)
    return Set([c])
end

function constraint_reactive_kcl_shunt{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    WR = getvariable(pm.model, :WR)
    w_index = pm.model.ext[:lookup_w_index][i]
    w_i = WR[w_index, w_index]

    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum(q[a] for a in bus_branches) == sum(qg[g] for g in bus_gens) - bus["qd"] + bus["bs"]*w_i)
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
    buspair = pm.set.buspairs[pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        WR = getvariable(pm.model, :WR)
        WI = getvariable(pm.model, :WI)
        w_fr_index = pm.model.ext[:lookup_w_index][f_bus]
        w_to_index = pm.model.ext[:lookup_w_index][t_bus]
        wr   = WR[w_fr_index, w_to_index]
        wi   = WI[w_fr_index, w_to_index]

        c1 = @constraint(pm.model, wi <= buspair["angmax"]*wr)
        c2 = @constraint(pm.model, wi >= buspair["angmin"]*wr)
        return Set([c1, c2])
    end
    return Set()
end


function add_bus_voltage_setpoint{T <: AbstractWRMForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :WR; scale = (x,item) -> sqrt(x), extract_var = (var,idx,item) -> var[pm.model.ext[:lookup_w_index][idx], pm.model.ext[:lookup_w_index][idx]])

    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end
