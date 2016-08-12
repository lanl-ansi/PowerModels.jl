# stuff that is universal to these variables

export 
    ACPPowerModel, ACPData

type ACPData 
    t
    v
    pg
    qg
    p
    q
end

typealias ACPPowerModel GenericPowerModel{ACPData}

# default AC constructor
function ACPPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    mdata = ACPData(nothing, nothing, nothing, nothing, nothing, nothing)
    return GenericPowerModel(data, mdata; setting = setting)
end

function add_vars(pm::ACPPowerModel)
    pm.ext.t  = phase_angle_variables(pm)
    pm.ext.v  = voltage_magnitude_variables(pm)

    pm.ext.pg = active_generation_variables(pm)
    pm.ext.qg = reactive_generation_variables(pm)

    pm.ext.p  = line_flow_variables(pm)
    pm.ext.q  = line_flow_variables(pm)
end

function post_constraints(pm::ACPPowerModel)
    for (l,i,j) in pm.set.arcs_from
        branch = pm.set.branches[l]
        constraint_active_ohms_v_yt(pm.model, pm.ext.p[(l,i,j)], pm.ext.p[(l,j,i)], pm.ext.v[i], pm.ext.v[j], pm.ext.t[i], pm.ext.t[j], branch)
        constraint_reactive_ohms_v_yt(pm.model, pm.ext.q[(l,i,j)], pm.ext.q[(l,j,i)], pm.ext.v[i], pm.ext.v[j], pm.ext.t[i], pm.ext.t[j], branch)
        
        constraint_phase_angle_diffrence_t(pm.model, pm.ext.t[i], pm.ext.t[j], branch)

        constraint_thermal_limit(pm.model, pm.ext.p[(l,i,j)], pm.ext.q[(l,i,j)], branch)
        constraint_thermal_limit(pm.model, pm.ext.p[(l,j,i)], pm.ext.q[(l,j,i)], branch)
    end

end

function constraint_theta_ref(pm::ACPPowerModel)
    @constraint(pm.model, pm.ext.t[pm.set.ref_bus] == 0)
end

function constraint_active_kcl_shunt(pm::ACPPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    @constraint(pm.model, sum{pm.ext.p[a], a in bus_branches} == sum{pm.ext.pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*pm.ext.v[i]^2)
end

function constraint_reactive_kcl_shunt(pm::ACPPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    @constraint(pm.model, sum{pm.ext.q[a], a in bus_branches} == sum{pm.ext.qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*pm.ext.v[i]^2)
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt(pm::ACPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)
  
  p_fr = pm.ext.p[f_idx]
  p_to = pm.ext.p[t_idx]
  v_fr = pm.ext.v[f_bus]
  v_to = pm.ext.v[t_bus]
  t_fr = pm.ext.t[f_bus]
  t_to = pm.ext.t[t_bus]

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
  
  q_fr = pm.ext.q[f_idx]
  q_to = pm.ext.q[t_idx]
  v_fr = pm.ext.v[f_bus]
  v_to = pm.ext.v[t_bus]
  t_fr = pm.ext.t[f_bus]
  t_to = pm.ext.t[t_bus]

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

  t_fr = pm.ext.t[f_bus]
  t_to = pm.ext.t[t_bus]

  @constraint(pm.model, t_fr - t_to <= branch["angmax"])
  @constraint(pm.model, t_fr - t_to >= branch["angmin"])
end

function constraint_thermal_limit(pm::ACPPowerModel, branch) 
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)

  p_fr = pm.ext.p[f_idx]
  p_to = pm.ext.p[t_idx]
  q_fr = pm.ext.q[f_idx]
  q_to = pm.ext.q[t_idx]

  @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2)
  @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2)
end




function getsolution(pm::ACPPowerModel)
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    return sol
end

function add_bus_voltage_setpoint(sol, pm::ACPPowerModel)
    sol_buses = nothing
    if !haskey(sol, "bus")
        sol_buses = Dict{Int,Any}()
        sol["bus"] = sol_buses
    else
        sol_buses = sol["bus"]
    end

    for bus in pm.data["bus"]
        idx = Int(bus["bus_i"])

        sol_bus = nothing
        if !haskey(sol_buses, idx)
            sol_bus = Dict{AbstractString,Any}()
            sol_buses[idx] = sol_bus
        else
            sol_bus = sol_buses[idx]
        end
        sol_bus["vm"] = NaN
        sol_bus["va"] = NaN

        if bus["bus_type"] != 4
            sol_bus["vm"] = getvalue(pm.ext.v[idx])
            sol_bus["va"] = getvalue(pm.ext.t[idx])*180/pi
        end
    end
end


function add_generator_power_setpoint(sol, pm::ACPPowerModel)
    mva_base = pm.data["baseMVA"]

    sol_gens = nothing
    if !haskey(sol, "gen")
        sol_gens = Dict{Int,Any}()
        sol["gen"] = sol_gens
    else
        sol_gens = sol["gen"]
    end

    for gen in pm.data["gen"]
        idx = Int(gen["index"])
        
        sol_gen = nothing
        if !haskey(sol_gens, idx)
            sol_gen = Dict{AbstractString,Any}()
            sol_gens[idx] = sol_gen
        else
            sol_gen = sol_gens[idx]
        end
        sol_gen["pg"] = NaN
        sol_gen["qg"] = NaN

        if gen["gen_status"] == 1
            sol_gen["pg"] = getvalue(pm.ext.pg[idx])*mva_base
            sol_gen["qg"] = getvalue(pm.ext.qg[idx])*mva_base
        end
    end
end

function add_branch_flow_setpoint(sol, pm::ACPPowerModel)
    mva_base = pm.data["baseMVA"]

    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true

        sol_branches = nothing
        if !haskey(sol, "branch")
            sol_branches = Dict{Int,Any}()
            sol["branch"] = sol_branches
        else
            sol_branches = sol["branch"]
        end

        for branch in pm.data["branch"]
            idx = Int(branch["index"])
            
            sol_branch = nothing
            if !haskey(sol_branches, idx)
                sol_branch = Dict{AbstractString,Any}()
                sol_branches[idx] = sol_branch
            else
                sol_branch = sol_branches[idx]
            end

            sol_branch["p_from"] = NaN
            sol_branch["q_from"] = NaN
            sol_branch["p_to"] = NaN
            sol_branch["q_to"] = NaN

            if Int(branch["br_status"]) == 1
                sol_branch["p_from"] = getvalue(p[(idx, branch["f_bus"] , branch["t_bus"])])*mva_base
                sol_branch["q_from"] = getvalue(q[(idx, branch["f_bus"] , branch["t_bus"])])*mva_base
                sol_branch["p_to"]   = getvalue(p[(idx, branch["t_bus"] , branch["f_bus"])])*mva_base
                sol_branch["q_to"]   = getvalue(q[(idx, branch["t_bus"] , branch["f_bus"])])*mva_base
            end
        end
    end
end

