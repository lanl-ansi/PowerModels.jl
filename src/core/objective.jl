################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

""
function objective_min_fuel_cost(pm::GenericPowerModel)
    pg = getindex(pm.model, :pg)
    dc_p = getindex(pm.model, :p_dc)
    from_idx = Dict(arc[1] => arc for arc in pm.ref[:arcs_from_dc])

    return @objective(pm.model, Min, 
        sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in pm.ref[:gen]) +
        sum(dcline["cost"][1]*dc_p[from_idx[i]]^2 + dcline["cost"][2]*dc_p[from_idx[i]] + dcline["cost"][3] for (i,dcline) in pm.ref[:dcline])
    )
end

""
function objective_min_fuel_cost{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T})
    #if length(pm.ref[:dcline]) > 0
    #    error("ConicPowerFormulations do not currently support dcline cost functions")
    #end

    pg = getindex(pm.model, :pg)
    dc_p = getindex(pm.model, :p_dc)
    from_idx = Dict(arc[1] => arc for arc in pm.ref[:arcs_from_dc])

    @variable(pm.model, pm.ref[:gen][i]["pmin"]^2 <= pg_sqr[i in keys(pm.ref[:gen])] <= pm.ref[:gen][i]["pmax"]^2)
    for (i, gen) in pm.ref[:gen]
        @constraint(pm.model, norm([2*pg[i], pg_sqr[i]-1]) <= pg_sqr[i]+1)
    end

    @variable(pm.model, pm.ref[:dcline][i]["pminf"]^2 <= dc_p_sqr[i in keys(pm.ref[:dcline])] <= pm.ref[:dcline][i]["pmaxf"]^2)
    for (i, dcline) in pm.ref[:dcline]
        @constraint(pm.model, norm([2*dc_p[from_idx[i]], dc_p_sqr[i]-1]) <= dc_p_sqr[i]+1)
    end

    return @objective(pm.model, Min,
        sum( gen["cost"][1]*pg_sqr[i] + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in pm.ref[:gen]) +
        sum(dcline["cost"][1]*dc_p_sqr[i]^2 + dcline["cost"][2]*dc_p[from_idx[i]] + dcline["cost"][3] for (i,dcline) in pm.ref[:dcline])
    )
end

"Cost of building lines"
function objective_tnep_cost(pm::GenericPowerModel)
    line_ne = getindex(pm.model, :line_ne)
    branches = pm.ref[:ne_branch]
    return @objective(pm.model, Min, sum( branches[i]["construction_cost"]*line_ne[i] for (i,branch) in branches) )
end
