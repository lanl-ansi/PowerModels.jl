# this file contains (balanced) convexified DistFlow formulation, in W space
export
    SOCBFPowerModel, SOCBFForm
""
abstract type AbstractBFForm <: AbstractPowerFormulation end

""
abstract type SOCBFForm <: AbstractBFForm end

""
const SOCBFPowerModel = GenericPowerModel{SOCBFForm}

"default SOC constructor"
SOCBFPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SOCBFForm; kwargs...)



""
function variable_current_magnitude_sqr(pm::GenericPowerModel{T}; nw::Int=pm.cnw, ph::Int=pm.cph, bounded = true) where T <: AbstractBFForm
    branch = ref(pm, nw, :branch)
    bus = ref(pm, nw, :bus)
    ub = Dict()
    for (i, b) in branch
        ub[i] = ((b["rate_a"][ph]*b["tap"][ph])/(bus[b["f_bus"]]["vmin"][ph]))^2
    end

    if bounded
        var(pm, nw, ph)[:cm] = @variable(pm.model,
            [i in ids(pm, nw, :branch)], basename="$(nw)_$(ph)_cm",
            lowerbound = 0,
            upperbound = ub[i],
            start = getval(branch[i], "cm_start", ph)
        )
    else
        var(pm, nw, ph)[:cm] = @variable(pm.model,
            [i in ids(pm, nw, :branch)], basename="$(nw)_$(ph)_cm",
            lowerbound = 0,
            start = getval(branch[i], "cm_start", ph)
        )
    end
end

""
function variable_branch_current(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractBFForm
    variable_current_magnitude_sqr(pm; kwargs...)
end

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractBFForm
    variable_voltage_magnitude_sqr(pm; kwargs...)
end

"""
Defines branch flow model power flow equations
"""
function constraint_flow_losses(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm) where T <: AbstractBFForm
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    p_to = var(pm, n, h, :p, t_idx)
    q_to = var(pm, n, h, :q, t_idx)
    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)
    cm =  var(pm, n, h, :cm, i)

    ym_sh_sqr = g_sh_fr^2 + b_sh_fr^2

    @constraint(pm.model, p_fr + p_to == r*(cm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)) + g_sh_fr*(w_fr/tm^2) + g_sh_to*w_to)
    @constraint(pm.model, q_fr + q_to == x*(cm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)) - b_sh_fr*(w_fr/tm^2) - b_sh_to*w_to)
end


"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_voltage_magnitude_difference(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm) where T <: AbstractBFForm
    p_fr = var(pm, n, h, :p, f_idx)
    q_fr = var(pm, n, h, :q, f_idx)
    w_fr = var(pm, n, h, :w, f_bus)
    w_to = var(pm, n, h, :w, t_bus)
    cm =  var(pm, n, h, :cm, i)

    ym_sh_sqr = g_sh_fr^2 + b_sh_fr^2

    @constraint(pm.model, (1+2*(r*g_sh_fr - x*b_sh_fr))*(w_fr/tm^2) - w_to ==  2*(r*p_fr + x*q_fr) - (r^2 + x^2)*(cm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)))
end

"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_branch_current(pm::GenericPowerModel{T}, n::Int, h::Int, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm) where T <: AbstractBFForm
    p_fr   = var(pm, n, h, :p, f_idx)
    q_fr   = var(pm, n, h, :q, f_idx)
    w_fr   = var(pm, n, h, :w, f_bus)
    cm = var(pm, n, h, :cm, i)

    # convex constraint linking p, q, w and ccm
    @constraint(pm.model, p_fr^2 + q_fr^2 <= (w_fr/tm^2)*cm)
end


function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, angmin, angmax) where T <: AbstractBFForm
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

