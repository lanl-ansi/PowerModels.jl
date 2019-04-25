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
function constraint_voltage(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    constraint_voltage(pm, nw, cnd)
end

""
function constraint_voltage_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    constraint_voltage_on_off(pm, nw, cnd)
end

""
function constraint_voltage_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    constraint_voltage_ne(pm, nw, cnd)
end


### Generator Constraints ###

""
function constraint_active_gen_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    gen = ref(pm, nw, :gen, i)
    constraint_active_gen_setpoint(pm, nw, cnd, gen["index"], gen["pg"][cnd])
end

""
function constraint_reactive_gen_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    gen = ref(pm, nw, :gen, i)
    constraint_reactive_gen_setpoint(pm, nw, cnd, gen["index"], gen["qg"][cnd])
end

function constraint_generation_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    gen = ref(pm, nw, :gen, i)

    constraint_generation_on_off(pm, nw, cnd, i, gen["pmin"][cnd], gen["pmax"][cnd], gen["qmin"][cnd], gen["qmax"][cnd])
end


### Bus - Setpoint Constraints ###

""
function constraint_theta_ref(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    constraint_theta_ref(pm, nw, cnd, i)
end

""
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    bus = ref(pm, nw, :bus, i)
    constraint_voltage_magnitude_setpoint(pm, nw, cnd, bus["index"], bus["vm"][cnd])
end


### Power Balance Constraints ###

"ensures that power generation and demand are balanced"
function constraint_power_balance(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    comp_bus_ids = ref(pm, nw, :components, i)

    comp_gen_ids = Set{Int64}()
    for bus_id in comp_bus_ids, gen_id in PowerModels.ref(pm, nw, :bus_gens, bus_id)
        push!(comp_gen_ids, gen_id)
    end

    comp_loads = Set()
    for bus_id in comp_bus_ids, load_id in PowerModels.ref(pm, nw, :bus_loads, bus_id)
        push!(comp_loads, PowerModels.ref(pm, nw, :load, load_id))
    end

    comp_shunts = Set()
    for bus_id in comp_bus_ids, shunt_id in PowerModels.ref(pm, nw, :bus_shunts, bus_id)
        push!(comp_shunts, PowerModels.ref(pm, nw, :shunt, shunt_id))
    end

    comp_branches = Set()
    for (branch_id, branch) in PowerModels.ref(pm, nw, :branch)
        if in(branch["f_bus"], comp_bus_ids) && in(branch["t_bus"], comp_bus_ids)
            push!(comp_branches, branch)
        end
    end

    comp_pd = Dict(load["index"] => (load["load_bus"], load["pd"][cnd]) for load in comp_loads)
    comp_qd = Dict(load["index"] => (load["load_bus"], load["qd"][cnd]) for load in comp_loads)

    comp_gs = Dict(shunt["index"] => (shunt["shunt_bus"], shunt["gs"][cnd]) for shunt in comp_shunts)
    comp_bs = Dict(shunt["index"] => (shunt["shunt_bus"], shunt["bs"][cnd]) for shunt in comp_shunts)

    comp_branch_g = Dict(branch["index"] => (branch["f_bus"], branch["t_bus"], branch["br_r"][cnd], branch["br_x"][cnd], branch["tap"][cnd], branch["g_fr"][cnd], branch["g_to"][cnd]) for branch in comp_branches)
    comp_branch_b = Dict(branch["index"] => (branch["f_bus"], branch["t_bus"], branch["br_r"][cnd], branch["br_x"][cnd], branch["tap"][cnd], branch["b_fr"][cnd], branch["b_to"][cnd]) for branch in comp_branches)

    constraint_power_balance(pm, nw, cnd, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b)
end


### Bus - KCL Constraints ###

""
function constraint_kcl_shunt(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(con(pm, nw, cnd), :kcl_p)
        con(pm, nw, cnd)[:kcl_p] = Dict{Int,JuMP.ConstraintRef}()
    end
    if !haskey(con(pm, nw, cnd), :kcl_q)
        con(pm, nw, cnd)[:kcl_q] = Dict{Int,JuMP.ConstraintRef}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd", cnd) for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd", cnd) for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", cnd) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", cnd) for k in bus_shunts)

    constraint_kcl_shunt(pm, nw, cnd, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
end

""
function constraint_kcl_shunt_storage(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(con(pm, nw, cnd), :kcl_p)
        con(pm, nw, cnd)[:kcl_p] = Dict{Int,JuMP.ConstraintRef}()
    end
    if !haskey(con(pm, nw, cnd), :kcl_q)
        con(pm, nw, cnd)[:kcl_q] = Dict{Int,JuMP.ConstraintRef}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd", cnd) for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd", cnd) for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", cnd) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", cnd) for k in bus_shunts)

    constraint_kcl_shunt_storage(pm, nw, cnd, i, bus_arcs, bus_arcs_dc, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end

""
function constraint_kcl_shunt_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_ne = ref(pm, nw, :ne_bus_arcs, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd", cnd) for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd", cnd) for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", cnd) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", cnd) for k in bus_shunts)

    constraint_kcl_shunt_ne(pm, nw, cnd, i, bus_arcs, bus_arcs_dc, bus_arcs_ne, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
end


### Branch - Ohm's Law Constraints ###

""
function constraint_ohms_yt_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    tm = branch["tap"][cnd]

    constraint_ohms_yt_from(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_fr, b_fr, tr[cnd], ti[cnd], tm)
end


""
function constraint_ohms_yt_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]

    constraint_ohms_yt_to(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_to, b_to, tr[cnd], ti[cnd], tm)
