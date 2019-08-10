################################################################################
# This file defines common variables used in power flow models
# This will hopefully make everything more compositional
################################################################################


function comp_start_value(comp::Dict{String,<:Any}, key::String, conductor::Int, default=0.0)
    if haskey(comp, key)
        vals = comp[key]
        return conductor_value(vals, conductor)
    end
    return default
end


"variable: `t[i]` for `i` in `bus`es"
function variable_voltage_angle(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    var(pm, nw, cnd)[:va] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_va",
        start = comp_start_value(ref(pm, nw, :bus, i), "va_start", cnd)
    )
end

"variable: `v[i]` for `i` in `bus`es"
function variable_voltage_magnitude(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:vm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vm",
            lower_bound = ref(pm, nw, :bus, i, "vmin", cnd),
            upper_bound = ref(pm, nw, :bus, i, "vmax", cnd),
            start = comp_start_value(ref(pm, nw, :bus, i), "vm_start", cnd, 1.0)
        )
    else
        var(pm, nw, cnd)[:vm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vm",
            start = comp_start_value(ref(pm, nw, :bus, i), "vm_start", cnd, 1.0)
        )
    end
end


"real part of the voltage variable `i` in `bus`es"
function variable_voltage_real(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    if bounded
        var(pm, nw, cnd)[:vr] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vr",
            lower_bound = -ref(pm, nw, :bus, i, "vmax", cnd),
            upper_bound =  ref(pm, nw, :bus, i, "vmax", cnd),
            start = comp_start_value(ref(pm, nw, :bus, i), "vr_start", cnd, 1.0)
        )
    else
        var(pm, nw, cnd)[:vr] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vr",
            start = comp_start_value(ref(pm, nw, :bus, i), "vr_start", cnd, 1.0)
        )
    end
end

"real part of the voltage variable `i` in `bus`es"
function variable_voltage_imaginary(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool = true)
    if bounded
        var(pm, nw, cnd)[:vi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vi",
            lower_bound = -ref(pm, nw, :bus, i, "vmax", cnd),
            upper_bound =  ref(pm, nw, :bus, i, "vmax", cnd),
            start = comp_start_value(ref(pm, nw, :bus, i), "vi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:vi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vi",
            start = comp_start_value(ref(pm, nw, :bus, i), "vi_start", cnd)
        )
    end
end



"variable: `0 <= vm_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:vm_fr] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_vm_fr",
        lower_bound = 0,
        upper_bound = buses[branches[i]["f_bus"]]["vmax"][cnd],
        start = comp_start_value(ref(pm, nw, :branch, i), "vm_fr_start", cnd, 1.0)
    )
end

"variable: `0 <= vm_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]` for `l` in `branch`es"
function variable_voltage_magnitude_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:vm_to] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_vm_to",
        lower_bound = 0,
        upper_bound = buses[branches[i]["t_bus"]]["vmax"][cnd],
        start = comp_start_value(ref(pm, nw, :branch, i), "vm_to_start", cnd, 1.0)
    )
end


"variable: `w[i] >= 0` for `i` in `bus`es"
function variable_voltage_magnitude_sqr(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:w] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_w",
            lower_bound = ref(pm, nw, :bus, i, "vmin", cnd)^2,
            upper_bound = ref(pm, nw, :bus, i, "vmax", cnd)^2,
            start = comp_start_value(ref(pm, nw, :bus, i), "w_start", cnd, 1.001)
        )
    else
        var(pm, nw, cnd)[:w] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_w",
            lower_bound = 0.0,
            start = comp_start_value(ref(pm, nw, :bus, i), "w_start", cnd, 1.001)
        )
    end
end

"variable: `0 <= w_fr[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:w_fr] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_w_fr",
        lower_bound = 0,
        upper_bound = buses[branches[i]["f_bus"]]["vmax"][cnd]^2,
        start = comp_start_value(ref(pm, nw, :branch, i), "w_fr_start", cnd, 1.001)
    )
end

