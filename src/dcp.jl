# stuff that is universal to these variables

export 
    DCPPowerModel, DCPData

type DCPData 
    t
    pg
    p
end

typealias DCPPowerModel GenericPowerModel{DCPData}

# default DC constructor
function DCPPowerModel(data::Dict{AbstractString,Any}; setting::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    mdata = DCPData(nothing, nothing, nothing)
    return GenericPowerModel(data, mdata; setting = setting)
end

function add_vars(pm::DCPPowerModel)
    pm.ext.t  = phase_angle_variables(pm)
    pm.ext.pg = active_generation_variables(pm)

    p = line_flow_variables(pm; both_sides = false)
    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in pm.set.arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in pm.set.arcs_from])
    pm.ext.p = p_expr
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
            sol_bus["va"] = getvalue(pm.ext.t[idx])*180/pi
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
            sol_gen["pg"] = getvalue(pm.ext.pg[idx])*mva_base
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

