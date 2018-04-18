################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

"""
Checks that all cost models are present and of the same type
"""
function check_cost_models(pm::GenericPowerModel)
    model = nothing

    for (n, ref) in pm.ref[:nw]
        for (i,gen) in ref[:gen]
            if haskey(gen, "cost")
                if model == nothing
                    model = gen["model"]
                else
                    if gen["model"] != model
                        error("cost models are inconsistent, the typical model is $(model) however model $(gen["model"]) is given on generator $(i)")
                    end
                end
            else
                error("no cost given for generator $(i)")
            end
        end
        for (i,dcline) in ref[:dcline]
            if haskey(dcline, "model")
                if model == nothing
                    model = dcline["model"]
                else
                    if dcline["model"] != model
                        error("cost models are inconsistent, the typical model is $(model) however model $(dcline["model"]) is given on dcline $(i)")
                    end
                end
            else
                error("no cost given for dcline $(i)")
            end
        end
    end

    return model
end



""
function objective_min_fuel_cost(pm::GenericPowerModel)
    model = check_cost_models(pm)

    if model == 1
        return objective_min_pwl_fuel_cost(pm)
    elseif model == 2
        return objective_min_polynomial_fuel_cost(pm)
    else
        error("Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end



"""
Checks that all cost models are polynomials, quadratic or less
"""
function check_polynomial_cost_models(pm::GenericPowerModel)
    for (n, ref) in pm.ref[:nw]
        for (i,gen) in ref[:gen]
            @assert gen["model"] == 2
            if length(gen["cost"]) > 3
                error("only cost models of degree 3 or less are supported at this time, given cost model of degree $(length(gen["cost"])) on generator $(i)")
            end
        end
        for (i,dcline) in ref[:dcline]
            @assert dcline["model"] == 2
            if length(dcline["cost"]) > 3
                error("only cost models of degree 3 or less are supported at this time, given cost model of degree $(length(dcline["cost"])) on dcline $(i)")
            end
        end
    end
end


""
function objective_min_polynomial_fuel_cost(pm::GenericPowerModel)
    check_polynomial_cost_models(pm)

    pg = Dict(n => pm.var[:nw][n][:pg] for n in nws(pm))
    dc_p = Dict(n => pm.var[:nw][n][:p_dc] for n in nws(pm))

    from_idx = Dict()
    for (n, ref) in pm.ref[:nw]
        from_idx[n] = Dict(arc[1] => arc for arc in ref[:arcs_from_dc])
    end

    return @objective(pm.model, Min, 
        sum(
            sum(gen["cost"][1]*pg[n][i]^2 + gen["cost"][2]*pg[n][i] + gen["cost"][3] for (i,gen) in ref[:gen]) +
            sum(dcline["cost"][1]*dc_p[n][from_idx[n][i]]^2 + dcline["cost"][2]*dc_p[n][from_idx[n][i]] + dcline["cost"][3] for (i,dcline) in ref[:dcline])
        for (n, ref) in pm.ref[:nw])
    )
end

""
function objective_min_polynomial_fuel_cost(pm::GenericPowerModel{T}) where T <: AbstractConicPowerFormulation
    check_polynomial_cost_models(pm)

    pg = Dict(n => pm.var[:nw][n][:pg] for n in nws(pm))
    dc_p = Dict(n => pm.var[:nw][n][:p_dc] for n in nws(pm))

    from_idx = Dict()
    for (n, ref) in pm.ref[:nw]
        from_idx[n] = Dict(arc[1] => arc for arc in ref[:arcs_from_dc])
    end

    pg_sqr = Dict()
    dc_p_sqr = Dict()
    for (n, ref) in pm.ref[:nw]
        pg_sqr[n] = pm.var[:nw][n][:pg_sqr] = @variable(pm.model, 
            [i in keys(ref[:gen])], basename="$(n)_pg_sqr",
            lowerbound = ref[:gen][i]["pmin"]^2,
            upperbound = ref[:gen][i]["pmax"]^2
        )
        for (i, gen) in ref[:gen]
            @constraint(pm.model, norm([2*pg[n][i], pg_sqr[n][i]-1]) <= pg_sqr[n][i]+1)
        end

        dc_p_sqr[n] = pm.var[:nw][n][:dc_p_sqr] = @variable(pm.model, 
            [i in keys(ref[:dcline])], basename="$(n)_dc_p_sqr",
            lowerbound = ref[:dcline][i]["pminf"]^2,
            upperbound = ref[:dcline][i]["pmaxf"]^2
        )

        for (i, dcline) in ref[:dcline]
            @constraint(pm.model, norm([2*dc_p[n][from_idx[n][i]], dc_p_sqr[n][i]-1]) <= dc_p_sqr[n][i]+1)
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum( gen["cost"][1]*pg_sqr[n][i] + gen["cost"][2]*pg[n][i] + gen["cost"][3] for (i,gen) in ref[:gen]) +
            sum(dcline["cost"][1]*dc_p_sqr[n][i]^2 + dcline["cost"][2]*dc_p[n][from_idx[n][i]] + dcline["cost"][3] for (i,dcline) in ref[:dcline])
        for (n, ref) in pm.ref[:nw])
    )
