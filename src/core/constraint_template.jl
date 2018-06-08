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
    gen = ref(pm, nw, :gen, i)
    constraint_active_gen_setpoint(pm, nw, ph, gen["index"], gen["pg"][ph])
end

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    gen = ref(pm, nw, :gen, i)
    constraint_reactive_gen_setpoint(pm, nw, ph, gen["index"], gen["qg"][ph])
end


### Bus - Setpoint Constraints ###

""
function constraint_theta_ref(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    constraint_theta_ref(pm, nw, ph, i)
end

""
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    bus = ref(pm, nw, :bus, i)
    constraint_voltage_magnitude_setpoint(pm, nw, ph, bus["index"], bus["vm"][ph])
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

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", ph) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", ph) for k in bus_shunts)

    constraint_kcl_shunt(pm, nw, ph, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
end


""
function constraint_kcl_shunt_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_ne = ref(pm, nw, :ne_bus_arcs, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd", ph) for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd", ph) for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", ph) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", ph) for k in bus_shunts)

    constraint_kcl_shunt_ne(pm, nw, ph, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
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

    constraint_ohms_yt_from(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_fr, b_fr, tr[ph], ti[ph], tm)
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

    constraint_ohms_yt_to(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_to, b_to, tr[ph], ti[ph], tm)
end


""
function constraint_ohms_y_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_fr = branch["g_fr"][ph]
    b_fr = branch["b_fr"][ph]
    tm = branch["tap"][ph]
    ta = branch["shift"][ph]

    constraint_ohms_y_from(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_fr, b_fr, tm, ta)
end


""
function constraint_ohms_y_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_to = branch["g_to"][ph]
    b_to = branch["b_to"][ph]
    tm = branch["tap"][ph]
    ta = branch["shift"][ph]

    constraint_ohms_y_to(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_to, b_to, tm, ta)
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
    dcline = ref(pm, nw, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    pf = dcline["pf"][ph]
    pt = dcline["pt"][ph]

    constraint_active_dcline_setpoint(pm, nw, ph, f_idx, t_idx, pf, pt)
end



### Branch - On/Off Ohm's Law Constraints ###

""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
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

    vad_min = ref(pm, nw, :off_angmin, ph)
    vad_max = ref(pm, nw, :off_angmax, ph)

    constraint_ohms_yt_from_on_off(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_fr, b_fr, tr[ph], ti[ph], tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
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

    vad_min = ref(pm, nw, :off_angmin, ph)
    vad_max = ref(pm, nw, :off_angmax, ph)

    constraint_ohms_yt_to_on_off(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_to, b_to, tr[ph], ti[ph], tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"][ph]
    b_fr = branch["b_fr"][ph]
    tm = branch["tap"][ph]

    vad_min = ref(pm, nw, :off_angmin, ph)
    vad_max = ref(pm, nw, :off_angmax, ph)

    constraint_ohms_yt_from_ne(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_fr, b_fr, tr[ph], ti[ph], tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"][ph]
    b_to = branch["b_to"][ph]
    tm = branch["tap"][ph]

    vad_min = ref(pm, nw, :off_angmin, ph)
    vad_max = ref(pm, nw, :off_angmax, ph)

    constraint_ohms_yt_to_ne(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, g[ph,ph], b[ph,ph], g_to, b_to, tr[ph], ti[ph], tm, vad_min, vad_max)
end



### Branch - Current ###

""
function constraint_power_magnitude_sqr(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"][ph]

    constraint_power_magnitude_sqr(pm, nw, ph, f_bus, t_bus, arc_from, tm)
end


""
function constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"][ph]

    constraint_power_magnitude_sqr_on_off(pm, nw, ph, i, f_bus, arc_from, tm)
end


""
function constraint_power_magnitude_link(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"][ph]
    b_fr = branch["b_fr"][ph]
    g_to = branch["g_to"][ph]
    b_to = branch["b_to"][ph]
    tm = branch["tap"][ph]

    constraint_power_magnitude_link(pm, nw, ph, f_bus, t_bus, arc_from, g[ph], b[ph], g_fr, b_fr, g_to, b_to, tr[ph], ti[ph], tm)
end


""
function constraint_power_magnitude_link_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"][ph]
    b_fr = branch["b_fr"][ph]
    g_to = branch["g_to"][ph]
    b_to = branch["b_to"][ph]
    tm = branch["tap"][ph]

    constraint_power_magnitude_link_on_off(pm, nw, ph, i, arc_from, g[ph], b[ph], g_fr, b_fr, g_to, b_to, tr[ph], ti[ph], tm)
end


### Branch - Thermal Limit Constraints ###

"""

    constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, i::Int)

Adds the (upper and lower) thermal limit constraints for the desired branch to the PowerModel.

"""
function constraint_thermal_limit_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    if !haskey(con(pm, nw, ph), :sm_fr)
        con(pm, nw, ph)[:sm_fr] = Dict{Int,Any}() # note this can be a constraint or a variable bound
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
        con(pm, nw, ph)[:sm_to] = Dict{Int,Any}() # note this can be a constraint or a variable bound
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to(pm, nw, ph, t_idx, branch["rate_a"][ph])
end


""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_on_off(pm, nw, ph, i, f_idx, branch["rate_a"][ph])
end


""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_on_off(pm, nw, ph, i, t_idx, branch["rate_a"][ph])
end


""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_ne(pm, nw, ph, i, f_idx, branch["rate_a"][ph])
end


""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_ne(pm, nw, ph, i, t_idx, branch["rate_a"][ph])
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
    branch = ref(pm, nw, :branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, nw, :off_angmin, ph)
    vad_max = ref(pm, nw, :off_angmax, ph)

    constraint_voltage_angle_difference_on_off(pm, nw, ph, f_idx, branch["angmin"][ph], branch["angmax"][ph], vad_min, vad_max)
end


""
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :ne_branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, nw, :off_angmin, ph)
    vad_max = ref(pm, nw, :off_angmax, ph)

    constraint_voltage_angle_difference_ne(pm, nw, ph, f_idx, branch["angmin"][ph], branch["angmax"][ph], vad_min, vad_max)
end


### Branch - Loss Constraints ###

""
function constraint_loss_lb(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    @assert branch["br_r"] >= 0
    @assert branch["br_x"] >= 0
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"][ph]
    b_fr = branch["b_fr"][ph]
    g_to = branch["g_to"][ph]
    b_to = branch["b_to"][ph]
    tr = branch["tr"][ph]

    constraint_loss_lb(pm, nw, ph, f_bus, t_bus, f_idx, t_idx, g_fr, b_fr, g_to, b_to, tr)
end


function constraint_flow_losses(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"][ph]
    x = branch["br_x"][ph]
    tm = branch["tap"][ph]
    g_sh_fr = branch["g_fr"][ph]
    g_sh_to = branch["g_to"][ph]
    b_sh_fr = branch["b_fr"][ph]
    b_sh_to = branch["b_to"][ph]

    constraint_flow_losses(pm::GenericPowerModel, nw, ph, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end


function constraint_voltage_magnitude_difference(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"][ph]
    x = branch["br_x"][ph]
    g_sh_fr = branch["g_fr"][ph]
    b_sh_fr = branch["b_fr"][ph]
    tm = branch["tap"][ph]

    constraint_voltage_magnitude_difference(pm, nw, ph, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end


function constraint_branch_current(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, ph::Int=pm.cph)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tm = branch["tap"][ph]
    g_sh_fr = branch["g_fr"][ph]
    b_sh_fr = branch["b_fr"][ph]

    constraint_branch_current(pm, nw, ph, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm)
end

