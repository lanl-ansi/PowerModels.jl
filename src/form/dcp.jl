export 
    DCPPowerModel, StandardDCPForm,
    DCPLLPowerModel, StandardDCPLLForm


abstract AbstractDCPForm <: AbstractPowerFormulation

type StandardDCPForm <: AbstractDCPForm end
typealias DCPPowerModel GenericPowerModel{StandardDCPForm}

# default DC constructor
function DCPPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardDCPForm(); kwargs...)
end

function variable_complex_voltage{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
end

function variable_reactive_generation{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have reactive variables
end

function variable_reactive_line_flow{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; bounded = true)
    # do nothing, this model does not have reactive variables
end

function variable_active_line_flow{T <: StandardDCPForm}(pm::GenericPowerModel{T}; bounded = true)
    if bounded
        @variable(pm.model, -pm.set.branches[l]["rate_a"] <= p[(l,i,j) in pm.set.arcs_from] <= pm.set.branches[l]["rate_a"], start = getstart(pm.set.branches, l, "p_start"))
    else
        @variable(pm.model, p[(l,i,j) in pm.set.arcs_from], start = getstart(pm.set.branches, l, "p_start"))
    end

    p_expr = [(l,i,j) => 1.0*p[(l,i,j)] for (l,i,j) in pm.set.arcs_from]
    p_expr = merge(p_expr, [(l,j,i) => -1.0*p[(l,i,j)] for (l,i,j) in pm.set.arcs_from])

    pm.model.ext[:p_expr] = p_expr
end

function constraint_complex_voltage{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_theta_ref{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    c = @constraint(pm.model, getvariable(pm.model, :t)[pm.set.ref_bus] == 0)
    return Set([c])
end

function constraint_voltage_magnitude_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, bus; epsilon = 0.0)
    # do nothing, this model does not have voltage variables
    return Set()
end

function constraint_reactive_gen_setpoint{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, gen)
    # do nothing, this model does not have reactive variables
    return Set()
end


function constraint_active_kcl_shunt{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    pg = getvariable(pm.model, :pg)
    p_expr = pm.model.ext[:p_expr]

    c = @constraint(pm.model, sum{p_expr[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*1.0^2)
    return Set([c])
end

function constraint_reactive_kcl_shunt{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, bus)
    # Do nothing, this model does not have reactive variables
    return Set()
end


# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    b = branch["b"]

    c = @constraint(pm.model, p_fr == -b*(t_fr - t_to))
    return Set([c])
end

function constraint_reactive_ohms_yt{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    # Do nothing, this model does not have reactive variables
    return Set()
end

function constraint_phase_angle_diffrence{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]

    c1 = @constraint(pm.model, t_fr - t_to <= branch["angmax"])
    c2 = @constraint(pm.model, t_fr - t_to >= branch["angmin"])
    return Set([c1, c2])
end

function constraint_thermal_limit_from{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch) 
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]

    if getlowerbound(p_fr) < -branch["rate_a"]
        setlowerbound(p_fr, -branch["rate_a"])
    end

    if getupperbound(p_fr) > branch["rate_a"]
        setupperbound(p_fr, branch["rate_a"])
    end

    return Set()
end

function constraint_thermal_limit_to{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch) 
    # nothing to do, from handles both sides
    return Set()
end



function add_bus_voltage_setpoint{T <: AbstractDCPForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v; default_value = (item) -> 1)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t; scale = (x,item) -> x*180/pi)
end




function variable_complex_voltage_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
end

function constraint_complex_voltage_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_active_ohms_yt_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    b = branch["b"]
    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

function constraint_reactive_ohms_yt_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    # Do nothing, this model does not have reactive variables
    return Set()
end

# Generic on/off thermal limit constraint
function constraint_thermal_limit_from_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, p_fr <= getupperbound(p_fr)*z)
    c2 = @constraint(pm.model, p_fr >= getlowerbound(p_fr)*z)
    return Set([c1, c2])
end

function constraint_thermal_limit_to_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch; scale = 1.0)
  # nothing to do, from handles both sides
  return Set()
end

function constraint_phase_angle_diffrence_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, t_fr - t_to <= branch["angmax"]*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= branch["angmin"]*z + t_min*(1-z))
    return Set([c1, c2])
end





abstract AbstractDCPLLForm <: AbstractDCPForm

type StandardDCPLLForm <: AbstractDCPLLForm end
typealias DCPLLPowerModel GenericPowerModel{StandardDCPLLForm}


# default DC constructor
function DCPLLPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, StandardDCPLLForm(); kwargs...)
end

function constraint_active_kcl_shunt{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    pg = getvariable(pm.model, :pg)
    p = getvariable(pm.model, :p)

    c = @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*1.0^2)
    return Set([c])
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_z)[i]

    b = branch["b"]
    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    t_m = max(abs(t_min),abs(t_max))
    c3 = @constraint(pm.model, p_fr + p_to >= branch["br_r"]*( (-branch["b"]*(t_fr - t_to))^2 - (-branch["b"]*(t_m))^2*(1-z) ) )
    return Set([c1, c2, c3])
end

function constraint_thermal_limit_to_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p)[t_idx]
    z = getvariable(pm.model, :line_z)[i]

    c1 = @constraint(pm.model, p_to <= getupperbound(p_to)*z)
    c2 = @constraint(pm.model, p_to >= getlowerbound(p_to)*z)
    return Set([c1, c2])
end