"variable: `0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2` for `l` in `branch`es"
function variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    buses = ref(pm, nw, :bus)
    branches = ref(pm, nw, :branch)

    var(pm, nw, cnd)[:w_to] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_w_to",
        lower_bound = 0,
        upper_bound = buses[branches[i]["t_bus"]]["vmax"][cnd]^2,
        start = comp_start_value(ref(pm, nw, :branch, i), "w_to_start", cnd, 1.001)
    )
end

""
function variable_cosine(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    cos_min = Dict((bp, -Inf) for bp in ids(pm, nw, :buspairs))
    cos_max = Dict((bp,  Inf) for bp in ids(pm, nw, :buspairs))

    for (bp, buspair) in ref(pm, nw, :buspairs)
        angmin = buspair["angmin"][cnd]
        angmax = buspair["angmax"][cnd]
        if angmin >= 0
            cos_max[bp] = cos(angmin)
            cos_min[bp] = cos(angmax)
        end
        if angmax <= 0
            cos_max[bp] = cos(angmax)
            cos_min[bp] = cos(angmin)
        end
        if angmin < 0 && angmax > 0
            cos_max[bp] = 1.0
            cos_min[bp] = min(cos(angmin), cos(angmax))
        end
    end

    var(pm, nw, cnd)[:cs] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_cs",
        lower_bound = cos_min[bp],
        upper_bound = cos_max[bp],
        start = comp_start_value(ref(pm, nw, :buspairs, bp), "cs_start", cnd, 1.0)
    )
end

""
function variable_sine(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:si] = JuMP.@variable(pm.model,
        [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_si",
        lower_bound = sin(ref(pm, nw, :buspairs, bp, "angmin", cnd)),
        upper_bound = sin(ref(pm, nw, :buspairs, bp, "angmax", cnd)),
        start = comp_start_value(ref(pm, nw, :buspairs, bp), "si_start", cnd)
    )
end

""
function variable_voltage_product(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)

        var(pm, nw, cnd)[:wr] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_wr",
            lower_bound = wr_min[bp],
            upper_bound = wr_max[bp],
            start = comp_start_value(ref(pm, nw, :buspairs, bp), "wr_start", cnd, 1.0)
        )
        var(pm, nw, cnd)[:wi] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_wi",
            lower_bound = wi_min[bp],
            upper_bound = wi_max[bp],
            start = comp_start_value(ref(pm, nw, :buspairs, bp), "wi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:wr] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_wr",
            start = comp_start_value(ref(pm, nw, :buspairs, bp), "wr_start", cnd, 1.0)
        )
        var(pm, nw, cnd)[:wi] = JuMP.@variable(pm.model,
            [bp in ids(pm, nw, :buspairs)], base_name="$(nw)_$(cnd)_wi",
            start = comp_start_value(ref(pm, nw, :buspairs, bp), "wi_start", cnd)
        )
    end
end

""
function variable_voltage_product_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)
    bi_bp = Dict((i, (b["f_bus"], b["t_bus"])) for (i,b) in ref(pm, nw, :branch))

    var(pm, nw, cnd)[:wr] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_wr",
        lower_bound = min(0, wr_min[bi_bp[b]]),
        upper_bound = max(0, wr_max[bi_bp[b]]),
        start = comp_start_value(ref(pm, nw, :buspairs, bi_bp[b]), "wr_start", cnd, 1.0)
    )
    var(pm, nw, cnd)[:wi] = JuMP.@variable(pm.model,
        [b in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_wi",
        lower_bound = min(0, wi_min[bi_bp[b]]),
        upper_bound = max(0, wi_max[bi_bp[b]]),
        start = comp_start_value(ref(pm, nw, :buspairs, bi_bp[b]), "wi_start", cnd)
    )
end


"generates variables for both `active` and `reactive` generation"
function variable_generation(pm::GenericPowerModel; kwargs...)
    variable_active_generation(pm; kwargs...)
    variable_reactive_generation(pm; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_active_generation(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:pg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_pg",
            lower_bound = ref(pm, nw, :gen, i, "pmin", cnd),
            upper_bound = ref(pm, nw, :gen, i, "pmax", cnd),
            start = comp_start_value(ref(pm, nw, :gen, i), "pg_start", cnd)
        )
    else
        var(pm, nw, cnd)[:pg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_pg",
            start = comp_start_value(ref(pm, nw, :gen, i), "pg_start", cnd)
        )
    end
end

"variable: `qq[j]` for `j` in `gen`"
function variable_reactive_generation(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        var(pm, nw, cnd)[:qg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_qg",
            lower_bound = ref(pm, nw, :gen, i, "qmin", cnd),
            upper_bound = ref(pm, nw, :gen, i, "qmax", cnd),
            start = comp_start_value(ref(pm, nw, :gen, i), "qg_start", cnd)
        )
    else
        var(pm, nw, cnd)[:qg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_qg",
            start = comp_start_value(ref(pm, nw, :gen, i), "qg_start", cnd)
        )
    end
end


function variable_generation_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, relax=false)
    if !relax
        var(pm, nw)[:z_gen] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_z_gen",
            binary = true,
            start = comp_start_value(ref(pm, nw, :gen, i), "z_gen_start", 1, 1.0)
        )
    else
        var(pm, nw)[:z_gen] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_z_gen",
            lower_bound = 0,
            upper_bound = 1,
            start = comp_start_value(ref(pm, nw, :gen, i), "z_gen_start", 1, 1.0)
        )
    end