end


""
function constraint_ohms_y_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    tm = branch["tap"][cnd]
    ta = branch["shift"][cnd]

    constraint_ohms_y_from(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_fr, b_fr, tm, ta)
end


""
function constraint_ohms_y_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]
    ta = branch["shift"][cnd]

    constraint_ohms_y_to(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_to, b_to, tm, ta)
end


### Branch - On/Off Ohm's Law Constraints ###

""
function constraint_ohms_yt_from_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    tm = branch["tap"][cnd]

    vad_min = ref(pm, nw, :off_angmin, cnd)
    vad_max = ref(pm, nw, :off_angmax, cnd)

    constraint_ohms_yt_from_on_off(pm, nw, cnd, i, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_fr, b_fr, tr[cnd], ti[cnd], tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_to_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]

    vad_min = ref(pm, nw, :off_angmin, cnd)
    vad_max = ref(pm, nw, :off_angmax, cnd)

    constraint_ohms_yt_to_on_off(pm, nw, cnd, i, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_to, b_to, tr[cnd], ti[cnd], tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_from_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    tm = branch["tap"][cnd]

    vad_min = ref(pm, nw, :off_angmin, cnd)
    vad_max = ref(pm, nw, :off_angmax, cnd)

    constraint_ohms_yt_from_ne(pm, nw, cnd, i, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_fr, b_fr, tr[cnd], ti[cnd], tm, vad_min, vad_max)
end


""
function constraint_ohms_yt_to_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]

    vad_min = ref(pm, nw, :off_angmin, cnd)
    vad_max = ref(pm, nw, :off_angmax, cnd)

    constraint_ohms_yt_to_ne(pm, nw, cnd, i, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_to, b_to, tr[cnd], ti[cnd], tm, vad_min, vad_max)
end



### Branch - Current ###

