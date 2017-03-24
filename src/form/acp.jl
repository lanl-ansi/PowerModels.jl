export 
    ACPPowerModel, StandardACPForm,
    APIACPPowerModel, APIACPForm

abstract AbstractACPForm <: AbstractPowerFormulation

abstract StandardACPForm <: AbstractACPForm
typealias ACPPowerModel GenericPowerModel{StandardACPForm}

# default AC constructor
function ACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardACPForm; kwargs...)
end

function variable_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

function variable_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
end


function constraint_voltage{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage constraints
    return Set()
end

function constraint_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage constraints
end

function constraint_theta_ref{T <: AbstractACPForm}(pm::GenericPowerModel{T}, ref_bus)
    c = @constraint(pm.model, getvariable(pm.model, :t)[ref_bus] == 0)
    return Set([c])
end

function constraint_voltage_magnitude_setpoint{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    v = getvariable(pm.model, :v)[i]

    if epsilon == 0.0
        c = @constraint(pm.model, v == vm)
        return Set([c])
    else
        c1 = @constraint(pm.model, v <= vm + epsilon)
        c2 = @constraint(pm.model, v >= vm - epsilon)
        return Set([c1, c2])
    end
end


function constraint_kcl_shunt{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    v = getvariable(pm.model, :v)[i]
    p = getvariable(pm.model, :p)
    q = getvariable(pm.model, :q)
    pg = getvariable(pm.model, :pg)
    qg = getvariable(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*v^2)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*v^2)
    return Set([c1, c2])
end

function constraint_kcl_shunt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    v = getvariable(pm.model, :v)[i]
    p = getvariable(pm.model, :p)
    q = getvariable(pm.model, :q)
    p_ne = getvariable(pm.model, :p_ne)
    q_ne = getvariable(pm.model, :q_ne)
    pg = getvariable(pm.model, :pg)
    qg = getvariable(pm.model, :qg)

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2)
    return Set([c1, c2])
end


# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_ohms_yt_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_fr == g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
    return Set([c1, c2])
end

function constraint_ohms_yt_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_to ==    g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
    c2 = @NLconstraint(pm.model, q_to ==    -(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
    return Set([c1, c2])
end

# Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)
function constraint_ohms_y_from{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_fr == g*(v_fr/tr)^2 + -g*v_fr/tr*v_to*cos(t_fr-t_to-as) + -b*v_fr/tr*v_to*sin(t_fr-t_to-as) )
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)*(v_fr/tr)^2 + b*v_fr/tr*v_to*cos(t_fr-t_to-as) + -g*v_fr/tr*v_to*sin(t_fr-t_to-as) )
    return Set([c1, c2])
end

function constraint_ohms_y_to{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @NLconstraint(pm.model, p_to == g*v_to^2 + -g*v_to*v_fr/tr*cos(t_to-t_fr+as) + -b*v_to*v_fr/tr*sin(t_to-t_fr+as) )
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*v_to^2 + b*v_to*v_fr/tr*cos(t_fr-t_to+as) + -g*v_to*v_fr/tr*sin(t_to-t_fr+as) )
    return Set([c1, c2])
end


function constraint_phase_angle_difference{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax)
    c2 = @constraint(pm.model, t_fr - t_to >= angmin)
    return Set([c1, c2])
end




function variable_voltage_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
end

function constraint_voltage_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage constraints
    return Set()
end

function constraint_ohms_yt_from_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @NLconstraint(pm.model, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    c2 = @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    return Set([c1, c2])
end

function constraint_ohms_yt_to_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @NLconstraint(pm.model, p_to ==    z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    c2 = @NLconstraint(pm.model, q_to ==    z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end

function constraint_ohms_yt_from_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @NLconstraint(pm.model, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    c2 = @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    return Set([c1, c2])
end

function constraint_ohms_yt_to_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @NLconstraint(pm.model, p_to ==    z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )      
    c2 = @NLconstraint(pm.model, q_to ==    z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end


function constraint_phase_angle_difference_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= angmax)
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= angmin)
    return Set([c1, c2])
end

function constraint_phase_angle_difference_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= angmax)
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= angmin)
    return Set([c1, c2])
end


function constraint_loss_lb{T <: AbstractACPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, c, tr)
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    c1 = @constraint(m, p_fr + p_to >= 0)
    c2 = @constraint(m, q_fr + q_to >= -c/2*(v_fr^2/tr^2 + v_to^2))
    return Set([c1, c2])
end





abstract APIACPForm <: AbstractACPForm
typealias APIACPPowerModel GenericPowerModel{APIACPForm}

# default AC constructor
function APIACPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, APIACPForm; kwargs...)
end

function variable_load_factor{T}(pm::GenericPowerModel{T})
    @variable(pm.model, load_factor >= 1.0, start = 1.0)
end

function objective_max_loading{T}(pm::GenericPowerModel{T})
    load_factor = getvariable(pm.model, :load_factor)
    return @objective(pm.model, Max, load_factor)
end

# Seems to create too much reactive power and makes even small models hard to converge
function objective_max_loading_voltage_norm{T}(pm::GenericPowerModel{T})
    load_factor = getvariable(pm.model, :load_factor)

    scale = length(pm.ref[:bus])
    v = getvariable(pm.model, :v)

    return @objective(pm.model, Max, 10*scale*load_factor - sum(((bus["vmin"] + bus["vmax"])/2 - v[i])^2 for (i,bus) in pm.ref[:bus] ))
end

# Works but adds unnessiary runtime
function objective_max_loading_gen_output{T}(pm::GenericPowerModel{T})
    load_factor = getvariable(pm.model, :load_factor)

    scale = length(pm.ref[:gen])
    pg = getvariable(pm.model, :pg)
    qg = getvariable(pm.model, :qg)

    return @NLobjective(pm.model, Max, 100*scale*load_factor - sum( (pg[i]^2 - (2*qg[i])^2)^2 for (i,gen) in pm.ref[:gen] ))
end


function bounds_tighten_voltage(pm::APIACPPowerModel; epsilon = 0.001)
    for (i,bus) in pm.ref[:bus]
        v = getvariable(pm.model, :v)[i]
        setupperbound(v, bus["vmax"]*(1.0-epsilon))
        setlowerbound(v, bus["vmin"]*(1.0+epsilon))
    end
end

function upperbound_negative_active_generation(pm::APIACPPowerModel)
    for (i,gen) in pm.ref[:gen]
        pg = getvariable(pm.model, :pg)[i]

        if gen["pmax"] <= 0 
            setupperbound(pg, gen["pmax"])
        end
    end
end

function constraint_kcl_shunt_scaled(pm::APIACPPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    load_factor = getvariable(pm.model, :load_factor)
    v = getvariable(pm.model, :v)
    p = getvariable(pm.model, :p)
    q = getvariable(pm.model, :q)
    pg = getvariable(pm.model, :pg)
    qg = getvariable(pm.model, :qg)

    if bus["pd"] > 0 && bus["qd"] > 0
        c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"]*load_factor - bus["gs"]*v[i]^2)
    else
        # super fallback impl
        c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - bus["pd"] - bus["gs"]*v[i]^2)
    end

    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - bus["qd"] + bus["bs"]*v[i]^2)

    return Set([c1, c2])
end

function get_solution(pm::APIACPPowerModel)
    # super fallback
    sol = init_solution(pm)
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)

    # extention
    add_bus_demand_setpoint(sol, pm)

    return sol
end

function add_bus_demand_setpoint(sol, pm::APIACPPowerModel)
    mva_base = pm.data["baseMVA"]
    add_setpoint(sol, pm, "bus", "bus_i", "pd", :load_factor; default_value = (item) -> item["pd"], scale = (x,item) -> item["pd"] > 0 && item["qd"] > 0 ? x*item["pd"] : item["pd"], extract_var = (var,idx,item) -> var)
    add_setpoint(sol, pm, "bus", "bus_i", "qd", :load_factor; default_value = (item) -> item["qd"], scale = (x,item) -> item["qd"], extract_var = (var,idx,item) -> var)
end




