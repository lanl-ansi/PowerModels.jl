################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

"""
Checks that all cost models are polynomials, quadratic or less
"""
function check_cost_models(pm::GenericPowerModel)
    for (i,gen) in pm.ref[:gen]
        if haskey(gen, "cost")
            if gen["model"] != 2
                error("only cost model 2 is supported at this time, given cost model $(gen["model"]) on generator $(i)")
            end
            if length(gen["cost"]) > 3
                error("only cost models of degree 3 or less are supported at this time, given cost model of degree $(length(gen["cost"])) on generator $(i)")
            end
        else
            error("no cost given for generator $(i)")
        end
    end
    for (i,dcline) in pm.ref[:dcline]
        if haskey(dcline, "model") 
            if haskey(dcline, "model") && dcline["model"] != 2
                error("only cost model 2 is supported at this time, given cost model $(dcline["model"]) on dcline $(i)")
            end
            if haskey(dcline, "cost") && length(dcline["cost"]) > 3
                error("only cost models of degree 3 or less are supported at this time, given cost model of degree $(length(dcline["cost"])) on dcline $(i)")
            end
        else
            error("no cost given for dcline $(i)")
        end
    end
end


""
function objective_min_fuel_cost(pm::GenericPowerModel)
    check_cost_models(pm)

    pg = pm.var[:pg]
    dc_p = pm.var[:p_dc]

    from_idx = Dict(arc[1] => arc for arc in pm.ref[:arcs_from_dc])

    return @objective(pm.model, Min, 
        sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in pm.ref[:gen]) +
        sum(dcline["cost"][1]*dc_p[from_idx[i]]^2 + dcline["cost"][2]*dc_p[from_idx[i]] + dcline["cost"][3] for (i,dcline) in pm.ref[:dcline])
    )
end

""
function objective_min_fuel_cost{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T})
    check_cost_models(pm)

    pg = pm.var[:pg]
    dc_p = pm.var[:p_dc]
    from_idx = Dict(arc[1] => arc for arc in pm.ref[:arcs_from_dc])

    pg_sqr = pm.var[:pg_sqr] = @variable(pm.model, 
        [i in keys(pm.ref[:gen])], basename="pg_sqr",
        lowerbound = pm.ref[:gen][i]["pmin"]^2,
        upperbound = pm.ref[:gen][i]["pmax"]^2
    )
    for (i, gen) in pm.ref[:gen]
        @constraint(pm.model, norm([2*pg[i], pg_sqr[i]-1]) <= pg_sqr[i]+1)
    end

    dc_p_sqr = pm.var[:dc_p_sqr] = @variable(pm.model, 
        dc_p_sqr[i in keys(pm.ref[:dcline])], basename="dc_p_sqr",
        lowerbound = pm.ref[:dcline][i]["pminf"]^2,
        upperbound = pm.ref[:dcline][i]["pmaxf"]^2
    )
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
    line_ne = pm.var[:line_ne]
    branches = pm.ref[:ne_branch]
    return @objective(pm.model, Min, sum( branches[i]["construction_cost"]*line_ne[i] for (i,branch) in branches) )
end
