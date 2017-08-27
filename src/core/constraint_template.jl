#
# Constraint Template Definitions
#
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
    constraint_active_gen_setpoint(pm, gen["index"], gen["pg"])
end

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, gen)
    constraint_reactive_gen_setpoint(pm, gen["index"], gen["qg"])
end

### Bus - Setpoint Constraints ###

""
constraint_theta_ref(pm::GenericPowerModel, i::Int) = constraint_theta_ref(pm, pm.cnw, i)

""
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, bus; epsilon = 0.0)
    @assert epsilon >= 0.0
    constraint_voltage_magnitude_setpoint(pm, bus["index"], bus["vm"], epsilon)
end

### Bus - KCL Constraints ###

""
function constraint_kcl_shunt(pm::GenericPowerModel, n::Int, i::Int)
    bus = ref(pm, n, :bus, i)
    bus_arcs = ref(pm, n, :bus_arcs, i)
    bus_arcs_dc = ref(pm, n, :bus_arcs_dc, i)
    bus_gens = ref(pm, n, :bus_gens, i)

    constraint_kcl_shunt(pm, n, i, bus_arcs, bus_arcs_dc, bus_gens, bus["pd"], bus["qd"], bus["gs"], bus["bs"])
end
constraint_kcl_shunt(pm::GenericPowerModel, i::Int) = constraint_kcl_shunt(pm, pm.cnw, i::Int)


""
function constraint_kcl_shunt_ne(pm::GenericPowerModel, bus)
    i = bus["index"]
    bus_arcs = pm.ref[:bus_arcs][i]
    bus_arcs_dc = pm.ref[:bus_arcs_dc][i]
    bus_arcs_ne = pm.ref[:ne_bus_arcs][i]
    bus_gens = pm.ref[:bus_gens][i]

    constraint_kcl_shunt_ne(pm, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus["pd"], bus["qd"], bus["gs"], bus["bs"])
end


### Branch - Ohm's Law Constraints ###

""
function constraint_ohms_yt_from(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    constraint_ohms_yt_from(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
end
constraint_ohms_yt_from(pm::GenericPowerModel, i::Int) = constraint_ohms_yt_from(pm, pm.cnw, i)


""
function constraint_ohms_yt_to(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    constraint_ohms_yt_to(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
end
constraint_ohms_yt_to(pm::GenericPowerModel, i::Int) = constraint_ohms_yt_to(pm, pm.cnw, i)


""
function constraint_ohms_y_from(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    c = branch["br_b"]
    tr = branch["tap"]
    as = branch["shift"]

    constraint_ohms_y_from(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
end
constraint_ohms_y_from(pm::GenericPowerModel, i::Int) = constraint_ohms_y_from(pm, pm.cnw, i)

""
function constraint_ohms_y_to(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    c = branch["br_b"]
    tr = branch["tap"]
    as = branch["shift"]

    constraint_ohms_y_to(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, as)
end
constraint_ohms_y_to(pm::GenericPowerModel, i::Int) = constraint_ohms_y_to(pm, pm.cnw, i)


### DC LINES ###

""
function constraint_dcline(pm::GenericPowerModel, n::Int, i::Int)
    dcline = ref(pm, n, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    loss0 = dcline["loss0"]
    loss1 = dcline["loss1"]

    constraint_dcline(pm, n, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
end
constraint_dcline(pm::GenericPowerModel, i::Int) = constraint_dcline(pm, pm.cnw, i)


""
function constraint_voltage_dcline_setpoint(pm::GenericPowerModel, dcline; epsilon = 0.0)
    @assert epsilon >= 0.0
    i = dcline["index"]
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    vf = dcline["vf"]
    vt = dcline["vt"]

    constraint_voltage_dcline_setpoint(pm, f_bus, t_bus, vf, vt, epsilon)
end

function constraint_active_dcline_setpoint(pm::GenericPowerModel, dcline; epsilon = 0.0)
    i = dcline["index"]
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    pf = dcline["pf"]
    pt = dcline["pt"]

    constraint_active_dcline_setpoint(pm, i, f_idx, t_idx, pf, pt, epsilon)
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

    constraint_ohms_yt_from_on_off(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
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

    constraint_ohms_yt_to_on_off(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
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

    constraint_ohms_yt_from_ne(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
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

    constraint_ohms_yt_to_ne(pm, i, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm, t_min, t_max)
end

### Branch - Current ###

""
function constraint_power_magnitude_sqr(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"]^2

    constraint_power_magnitude_sqr(pm, n, f_bus, t_bus, arc_from, tm)
end
constraint_power_magnitude_sqr(pm::GenericPowerModel, i::Int; kwargs...) = constraint_power_magnitude_sqr(pm, pm.cnw, i; kwargs...)


""
function constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"]^2

    constraint_power_magnitude_sqr_on_off(pm, i, f_bus, arc_from, tm)
end

""
function constraint_power_magnitude_link(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    constraint_power_magnitude_link(pm, n, f_bus, t_bus, arc_from, g, b, c, tr, ti, tm)
end
constraint_power_magnitude_link(pm::GenericPowerModel, i::Int; kwargs...) = constraint_power_magnitude_link(pm, pm.cnw, i; kwargs...)

""
function constraint_power_magnitude_link_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]^2

    constraint_power_magnitude_link_on_off(pm, i, arc_from, g, b, c, tr, ti, tm)
end

### Branch - Thermal Limit Constraints ###

""
function constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, i::Int; scale = 1.0)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from(pm, n, f_idx, branch["rate_a"]*scale)
end
constraint_thermal_limit_from(pm::GenericPowerModel, i::Int; kwargs...) = constraint_thermal_limit_from(pm, pm.cnw, i; kwargs...)

""
function constraint_thermal_limit_to(pm::GenericPowerModel, n::Int, i::Int; scale = 1.0)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to(pm, n, t_idx, branch["rate_a"]*scale)
end
constraint_thermal_limit_to(pm::GenericPowerModel, i::Int; kwargs...) = constraint_thermal_limit_to(pm, pm.cnw, i; kwargs...)

""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_on_off(pm, i, f_idx, branch["rate_a"])
end

""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_on_off(pm, i, t_idx, branch["rate_a"])
end

""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_ne(pm, i, f_idx, branch["rate_a"])
end

""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_ne(pm, i, t_idx, branch["rate_a"])
end

### Branch - Phase Angle Difference Constraints ###

""
function constraint_voltage_angle_difference(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = ref(pm, n, :buspairs, pair)

    if buspair["line"] == i
        constraint_voltage_angle_difference(pm, n, f_bus, t_bus, buspair["angmin"], buspair["angmax"])
    end
end
constraint_voltage_angle_difference(pm::GenericPowerModel, i::Int) = constraint_voltage_angle_difference(pm, pm.cnw, i)

""
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    constraint_voltage_angle_difference_on_off(pm, i, f_bus, t_bus, branch["angmin"], branch["angmax"], t_min, t_max)
end

""
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_min = pm.ref[:off_angmin]
    t_max = pm.ref[:off_angmax]

    constraint_voltage_angle_difference_ne(pm, i, f_bus, t_bus, branch["angmin"], branch["angmax"], t_min, t_max)
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

    constraint_loss_lb(pm, f_bus, t_bus, f_idx, t_idx, c, tr)
end