end


function variable_generation_on_off(pm::GenericPowerModel; kwargs...)
    variable_active_generation_on_off(pm; kwargs...)
    variable_reactive_generation_on_off(pm; kwargs...)
end

function variable_active_generation_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:pg] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_pg",
        lower_bound = min(0, ref(pm, nw, :gen, i, "pmin", cnd)),
        upper_bound = max(0, ref(pm, nw, :gen, i, "pmax", cnd)),
        start = comp_start_value(ref(pm, nw, :gen, i), "pg_start", cnd)
    )
end

function variable_reactive_generation_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:qg] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_qg",
        lower_bound = min(0, ref(pm, nw, :gen, i, "qmin", cnd)),
        upper_bound = max(0, ref(pm, nw, :gen, i, "qmax", cnd)),
        start = comp_start_value(ref(pm, nw, :gen, i), "qg_start", cnd)
    )
end



""
function variable_branch_flow(pm::GenericPowerModel; kwargs...)
    variable_active_branch_flow(pm; kwargs...)
    variable_reactive_branch_flow(pm; kwargs...)
end


"variable: `p[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_active_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = ref_calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)

        p = var(pm, nw, cnd)[:p] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_p",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = comp_start_value(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    else
        p = var(pm, nw, cnd)[:p] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_p",
            start = comp_start_value(ref(pm, nw, :branch, l), "p_start", cnd)
        )
    end

    for (l,branch) in ref(pm, nw, :branch)
        if haskey(branch, "pf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(p[f_idx], branch["pf_start"])
        end
        if haskey(branch, "pt_start")
            t_idx = (l, branch["t_bus"], branch["f_bus"])
            JuMP.set_start_value(p[t_idx], branch["pt_start"])
        end
    end
end

"variable: `q[l,i,j]` for `(l,i,j)` in `arcs`"
function variable_reactive_branch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = ref_calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus), cnd)

        q = var(pm, nw, cnd)[:q] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_q",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = comp_start_value(ref(pm, nw, :branch, l), "q_start", cnd)
        )
    else
        q = var(pm, nw, cnd)[:q] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_q",
            start = comp_start_value(ref(pm, nw, :branch, l), "q_start", cnd)
        )
    end

    for (l,branch) in ref(pm, nw, :branch)
        if haskey(branch, "qf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(q[f_idx], branch["qf_start"])
        end
        if haskey(branch, "qt_start")
            t_idx = (l, branch["t_bus"], branch["f_bus"])
            JuMP.set_start_value(q[t_idx], branch["qt_start"])
        end
    end
end

function variable_dcline_flow(pm::GenericPowerModel; kwargs...)
    variable_active_dcline_flow(pm; kwargs...)
    variable_reactive_dcline_flow(pm; kwargs...)
end

"variable: `p_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_active_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    p_dc = var(pm, nw, cnd)[:p_dc] = JuMP.@variable(pm.model,
        [arc in ref(pm, nw, :arcs_dc)], base_name="$(nw)_$(cnd)_p_dc",
    )

    if bounded
        for (l,dcline) in ref(pm, nw, :dcline)
            f_idx = (l, dcline["f_bus"], dcline["t_bus"])
            t_idx = (l, dcline["t_bus"], dcline["f_bus"])

            JuMP.set_lower_bound(p_dc[f_idx], dcline["pminf"][cnd])
            JuMP.set_upper_bound(p_dc[f_idx], dcline["pmaxf"][cnd])

            JuMP.set_lower_bound(p_dc[t_idx], dcline["pmint"][cnd])
            JuMP.set_upper_bound(p_dc[t_idx], dcline["pmaxt"][cnd])
        end
    end

    for (l,dcline) in ref(pm, nw, :dcline)
        if haskey(dcline, "pf")
            f_idx = (l, dcline["f_bus"], dcline["t_bus"])
            JuMP.set_start_value(p_dc[f_idx], dcline["pf"][cnd])
        end

        if haskey(dcline, "pt")
            t_idx = (l, dcline["t_bus"], dcline["f_bus"])
            JuMP.set_start_value(p_dc[t_idx], dcline["pt"][cnd])
        end
    end
