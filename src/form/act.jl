### w-theta form of the non-convex AC equations

export 
    ACTPowerModel, StandardACTForm

""
@compat abstract type AbstractACTForm <: AbstractPowerFormulation end

""
@compat abstract type StandardACTForm <: AbstractACTForm end

""
const ACTPowerModel = GenericPowerModel{StandardACTForm}

"default AC constructor"
ACTPowerModel(data::Dict{String,Any}; kwargs...) = 
    GenericPowerModel(data, StandardACTForm; kwargs...)

"`t[ref_bus] == 0`"
function constraint_theta_ref{T <: AbstractACTForm}(pm::GenericPowerModel{T}, n::Int, i::Int)
    @constraint(pm.model, pm.var[:nw][n][:va][i] == 0)
end

""
function variable_voltage{T <: AbstractACTForm}(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...)
    variable_voltage_angle(pm, n; kwargs...)
    variable_voltage_magnitude_sqr(pm, n; kwargs...)
    variable_voltage_product(pm, n; kwargs...)
end

function constraint_voltage{T <: StandardACTForm}(pm::GenericPowerModel{T}, n::Int)
    t = pm.var[:nw][n][:va]
    w = pm.var[:nw][n][:w]
    wr = pm.var[:nw][n][:wr]
    wi = pm.var[:nw][n][:wi]

    for (i,j) in keys(pm.ref[:nw][n][:buspairs])
        @constraint(pm.model, wr[(i,j)]^2 + wi[(i,j)]^2 == w[i]*w[j])
        @NLconstraint(pm.model, wi[(i,j)] == tan(t[i] - t[j])*wr[(i,j)])
    end
end


"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_voltage_angle_difference{T <: StandardACTForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, angmin, angmax)
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]

    @constraint(pm.model, va_fr - va_to <= angmax)
    @constraint(pm.model, va_fr - va_to >= angmin)
end


""
function add_bus_voltage_setpoint{T <: AbstractACTForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "vm", :w; scale = (x,item) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "va", :va)
end