""
function constraint_power_magnitude_sqr(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"][cnd]

    constraint_power_magnitude_sqr(pm, nw, cnd, f_bus, t_bus, arc_from, tm)
end


""
function constraint_power_magnitude_sqr_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    tm = branch["tap"][cnd]

    constraint_power_magnitude_sqr_on_off(pm, nw, cnd, i, f_bus, arc_from, tm)
end


""
function constraint_power_magnitude_link(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]

    constraint_power_magnitude_link(pm, nw, cnd, f_bus, t_bus, arc_from, g[cnd], b[cnd], g_fr, b_fr, g_to, b_to, tr[cnd], ti[cnd], tm)
end


""
function constraint_power_magnitude_link_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    arc_from = (i, f_bus, t_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]

    constraint_power_magnitude_link_on_off(pm, nw, cnd, i, arc_from, g[cnd], b[cnd], g_fr, b_fr, g_to, b_to, tr[cnd], ti[cnd], tm)
end


### Branch - Thermal Limit Constraints ###

"""

    constraint_thermal_limit_from(pm::GenericPowerModel, n::Int, i::Int)

Adds the (upper and lower) thermal limit constraints for the desired branch to the PowerModel.

"""
function constraint_thermal_limit_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(con(pm, nw, cnd), :sm_fr)
        con(pm, nw, cnd)[:sm_fr] = Dict{Int,Any}() # note this can be a constraint or a variable bound
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from(pm, nw, cnd, f_idx, branch["rate_a"][cnd])
end


""
function constraint_thermal_limit_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(con(pm, nw, cnd), :sm_to)
        con(pm, nw, cnd)[:sm_to] = Dict{Int,Any}() # note this can be a constraint or a variable bound
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to(pm, nw, cnd, t_idx, branch["rate_a"][cnd])
end


""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_on_off(pm, nw, cnd, i, f_idx, branch["rate_a"][cnd])
end


""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_on_off(pm, nw, cnd, i, t_idx, branch["rate_a"][cnd])
end


""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_thermal_limit_from_ne(pm, nw, cnd, i, f_idx, branch["rate_a"][cnd])
end


""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    constraint_thermal_limit_to_ne(pm, nw, cnd, i, t_idx, branch["rate_a"][cnd])
end


### Branch - Current Limit Constraints ###

"""
Adds a current magnitude limit constraint for the desired branch to the PowerModel.
"""
function constraint_current_limit(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    constraint_current_limit(pm, nw, cnd, f_idx, branch["c_rating_a"][cnd])
end


### Branch - Phase Angle Difference Constraints ###

""
function constraint_voltage_angle_difference(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    pair = (f_bus, t_bus)
    buspair = ref(pm, nw, :buspairs, pair)

    if buspair["branch"] == i
        constraint_voltage_angle_difference(pm, nw, cnd, f_idx, buspair["angmin"][cnd], buspair["angmax"][cnd])
    end
end


""
function constraint_voltage_angle_difference_on_off(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, nw, :off_angmin, cnd)
    vad_max = ref(pm, nw, :off_angmax, cnd)

    constraint_voltage_angle_difference_on_off(pm, nw, cnd, f_idx, branch["angmin"][cnd], branch["angmax"][cnd], vad_min, vad_max)
end


""
function constraint_voltage_angle_difference_ne(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :ne_branch, i)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = ref(pm, nw, :off_angmin, cnd)
    vad_max = ref(pm, nw, :off_angmax, cnd)

    constraint_voltage_angle_difference_ne(pm, nw, cnd, f_idx, branch["angmin"][cnd], branch["angmax"][cnd], vad_min, vad_max)
end


### Branch - Loss Constraints ###

""
function constraint_loss_lb(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    @assert branch["br_r"] >= 0
    @assert branch["br_x"] >= 0
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    # CHECK: Do I need all these variables?
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tr = branch["tr"][cnd]

    constraint_loss_lb(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g_fr, b_fr, g_to, b_to, tr)
end

""
function constraint_flow_losses(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"][cnd]
    x = branch["br_x"][cnd]
    tm = branch["tap"][cnd]
    g_sh_fr = branch["g_fr"][cnd]
    g_sh_to = branch["g_to"][cnd]
    b_sh_fr = branch["b_fr"][cnd]
    b_sh_to = branch["b_to"][cnd]

    constraint_flow_losses(pm::GenericPowerModel, nw, cnd, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end

""
function constraint_voltage_magnitude_difference(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"][cnd]
    x = branch["br_x"][cnd]
    g_sh_fr = branch["g_fr"][cnd]
    b_sh_fr = branch["b_fr"][cnd]
    tm = branch["tap"][cnd]

    constraint_voltage_magnitude_difference(pm, nw, cnd, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end

""
function constraint_branch_current(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tm = branch["tap"][cnd]
    g_sh_fr = branch["g_fr"][cnd]
    b_sh_fr = branch["b_fr"][cnd]

    constraint_branch_current(pm, nw, cnd, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm)
end




### Storage Constraints ###

""
function constraint_storage_thermal_limit(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    storage = ref(pm, nw, :storage, i)
    constraint_storage_thermal_limit(pm, nw, cnd, i, storage["thermal_rating"][cnd])
end

""
function constraint_storage_current_limit(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    storage = ref(pm, nw, :storage, i)
    constraint_storage_current_limit(pm, nw, cnd, i, storage["storage_bus"], storage["current_rating"][cnd])
end

""
function constraint_storage_complementarity(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    constraint_storage_complementarity(pm, nw, i)
end

""
function constraint_storage_loss(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    storage = ref(pm, nw, :storage, i)

    constraint_storage_loss(pm, nw, i, storage["storage_bus"], storage["r"][cnd], storage["x"][cnd], storage["standby_loss"])
end

""
function constraint_storage_state(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw)
    storage = ref(pm, nw, :storage, i)

    if haskey(pm.data, "time_elapsed")
        time_elapsed = pm.data["time_elapsed"]
    else
        Memento.warn("network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    constraint_storage_state_initial(pm, nw, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], time_elapsed)
end

""
function constraint_storage_state(pm::GenericPowerModel, i::Int, nw_1::Int, nw_2::Int)
    storage = ref(pm, nw_2, :storage, i)

    if haskey(pm.data, "time_elapsed")
        time_elapsed = pm.data["time_elapsed"]
    else
        Memento.warn("network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    constraint_storage_state(pm, nw_1, nw_2, i, storage["charge_efficiency"], storage["discharge_efficiency"], time_elapsed)
end


### DC LINES ###

""
function constraint_dcline(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    dcline = ref(pm, nw, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    loss0 = dcline["loss0"][cnd]
    loss1 = dcline["loss1"][cnd]

    constraint_dcline(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
end

""
function constraint_active_dcline_setpoint(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    dcline = ref(pm, nw, :dcline, i)
    f_bus = dcline["f_bus"]
    t_bus = dcline["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    pf = dcline["pf"][cnd]
    pt = dcline["pt"][cnd]

    constraint_active_dcline_setpoint(pm, nw, cnd, f_idx, t_idx, pf, pt)
end
