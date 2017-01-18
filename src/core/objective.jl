################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

function objective_min_fuel_cost{T}(pm::GenericPowerModel{T})
    pg = getvariable(pm.model, :pg)
    return @objective(pm.model, Min, sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in pm.ref[:gen]) )
end

function objective_min_fuel_cost{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T})
    @variable(pm.model, pm.ref[:gen][i]["pmin"]^2 <= pg_sqr[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["pmax"]^2)

    pg = getvariable(pm.model, :pg)

    for (i, gen) in pm.ref[:gen]
        @constraint(pm.model, norm([2*pg[i], pg_sqr[i]-1]) <= pg_sqr[i]+1)
    end

    return @objective(pm.model, Min, sum( gen["cost"][1]*pg_sqr[i] + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in pm.ref[:gen]) )
end

### Cost of building lines
function objective_tnep_cost{T}(pm::GenericPowerModel{T})
    line_ne = getvariable(pm.model, :line_ne)
    branches = pm.ref[:ne_branch]
    return @objective(pm.model, Min, sum( branches[i]["construction_cost"]*line_ne[i] for (i,branch) in branches) )
end
