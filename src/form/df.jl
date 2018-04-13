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
function variable_branch_flow(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDFForm
    variable_active_branch_flow(pm, n; kwargs...)
    variable_reactive_branch_flow(pm, n; kwargs...)
    variable_active_branch_series_flow(pm, n; kwargs...)
    variable_reactive_branch_series_flow(pm, n; kwargs...)

end


function variable_active_branch_series_flow(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:p_s] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs_from]], basename="$(n)_p_s",
            lowerbound = -pm.ref[:nw][n][:branch][l]["rate_a"],
            upperbound =  pm.ref[:nw][n][:branch][l]["rate_a"],
            start = getstart(pm.ref[:nw][n][:branch], l, "p_start")
        )
    else
        pm.var[:nw][n][:p_s] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs_from]], basename="$(n)_p_s",
            start = getstart(pm.ref[:nw][n][:branch], l, "p_start")
        )
    end
end


function variable_reactive_branch_series_flow(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    if bounded
        pm.var[:nw][n][:q_s] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs_from]], basename="$(n)_q_s",
            lowerbound = -pm.ref[:nw][n][:branch][l]["rate_a"],
            upperbound =  pm.ref[:nw][n][:branch][l]["rate_a"],
            start = getstart(pm.ref[:nw][n][:branch], l, "q_start")
        )
    else
        pm.var[:nw][n][:q_s] = @variable(pm.model,
            [(l,i,j) in pm.ref[:nw][n][:arcs_from]], basename="$(n)_q_s",
            start = getstart(pm.ref[:nw][n][:branch], l, "q_start")
        )
    end
end


""
function variable_branch_current(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDFForm
    variable_branch_series_current_magnitude_sqr(pm, n; kwargs...)
end

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDFForm
    variable_voltage_magnitude_sqr(pm, n; kwargs...)
end

"""
Defines branch flow model power flow equations
"""
function constraint_flow_losses(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm) where T <: AbstractDFForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    q_to = pm.var[:nw][n][:q][t_idx]
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]
    ccm =  pm.var[:nw][n][:ccm][i]

    @constraint(pm.model, p_fr + p_to ==  g_sh_fr*(w_fr/tm^2) + r*ccm +  g_sh_to*w_to)
    @constraint(pm.model, q_fr + q_to == -b_sh_fr*(w_fr/tm^2) + x*ccm + -b_sh_to*w_to)
end


"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_voltage_magnitude_difference(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm) where T <: AbstractDFForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]
    ccm =  pm.var[:nw][n][:ccm][i]

    #define series flow expressions to simplify Ohm's law
    p_fr_s = p_fr - g_sh_fr*(w_fr/tm^2)
    q_fr_s = q_fr + b_sh_fr*(w_fr/tm^2)

    #KVL over the line:
    @constraint(pm.model, w_to == (w_fr/tm^2) - 2*(r*p_fr_s + x*q_fr_s) + (r^2 + x^2)*ccm)

end

"""
Defines relationship between branch (series) power flow, branch (series) current and node voltage magnitude
"""
function constraint_branch_current(pm::GenericPowerModel{T}, n::Int, i, f_bus, f_idx, g_sh_fr, b_sh_fr, tm) where T <: AbstractDFForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    p_s_fr = pm.var[:nw][n][:p_s][f_idx]
    q_s_fr = pm.var[:nw][n][:q_s][f_idx]
    w_fr = pm.var[:nw][n][:w][f_bus]
    ccm  = pm.var[:nw][n][:ccm][i]

    @constraint(pm.model, p_s_fr == p_fr - g_sh_fr*(w_fr/tm^2))
    @constraint(pm.model, q_s_fr == q_fr + b_sh_fr*(w_fr/tm^2))
    @constraint(pm.model, p_s_fr^2 + q_s_fr^2 <= (w_fr/tm^2)*ccm)

    # define series flow expressions to simplify constraint
    #p_fr_s = p_fr - g_sh_fr*(w_fr/tm^2)
    #q_fr_s = q_fr + b_sh_fr*(w_fr/tm^2)

    # convex constraint linking p, q, w and ccm
    #@constraint(pm.model, p_fr_s^2 + q_fr_s^2 <= (w_fr/tm^2)*ccm)
end


function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, arc_from, f_bus, t_bus, angmin, angmax) where T <: AbstractDFForm
    i = arc_from[1]
    f_idx = arc_from
    t_idx = (i, t_bus, f_bus)

    branch = ref(pm, n, :branch, i)
    tm = branch["tap"]
    g, b = calc_branch_y(branch)
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    tr, ti = calc_branch_t(branch)

    # convert series admittance to impedance
    z_s = 1/(g + im*b)
    r_s = real(z_s)
    x_s = imag(z_s)

    # getting the variables
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]

    p_fr = pm.var[:nw][n][:p][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]

    q_fr = pm.var[:nw][n][:q][f_idx]
    q_to = pm.var[:nw][n][:q][t_idx]

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
function variable_branch_series_current_magnitude_sqr(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    branches = pm.ref[:nw][n][:branch]
    buses = pm.ref[:nw][n][:bus]
    cmax = calc_series_current_magnitude_bound(branches, buses)
    if bounded
        pm.var[:nw][n][:ccm] = @variable(pm.model,
            [l in keys(pm.ref[:nw][n][:branch])], basename="$(n)_ccm",
            lowerbound = 0,
            upperbound = (cmax[l])^2,
            start = getstart(pm.ref[:nw][n][:branch], l, "i_start")
        )
    else
        pm.var[:nw][n][:ccm] = @variable(pm.model,
            [l in keys(pm.ref[:nw][n][:branch])], basename="$(n)_ccm",
            lowerbound = 0,
            start = getstart(pm.ref[:nw][n][:branch], l, "i_start")
        )
    end
end
