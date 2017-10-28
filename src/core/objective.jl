################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

"""
Checks that all cost models are polynomials, quadratic or less
"""
function check_cost_models(pm::GenericPowerModel, nws)
    for n in nws
        ref = pm.ref[:nw][n]
        for (i,gen) in ref[:gen]
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
        for (i,dcline) in ref[:dcline]
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
end


""
function objective_min_fuel_cost(pm::GenericPowerModel, nws=[pm.cnw])
    check_cost_models(pm, nws)

    pg = Dict(n => pm.var[:nw][n][:pg] for n in nws)
    dc_p = Dict(n => pm.var[:nw][n][:p_dc] for n in nws)

    from_idx = Dict()
    for n in nws
        ref = pm.ref[:nw][n]
        from_idx[n] = Dict(arc[1] => arc for arc in ref[:arcs_from_dc])
    end

    return @objective(pm.model, Min, 
        sum(
            sum(gen["cost"][1]*pg[n][i]^2 + gen["cost"][2]*pg[n][i] + gen["cost"][3] for (i,gen) in pm.ref[:nw][n][:gen]) +
            sum(dcline["cost"][1]*dc_p[n][from_idx[n][i]]^2 + dcline["cost"][2]*dc_p[n][from_idx[n][i]] + dcline["cost"][3] for (i,dcline) in pm.ref[:nw][n][:dcline])
        for n in nws)
    )
end

""
function objective_min_fuel_cost{T <: AbstractConicPowerFormulation}(pm::GenericPowerModel{T}, nws=[pm.cnw])
    check_cost_models(pm, nws)

    pg = Dict(n => pm.var[:nw][n][:pg] for n in nws)
    dc_p = Dict(n => pm.var[:nw][n][:p_dc] for n in nws)

    from_idx = Dict()
    for n in nws
        ref = pm.ref[:nw][n]
        from_idx[n] = Dict(arc[1] => arc for arc in ref[:arcs_from_dc])
    end

    pg_sqr = Dict()
    dc_p_sqr = Dict()
    for n in nws
        pg_sqr[n] = pm.var[:nw][n][:pg_sqr] = @variable(pm.model, 
            [i in keys(pm.ref[:nw][n][:gen])], basename="$(n)_pg_sqr",
            lowerbound = pm.ref[:nw][n][:gen][i]["pmin"]^2,
            upperbound = pm.ref[:nw][n][:gen][i]["pmax"]^2
        )
        for (i, gen) in pm.ref[:nw][n][:gen]
            @constraint(pm.model, norm([2*pg[n][i], pg_sqr[n][i]-1]) <= pg_sqr[n][i]+1)
        end

        dc_p_sqr[n] = pm.var[:nw][n][:dc_p_sqr] = @variable(pm.model, 
            [i in keys(pm.ref[:nw][n][:dcline])], basename="$(n)_dc_p_sqr",
            lowerbound = pm.ref[:nw][n][:dcline][i]["pminf"]^2,
            upperbound = pm.ref[:nw][n][:dcline][i]["pmaxf"]^2
        )

        for (i, dcline) in pm.ref[:nw][n][:dcline]
            @constraint(pm.model, norm([2*dc_p[n][from_idx[n][i]], dc_p_sqr[n][i]-1]) <= dc_p_sqr[n][i]+1)
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum( gen["cost"][1]*pg_sqr[n][i] + gen["cost"][2]*pg[n][i] + gen["cost"][3] for (i,gen) in pm.ref[:nw][n][:gen]) +
            sum(dcline["cost"][1]*dc_p_sqr[n][i]^2 + dcline["cost"][2]*dc_p[n][from_idx[n][i]] + dcline["cost"][3] for (i,dcline) in pm.ref[:nw][n][:dcline])
        for n in nws)
    )
end


"Cost of building branchs"
function objective_tnep_cost(pm::GenericPowerModel, nws=[pm.cnw])
    branch_ne = Dict(n => pm.var[:nw][n][:branch_ne] for n in nws)
    branches = Dict(n => pm.ref[:nw][n][:ne_branch] for n in nws)

    return @objective(pm.model, Min, 
        sum(
            sum( branch["construction_cost"]*branch_ne[n][i] for (i,branch) in branches[n])
        for n in nws)
    )
end
