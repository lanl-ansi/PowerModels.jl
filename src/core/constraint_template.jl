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


### Generator Constraints ###
""
function constraint_active_gen_setpoint(pm::GenericPowerModel, gen)
    return constraint_active_gen_setpoint(pm, gen["index"], gen["pg"])
end

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, gen)
    return constraint_reactive_gen_setpoint(pm, gen["index"], gen["qg"])
end

### Bus - Setpoint Constraints ###

""
function constraint_theta_ref(pm::GenericPowerModel)
    return constraint_theta_ref(pm, pm.ref[:ref_bus])
end

""
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, bus; epsilon = 0.0)
    @assert epsilon >= 0.0
    return constraint_voltage_magnitude_setpoint(pm, bus["index"], bus["vm"], epsilon)
end

### Bus - KCL Constraints ###

""
function constraint_kcl_shunt(pm::GenericPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    return constraint_kcl_shunt(pm, i, bus_arcs, bus_gens, bus["pd"], bus["qd"], bus["gs"], bus["bs"])
end

""
function constraint_kcl_shunt_ne(pm::GenericPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_arcs_ne = pm.ref[:ne_bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    return constraint_kcl_shunt_ne(pm, i, bus_arcs, bus_arcs_ne, bus_gens, bus["pd"], bus["qd"], bus["gs"], bus["bs"])
end

### Branch - Ohm's Law Constraints ### 

""
function constraint_ohms_yt_from(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    return constraint_ohms_yt_from(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
end

""
function constraint_ohms_yt_to(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    return constraint_ohms_yt_to(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
end

""
function constraint_ohms_y_from(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    c = branch["br_b"]
    tr = branch["tap"]
    as = branch["shift"]

    return constraint_ohms_y_from(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
end

""
function constraint_ohms_y_to(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    c = branch["br_b"]
    tr = branch["tap"]
    as = branch["shift"]

    return constraint_ohms_y_to(pm, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
end

### Branch - On/Off Ohm's Law Constraints ### 

""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2 

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    return constraint_ohms_yt_from_on_off(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
end

""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2 

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    return constraint_ohms_yt_to_on_off(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
end

""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    return constraint_ohms_yt_from_ne(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
end

""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2 

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    return constraint_ohms_yt_to_ne(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
end

### Branch - Current ### 

""
function constraint_power_magnitude_sqr(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    f_idx = (i, f_bus, t_bus)

    tm = branch["tap"]^2

    return constraint_power_magnitude_sqr(pm, f_bus, t_bus, f_idx, tm)
end

""
function constraint_power_magnitude_link(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    f_idx = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2 

    return constraint_power_magnitude_link(pm, f_bus, t_bus, f_idx, g, b, c, tr, ti, tm)
end

### Branch - Thermal Limit Constraints ### 

""
function constraint_thermal_limit_from(pm::GenericPowerModel, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    return constraint_thermal_limit_from(pm, f_idx, branch["rate_a"]*scale)
end

""
function constraint_thermal_limit_to(pm::GenericPowerModel, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    return constraint_thermal_limit_to(pm, t_idx, branch["rate_a"]*scale)
end

""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    return constraint_thermal_limit_from_on_off(pm, i, f_idx, branch["rate_a"])
end

""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    return constraint_thermal_limit_to_on_off(pm, i, t_idx, branch["rate_a"])
end

""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    return constraint_thermal_limit_from_ne(pm, i, f_idx, branch["rate_a"])
end

""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    return constraint_thermal_limit_to_ne(pm, i, t_idx, branch["rate_a"])
end

### Branch - Phase Angle Difference Constraints ### 

""
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

""
function constraint_phase_angle_difference_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    return constraint_phase_angle_difference_on_off(pm, i, f_bus, t_bus, branch["angmin"], branch["angmax"], t_min, t_max)
end

""
function constraint_phase_angle_difference_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    return constraint_phase_angle_difference_ne(pm, i, f_bus, t_bus, branch["angmin"], branch["angmax"], t_min, t_max)
end

### Branch - Loss Constraints ### 

""
function constraint_loss_lb(pm::GenericPowerModel, branch)
    @assert branch["br_r"] >= 0
    @assert branch["br_x"] >= 0
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    c = branch["br_b"]
    tr = branch["tr"]

    return constraint_loss_lb(pm, f_bus, t_bus, f_idx, t_idx, c, tr)
end
