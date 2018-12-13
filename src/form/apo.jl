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


""
function add_generator_power_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractActivePowerFormulation
    add_setpoint(sol, pm, "gen", "pg", :pg)
    add_setpoint_fixed(sol, pm, "gen", "qg")
end


""
function add_storage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractActivePowerFormulation
    if haskey(pm.data, "storage") || (InfrastructureModels.ismultinetwork(pm.data) && haskey(pm.data["nw"]["$(pm.cnw)"], "storage"))
        add_setpoint(sol, pm, "storage", "ps", :ps)
        add_setpoint_fixed(sol, pm, "storage", "qs")
        add_setpoint(sol, pm, "storage", "se", :se, conductorless=true)
    end
end

