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

""
function constraint_voltage(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    constraint_voltage(pm, nw, ph)
end

""
function constraint_voltage_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    constraint_voltage_on_off(pm, nw, ph)
end

""
function constraint_voltage_ne(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph)
    constraint_voltage_ne(pm, nw, ph)
end


### Generator Constraints ###

""
function constraint_active_gen_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    gen = ref(pm, nw, ph, :gen, i)
    constraint_active_gen_setpoint(pm, nw, ph, gen["index"], gen["pg"])
end

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    gen = ref(pm, nw, ph, :gen, i)
    constraint_reactive_gen_setpoint(pm, nw, ph, gen["index"], gen["qg"])
end


### Bus - Setpoint Constraints ###

""
function constraint_theta_ref(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    constraint_theta_ref(pm, nw, ph, i)
end

""
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    bus = ref(pm, nw, ph, :bus, i)
    constraint_voltage_magnitude_setpoint(pm, nw, ph, bus["index"], bus["vm"])
end


### Bus - KCL Constraints ###

""
function constraint_kcl_shunt(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    if !haskey(con(pm, nw, ph), :kcl_p)
        con(pm, nw, ph)[:kcl_p] = Dict{Int,ConstraintRef}()
    end
    if !haskey(con(pm, nw, ph), :kcl_q)
        con(pm, nw, ph)[:kcl_q] = Dict{Int,ConstraintRef}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd", ph) for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd", ph) for k in bus_loads)

    bus_gs = Dict(k => ref(pm, n, :shunt, k, "gs", ph) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, n, :shunt, k, "bs", ph) for k in bus_shunts)

    constraint_kcl_shunt(pm, nw, ph, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
end


""
function constraint_kcl_shunt_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    bus = ref(pm, nw, ph, :bus, i)
    bus_arcs = ref(pm, nw, ph, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, ph, :bus_arcs_dc, i)
    bus_arcs_ne = ref(pm, nw, ph, :ne_bus_arcs, i)
    bus_gens = ref(pm, nw, ph, :bus_gens, i)
    bus_loads = ref(pm, nw, ph, :bus_loads, i)
    bus_shunts = ref(pm, nw, ph, :bus_shunts, i)

    pd = Dict(k => v["pd"] for (k,v) in ref(pm, nw, ph, :load))
    qd = Dict(k => v["qd"] for (k,v) in ref(pm, nw, ph, :load))

    gs = Dict(k => v["gs"] for (k,v) in ref(pm, nw, ph, :shunt))
    bs = Dict(k => v["bs"] for (k,v) in ref(pm, nw, ph, :shunt))

    constraint_kcl_shunt_ne(pm, nw, ph, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, pd, qd, gs, bs)
end


### Branch - Ohm's Law Constraints ###

""
function constraint_ohms_yt_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"][ph]
    b_fr = branch["b_fr"][ph]
    tm = branch["tap"][ph]

    constraint_ohms_yt_from(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g[ph], b[ph], g_fr, b_fr, tr[ph], ti[ph], tm)
end


""
function constraint_ohms_yt_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"][ph]
    b_to = branch["b_to"][ph]
    tm = branch["tap"][ph]

    constraint_ohms_yt_to(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g[ph], b[ph], g_to, b_to, tr[ph], ti[ph], tm)
end


""
function constraint_ohms_y_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]
    ta = branch["shift"]

    constraint_ohms_y_from(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tm, ta)
end


""
function constraint_ohms_y_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]
    ta = branch["shift"]

    constraint_ohms_y_to(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tm, ta)
end


### DC LINES ###

