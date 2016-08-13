# stuff that is universal to these variables

export 
    DCPPowerModel, DCPVars

type DCPVars <: AbstractPowerVars
    t
    pg
    p
    p_expr
    DCPVars() = new()
end

typealias DCPPowerModel GenericPowerModel{DCPVars}

# default DC constructor
function DCPPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    return GenericPowerModel(data, DCPVars(); setting = setting)
end

function init_vars(pm::DCPPowerModel)
    pm.var.t  = phase_angle_variables(pm)
    pm.var.pg = active_generation_variables(pm)

    pm.var.p = line_flow_variables(pm; both_sides = false)
    p_expr = [(l,i,j) => 1.0*pm.var.p[(l,i,j)] for (l,i,j) in pm.set.arcs_from]
    pm.var.p_expr = merge(p_expr, [(l,j,i) => -1.0*pm.var.p[(l,i,j)] for (l,i,j) in pm.set.arcs_from])
end



function constraint_theta_ref(pm::DCPPowerModel)
    @constraint(pm.model, pm.var.t[pm.set.ref_bus] == 0)
end

#constraint_active_kcl_shunt_const(pm.model, pm.var.p, pm.var.pg, bus, bus_branches, pm.set.bus_gens[i])
function constraint_active_kcl_shunt(pm::DCPPowerModel, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    @constraint(pm.model, sum{pm.var.p_expr[a], a in bus_branches} == sum{pm.var.pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*1.0^2)
end

function constraint_reactive_kcl_shunt(pm::DCPPowerModel, bus)
    # Do nothing, this model does not have reactive variables
end


# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt(pm::DCPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)
  
  p_fr = pm.var.p[f_idx]
  t_fr = pm.var.t[f_bus]
  t_to = pm.var.t[t_bus]

  b = branch["b"]

  @constraint(pm.model, p_fr == -b*(t_fr - t_to))
end

function constraint_reactive_ohms_yt(pm::DCPPowerModel, branch)
    # Do nothing, this model does not have reactive variables
end

function constraint_phase_angle_diffrence(pm::DCPPowerModel, branch)
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]

  t_fr = pm.var.t[f_bus]
  t_to = pm.var.t[t_bus]

  @constraint(pm.model, t_fr - t_to <= branch["angmax"])
  @constraint(pm.model, t_fr - t_to >= branch["angmin"])
end

function constraint_thermal_limit(pm::DCPPowerModel, branch) 
  i = branch["index"]
  f_bus = branch["f_bus"]
  t_bus = branch["t_bus"]
  f_idx = (i, f_bus, t_bus)
  t_idx = (i, t_bus, f_bus)

  p_fr = pm.var.p[f_idx]

  if getlowerbound(p_fr) < -branch["rate_a"]
    setlowerbound(p_fr, -branch["rate_a"])
  end

  if getupperbound(p_fr) < branch["rate_a"]
    getupperbound(p_fr, branch["rate_a"])
  end
end



function getsolution(pm::DCPPowerModel)
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    return sol
end

function add_bus_voltage_setpoint(sol, pm::DCPPowerModel)
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
            sol_bus["vm"] = 1.0
            sol_bus["va"] = getvalue(pm.var.t[idx])*180/pi
        end
    end
end


function add_generator_power_setpoint(sol, pm::DCPPowerModel)
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
            sol_gen["pg"] = getvalue(pm.var.pg[idx])*mva_base
        end
    end
end

function add_branch_flow_setpoint(sol, pm::DCPPowerModel)
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
                sol_branch["p_to"]   = getvalue(p[(idx, branch["t_bus"] , branch["f_bus"])])*mva_base
            end
        end
    end
end