end

"variable: `q_dc[l,i,j]` for `(l,i,j)` in `arcs_dc`"
function variable_reactive_dcline_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    q_dc = var(pm, nw, cnd)[:q_dc] = JuMP.@variable(pm.model,
        [arc in ref(pm, nw, :arcs_dc)], base_name="$(nw)_$(cnd)_q_dc",
    )

    if bounded
        for (l,dcline) in ref(pm, nw, :dcline)
            f_idx = (l, dcline["f_bus"], dcline["t_bus"])
            t_idx = (l, dcline["t_bus"], dcline["f_bus"])

            JuMP.set_lower_bound(q_dc[f_idx], dcline["qminf"][cnd])
            JuMP.set_upper_bound(q_dc[f_idx], dcline["qmaxf"][cnd])

            JuMP.set_lower_bound(q_dc[t_idx], dcline["qmint"][cnd])
            JuMP.set_upper_bound(q_dc[t_idx], dcline["qmaxt"][cnd])
        end
    end

    for (l,dcline) in ref(pm, nw, :dcline)
        if haskey(dcline, "qf")
            f_idx = (l, dcline["f_bus"], dcline["t_bus"])
            JuMP.set_start_value(q_dc[f_idx], dcline["qf"][cnd])
        end

        if haskey(dcline, "qt")
            t_idx = (l, dcline["t_bus"], dcline["f_bus"])
            JuMP.set_start_value(q_dc[t_idx], dcline["qt"][cnd])
        end
    end
end



function variable_switch_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, relax=false)
    if !relax
        var(pm, nw)[:z_switch] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :switch)], base_name="$(nw)_z_switch",
            binary = true,
            start = comp_start_value(ref(pm, nw, :switch, i), "z_switch_start", 1, 1.0)
        )
    else
        var(pm, nw)[:z_switch] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :switch)], base_name="$(nw)_z_switch",
            lower_bound = 0,
            upper_bound = 1,
            start = comp_start_value(ref(pm, nw, :switch, i), "z_switch_start", 1, 1.0)
        )
    end
end


""
function variable_switch_flow(pm::GenericPowerModel; kwargs...)
    variable_active_switch_flow(pm; kwargs...)
    variable_reactive_switch_flow(pm; kwargs...)
end


