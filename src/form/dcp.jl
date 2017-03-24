export
    DCPPowerModel, StandardDCPForm,
    DCPLLPowerModel, StandardDCPLLForm

abstract AbstractDCPForm <: AbstractPowerFormulation

abstract StandardDCPForm <: AbstractDCPForm
typealias DCPPowerModel GenericPowerModel{StandardDCPForm}

# default DC constructor
function DCPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardDCPForm; kwargs...)
end



function variable_voltage{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
end

function variable_voltage_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
end

function variable_generation{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_active_generation(pm; kwargs...)
    # omit reactive variables
end

function variable_line_flow{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_active_line_flow(pm; kwargs...)
    # omit reactive variables
end

function variable_line_flow_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    # do nothing, this model does not have reactive variables
    variable_active_line_flow_ne(pm; kwargs...)
end


function variable_active_line_flow{T <: StandardDCPForm}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, -pm.ref[:branch][l]["rate_a"] <= p[(l,i,j) in pm.ref[:arcs_from]] <= pm.ref[:branch][l]["rate_a"], start = getstart(pm.ref[:branch], l, "p_start"))
    else
        @variable(pm.model, p[(l,i,j) in pm.ref[:arcs_from]], start = getstart(pm.ref[:branch], l, "p_start"))
    end

    p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in pm.ref[:arcs_from]])
    p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in pm.ref[:arcs_from]]))

    pm.model.ext[:p_expr] = p_expr
end

function variable_active_line_flow_ne{T <: StandardDCPForm}(pm::GenericPowerModel{T})
    @variable(pm.model, -pm.ref[:ne_branch][l]["rate_a"] <= p_ne[(l,i,j) in pm.ref[:ne_arcs_from]] <= pm.ref[:ne_branch][l]["rate_a"], start = getstart(pm.ref[:ne_branch], l, "p_start"))
 
    p_ne_expr = Dict([((l,i,j), 1.0*p_ne[(l,i,j)]) for (l,i,j) in pm.ref[:ne_arcs_from]])
    p_ne_expr = merge(p_ne_expr, Dict([((l,j,i), -1.0*p_ne[(l,i,j)]) for (l,i,j) in pm.ref[:ne_arcs_from]]))

    pm.model.ext[:p_ne_expr] = p_ne_expr
end


function constraint_voltage{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_voltage_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_theta_ref{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, ref_bus)
    c = @constraint(pm.model, getvariable(pm.model, :t)[ref_bus] == 0)
    return Set([c])
end

function constraint_voltage_magnitude_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, vm, epsilon)
    # do nothing, this model does not have voltage variables
    return Set()
end

function constraint_reactive_gen_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, qg)
    # do nothing, this model does not have reactive variables
    return Set()
end


