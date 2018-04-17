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


### Voltage Constraints ###

constraint_voltage(pm::GenericPowerModel) = constraint_voltage(pm, pm.cnw)
# no data, so no further templating is needed, constraint goes directly to the formulations

constraint_voltage_on_off(pm::GenericPowerModel) = constraint_voltage_on_off(pm, pm.cnw)
# no data, so no further templating is needed, constraint goes directly to the formulations

constraint_voltage_ne(pm::GenericPowerModel) = constraint_voltage_ne(pm, pm.cnw)
# no data, so no further templating is needed, constraint goes directly to the formulations


### Generator Constraints ###

""
function constraint_active_gen_setpoint(pm::GenericPowerModel, n::Int, i::Int)
    gen = ref(pm, n, :gen, i)
    constraint_active_gen_setpoint(pm, n, gen["index"], gen["pg"])
end
constraint_active_gen_setpoint(pm::GenericPowerModel, i::Int) = constraint_active_gen_setpoint(pm, pm.cnw, i::Int)

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, n::Int, i::Int)
    gen = ref(pm, n, :gen, i)
    constraint_reactive_gen_setpoint(pm, gen["index"], gen["qg"])
end
constraint_reactive_gen_setpoint(pm::GenericPowerModel, i::Int) = constraint_reactive_gen_setpoint(pm, pm.cnw, i::Int)


### Bus - Setpoint Constraints ###

""
constraint_theta_ref(pm::GenericPowerModel, i::Int) = constraint_theta_ref(pm, pm.cnw, i)
# no data, so no further templating is needed, constraint goes directly to the formulations

""
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, n::Int, i::Int)
    bus = ref(pm, n, :bus, i)
    constraint_voltage_magnitude_setpoint(pm, n, bus["index"], bus["vm"])
end
constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, i::Int) = constraint_voltage_magnitude_setpoint(pm, pm.cnw, i::Int)


### Bus - KCL Constraints ###

""
function constraint_kcl_shunt(pm::GenericPowerModel, n::Int, i::Int)
    if !haskey(pm.con[:nw][n], :kcl_p)
        pm.con[:nw][n][:kcl_p] = Dict{Int,ConstraintRef}()
    end
    if !haskey(pm.con[:nw][n], :kcl_q)
        pm.con[:nw][n][:kcl_q] = Dict{Int,ConstraintRef}()
    end

    bus = ref(pm, n, :bus, i)
    bus_arcs = ref(pm, n, :bus_arcs, i)
    bus_arcs_dc = ref(pm, n, :bus_arcs_dc, i)
    bus_gens = ref(pm, n, :bus_gens, i)
    bus_loads = ref(pm, n, :bus_loads, i)
    bus_shunts = ref(pm, n, :bus_shunts, i)

    pd = Dict(k => v["pd"] for (k,v) in ref(pm, n, :load))
    qd = Dict(k => v["qd"] for (k,v) in ref(pm, n, :load))

    gs = Dict(k => v["gs"] for (k,v) in ref(pm, n, :shunt))
    bs = Dict(k => v["bs"] for (k,v) in ref(pm, n, :shunt))

    constraint_kcl_shunt(pm, n, i, bus_arcs, bus_arcs_dc, bus_gens, bus_loads, bus_shunts, pd, qd, gs, bs)
end
constraint_kcl_shunt(pm::GenericPowerModel, i::Int) = constraint_kcl_shunt(pm, pm.cnw, i::Int)


""
function constraint_kcl_shunt_ne(pm::GenericPowerModel, n::Int, i::Int)
    bus = ref(pm, n, :bus, i)
    bus_arcs = ref(pm, n, :bus_arcs, i)
    bus_arcs_dc = ref(pm, n, :bus_arcs_dc, i)
    bus_arcs_ne = ref(pm, n, :ne_bus_arcs, i)
    bus_gens = ref(pm, n, :bus_gens, i)
    bus_loads = ref(pm, n, :bus_loads, i)
    bus_shunts = ref(pm, n, :bus_shunts, i)

    pd = Dict(k => v["pd"] for (k,v) in ref(pm, n, :load))
    qd = Dict(k => v["qd"] for (k,v) in ref(pm, n, :load))

    gs = Dict(k => v["gs"] for (k,v) in ref(pm, n, :shunt))
    bs = Dict(k => v["bs"] for (k,v) in ref(pm, n, :shunt))

    constraint_kcl_shunt_ne(pm, n, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, pd, qd, gs, bs)
