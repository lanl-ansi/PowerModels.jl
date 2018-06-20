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
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, h::Int, i::Int) where T <: AbstractACTForm
    @constraint(pm.model, var(pm, n, h, :va)[i] == 0)
end

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACTForm
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_voltage(pm::GenericPowerModel{T}, n::Int, h::Int) where T <: StandardACTForm
    t  = var(pm, n, h, :va)
    w  = var(pm, n, h,  :w)
    wr = var(pm, n, h, :wr)
    wi = var(pm, n, h, :wi)

    for (i,j) in ids(pm, n, :buspairs)
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
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, h::Int, f_idx, angmin, angmax) where T <: StandardACTForm
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, h, :va)[f_bus]
    va_to = var(pm, n, h, :va)[t_bus]

    @constraint(pm.model, va_fr - va_to <= angmax)
    @constraint(pm.model, va_fr - va_to >= angmin)
end


""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractACTForm
    add_setpoint(sol, pm, "bus", "vm", :w; scale = (x,item) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "va", :va)
end
