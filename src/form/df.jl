# contains (balanced) DistFlow formulation
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
function variable_current(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDFForm
    variable_series_current_magnitude_sqr(pm, n; kwargs...)
end

""
function variable_branch_flow(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDFForm
    variable_active_branch_flow(pm, n; kwargs...)
    variable_reactive_branch_flow(pm, n; kwargs...)
    variable_current(pm, n; kwargs...)
end

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractDFForm
    variable_voltage_magnitude_sqr(pm, n; kwargs...)
end

"do nothing, this model does not have complex voltage constraints"
function constraint_voltage(pm::GenericPowerModel{T}, n::Int) where T <: AbstractDFForm
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm) where T <: AbstractDFForm
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    q_to = pm.var[:nw][n][:q][t_idx]
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]
    l = f_idx[1]
    cm =    pm.var[:nw][n][:cm][l]

    # convert series admittance to impedance
    z_s = 1/(g + im*b)
    r_s = real(z_s)
    x_s = imag(z_s)

    # to support asymmetric shunts + conductance
    g_sh_fr = 0
    g_sh_to = 0
    b_sh_fr = c/2
    b_sh_to = c/2

    @constraint(pm.model, p_fr + p_to ==  g_sh_fr*(w_fr/tm^2) + r_s*cm +  g_sh_to*w_to)
    @constraint(pm.model, q_fr + q_to == -b_sh_fr*(w_fr/tm^2) + x_s*cm + -b_sh_to*w_to)

    #define series flow expressions to simplify KVL equation
    p_fr_s = p_fr - g_sh_fr*(w_fr/tm^2)
    p_to_s = p_to - g_sh_to*w_to
    q_fr_s = q_fr + b_sh_fr*(w_fr/tm^2)
    q_to_s = q_to + g_sh_to*w_to

    #KVL over the line:
    @constraint(pm.model, w_to == (w_fr/tm^2) - 2(r_s*p_fr_s + x_s*q_fr_s) + (r_s^2 + x_s^2)*cm)

    #convex constraint linking P, Q, W and I
    @constraint(pm.model, p_fr_s^2 +q_fr_s^2 <= (w_fr/tm^2)*cm)
end


"""
Do nothing, as there is no second ohm's constraint in a branch flow model
"""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm) where T <: AbstractDFForm
end


function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, i, f_bus, t_bus, angmin, angmax) where T <: AbstractDFForm
    # how to evolve the constraint template? - new method definition only for this formulation?
    branch = ref(pm, n, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    c = branch["br_b"]
    tm = branch["tap"]

    f_idx = (i, f_bus, t_bus)
    t_idx = (i, f_bus, t_bus)

    # convert series admittance to impedance
    z_s = 1/(g + im*b)
    r_s = real(z_s)
    x_s = imag(z_s)

    # to support asymmetric shunts + conductance
    g_sh_fr = 0
    g_sh_to = 0
    b_sh_fr = c/2
    b_sh_to = c/2

    # getting the variables
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    p_to = pm.var[:nw][n][:p][t_idx]
    q_to = pm.var[:nw][n][:q][t_idx]

    #todo: adapt for asymmetric shunts + shunt conductance
    tzr = r_s*tr - x_s*ti
    tzi = r_s*ti + x_s*tr
    a1 = ( tr - tzr*b_sh_fr)*(w_fr/tm^2) - tzr*p_fr - tzi*q_fr
    a2 = (-ti - tzr*b_sh_fr)*(w_fr/tm^2) - tzr*q_fr + tzi*p_fr
    a3 = ( tr - tzi*b_sh_fr)*(w_fr/tm^2) - tzr*p_fr - tzi*q_fr
    a4 = (-ti - tzr*b_sh_fr)*(w_fr/tm^2) - tzr*q_fr + tzi*p_fr

    # tr = 1
    # ti = 0
    # tm = 1
    # tzr = r_s*tr - x_s*ti
    # tzi = r_s*ti + x_s*tr
    # a5 = ( tr - tzr*b_sh_to)*(w_to/tm^2) - tzr*p_to - tzi*q_to
    # a6 = (-ti - tzr*b_sh_to)*(w_to/tm^2) - tzr*q_to + tzi*p_to
    # a7 = ( tr - tzi*b_sh_to)*(w_to/tm^2) - tzr*p_to - tzi*q_to
    # a8 = (-ti - tzr*b_sh_to)*(w_to/tm^2) - tzr*q_to + tzi*p_to

    @constraint(pm.model, tan(angmin)*a1 <= a2)
    @constraint(pm.model, tan(angmax)*a3 >= a4)
    #@constraint(pm.model, tan(angmin)*a5 <= a6)
    #@constraint(pm.model, tan(angmax)*a7 >= a8)
end


"variable: `0 <= i[l] <= (Imax)^2` for `l` in `branch`es"
function variable_series_current_magnitude_sqr(pm::GenericPowerModel, n::Int=pm.cnw; bounded = true)
    v_pu = 1  #assuming 1 pu voltage to derive current value from apparent power
    # should data model be expanded?
    bigM = 2  #w.r.t total current, which is supposed to be bound in magnitude by Imax, shunt currents add or substract
    # therefore, big M needed for series current magnitude
    # constraint limiting *total* current magnitude needs to be defined separately
    # TODO derive exact bound
    if bounded
        pm.var[:nw][n][:cm] = @variable(pm.model,
            [l in keys(pm.ref[:nw][n][:branch])], basename="$(n)_cm",
            lowerbound = 0,
            upperbound = (pm.ref[:nw][n][:branch][l]["rate_a"]*bigM/v_pu)^2,
            start = getstart(pm.ref[:nw][n][:branch], l, "i_start")
        )
    else
        pm.var[:nw][n][:i] = @variable(pm.model,
            [l in keys(pm.ref[:nw][n][:branch])], basename="$(n)_cm",  #assuming 1 pu voltage
            start = getstart(pm.ref[:nw][n][:branch], l, "i_start")
        )
    end
end
