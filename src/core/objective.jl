################################################################################
# The purpose of this file is to define common objectives for power flow models
# This will hopefully make everything more compositional
################################################################################

function objective_min_fuel_cost{T}(pm::GenericPowerModel{T})
    pg = getvariable(pm.model, :pg)
    cost(i) = pm.set.gens[i]["cost"]
    return @objective(pm.model, Min, sum{ cost(i)[1]*pg[i]^2 + cost(i)[2]*pg[i] + cost(i)[3], i in pm.set.gen_indexes} )
end

function objective_min_fuel_cost{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T})
    @variable(pm.model, pm.set.gens[i]["pmin"]^2 <= pg_sqr[i in pm.set.gen_indexes] <= pm.set.gens[i]["pmax"]^2)

    pg = getvariable(pm.model, :pg)

    for (i, gen) in pm.set.gens
        @constraint(pm.model, norm([2*pg[i], pg_sqr[i]-1]) <= pg_sqr[i]+1)
    end

    cost(i) = pm.set.gens[i]["cost"]
    return @objective(pm.model, Min, sum{ cost(i)[1]*pg_sqr[i] + cost(i)[2]*pg[i] + cost(i)[3], i in pm.set.gen_indexes} )
end