end
constraint_kcl_shunt_ne(pm::GenericPowerModel, i::Int) = constraint_kcl_shunt_ne(pm, pm.cnw, i::Int)



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
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_ohms_yt_from(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
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
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_ohms_yt_to(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
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
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]
    ta = branch["shift"]

    constraint_ohms_y_from(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tm, ta)
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
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]
    ta = branch["shift"]

    constraint_ohms_y_to(pm, n, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tm, ta)
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


function constraint_active_dcline_setpoint(pm::GenericPowerModel, n::Int, i::Int)
    dcline = ref(pm, n, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    pf = dcline["pf"]
    pt = dcline["pt"]

    constraint_active_dcline_setpoint(pm, n, f_idx, t_idx, pf, pt)
end
constraint_active_dcline_setpoint(pm::GenericPowerModel, i::Int) = constraint_active_dcline_setpoint(pm, pm.cnw, i)



### Branch - On/Off Ohm's Law Constraints ###

""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    vad_min = ref(pm, n, :off_angmin)
    vad_max = ref(pm, n, :off_angmax)

    constraint_ohms_yt_from_on_off(pm, n, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
end
constraint_ohms_yt_from_on_off(pm::GenericPowerModel, i::Int) = constraint_ohms_yt_from_on_off(pm, pm.cnw, i)


""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    vad_min = ref(pm, n, :off_angmin)
    vad_max = ref(pm, n, :off_angmax)

    constraint_ohms_yt_to_on_off(pm, n, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end
constraint_ohms_yt_to_on_off(pm::GenericPowerModel, i::Int) = constraint_ohms_yt_to_on_off(pm, pm.cnw, i)


""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    vad_min = ref(pm, n, :off_angmin)
    vad_max = ref(pm, n, :off_angmax)

    constraint_ohms_yt_from_ne(pm, n, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
end
constraint_ohms_yt_from_ne(pm::GenericPowerModel, i::Int) = constraint_ohms_yt_from_ne(pm, pm.cnw, i)


""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    vad_min = ref(pm, n, :off_angmin)
    vad_max = ref(pm, n, :off_angmax)

    constraint_ohms_yt_to_ne(pm, n, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end
constraint_ohms_yt_to_ne(pm::GenericPowerModel, i::Int) = constraint_ohms_yt_to_ne(pm, pm.cnw, i)



### Branch - Current ###

""
function constraint_power_magnitude_sqr(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"]

    constraint_power_magnitude_sqr(pm, n, f_bus, t_bus, arc_from, tm)
end
constraint_power_magnitude_sqr(pm::GenericPowerModel, i::Int) = constraint_power_magnitude_sqr(pm, pm.cnw, i)


""
function constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"]

    constraint_power_magnitude_sqr_on_off(pm, n, i, f_bus, arc_from, tm)
end
constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel, i::Int) = constraint_power_magnitude_sqr_on_off(pm, pm.cnw, i)


""
function constraint_power_magnitude_link(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_power_magnitude_link(pm, n, f_bus, t_bus, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
end
constraint_power_magnitude_link(pm::GenericPowerModel, i::Int) = constraint_power_magnitude_link(pm, pm.cnw, i)

""
function constraint_power_magnitude_link_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_power_magnitude_link_on_off(pm, n, i, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
end
constraint_power_magnitude_link_on_off(pm::GenericPowerModel, i::Int) = constraint_power_magnitude_link_on_off(pm, pm.cnw, i)


### Branch - Thermal Limit Constraints ###

"""

    constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, i::Int)

Adds the (upper and lower) thermal limit constraints for the desired branch to the PowerModel.

"""
function constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, i::Int)
    if !haskey(pm.con[:nw][n], :sm_fr)
        pm.con[:nw][n][:sm_fr] = Dict{Int,Any}() # note this can be a constraint or variable
    end

    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from(pm, n, f_idx, branch["rate_a"])
end
constraint_thermal_limit_from(pm::GenericPowerModel, i::Int) = constraint_thermal_limit_from(pm, pm.cnw, i)

""
function constraint_thermal_limit_to(pm::GenericPowerModel, n::Int, i::Int)
    if !haskey(pm.con[:nw][n], :sm_to)
        pm.con[:nw][n][:sm_to] = Dict{Int,Any}() # note this can be a constraint or variable
    end

    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to(pm, n, t_idx, branch["rate_a"])
end
constraint_thermal_limit_to(pm::GenericPowerModel, i::Int) = constraint_thermal_limit_to(pm, pm.cnw, i)

""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_on_off(pm, n, i, f_idx, branch["rate_a"])
end
constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i::Int) = constraint_thermal_limit_from_on_off(pm, pm.cnw, i)


""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_on_off(pm, n, i, t_idx, branch["rate_a"])
end
constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i::Int) = constraint_thermal_limit_to_on_off(pm, pm.cnw, i)


""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_ne(pm, n, i, f_idx, branch["rate_a"])
end
constraint_thermal_limit_from_ne(pm::GenericPowerModel, i::Int) = constraint_thermal_limit_from_ne(pm, pm.cnw, i)


""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_ne(pm, n, i, t_idx, branch["rate_a"])
end
constraint_thermal_limit_to_ne(pm::GenericPowerModel, i::Int) = constraint_thermal_limit_to_ne(pm, pm.cnw, i)



### Branch - Phase Angle Difference Constraints ###

""
function constraint_voltage_angle_difference(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    pair = (f_bus, t_bus)
    buspair = ref(pm, n, :buspairs, pair)

    if buspair["branch"] == i
        constraint_voltage_angle_difference(pm, n, f_idx, buspair["angmin"], buspair["angmax"])
    end
end
constraint_voltage_angle_difference(pm::GenericPowerModel, i::Int) = constraint_voltage_angle_difference(pm, pm.cnw, i)


""
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, n, :off_angmin)
    vad_max = ref(pm, n, :off_angmax)

    constraint_voltage_angle_difference_on_off(pm, n, f_idx, branch["angmin"], branch["angmax"], vad_min, vad_max)
end
constraint_voltage_angle_difference_on_off(pm::GenericPowerModel, i::Int) = constraint_voltage_angle_difference_on_off(pm, pm.cnw, i)


""
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :ne_branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, n, :off_angmin)
    vad_max = ref(pm, n, :off_angmax)

    constraint_voltage_angle_difference_ne(pm, n, f_idx, branch["angmin"], branch["angmax"], vad_min, vad_max)
end
constraint_voltage_angle_difference_ne(pm::GenericPowerModel, i::Int) = constraint_voltage_angle_difference_ne(pm, pm.cnw, i)


### Branch - Loss Constraints ###

""
function constraint_loss_lb(pm::GenericPowerModel, n::Int, i::Int)
    branch = ref(pm, n, :branch, i)
    @assert branch["br_r"] >= 0
    @assert branch["br_x"] >= 0
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tr = branch["tr"]

    constraint_loss_lb(pm, n, f_bus, t_bus, f_idx, t_idx, g_fr, b_fr, g_to, b_to, tr)
end
constraint_loss_lb(pm::GenericPowerModel, i::Int) = constraint_loss_lb(pm, pm.cnw, i)

function constraint_flow_losses(pm::GenericPowerModel, n::Int, i)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]

    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]
    constraint_flow_losses(pm::GenericPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end
constraint_flow_losses(pm::GenericPowerModel, i::Int) = constraint_flow_losses(pm, pm.cnw, i)

function constraint_voltage_magnitude_difference(pm::GenericPowerModel, n::Int, i)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_voltage_magnitude_difference(pm, n, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)

end
constraint_voltage_magnitude_difference(pm::GenericPowerModel, i::Int) = constraint_voltage_magnitude_difference(pm, pm.cnw, i)


function constraint_branch_current(pm::GenericPowerModel, n::Int, i)
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    tm = branch["tap"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]

    constraint_branch_current(pm, n, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm)
end
constraint_branch_current(pm::GenericPowerModel, i::Int) = constraint_branch_current(pm, pm.cnw, i)
