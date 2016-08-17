export 
    ACPPowerModel, ACPVars


abstract AbstractACPForm <: AbstractPowerFormulation

type StandardACPForm <: AbstractACPForm end
typealias ACPPowerModel GenericPowerModel{StandardACPForm}

# default AC constructor
function ACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardACPForm(); kwargs...)
end

function init_vars(pm::ACPPowerModel)
    phase_angle_variables(pm)
    voltage_magnitude_variables(pm)

    active_generation_variables(pm)
    reactive_generation_variables(pm)

    active_line_flow_variables(pm)
    reactive_line_flow_variables(pm)
end

function free_bounded_variables{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    for (i,bus) in pm.set.buses
        v = getvariable(pm.model, :v)[i]
        setupperbound(v, Inf)
        setlowerbound(v, 0)
    end
    for (i,gen) in pm.set.gens
        pg = getvariable(pm.model, :pg)[i]
        setupperbound(pg,  Inf)
        setlowerbound(pg, -Inf)
        qg = getvariable(pm.model, :pg)[i]
        setupperbound(pg,  Inf)
        setlowerbound(pg, -Inf)
    end
    for arc in pm.set.arcs
        p = getvariable(pm.model, :p)[arc]
        setupperbound(p,  Inf)
        setlowerbound(p, -Inf)
        q = getvariable(pm.model, :p)[arc]
        setupperbound(q,  Inf)
        setlowerbound(q, -Inf)
    end
end


function constraint_theta_ref(pm::ACPPowerModel)
    @constraint(pm.model, getvariable(pm.model, :t)[pm.set.ref_bus] == 0)
end

function constraint_voltage_magnitude_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, bus; epsilon = 0.0)
    i = bus["index"]
    v = getvariable(pm.model, :v)[i]

    if epsilon == 0.0
        @constraint(pm.model, v == bus["vm"])
    else
        @assert epsilon > 0.0
        @constraint(pm.model, v <= bus["vm"] + epsilon)
        @constraint(pm.model, v >= bus["vm"] - epsilon)
    end
end


function constraint_active_kcl_shunt(pm::ACPPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    v = getvariable(pm.model, :v)
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*v[i]^2)
end

function constraint_reactive_kcl_shunt(pm::ACPPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    v = getvariable(pm.model, :v)
    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    @constraint(pm.model, sum{q[a], a in bus_branches} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*v[i]^2)
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt(pm::ACPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)
  
  p_fr = getvariable(pm.model, :p)[f_idx]
  p_to = getvariable(pm.model, :p)[t_idx]
  v_fr = getvariable(pm.model, :v)[f_bus]
  v_to = getvariable(pm.model, :v)[t_bus]
  t_fr = getvariable(pm.model, :t)[f_bus]
  t_to = getvariable(pm.model, :t)[t_bus]

  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(pm.model, p_fr == g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
  @NLconstraint(pm.model, p_to ==    g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
end

function constraint_reactive_ohms_yt(pm::ACPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)
  
  q_fr = getvariable(pm.model, :q)[f_idx]
  q_to = getvariable(pm.model, :q)[t_idx]
  v_fr = getvariable(pm.model, :v)[f_bus]
  v_to = getvariable(pm.model, :v)[t_bus]
  t_fr = getvariable(pm.model, :t)[f_bus]
  t_to = getvariable(pm.model, :t)[t_bus]

  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
  @NLconstraint(pm.model, q_to ==    -(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
end

function constraint_phase_angle_diffrence(pm::ACPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]

  t_fr = getvariable(pm.model, :t)[f_bus]
  t_to = getvariable(pm.model, :t)[t_bus]

  @constraint(pm.model, t_fr - t_to <= branch["angmax"])
  @constraint(pm.model, t_fr - t_to >= branch["angmin"])
end