"variable: `pws[l,i,j]` for `(l,i,j)` in `arcs_sw`"
function variable_active_switch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = ref_calc_switch_flow_bounds(ref(pm, nw, :switch), ref(pm, nw, :bus), cnd)

        psw = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from_sw)], base_name="$(nw)_$(cnd)_psw",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = comp_start_value(ref(pm, nw, :switch, l), "psw_start", cnd)
        )
    else
        psw = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from_sw)], base_name="$(nw)_$(cnd)_psw",
            start = comp_start_value(ref(pm, nw, :switch, l), "psw_start", cnd)
        )
    end

    # this explicit type erasure is necessary
    psw_expr = Dict{Any,Any}( (l,i,j) => psw[(l,i,j)] for (l,i,j) in ref(pm, nw, :arcs_from_sw) )
    psw_expr = merge(psw_expr, Dict( (l,j,i) => -1.0*psw[(l,i,j)] for (l,i,j) in ref(pm, nw, :arcs_from_sw)))
    var(pm, nw, cnd)[:psw] = psw_expr
end


"variable: `pws[l,i,j]` for `(l,i,j)` in `arcs_sw`"
function variable_reactive_switch_flow(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    if bounded
        flow_lb, flow_ub = ref_calc_switch_flow_bounds(ref(pm, nw, :switch), ref(pm, nw, :bus), cnd)

        qsw = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from_sw)], base_name="$(nw)_$(cnd)_qsw",
            lower_bound = flow_lb[l],
            upper_bound = flow_ub[l],
            start = comp_start_value(ref(pm, nw, :switch, l), "qsw_start", cnd)
        )
    else
        qsw = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from_sw)], base_name="$(nw)_$(cnd)_qsw",
            start = comp_start_value(ref(pm, nw, :switch, l), "qsw_start", cnd)
        )
    end

    # this explicit type erasure is necessary
    qsw_expr = Dict{Any,Any}( (l,i,j) => qsw[(l,i,j)] for (l,i,j) in ref(pm, nw, :arcs_from_sw) )
    qsw_expr = merge(qsw_expr, Dict( (l,j,i) => -1.0*qsw[(l,i,j)] for (l,i,j) in ref(pm, nw, :arcs_from_sw)))
    var(pm, nw, cnd)[:qsw] = qsw_expr
end



"variables for modeling storage units, includes grid injection and internal variables"
function variable_storage(pm::GenericPowerModel; kwargs...)
    variable_active_storage(pm; kwargs...)
    variable_reactive_storage(pm; kwargs...)
    variable_storage_energy(pm; kwargs...)
    variable_storage_charge(pm; kwargs...)
    variable_storage_discharge(pm; kwargs...)
end

""
function variable_active_storage(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    inj_lb, inj_ub = ref_calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), cnd)

    var(pm, nw, cnd)[:ps] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_$(cnd)_ps",
        lower_bound = inj_lb[i],
        upper_bound = inj_ub[i],
        start = comp_start_value(ref(pm, nw, :storage, i), "ps_start", cnd)
    )
end

""
function variable_reactive_storage(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    inj_lb, inj_ub = ref_calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), cnd)

    var(pm, nw, cnd)[:qs] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_$(cnd)_qs",
        lower_bound = max(inj_lb[i], ref(pm, nw, :storage, i, "qmin", cnd)),
        upper_bound = min(inj_ub[i], ref(pm, nw, :storage, i, "qmax", cnd)),
        start = comp_start_value(ref(pm, nw, :storage, i), "qs_start", cnd)
    )
end

""
function variable_storage_energy(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:se] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_se",
        lower_bound = 0,
        upper_bound = ref(pm, nw, :storage, i, "energy_rating"),
        start = comp_start_value(ref(pm, nw, :storage, i), "se_start", 1)
    )
end

""
function variable_storage_charge(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:sc] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_sc",
        lower_bound = 0,
        upper_bound = ref(pm, nw, :storage, i, "charge_rating"),
        start = comp_start_value(ref(pm, nw, :storage, i), "sc_start", 1)
    )
end

""
function variable_storage_discharge(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:sd] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_sd",
        lower_bound = 0,
        upper_bound = ref(pm, nw, :storage, i, "discharge_rating"),
        start = comp_start_value(ref(pm, nw, :storage, i), "sd_start", 1)
    )
end

"variables for modeling storage units, includes grid injection and internal variables, with mixed int variables for charge/discharge"
function variable_storage_mi(pm::GenericPowerModel; kwargs...)
    variable_active_storage(pm; kwargs...)
    variable_reactive_storage(pm; kwargs...)
    variable_storage_energy(pm; kwargs...)
    variable_storage_charge(pm; kwargs...)
    variable_storage_discharge(pm; kwargs...)
    variable_storage_complementary_indicator(pm; kwargs...)
