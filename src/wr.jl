export 
    SOCWRPowerModel, SOCWRForm,
    SDPWRPowerModel, SDPWRForm


abstract AbstractWRForm <: AbstractPowerFormulation

type SOCWRForm <: AbstractWRForm end
typealias SOCWRPowerModel GenericPowerModel{SOCWRForm}

function SOCWRPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    return GenericPowerModel(data, SOCWRForm(); setting = setting)
end

function constraint_voltage_relaxation(pm::SOCWRPowerModel)
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    
    for (i,j) in pm.set.buspair_indexes
        complex_product_relaxation(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

function init_vars{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    voltage_magnitude_sqr_variables(pm)
    complex_voltage_product_variables(pm)

    active_generation_variables(pm)
    reactive_generation_variables(pm)

    active_line_flow_variables(pm)
    reactive_line_flow_variables(pm)
end

function constraint_theta_ref{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    # Do nothing, no way to represent this in these variables
end

function constraint_active_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*w[i])
end

function constraint_reactive_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    @constraint(pm.model, sum{q[a], a in bus_branches} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*w[i])
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    @NLconstraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @NLconstraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
end

function constraint_reactive_ohms_yt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    @NLconstraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

function constraint_phase_angle_diffrence{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.set.buspairs[pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        wr = getvariable(pm.model, :wr)[pair]
        wi = getvariable(pm.model, :wi)[pair]

        @constraint(pm.model, wi <= buspair["angmax"]*wr)
        @constraint(pm.model, wi >= buspair["angmin"]*wr)
    end
end





type SDPWRForm <: AbstractWRForm end
typealias SDPWRPowerModel GenericPowerModel{SDPWRForm}

function SDPWRPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    return GenericPowerModel(data, SDPWRForm(); setting = setting)
end

#TODO get Miles Help with this
function constraint_voltage_relaxation(pm::SDPWRPowerModel)
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)

    w_index = 1:length(pm.set.bus_indexes)
    lookup_w_index = [i => bi for (i, bi) in enumerate(pm.set.bus_indexes)]

    #@variable(m, WR[1:length(bus_indexes), 1:length(bus_indexes)], Symmetric)
    #@variable(m, WI[1:length(bus_indexes), 1:length(bus_indexes)])

    lookup_wr = function(i,j)
        w_idx = lookup_w_index[i]
        w_jdx = lookup_w_index[j]
        if w_idx == w_jdx
            return w[w_idx]
        else
            if w_idx < w_jdx
                try
                    return wr[(w_idx, w_jdx)]
                catch
                    return zero(AffExpr)
                end
            else
                try
                    return wr[(w_jdx, w_jdx)]
                catch
                    return zero(AffExpr)
                end
            end
        end
    end

    lookup_wi = function(i,j)
        w_idx = lookup_w_index[i]
        w_jdx = lookup_w_index[j]
        if w_idx == w_jdx
            return zero(AffExpr)
        else
            if w_idx < w_jdx
                try
                    return wi[(w_idx, w_jdx)]
                catch
                    return zero(AffExpr)
                end
            else
                try
                    return -wi[(w_jdx, w_idx)]
                catch
                    return zero(AffExpr)
                end
            end
        end
    end

    WR = [ lookup_wr(i,j) for i in w_index, j in w_index]
    WI = [ lookup_wi(i,j) for i in w_index, j in w_index]

    println(WR)
    println(WI)
    # follow this: http://docs.mosek.com/modeling-cookbook/sdo.html
    #@SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    for (i,j) in pm.set.buspair_indexes
        complex_product_relaxation(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end

end



function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end
