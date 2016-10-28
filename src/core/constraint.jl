################################################################################
# This file defines commonly used and created constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

# Generic thermal limit constraint
function constraint_thermal_limit_from{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2*scale)
    return Set([c])
end

function constraint_thermal_limit_to{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2*scale)
    return Set([c])
end

function constraint_thermal_limit_from{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]

    c = @constraint(pm.model, norm([p_fr; q_fr]) <= branch["rate_a"])
    return Set([c])
end

function constraint_thermal_limit_to{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    c = @constraint(pm.model, norm([p_to; q_to]) <= branch["rate_a"])
    return Set([c])
end

# Generic on/off thermal limit constraint
function constraint_thermal_limit_from_on_off{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    z = getvariable(pm.model, :line_z)[i]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2*z^2*scale)
    return Set([c])
end

function constraint_thermal_limit_to_on_off{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    z = getvariable(pm.model, :line_z)[i]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2*z^2*scale)
    return Set([c])
end

function constraint_thermal_limit_from_ne{T}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2*z^2)
    return Set([c])
end

function constraint_thermal_limit_to_ne{T}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p_ne)[t_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2*z^2)
    return Set([c])
end

function constraint_active_gen_setpoint{T}(pm::GenericPowerModel{T}, gen)
    i = gen["index"]
    pg = getvariable(pm.model, :pg)[gen["index"]]

    return @constraint(pm.model, pg == gen["pg"])
end

function constraint_reactive_gen_setpoint{T}(pm::GenericPowerModel{T}, gen)
    i = gen["index"]
    qg = getvariable(pm.model, :qg)[gen["index"]]

    c = @constraint(pm.model, qg == gen["qg"])
    return Set([c])
end

function constraint_active_loss_lb{T}(pm::GenericPowerModel{T}, branch)
    @assert branch["br_r"] >= 0

    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]

    c = @constraint(m, p_fr + p_to >= 0)
    return Set([c])
end

function constraint_reactive_loss_lb{T}(pm::GenericPowerModel{T}, branch)
    @assert branch["br_x"] >= 0

    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]

    c = @constraint(m, q_fr + q_to >= -branch["br_b"]/2*(v_fr^2/branch["tap"]^2 + v_to^2))
    return Set([c])
end
