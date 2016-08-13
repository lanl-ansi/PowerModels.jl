export 
    SOCWPowerModel, WRVars

type WRVars <: AbstractPowerVars
    w
    wr
    wi
    pg
    qg
    p
    q
    WRVars() = new()
end

typealias SOCWPowerModel GenericPowerModel{WRVars}

# default AC constructor
function SOCWPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    return GenericPowerModel(data, WRVars(); setting = setting)
end

function init_vars(pm::SOCWPowerModel)
    pm.var.w  = voltage_magnitude_sqr_variables(pm)
    pm.var.wr, pm.var.wi = complex_voltage_product_variables(pm)

    pm.var.pg = active_generation_variables(pm)
    pm.var.qg = reactive_generation_variables(pm)

    pm.var.p  = line_flow_variables(pm)
    pm.var.q  = line_flow_variables(pm)
end

function constraint_voltage_relaxation(pm::SOCWPowerModel)
    for (i,j) in pm.set.buspair_indexes
        complex_product_relaxation(pm.model, pm.var.w[i], pm.var.w[j], pm.var.wr[(i,j)], pm.var.wi[(i,j)])
    end
end



function constraint_theta_ref(pm::SOCWPowerModel)
    # Do nothing, no way to represent this in these variables
end

function constraint_active_kcl_shunt(pm::SOCWPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    @constraint(pm.model, sum{pm.var.p[a], a in bus_branches} == sum{pm.var.pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*pm.var.w[i])
end

function constraint_reactive_kcl_shunt(pm::SOCWPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    @constraint(pm.model, sum{pm.var.q[a], a in bus_branches} == sum{pm.var.qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*pm.var.w[i])
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt(pm::SOCWPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = pm.var.p[f_idx]
    p_to = pm.var.p[t_idx]
    w_fr = pm.var.w[f_bus]
    w_to = pm.var.w[t_bus]
    wr = pm.var.wr[(f_bus, t_bus)]
    wi = pm.var.wi[(f_bus, t_bus)]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    @NLconstraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @NLconstraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
end

function constraint_reactive_ohms_yt(pm::SOCWPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = pm.var.q[f_idx]
    q_to = pm.var.q[t_idx]
    w_fr = pm.var.w[f_bus]
    w_to = pm.var.w[t_bus]
    wr = pm.var.wr[(f_bus, t_bus)]
    wi = pm.var.wi[(f_bus, t_bus)]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    @NLconstraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

function constraint_phase_angle_diffrence(pm::SOCWPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.set.buspairs[pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        wr = pm.var.wr[pair]
        wi = pm.var.wi[pair]

        @constraint(pm.model, wi <= buspair["angmax"]*wr)
        @constraint(pm.model, wi >= buspair["angmin"]*wr)
    end
end

#TODO See how this can be combined with "ACPPowerModel" model version
function constraint_thermal_limit(pm::SOCWPowerModel, branch) 
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)

  p_fr = pm.var.p[f_idx]
  p_to = pm.var.p[t_idx]
  q_fr = pm.var.q[f_idx]
  q_to = pm.var.q[t_idx]

  @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2)
  @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2)
end
