### W-Theta form non-convex AC equations

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

""
function variable_voltage{T <: AbstractACTForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_voltage{T <: StandardACTForm}(pm::GenericPowerModel{T})
    t = getindex(pm.model, :t)
    w = getindex(pm.model, :w)
    wr = getindex(pm.model, :wr)
    wi = getindex(pm.model, :wi)

    for (i,j) in keys(pm.ref[:buspairs])
        @NLconstraint(pm.model, wr[(i,j)]^2 + wi[(i,j)]^2 == w[i]*w[j])
        @NLconstraint(pm.model, wi[(i,j)]/wr[(i,j)] == tan(t[i] - t[j]))
    end
end

"`t[ref_bus] == 0`"
constraint_theta_ref{T <: AbstractACTForm}(pm::GenericPowerModel{T}, ref_bus::Int) =
    Set([@constraint(pm.model, getindex(pm.model, :t)[ref_bus] == 0)])


"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_phase_angle_difference{T <: AbstractACTForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    t_fr = getindex(pm.model, :t)[f_bus]
    t_to = getindex(pm.model, :t)[t_bus]

    c1 = @constraint(pm.model, t_fr - t_to <= angmax)
    c2 = @constraint(pm.model, t_fr - t_to >= angmin)
    return Set([c1, c2])
end

""
function add_bus_voltage_setpoint{T <: AbstractACTForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end
