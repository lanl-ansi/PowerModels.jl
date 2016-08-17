export 
    ACPPowerModel, StandardACPForm,
    APIACPPowerModel, APIACPForm,
    SADACPPowerModel, SADACPForm,
    LSACPPowerModel, LSACPForm

abstract AbstractACPForm <: AbstractPowerFormulation

type StandardACPForm <: AbstractACPForm end
typealias ACPPowerModel GenericPowerModel{StandardACPForm}

# default AC constructor
function ACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardACPForm(); kwargs...)
end

function complex_voltage_variables{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    t = phase_angle_variables(pm)
    v = voltage_magnitude_variables(pm)
end

function constraint_complex_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T})
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


function constraint_theta_ref{T <: AbstractACPForm}(pm::GenericPowerModel{T})
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


function constraint_active_kcl_shunt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    v = getvariable(pm.model, :v)
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*v[i]^2)
end

function constraint_reactive_kcl_shunt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    v = getvariable(pm.model, :v)
    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    @constraint(pm.model, sum{q[a], a in bus_branches} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*v[i]^2)
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
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

function constraint_reactive_ohms_yt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
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

# Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)
function constraint_active_ohms_y{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
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
  tr = branch["tap"]
  as = branch["shift"]

  @NLconstraint(pm.model, p_fr == g*(v_fr/tr)^2 + -g*v_fr/tr*v_to*cos(t_fr-t_to-as) + -b*v_fr/tr*v_to*sin(t_fr-t_to-as) )
  @NLconstraint(pm.model, p_to ==      g*v_to^2 + -g*v_to*v_fr/tr*cos(t_to-t_fr+as) + -b*v_to*v_fr/tr*sin(t_to-t_fr+as) )
end

function constraint_reactive_ohms_y{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
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
  tr = branch["tap"]
  as = branch["shift"]

  @NLconstraint(pm.model, q_fr == -(b+c/2)*(v_fr/tr)^2 + b*v_fr/tr*v_to*cos(t_fr-t_to-as) + -g*v_fr/tr*v_to*sin(t_fr-t_to-as) )
  @NLconstraint(pm.model, q_to ==      -(b+c/2)*v_to^2 + b*v_to*v_fr/tr*cos(t_fr-t_to+as) + -g*v_to*v_fr/tr*sin(t_to-t_fr+as) )
end




function constraint_phase_angle_diffrence{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]

  t_fr = getvariable(pm.model, :t)[f_bus]
  t_to = getvariable(pm.model, :t)[t_bus]

  @constraint(pm.model, t_fr - t_to <= branch["angmax"])
  @constraint(pm.model, t_fr - t_to >= branch["angmin"])
end




abstract AbstractLSACPForm <: AbstractACPForm

type LSACPForm <: AbstractLSACPForm end
typealias LSACPPowerModel GenericPowerModel{LSACPForm}

# default AC constructor
function LSACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, LSACPForm(); kwargs...)
end

function constraint_active_ohms_yt_on_off{T <: AbstractLSACPForm}(pm::GenericPowerModel{T}, branch)
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
  z = getvariable(pm.model, :line_z)[i]

  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(pm.model, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
  @NLconstraint(pm.model, p_to ==    z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
end

function constraint_reactive_ohms_yt_on_off{T <: AbstractLSACPForm}(pm::GenericPowerModel{T}, branch)
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
  z = getvariable(pm.model, :line_z)[i]

  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
  @NLconstraint(pm.model, q_to ==    z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
end

function constraint_phase_angle_diffrence_on_off{T <: AbstractLSACPForm}(pm::GenericPowerModel{T}, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]

  t_fr = getvariable(pm.model, :t)[f_bus]
  t_to = getvariable(pm.model, :t)[t_bus]
  z = getvariable(pm.model, :line_z)[i]

  @constraint(pm.model, z*(t_fr - t_to) <= branch["angmax"])
  @constraint(pm.model, z*(t_fr - t_to) >= branch["angmin"])
end

function getsolution{T <: AbstractLSACPForm}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_status_setpoint(sol, pm)
    return sol
end




type APIACPForm <: AbstractACPForm end
typealias APIACPPowerModel GenericPowerModel{APIACPForm}

# default AC constructor
function APIACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, APIACPForm(); kwargs...)
end

function complex_voltage_variables(pm::APIACPPowerModel)
    t = phase_angle_variables(pm)
    v = voltage_magnitude_variables(pm)
    @variable(pm.model, load_factor >= 1.0, start = 1.0)
end


function free_api_variables(pm::APIACPPowerModel)
    for (i,bus) in pm.set.buses
        v = getvariable(pm.model, :v)[i]
        setupperbound(v, bus["vmax"]*0.999)
        setlowerbound(v, bus["vmin"]*1.001)
    end
    for (i,gen) in pm.set.gens
        pg = getvariable(pm.model, :pg)[i]
        qg = getvariable(pm.model, :qg)[i]
        if gen["pmax"] > 0 
            setupperbound(pg, Inf)
        end
        setupperbound(qg,  Inf)
        setlowerbound(qg, -Inf)
    end
end


function constraint_active_kcl_shunt_scaled(pm::APIACPPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    load_factor = getvariable(pm.model, :load_factor)
    v = getvariable(pm.model, :v)
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    if bus["pd"] > 0 && bus["qd"] > 0
        @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"]*load_factor - bus["gs"]*v[i]^2)
    else
        # super fallback impl
        @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*v[i]^2)
    end
end

function objective_max_loading(pm::APIACPPowerModel)
    load_factor = getvariable(pm.model, :load_factor)
    @objective(pm.model, Max, load_factor)
end


function getsolution(pm::APIACPPowerModel)
    # super fallback
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)

    # extention
    add_bus_demand_setpoint(sol, pm)

    return sol
end

function add_bus_demand_setpoint(sol, pm::APIACPPowerModel)
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "bus", "bus_i", "pd", :load_factor; default_value = (item) -> item["pd"]*mva_base, scale = (x,item) -> item["pd"] > 0 && item["qd"] > 0 ? x*item["pd"]*mva_base : item["pd"]*mva_base, extract_var = (var,idx,item) -> var)
    add_setpoint(sol, pm, "bus", "bus_i", "qd", :load_factor; default_value = (item) -> item["qd"]*mva_base, scale = (x,item) -> item["qd"]*mva_base, extract_var = (var,idx,item) -> var)
end






type SADACPForm <: AbstractACPForm end
typealias SADACPPowerModel GenericPowerModel{SADACPForm}

# default AC constructor
function SADACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, SADACPForm(); kwargs...)
end

function complex_voltage_variables(pm::SADACPPowerModel)
    t = phase_angle_variables(pm)
    v = voltage_magnitude_variables(pm)
    @variable(pm.model, theta_delta_bound >= 0.0, start = 0.523598776)
end


function constraint_phase_angle_diffrence_flexible(pm::SADACPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]

  t_fr = getvariable(pm.model, :t)[f_bus]
  t_to = getvariable(pm.model, :t)[t_bus]

  theta_delta_bound = getvariable(pm.model, :theta_delta_bound)

  @constraint(pm.model, t_fr - t_to <=  theta_delta_bound)
  @constraint(pm.model, t_fr - t_to >= -theta_delta_bound)
end

function objective_min_theta_delta(pm::SADACPPowerModel)
    theta_delta_bound = getvariable(pm.model, :theta_delta_bound)
    @objective(pm.model, Min, theta_delta_bound)
end


