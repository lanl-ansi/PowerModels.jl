#
# Constraint Template Definitions
# Constraint templates help simplify data wrangling across multiple Power 
# Flow formulations by providing an abstraction layer between the network data
# and network constraint definitions.  The constraint template's job is to 
# extract the required parameters from a given network data structure and 
# pass the data as named arguments to the Power Flow formulations.
#
# Constraint templates should always be defined over "GenericPowerModel"
# and should never refer to model variables
#


### KCL Constraints ###

function constraint_active_kcl_shunt(pm::GenericPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    return constraint_active_kcl_shunt(pm, i, bus_arcs, bus_gens, bus["pd"], bus["qd"], bus["gs"], bus["bs"])
end

function constraint_reactive_kcl_shunt(pm::GenericPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    return constraint_reactive_kcl_shunt(pm, i, bus_arcs, bus_gens, bus["pd"], bus["qd"], bus["gs"], bus["bs"])
end


### Ohm's Law Constraints ### 

function constraint_active_ohms_yt(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    return constraint_active_ohms_yt(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
end

function constraint_reactive_ohms_yt(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    return constraint_reactive_ohms_yt(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
end


function constraint_active_ohms_y(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tap"]
    as = branch["shift"]

    return constraint_active_ohms_y(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
end

function constraint_reactive_ohms_y(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tap"]
    as = branch["shift"]

    return constraint_reactive_ohms_y(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
end


### Thermal Limit Constraints ### 

function constraint_thermal_limit_from(pm::GenericPowerModel, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    return constraint_thermal_limit_from(pm, f_idx, branch["rate_a"]*scale)
end

function constraint_thermal_limit_to{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    return constraint_thermal_limit_to(pm, t_idx, branch["rate_a"]*scale)
end


function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    return constraint_thermal_limit_from_on_off(pm, i, f_idx, branch["rate_a"])
end

function constraint_thermal_limit_to_on_off{T}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    return constraint_thermal_limit_to_on_off(pm, i, t_idx, branch["rate_a"])
end


function constraint_thermal_limit_from_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    return constraint_thermal_limit_from_ne(pm, i, f_idx, branch["rate_a"])
end

function constraint_thermal_limit_to_ne{T}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    return constraint_thermal_limit_to_ne(pm, i, t_idx, branch["rate_a"])
end


### Phase Angle Difference Constraints ### 

function constraint_phase_angle_difference(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.ref[:buspairs][pair]

    if buspair["line"] == i
        return constraint_phase_angle_difference(pm, f_bus, t_bus, buspair["angmin"], buspair["angmax"])
    end
    return Set()
end