end



"""
compute m and b from points pwl points
"""
function slope_intercepts(points::Array{T,1}) where T <: Real
    line_data = []

    for i in 3:2:length(points)
        x1 = points[i-2]
        y1 = points[i-1]
        x2 = points[i-0]
        y2 = points[i+1]

        m = (y2 - y1)/(x2 - x1)
        b = y1 - m * x1

        line = Dict{String,Any}(
            "slope" => m,
            "intercept" => b
        )
        push!(line_data, line)
    end

    return line_data
end


"""
compute lines in m and b from from pwl cost models
data is a list of components
"""
function get_lines(data)
    lines = Dict{Int,Any}()
    for (i,comp) in data
        @assert comp["model"] == 1
        line_data = slope_intercepts(comp["cost"])
        lines[i] = line_data
        for i in 2:length(line_data)
            if line_data[i-1]["slope"] > line_data[i]["slope"]
                error("non-convex pwl function found in points $(comp["cost"])\nlines: $(line_data)")
            end
        end
    end
    return lines
end


""
function objective_min_pwl_fuel_cost(pm::GenericPowerModel)
    #check_polynomial_cost_models(pm)

    pg = Dict(n => pm.var[:nw][n][:pg] for n in nws(pm))
    dc_p = Dict(n => pm.var[:nw][n][:p_dc] for n in nws(pm))

    pg_cost = Dict()
    dc_p_cost = Dict()
    for (n, ref) in pm.ref[:nw]
        pg_cost[n] = pm.var[:nw][n][:pg_cost] = @variable(pm.model, 
            [i in keys(ref[:gen])], basename="$(n)_pg_cost"
        )

        # pwl cost
        gen_lines = get_lines(ref[:gen])
        for (i, gen) in ref[:gen]
            for line in gen_lines[i]
                @constraint(pm.model, pg_cost[n][i] >= line["slope"]*pg[n][i] + line["intercept"])
            end
        end

        dc_p_cost[n] = pm.var[:nw][n][:dc_p_cost] = @variable(pm.model, 
            [i in keys(ref[:dcline])], basename="$(n)_dc_p_cost",
        )

        # pwl cost
        dcline_lines = get_lines(ref[:dcline])
        for (i, dcline) in ref[:dcline]
            for line in dcline_lines[i]
                @constraint(pm.model, dc_p_cost[n][i] >= line["slope"]*dc_p[n][i] + line["intercept"])
            end
        end

        #for (i, dcline) in ref[:dcline]
        #    @constraint(pm.model, norm([2*dc_p[n][from_idx[n][i]], dc_p_sqr[n][i]-1]) <= dc_p_sqr[n][i]+1)
        #end
    end


    return @objective(pm.model, Min,
        sum(
            sum( pg_cost[n][i] for (i,gen) in ref[:gen]) +
            sum( dc_p_cost[n][i] for (i,dcline) in ref[:dcline])
        for (n, ref) in pm.ref[:nw])
    )
end


"Cost of building branches"
function objective_tnep_cost(pm::GenericPowerModel)
    branch_ne = Dict(n => pm.var[:nw][n][:branch_ne] for n in nws(pm))
    branches = Dict(n => pm.ref[:nw][n][:ne_branch] for n in nws(pm))

    return @objective(pm.model, Min, 
        sum(
            sum( branch["construction_cost"]*branch_ne[n][i] for (i,branch) in branches[n])
        for n in nws(pm))
    )
end
