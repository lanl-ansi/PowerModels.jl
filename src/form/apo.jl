### generic features that apply to all active-power-only (apo) approximations


"apo models ignore reactive power flows"
function variable_reactive_generation(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractActivePowerFormulation
end

"apo models ignore reactive power flows"
function variable_reactive_storage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractActivePowerFormulation
end

"apo models ignore reactive power flows"
function variable_reactive_branch_flow(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractActivePowerFormulation
end

"apo models ignore reactive power flows"
function variable_reactive_branch_flow_ne(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractActivePowerFormulation
end

"apo models ignore reactive power flows"
function variable_reactive_dcline_flow(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractActivePowerFormulation
end

"do nothing, apo models do not have reactive variables"
function constraint_reactive_gen_setpoint(pm::GenericPowerModel{T}, n::Int, c::Int, i, qg) where T <: AbstractActivePowerFormulation
end


"on/off constraint for generators"
function constraint_generation_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int, pmin, pmax, qmin, qmax) where T <: AbstractActivePowerFormulation
    pg = var(pm, n, c, :pg, i)
    z = var(pm, n, :z_gen, i)

    @constraint(pm.model, pg <= pmax*z)
    @constraint(pm.model, pg >= pmin*z)
end


"`-rate_a <= p[f_idx] <= rate_a`"
function constraint_thermal_limit_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, rate_a) where T <: AbstractActivePowerFormulation
    p_fr = con(pm, n, c, :sm_fr)[f_idx[1]] = var(pm, n, c, :p, f_idx)
    getlowerbound(p_fr) < -rate_a && setlowerbound(p_fr, -rate_a)
    getupperbound(p_fr) >  rate_a && setupperbound(p_fr,  rate_a)
end

""
function constraint_thermal_limit_to(pm::GenericPowerModel{T}, n::Int, c::Int, t_idx, rate_a) where T <: AbstractActivePowerFormulation
    p_to = con(pm, n, c, :sm_to)[t_idx[1]] = var(pm, n, c, :p, t_idx)
    getlowerbound(p_to) < -rate_a && setlowerbound(p_to, -rate_a)
    getupperbound(p_to) >  rate_a && setupperbound(p_to,  rate_a)
end

""
function constraint_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, c_rating_a) where T <: AbstractActivePowerFormulation
    p_fr = var(pm, n, c, :p, f_idx)

    getlowerbound(p_fr) < -c_rating_a && setlowerbound(p_fr, -c_rating_a)
    getupperbound(p_fr) >  c_rating_a && setupperbound(p_fr,  c_rating_a)
end


""
function constraint_thermal_limit_from_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_idx, rate_a) where T <: AbstractActivePowerFormulation
    p_fr = var(pm, n, c, :p, f_idx)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, p_fr <=  rate_a*z)
    @constraint(pm.model, p_fr >= -rate_a*z)
end

""
function constraint_thermal_limit_to_on_off(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: AbstractActivePowerFormulation
    p_to = var(pm, n, c, :p, t_idx)
    z = var(pm, n, c, :branch_z, i)

    @constraint(pm.model, p_to <=  rate_a*z)
    @constraint(pm.model, p_to >= -rate_a*z)
end

""
function constraint_thermal_limit_from_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, f_idx, rate_a) where T <: AbstractDCPForm
    p_fr = var(pm, n, c, :p_ne, f_idx)
    z = var(pm, n, c, :branch_ne, i)

    @constraint(pm.model, p_fr <=  rate_a*z)
    @constraint(pm.model, p_fr >= -rate_a*z)
end

""
function constraint_thermal_limit_to_ne(pm::GenericPowerModel{T}, n::Int, c::Int, i, t_idx, rate_a) where T <: AbstractDCPForm
    p_to = var(pm, n, c, :p_ne, t_idx)
    z = var(pm, n, c, :branch_ne, i)

    @constraint(pm.model, p_to <=  rate_a*z)
    @constraint(pm.model, p_to >= -rate_a*z)
end





""
function constraint_storage_thermal_limit(pm::GenericPowerModel{T}, n::Int, c::Int, i, rating) where T <: AbstractActivePowerFormulation
    ps = var(pm, n, c, :ps, i)

    getlowerbound(ps) < -rating && setlowerbound(ps, -rating)
    getupperbound(ps) >  rating && setupperbound(ps,  rating)
end

""
function constraint_storage_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus, rating) where T <: AbstractActivePowerFormulation
    ps = var(pm, n, c, :ps, i)

    getlowerbound(ps) < -rating && setlowerbound(ps, -rating)
    getupperbound(ps) >  rating && setupperbound(ps,  rating)
end

""
function constraint_storage_loss(pm::GenericPowerModel{T}, n::Int, i, bus, r, x, standby_loss) where T <: AbstractActivePowerFormulation
    ps = var(pm, n, pm.ccnd, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)
    @constraint(pm.model, ps + (sd - sc) == standby_loss + r*ps^2)
end




""
function add_generator_power_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractActivePowerFormulation
    add_setpoint(sol, pm, "gen", "pg", :pg)
    add_setpoint_fixed(sol, pm, "gen", "qg")
end

""
function add_storage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractActivePowerFormulation
    add_setpoint(sol, pm, "storage", "ps", :ps)
    add_setpoint_fixed(sol, pm, "storage", "qs")
    add_setpoint(sol, pm, "storage", "se", :se, conductorless=true)
end

