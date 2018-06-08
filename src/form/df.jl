# this file contains (balanced) convexified DistFlow formulation, in W space
export
    SOCDFPowerModel, SOCDFForm
""
abstract type AbstractDFForm <: AbstractPowerFormulation end

""
abstract type SOCDFForm <: AbstractDFForm end

""
const SOCDFPowerModel = GenericPowerModel{SOCDFForm}

"default SOC constructor"
SOCDFPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SOCDFForm; kwargs...)


""
function variable_branch_flow(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDFForm
    variable_active_branch_flow(pm; kwargs...)
    variable_reactive_branch_flow(pm; kwargs...)
    variable_active_branch_series_flow(pm; kwargs...)
    variable_reactive_branch_series_flow(pm; kwargs...)

end


function variable_active_branch_series_flow(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        branches = ref(pm, nw, :branch)
        buses = ref(pm, nw, :bus)
        pmax = calc_series_active_power_bound(branches, buses, ph)
        var(pm, nw, ph)[:p_s] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], basename="$(nw)_$(ph)_p_s",
            lowerbound = -pmax[l],
            upperbound =  pmax[l],
            start = getval(ref(pm, nw, :branch, l), "p_start", ph)
        )
    else
        var(pm, nw, ph)[:p_s] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], basename="$(nw)_$(ph)_p_s",
            start = getval(ref(pm, nw, :branch, l), "p_start", ph)
        )
    end
end


function variable_reactive_branch_series_flow(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    if bounded
        branches = ref(pm, nw, :branch)
        buses = ref(pm, nw, :bus)
        qmax = calc_series_reactive_power_bound(branches, buses, ph)
        var(pm, nw, ph)[:q_s] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], basename="$(nw)_$(ph)_q_s",
            lowerbound = -qmax[l],
            upperbound =  qmax[l],
            start = getval(ref(pm, nw, :branch, l), "q_start", ph)
        )
    else
        var(pm, nw, ph)[:q_s] = @variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], basename="$(nw)_$(ph)_q_s",
            start = getval(ref(pm, nw, :branch, l), "q_start", ph)
        )
    end
end


""
function variable_branch_current(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDFForm
    variable_branch_series_current_magnitude_sqr(pm; kwargs...)
end

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractDFForm
    variable_voltage_magnitude_sqr(pm; kwargs...)
end

"""
Defines branch flow model power flow equations
"""
function constraint_flow_losses(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm) where T <: AbstractDFForm
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    p_to = var(pm, n, h, :p, t_idx)
    q_to = var(pm, n, h, :q, t_idx)
    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)
    ccm =  var(pm, n, h, :ccm, i)

    @constraint(pm.model, p_fr + p_to ==  g_sh_fr*(w_fr/tm^2) + r*ccm +  g_sh_to*w_to)
    @constraint(pm.model, q_fr + q_to == -b_sh_fr*(w_fr/tm^2) + x*ccm + -b_sh_to*w_to)
end


"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_voltage_magnitude_difference(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm) where T <: AbstractDFForm
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)
    ccm =  var(pm, n, h, :ccm, i)

    #define series flow expressions to simplify Ohm's law
    p_s_fr = p_fr - g_sh_fr*(w_fr/tm^2)
    q_s_fr = q_fr + b_sh_fr*(w_fr/tm^2)

    #KVL over the line:
    @constraint(pm.model, w_to == (w_fr/tm^2) - 2*(r*p_s_fr + x*q_s_fr) + (r^2 + x^2)*ccm)

end

"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_branch_current(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm) where T <: AbstractDFForm
    p_fr   = var(pm, n, h, :p, f_idx)
    q_fr   = var(pm, n, h, :q, f_idx)
    p_s_fr = var(pm, n, h, :p_s, f_idx)
    q_s_fr = var(pm, n, h, :q_s, f_idx)
    w_fr   = var(pm, n, h, :w, f_bus)
    ccm    = var(pm, n, h, :ccm, i)

    @constraint(pm.model, p_s_fr == p_fr - g_sh_fr*(w_fr/tm^2))
    @constraint(pm.model, q_s_fr == q_fr + b_sh_fr*(w_fr/tm^2))
    @constraint(pm.model, p_s_fr^2 + q_s_fr^2 <= (w_fr/tm^2)*ccm)

    # define series flow expressions to simplify constraint
    #p_fr_s = p_fr - g_sh_fr*(w_fr/tm^2)
    #q_fr_s = q_fr + b_sh_fr*(w_fr/tm^2)

    # convex constraint linking p, q, w and ccm
    #@constraint(pm.model, p_fr_s^2 + q_fr_s^2 <= (w_fr/tm^2)*ccm)
end


function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, angmin, angmax) where T <: AbstractDFForm
    i, f_bus, t_bus = f_idx
    t_idx = (i, t_bus, f_bus)

    branch = ref(pm, n, :branch, i)
    tm = getmpv(branch["tap"], h)
    g, b = calc_branch_y(branch)
    g, b = getmpv(g, h, h), getmpv(b, h, h)
    g_sh_fr = getmpv(branch["g_fr"], h)
    g_sh_to = getmpv(branch["g_to"], h)
    b_sh_fr = getmpv(branch["b_fr"], h)
    b_sh_to = getmpv(branch["b_to"], h)

    tr, ti = calc_branch_t(branch)
    tr, ti = getmpv(tr, h), getmpv(ti, h)

    # convert series admittance to impedance
    z_s = 1/(g + im*b)
    r_s = real(z_s)
    x_s = imag(z_s)

    # getting the variables
    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)

    p_fr = var(pm, n, h, :p, f_idx)
    p_to = var(pm, n, h, :p, t_idx)

    q_fr = var(pm, n, h, :q, f_idx)
    q_to = var(pm, n, h, :q, t_idx)

    tzr = r_s*tr - x_s*ti
    tzi = r_s*ti + x_s*tr

    @constraint(pm.model,
        tan(angmin)*(( tr + tzr*g_sh_fr - tzi*b_sh_fr)*(w_fr/tm^2) - tzr*p_fr - tzi*q_fr)
                 <= ((-ti - tzi*g_sh_fr - tzr*b_sh_fr)*(w_fr/tm^2) - tzr*q_fr + tzi*p_fr)
        )
    @constraint(pm.model,
        tan(angmax)*(( tr + tzr*g_sh_fr - tzi*b_sh_fr)*(w_fr/tm^2) - tzr*p_fr - tzi*q_fr)
                 >= ((-ti - tzi*g_sh_fr - tzr*b_sh_fr)*(w_fr/tm^2) - tzr*q_fr + tzi*p_fr)
        )
end


"variable: `0 <= i[l] <= (Imax)^2` for `l` in `branch`es"
function variable_branch_series_current_magnitude_sqr(pm::GenericPowerModel; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true)
    branches = ref(pm, nw, :branch)
    buses = ref(pm, nw, :bus)
    cmax = calc_series_current_magnitude_bound(branches, buses, ph)

    if bounded
        var(pm, nw, ph)[:ccm] = @variable(pm.model,
            [l in ids(pm, nw, :branch)], basename="$(nw)_$(ph)_ccm",
            lowerbound = 0,
            upperbound = (cmax[l])^2,
            start = getval(ref(pm, nw, :branch, l), "i_start", ph)
        )
    else
        var(pm, nw, ph)[:ccm] = @variable(pm.model,
            [l in ids(pm, nw, :branch)], basename="$(nw)_$(ph)_ccm",
            lowerbound = 0,
            start = getval(ref(pm, nw, :branch, l), "i_start", ph)
        )
    end
end