end

""
function variable_storage_complementary_indicator(pm::GenericPowerModel; nw::Int=pm.cnw)
    var(pm, nw)[:sc_on] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_sc", Bin,
        start = comp_start_value(ref(pm, nw, :storage, i), "sc_on_start", 0)
    )
    var(pm, nw)[:sd_on] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_sd", Bin,
        start = comp_start_value(ref(pm, nw, :storage, i), "sd_on_start", 0)
    )
end

function variable_storage_mi_on_off(pm::GenericPowerModel; kwargs...)
    variable_active_storage_on_off(pm; kwargs...)
    variable_reactive_storage_on_off(pm; kwargs...)
    variable_storage_energy(pm; kwargs...)
    variable_storage_charge(pm; kwargs...)
    variable_storage_discharge(pm; kwargs...)
    variable_storage_complementary_indicator(pm; kwargs...)
end

function variable_active_storage_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    inj_lb, inj_ub = ref_calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), cnd)

    var(pm, nw, cnd)[:ps] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_$(cnd)_ps",
        lower_bound = min(0, inj_lb[i]),
        upper_bound = max(0, inj_ub[i]),
        start = comp_start_value(ref(pm, nw, :storage, i), "ps_start", cnd)
    )
end

function variable_reactive_storage_on_off(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    inj_lb, inj_ub = ref_calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), cnd)

    var(pm, nw, cnd)[:qs] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :storage)], base_name="$(nw)_$(cnd)_qs",
        lower_bound = min(0, max(inj_lb[i], ref(pm, nw, :storage, i, "qmin", cnd))),
        upper_bound = max(0, min(inj_ub[i], ref(pm, nw, :storage, i, "qmax", cnd))),
        start = comp_start_value(ref(pm, nw, :storage, i), "qs_start", cnd)
    )
end

function variable_storage_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, relax=false)
    if !relax
        var(pm, nw)[:z_storage] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :storage)], base_name="$(nw)_z_storage",
            binary = true,
            start = comp_start_value(ref(pm, nw, :storage, i), "z_storage_start", 1, 1.0)
        )
    else
        var(pm, nw)[:z_storage] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :storage)], base_name="$(nw)_z_storage",
            lower_bound = 0,
            upper_bound = 1,
            start = comp_start_value(ref(pm, nw, :storage, i), "z_storage_start", 1, 1.0)
        )
    end
end


##################################################################
### Network Expantion Variables

"generates variables for both `active` and `reactive` `branch_flow_ne`"
function variable_branch_flow_ne(pm::GenericPowerModel; kwargs...)
    variable_active_branch_flow_ne(pm; kwargs...)
    variable_reactive_branch_flow_ne(pm; kwargs...)
end

"variable: `-ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_active_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:p_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs)], base_name="$(nw)_$(cnd)_p_ne",
        lower_bound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upper_bound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "p_start", cnd)
    )
end

"variable: `-ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"]` for `(l,i,j)` in `ne_arcs`"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:q_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs)], base_name="$(nw)_$(cnd)_q_ne",
        lower_bound = -ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        upper_bound =  ref(pm, nw, :ne_branch, l, "rate_a", cnd),
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "q_start", cnd)
    )
end

"variable: `0 <= branch_z[l] <= 1` for `l` in `branch`es"
function variable_branch_indicator(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:branch_z] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_branch_z",
        binary = true,
        start = comp_start_value(ref(pm, nw, :branch, l), "branch_z_start", cnd, 1.0)
    )
end

"variable: `0 <= branch_ne[l] <= 1` for `l` in `branch`es"
function variable_branch_ne(pm::GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    var(pm, nw, cnd)[:branch_ne] = JuMP.@variable(pm.model,
        [l in ids(pm, nw, :ne_branch)], base_name="$(nw)_$(cnd)_branch_ne",
        binary = true,
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "branch_tnep_start", cnd, 1.0)
    )
end
