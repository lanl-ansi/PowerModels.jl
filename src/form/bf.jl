# this file contains (balanced) convexified DistFlow formulation, in W space

""
function variable_current_magnitude_sqr(pm::AbstractBFModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    branch = ref(pm, nw, :branch)
    bus = ref(pm, nw, :bus)
    ub = Dict()
    for (i, b) in branch
        ub[i] = ((b["rate_a"][cnd]*b["tap"][cnd])/(bus[b["f_bus"]]["vmin"][cnd]))^2
    end

    if bounded
        var(pm, nw, cnd)[:ccm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_ccm",
            lower_bound = 0,
            upper_bound = ub[i],
            start = comp_start_value(branch[i], "ccm_start", cnd)
        )
    else
        var(pm, nw, cnd)[:ccm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :branch)], base_name="$(nw)_$(cnd)_ccm",
            lower_bound = 0,
            start = comp_start_value(branch[i], "ccm_start", cnd)
        )
    end
end

""
function variable_branch_current(pm::AbstractBFModel; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

""
function variable_voltage(pm::AbstractBFModel; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
end

"""
Defines branch flow model power flow equations
"""
function constraint_flow_losses(pm::AbstractBFModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    ccm =  var(pm, n, c, :ccm, i)

    ym_sh_sqr = g_sh_fr^2 + b_sh_fr^2

    JuMP.@constraint(pm.model, p_fr + p_to == r*(ccm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)) + g_sh_fr*(w_fr/tm^2) + g_sh_to*w_to)
    JuMP.@constraint(pm.model, q_fr + q_to == x*(ccm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)) - b_sh_fr*(w_fr/tm^2) - b_sh_to*w_to)
end


"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_voltage_magnitude_difference(pm::AbstractBFModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    w_fr = var(pm, n, c, :w, f_bus)
    w_to = var(pm, n, c, :w, t_bus)
    ccm =  var(pm, n, c, :ccm, i)

    ym_sh_sqr = g_sh_fr^2 + b_sh_fr^2

    JuMP.@constraint(pm.model, (1+2*(r*g_sh_fr - x*b_sh_fr))*(w_fr/tm^2) - w_to ==  2*(r*p_fr + x*q_fr) - (r^2 + x^2)*(ccm + ym_sh_sqr*(w_fr/tm^2) - 2*(g_sh_fr*p_fr - b_sh_fr*q_fr)))
end


"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_model_current(pm::AbstractBFQPModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:p,:q,:w,:ccm], typeof(pm))

    p  = var(pm, n, c, :p)
    q  = var(pm, n, c, :q)
    w  = var(pm, n, c, :w)
    ccm = var(pm, n, c, :ccm)

    for (i,branch) in ref(pm, n, :branch)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_idx = (i, f_bus, t_bus)
        tm = branch["tap"][c]

        JuMP.@constraint(pm.model, p[f_idx]^2 + q[f_idx]^2 <= (w[f_bus]/tm^2)*ccm[i])
    end
end


"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_model_current(pm::AbstractBFConicModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:p,:q,:w,:ccm], typeof(pm))

    p  = var(pm, n, c, :p)
    q  = var(pm, n, c, :q)
    w  = var(pm, n, c, :w)
    ccm = var(pm, n, c, :ccm)

    for (i,branch) in ref(pm, n, :branch)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_idx = (i, f_bus, t_bus)
        tm = branch["tap"][c]

        JuMP.@constraint(pm.model, [w[f_bus]/tm^2, ccm[i]/2, p[f_idx], q[f_idx]] in JuMP.RotatedSecondOrderCone())
    end
end


function constraint_voltage_angle_difference(pm::AbstractBFModel, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx
    t_idx = (i, t_bus, f_bus)

    branch = ref(pm, n, :branch, i)
    tm = branch["tap"][c]
    g_fr = branch["g_fr"][c]
    g_to = branch["g_to"][c]
    b_fr = branch["b_fr"][c]
    b_to = branch["b_to"][c]

    tr, ti = calc_branch_t(branch)
    tr, ti = tr[c], ti[c]

    r = branch["br_r"][c,c]
    x = branch["br_x"][c,c]

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
