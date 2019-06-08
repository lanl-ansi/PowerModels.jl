### w-theta form of the non-convex AC equations

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int) where T <: AbstractACTForm
    JuMP.@constraint(pm.model, var(pm, n, c, :va)[i] == 0)
end

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACTForm
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_model_voltage(pm::GenericPowerModel{T}, n::Int, c::Int) where T <: StandardACTForm
    _check_missing_keys(var(pm, n, c), [:va,:w,:wr,:wi], T)

    t  = var(pm, n, c, :va)
    w  = var(pm, n, c,  :w)
    wr = var(pm, n, c, :wr)
    wi = var(pm, n, c, :wi)

    for (i,j) in ids(pm, n, :buspairs)
        JuMP.@constraint(pm.model, wr[(i,j)]^2 + wi[(i,j)]^2 == w[i]*w[j])
        JuMP.@NLconstraint(pm.model, wi[(i,j)] == tan(t[i] - t[j])*wr[(i,j)])
    end
end


"""
```
t[f_bus] - t[t_bus] <= angmax
t[f_bus] - t[t_bus] >= angmin
```
"""
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax) where T <: StandardACTForm
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va)[f_bus]
    va_to = var(pm, n, c, :va)[t_bus]

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin)
end


""
function add_setpoint_bus_voltage!(sol, pm::GenericPowerModel{T}) where T <: AbstractACTForm
    add_setpoint!(sol, pm, "bus", "vm", :w, status_name="bus_type", inactive_status_value = 4, scale = (x,item,cnd) -> sqrt(x))
    add_setpoint!(sol, pm, "bus", "va", :va, status_name="bus_type", inactive_status_value = 4)
end