""
function constraint_dcline(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    dcline = ref(pm, nw, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    loss0 = dcline["loss0"][ph]
    loss1 = dcline["loss1"][ph]

    constraint_dcline(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
end


function constraint_active_dcline_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    dcline = ref(pm, nw, ph, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    pf = dcline["pf"]
    pt = dcline["pt"]

    constraint_active_dcline_setpoint(pm, nw, ph, f_idx, t_idx, pf, pt)
end



### Branch - On/Off Ohm's Law Constraints ###

""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    vad_min = ref(pm, nw, ph, :off_angmin)
    vad_max = ref(pm, nw, ph, :off_angmax)

    constraint_ohms_yt_from_on_off(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    vad_min = ref(pm, nw, ph, :off_angmin)
    vad_max = ref(pm, nw, ph, :off_angmax)

    constraint_ohms_yt_to_on_off(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    vad_min = ref(pm, nw, ph, :off_angmin)
    vad_max = ref(pm, nw, ph, :off_angmax)

    constraint_ohms_yt_from_ne(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    vad_min = ref(pm, nw, ph, :off_angmin)
    vad_max = ref(pm, nw, ph, :off_angmax)

    constraint_ohms_yt_to_ne(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end



### Branch - Current ###

""
function constraint_power_magnitude_sqr(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"]

    constraint_power_magnitude_sqr(pm, nw, ph, f_bus, t_bus, arc_from, tm)
end


""
function constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"]

    constraint_power_magnitude_sqr_on_off(pm, nw, ph, i, f_bus, arc_from, tm)
end


""
function constraint_power_magnitude_link(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
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

    constraint_power_magnitude_link(pm, nw, ph, f_bus, t_bus, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
end


""
function constraint_power_magnitude_link_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
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

    constraint_power_magnitude_link_on_off(pm, nw, ph, i, arc_from, g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm)
end


### Branch - Thermal Limit Constraints ###

"""

    constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, i::Int)

Adds the (upper and lower) thermal limit constraints for the desired branch to the PowerModel.

"""
function constraint_thermal_limit_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    if !haskey(con(pm, nw, ph), :sm_fr)
        con(pm, nw, ph)[:sm_fr] = Dict{Int,Any}() # note this can be a constraint or variable
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from(pm, nw, ph, f_idx, branch["rate_a"][ph])
end


""
function constraint_thermal_limit_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    if !haskey(con(pm, nw, ph), :sm_to)
        con(pm, nw, ph)[:sm_to] = Dict{Int,Any}() # note this can be a constraint or variable
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to(pm, nw, ph, t_idx, branch["rate_a"][ph])
end


""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_on_off(pm, nw, ph, i, f_idx, branch["rate_a"])
end


""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_on_off(pm, nw, ph, i, t_idx, branch["rate_a"])
end


""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_ne(pm, nw, ph, i, f_idx, branch["rate_a"])
end


""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_ne(pm, nw, ph, i, t_idx, branch["rate_a"])
end



### Branch - Phase Angle Difference Constraints ###

""
function constraint_voltage_angle_difference(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    pair = (f_bus, t_bus)
    buspair = ref(pm, nw, :buspairs, pair)

    if buspair["branch"] == i
        constraint_voltage_angle_difference(pm, nw, ph, f_idx, buspair["angmin"][ph], buspair["angmax"][ph])
    end
end


""
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, nw, ph, :off_angmin)
    vad_max = ref(pm, nw, ph, :off_angmax)

    constraint_voltage_angle_difference_on_off(pm, nw, ph, f_idx, branch["angmin"], branch["angmax"], vad_min, vad_max)
end


""
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :ne_branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, nw, ph, :off_angmin)
    vad_max = ref(pm, nw, ph, :off_angmax)

    constraint_voltage_angle_difference_ne(pm, nw, ph, f_idx, branch["angmin"], branch["angmax"], vad_min, vad_max)
end


### Branch - Loss Constraints ###

""
function constraint_loss_lb(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
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

    constraint_loss_lb(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g_fr, b_fr, g_to, b_to, tr)
end


function constraint_flow_losses(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
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
    constraint_flow_losses(pm::GenericPowerModel, nw, ph, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end


function constraint_voltage_magnitude_difference(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_voltage_magnitude_difference(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end


function constraint_branch_current(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, ph, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    tm = branch["tap"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]

    constraint_branch_current(pm, nw, ph, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm)
end

