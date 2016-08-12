# stuff that is universal to these variables

export 
    ACPPowerModel, ACPData,
    test_ac

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
    acpd = ACPData(nothing, nothing, nothing, nothing, nothing, nothing)
    return GenericPowerModel(data, acpd; setting = setting)
end

function add_vars(pm::ACPPowerModel)
    pm.ext.t  = phase_angle_variables(pm.model, pm.set.bus_indexes)
    pm.ext.v  = voltage_magnitude_variables(pm.model, pm.set.buses, pm.set.bus_indexes; start = create_default_start(pm.set.bus_indexes, 1.0, "v_start"))

    pm.ext.pg = active_generation_variables(pm.model, pm.set.gens, pm.set.gen_indexes)
    pm.ext.qg = reactive_generation_variables(pm.model, pm.set.gens, pm.set.gen_indexes)

    pm.ext.p  = line_flow_variables(pm.model, pm.set.arcs, pm.set.branches, pm.set.branch_indexes)
    pm.ext.q  = line_flow_variables(pm.model, pm.set.arcs, pm.set.branches, pm.set.branch_indexes)
end

function post_constraints(pm::ACPPowerModel)
    @constraint(pm.model, pm.ext.t[pm.set.ref_bus] == 0)

    for (i,bus) in pm.set.buses
        bus_branches = filter(x -> x[2] == i, pm.set.arcs)
        constraint_active_kcl_shunt_v(pm.model, pm.ext.p, pm.ext.pg, pm.ext.v[i], bus, bus_branches, pm.set.bus_gens[i])
        constraint_reactive_kcl_shunt_v(pm.model, pm.ext.q, pm.ext.qg, pm.ext.v[i], bus, bus_branches, pm.set.bus_gens[i])
    end

    for (l,i,j) in pm.set.arcs_from
        branch = pm.set.branches[l]
        constraint_active_ohms_v_yt(pm.model, pm.ext.p[(l,i,j)], pm.ext.p[(l,j,i)], pm.ext.v[i], pm.ext.v[j], pm.ext.t[i], pm.ext.t[j], branch)
        constraint_reactive_ohms_v_yt(pm.model, pm.ext.q[(l,i,j)], pm.ext.q[(l,j,i)], pm.ext.v[i], pm.ext.v[j], pm.ext.t[i], pm.ext.t[j], branch)
        
        constraint_phase_angle_diffrence_t(pm.model, pm.ext.t[i], pm.ext.t[j], branch)

        constraint_thermal_limit(pm.model, pm.ext.p[(l,i,j)], pm.ext.q[(l,i,j)], branch)
        constraint_thermal_limit(pm.model, pm.ext.p[(l,j,i)], pm.ext.q[(l,j,i)], branch)
    end

end

function post_objective(pm::ACPPowerModel)
    objective_min_fuel_cost(pm.model, pm.ext.pg, pm.set.gens, pm.set.gen_indexes)
end

function post_ac_opf(pm::ACPPowerModel)
    add_vars(pm)
    post_constraints(pm)
    post_objective(pm)
end

using Ipopt

function test_ac()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"));
    data = parse_matpower(data_string);

    apm = ACPPowerModel(data);
    post_ac_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
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
            #sol_branch["br_status"] = () -> 0.111

            sol_branch["p_from"] = NaN
            sol_branch["q_from"] = NaN
            sol_branch["p_to"] = NaN
            sol_branch["q_to"] = NaN

            if Int(branch["br_status"]) == 1
                sol_branch["p_from"] = getvalue(p[(idx, branch["f_bus"] , branch["t_bus"])])*mva_base
                sol_branch["q_from"] = getvalue(q[(idx, branch["f_bus"] , branch["t_bus"])])*mva_base
                sol_branch["p_to"]   = getvalue(p[(idx, branch["t_bus"] , branch["f_bus"])])*mva_base
                sol_branch["p_to"]   = getvalue(q[(idx, branch["t_bus"] , branch["f_bus"])])*mva_base
            end
        end
    end
end