function constraint_kcl_shunt{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    pg = getvariable(pm.model, :pg)
    p_expr = pm.model.ext[:p_expr]

    c = @constraint(pm.model, sum(p_expr[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    # omit reactive constraint
    return Set([c])
end

function constraint_kcl_shunt_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    pg = getvariable(pm.model, :pg)
    p_expr = pm.model.ext[:p_expr]
    p_ne_expr = pm.model.ext[:p_ne_expr]

    c = @constraint(pm.model, sum(p_expr[a] for a in bus_arcs) + sum(p_ne_expr[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    return Set([c])
end


# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_ohms_yt_from{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = getvariable(pm.model, :p)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c = @constraint(pm.model, p_fr == -b*(t_fr - t_to))
    # omit reactive constraint
    return Set([c])
end

function constraint_ohms_yt_to{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    # Do nothing, this model is symmetric
    return Set()
end


function constraint_ohms_yt_from_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

function constraint_ohms_yt_to_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    # Do nothing, this model is symmetric
    return Set()
end


function constraint_phase_angle_difference{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax)
    c2 = @constraint(pm.model, t_fr - t_to >= angmin)
    return Set([c1, c2])
end

function constraint_thermal_limit_from{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p)[f_idx]

    if getlowerbound(p_fr) < -rate_a
        setlowerbound(p_fr, -rate_a)
    end

    if getupperbound(p_fr) > rate_a
        setupperbound(p_fr, rate_a)
    end

    return Set()
end

function constraint_thermal_limit_to{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, t_idx, rate_a)
    # Do nothing, this model is symmetric
    return Set()
end



function add_bus_voltage_setpoint{T <: AbstractDCPForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v; default_value = (item) -> 1)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end

function add_branch_flow_setpoint{T <: AbstractDCPForm}(sol, pm::GenericPowerModel{T})
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
        mva_base = pm.data["baseMVA"]

        add_setpoint(sol, pm, "branch", "index", "p_from", :p; scale = (x,item) ->  x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "index", "q_from", :q; scale = (x,item) ->  x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "index",   "p_to", :p; scale = (x,item) -> -x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch", "index",   "q_to", :q; scale = (x,item) -> -x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
    end
end




function variable_voltage_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
end

function constraint_voltage_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_ohms_yt_from_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

function constraint_ohms_yt_to_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    # Do nothing, this model is symetric
    return Set()
end

# Generic on/off thermal limit constraint
function constraint_thermal_limit_from_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p)[f_idx]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, p_fr <=  rate_a*z)
    c2 = @constraint(pm.model, p_fr >= -rate_a*z)
    return Set([c1, c2])
end

function constraint_thermal_limit_from_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_idx, rate_a)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, p_fr <=  rate_a*z)
    c2 = @constraint(pm.model, p_fr >= -rate_a*z)
    return Set([c1, c2])
end

function constraint_thermal_limit_to_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a)
  # nothing to do, from handles both sides
  return Set()
end

function constraint_thermal_limit_to_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a)
  # nothing to do, from handles both sides
  return Set()
end


function constraint_phase_angle_difference_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= angmin*z + t_min*(1-z))
    return Set([c1, c2])
end

function constraint_phase_angle_difference_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, angmin, angmax, t_min, t_max)
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= angmin*z + t_min*(1-z))
    return Set([c1, c2])
end




abstract AbstractDCPLLForm <: AbstractDCPForm

abstract StandardDCPLLForm <: AbstractDCPLLForm
typealias DCPLLPowerModel GenericPowerModel{StandardDCPLLForm}


# default DC constructor
function DCPLLPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardDCPLLForm; kwargs...)
end

function constraint_kcl_shunt{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_gens, pd, qd, gs, bs)
    pg = getvariable(pm.model, :pg)
    p = getvariable(pm.model, :p)

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    return Set([c])
end

function constraint_kcl_shunt_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_ne, bus_gens, pd, qd, gs, bs)
    p = getvariable(pm.model, :p)
    p_ne = getvariable(pm.model, :p_ne)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2)
    return Set([c])
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_ohms_yt_from_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    return Set([c1, c2])
end

function constraint_ohms_yt_to_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    r = g/(g^2 + b^2)
    t_m = max(abs(t_min),abs(t_max))
    c = @constraint(pm.model, p_fr + p_to >= r*( (-b*(t_fr - t_to))^2 - (-b*(t_m))^2*(1-z) ) )
    return Set([c])
end

function constraint_ohms_yt_from_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    return Set([c1, c2])
end

function constraint_ohms_yt_to_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    r = g/(g^2 + b^2)
    t_m = max(abs(t_min),abs(t_max))
    c = @constraint(pm.model, p_fr + p_to >= r*( (-b*(t_fr - t_to))^2 - (-b*(t_m))^2*(1-z) ) )
    return Set([c])
end

function constraint_thermal_limit_to_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a)
    p_to = getvariable(pm.model, :p)[t_idx]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, p_to <=  rate_a*z)
    c2 = @constraint(pm.model, p_to >= -rate_a*z)
    return Set([c1, c2])
end

function constraint_thermal_limit_to_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, i, t_idx, rate_a)
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, p_to <=  rate_a*z)
    c2 = @constraint(pm.model, p_to >= -rate_a*z)
    return Set([c1, c2])
end
