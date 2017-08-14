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

""
function variable_voltage{T <: AbstractACTForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_product(pm; kwargs...)
end

function constraint_voltage{T <: StandardACTForm}(pm::GenericPowerModel{T})
    t = pm.var[:t]
    w = pm.var[:w]
    wr = pm.var[:wr]
    wi = pm.var[:wi]

    for (i,j) in keys(pm.ref[:buspairs])
        @NLconstraint(pm.model, wr[(i,j)]^2 + wi[(i,j)]^2 == w[i]*w[j])
        @NLconstraint(pm.model, wi[(i,j)]/wr[(i,j)] == tan(t[i] - t[j]))
    end
end


""
function add_bus_voltage_setpoint{T <: AbstractACTForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end
