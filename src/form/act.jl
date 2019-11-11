### w-theta form of the non-convex AC equations

"`t[ref_bus] == 0`"
function constraint_theta_ref(pm::AbstractACTModel, n::Int, c::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, c, :va)[i] == 0)
end

""
function variable_voltage(pm::AbstractACTModel; kwargs...)
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_model_voltage(pm::AbstractACTModel, n::Int, c::Int)
    _check_missing_keys(var(pm, n, c), [:va,:w,:wr,:wi], typeof(pm))

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
function constraint_voltage_angle_difference(pm::AbstractACTModel, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    va_fr = var(pm, n, c, :va)[f_bus]
    va_to = var(pm, n, c, :va)[t_bus]

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin)
end


""
function add_bus_voltage_setpoint(sol, pm::AbstractACTModel)
    add_setpoint!(sol, pm, "bus", "vm", :w, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"], scale = (x,item,cnd) -> sqrt(x))
    add_setpoint!(sol, pm, "bus", "va", :va, status_name=pm_component_status["bus"], inactive_status_value = pm_component_status_inactive["bus"])
end
