### w-theta form of the non-convex AC equations

export
    ACTPowerModel, StandardACTForm

""
abstract type AbstractACTForm <: AbstractPowerFormulation end

""
abstract type StandardACTForm <: AbstractACTForm end

""
const ACTPowerModel = GenericPowerModel{StandardACTForm}

"default AC constructor"
ACTPowerModel(data::Dict{String,Any}; kwargs...) =
    GenericPowerModel(data, StandardACTForm; kwargs...)

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, i::Int) where T <: AbstractACTForm
    @constraint(pm.model, pm.var[:nw][n][:va][i] == 0)
end

""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...) where T <: AbstractACTForm
    variable_voltage_angle(pm, n; kwargs...)
    variable_voltage_magnitude_sqr(pm, n; kwargs...)
    variable_voltage_product(pm, n; kwargs...)
end

function constraint_voltage(pm::GenericPowerModel{T}, n::Int) where T <: StandardACTForm
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
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, arc_from, f_bus, t_bus, angmin, angmax) where T <: StandardACTForm
    va_fr = pm.var[:nw][n][:va][f_bus]
    va_to = pm.var[:nw][n][:va][t_bus]

    @constraint(pm.model, va_fr - va_to <= angmax)
    @constraint(pm.model, va_fr - va_to >= angmin)
end


""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractACTForm
    add_setpoint(sol, pm, "bus", "vm", :w; scale = (x,item) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "va", :va)
end
