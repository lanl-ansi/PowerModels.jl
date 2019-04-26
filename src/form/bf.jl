# this file contains (balanced) convexified DistFlow formulation, in W space

""
function variable_current_magnitude_sqr(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: AbstractBFForm
    branch = ref(pm, nw, :branch)
    bus = ref(pm, nw, :bus)
    ub = Dict()
    for (i, b) in branch
        ub[i] = ((b["rate_a"][cnd]*b["tap"][cnd])/(bus[b["f_bus"]]["vmin"][cnd]))^2
    end

    if bounded
        var(pm, nw, cnd)[:cm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_cm",
            lowerbound = 0,
            upperbound = ub[i],
            start = getval(branch[i], "cm_start", cnd)
        )
    else
        var(pm, nw, cnd)[:cm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :branch)], basename="$(nw)_$(cnd)_cm",
            lowerbound = 0,
            start = getval(branch[i], "cm_start", cnd)
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
function constraint_flow_losses(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm) where T <: AbstractBFForm
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    cm =  var(pm, n, c, :cm, i)

    ym_sh_sqr = g_sh_fr^2 + b_sh_fr^2

    JuMP.@constraint(pm.model, p_fr + p_to == r*(cm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)) + g_sh_fr*(w_fr/tm^2) + g_sh_to*w_to)
    JuMP.@constraint(pm.model, q_fr + q_to == x*(cm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)) - b_sh_fr*(w_fr/tm^2) - b_sh_to*w_to)
end


"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_voltage_magnitude_difference(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm) where T <: AbstractBFForm
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    cm =  var(pm, n, c, :cm, i)

    ym_sh_sqr = g_sh_fr^2 + b_sh_fr^2

    JuMP.@constraint(pm.model, (1+2*(r*g_sh_fr - x*b_sh_fr))*(w_fr/tm^2) - w_to ==  2*(r*p_fr + x*q_fr) - (r^2 + x^2)*(cm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)))
end

"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_branch_current(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm) where T <: AbstractBFQPForm
    p_fr   = var(pm, n, c, :p, f_idx)
    q_fr   = var(pm, n, c, :q, f_idx)
    w_fr   = var(pm, n, c, :w, f_bus)
    cm = var(pm, n, c, :cm, i)

    # convex constraint linking p, q, w and ccm
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= (w_fr/tm^2)*cm)
end


"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_branch_current(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm) where T <: AbstractBFConicForm
    p_fr   = var(pm, n, c, :p, f_idx)
    q_fr   = var(pm, n, c, :q, f_idx)
    w_fr   = var(pm, n, c, :w, f_bus)
    cm = var(pm, n, c, :cm, i)

    # convex constraint linking p, q, w and ccm
    JuMP.@constraint(pm.model, JuMP.norm([2*p_fr; 2*q_fr; w_fr/tm^2 - cm]) <= w_fr/tm^2 + cm)
end


function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax) where T <: AbstractBFForm
    i, f_bus, t_bus = f_idx
    t_idx = (i, t_bus, f_bus)

    branch = ref(pm, n, :branch, i)
    tm = branch["tap"][c]
    g, b = calc_branch_y(branch)
    g, b = g[c,c], b[c,c]
    g_fr = branch["g_fr"][c]
    g_to = branch["g_to"][c]
    b_fr = branch["b_fr"][c]
    b_to = branch["b_to"][c]

    tr, ti = calc_branch_t(branch)
    tr, ti = tr[c], ti[c]

    # convert series admittance to impedance
    z = 1/(g + im*b)
    r = real(z)
    x = imag(z)

    # getting the variables
    w_fr = var(pm, n, c, :w, f_bus)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)

    tzr = r*tr + x*ti
    tzi = r*ti - x*tr

    JuMP.@constraint(pm.model,
        tan(angmin)*((tr + tzr*g_fr + tzi*b_fr)*(w_fr/tm^2) - tzr*p_fr + tzi*q_fr)
                 <= ((ti + tzi*g_fr - tzr*b_fr)*(w_fr/tm^2) - tzi*p_fr - tzr*q_fr)
        )
    JuMP.@constraint(pm.model,
        tan(angmax)*((tr + tzr*g_fr + tzi*b_fr)*(w_fr/tm^2) - tzr*p_fr + tzi*q_fr)
                 >= ((ti + tzi*g_fr - tzr*b_fr)*(w_fr/tm^2) - tzi*p_fr - tzr*q_fr)
        )
end
