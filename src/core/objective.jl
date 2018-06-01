################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

"""
Checks that all cost models are present and of the same type
"""
function check_cost_models(pm::GenericPowerModel)
    model = nothing

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            if haskey(gen, "cost")
                for h in phase_ids(pm, n)
                    if model == nothing
                        model = gen["model"][h]
                    else
                        if gen["model"][h] != model
                            error("cost models are inconsistent, the typical model is $(model) however model $(gen["model"]) is given on generator $(i)")
                        end
                    end
                end
            else
                error("no cost given for generator $(i)")
            end
        end

        for (i,dcline) in nw_ref[:dcline]
            if haskey(dcline, "model")
                for h in phase_ids(pm, n)
                    if model == nothing
                        model = dcline["model"][h]
                    else
                        if dcline["model"][h] != model
                            error("cost models are inconsistent, the typical model is $(model) however model $(dcline["model"]) is given on dcline $(i)")
                        end
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
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            for h in phase_ids(pm, n)
                @assert gen["model"][h] == 2
                if length(gen["cost"][h]) > 3
                    error("only cost models of degree 3 or less are supported at this time, given cost model of degree $(length(gen["cost"][h])) on generator $(i)")
                end
            end
        end
        for (i,dcline) in nw_ref[:dcline]
            for h in phase_ids(pm, n)
                @assert dcline["model"][h] == 2
                if length(dcline["cost"][h]) > 3
                    error("only cost models of degree 3 or less are supported at this time, given cost model of degree $(length(dcline["cost"][h])) on dcline $(i)")
                end
            end
        end
    end
end



""
function objective_min_polynomial_fuel_cost(pm::GenericPowerModel)
    check_polynomial_cost_models(pm)

    from_idx = Dict()
    for (n, nw_ref) in nws(pm)
        from_idx[n] = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])
    end

    return @objective(pm.model, Min,
        sum(
            sum(
                sum(   getmpv(gen["cost"],h)[1]*var(pm, n, h, :pg, i)^2 + getmpv(gen["cost"],h)[2]*var(pm, n, h, :pg, i) + getmpv(gen["cost"],h)[3] for (i,gen) in nw_ref[:gen]) +
                sum(getmpv(dcline["cost"],h)[1]*var(pm, n, h, :p_dc, from_idx[n][i])^2 + getmpv(dcline["cost"],h)[2]*var(pm, n, h, :p_dc, from_idx[n][i]) + getmpv(dcline["cost"],h)[3] for (i,dcline) in nw_ref[:dcline])
            for h in phase_ids(pm, n))
        for (n, nw_ref) in nws(pm))
    )
end


""
function objective_min_polynomial_fuel_cost(pm::GenericPowerModel{T}) where T <: AbstractConicPowerFormulation
    check_polynomial_cost_models(pm)

    from_idx = Dict()
    for (n, nw_ref) in nws(pm)
        from_idx[n] = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])
    end

    pg_sqr = Dict()
    dc_p_sqr = Dict()
    for (n, nw_ref) in nws(pm)
        for h in phase_ids(pm, n)
            pg_sqr = var(pm, n, h)[:pg_sqr] = @variable(pm.model, 
                [i in ids(pm, n, :gen)], basename="$(n)_$(h)_pg_sqr",
                lowerbound = ref(pm, n, :gen, i, "pmin", h)^2,
                upperbound = ref(pm, n, :gen, i, "pmax", h)^2
            )
            for (i, gen) in nw_ref[:gen]
                @constraint(pm.model, norm([2*var(pm, n, h, :pg, i), pg_sqr[i]-1]) <= pg_sqr[i]+1)
            end

            dc_p_sqr = var(pm, n, h)[:p_dc_sqr] = @variable(pm.model, 
                [i in ids(pm, n, :dcline)], basename="$(n)_$(h)_dc_p_sqr",
                lowerbound = ref(pm, n, :dcline, i, "pminf", h)^2,
                upperbound = ref(pm, n, :dcline, i, "pmaxf", h)^2
            )

            for (i, dcline) in nw_ref[:dcline]
                @constraint(pm.model, norm([2*var(pm, n, h, :p_dc)[from_idx[n][i]], dc_p_sqr[i]-1]) <= dc_p_sqr[i]+1)
            end
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum(
                sum(   getmpv(gen["cost"],h)[1]*var(pm, n, h, :pg_sqr, i)      + getmpv(gen["cost"],h)[2]*var(pm, n, h, :pg, i)                   + getmpv(gen["cost"],h)[3] for (i,gen) in nw_ref[:gen]) +
                sum(getmpv(dcline["cost"],h)[1]*var(pm, n, h, :p_dc_sqr, i) + getmpv(dcline["cost"],h)[2]*var(pm, n, h, :p_dc, from_idx[n][i]) + getmpv(dcline["cost"],h)[3] for (i,dcline) in nw_ref[:dcline])
            for h in phase_ids(pm, n))
        for (n, nw_ref) in nws(pm))
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
function get_lines(data, ph::Int)
    lines = Dict{Int,Any}()
    for (i,comp) in data
        @assert comp["model"][ph] == 1
        line_data = slope_intercepts(getmpv(comp["cost"], ph))
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

    for (n, nw_ref) in nws(pm)
        for h in phase_ids(pm, n)
            pg_cost = var(pm, n, h)[:pg_cost] = @variable(pm.model, 
                [i in ids(pm, n, :gen)], basename="$(n)_$(h)_pg_cost"
            )

            # pwl cost
            gen_lines = get_lines(nw_ref[:gen], h)
            for (i, gen) in nw_ref[:gen]
                for line in gen_lines[i]
                    @constraint(pm.model, pg_cost[i] >= line["slope"]*var(pm, n, h, :pg, i) + line["intercept"])
                end
            end

            dc_p_cost = var(pm, n, h)[:p_dc_cost] = @variable(pm.model, 
                [i in ids(pm, n, :dcline)], basename="$(n)_$(h)_dc_p_cost",
            )

            # pwl cost
            dcline_lines = get_lines(nw_ref[:dcline], h)
            for (i, dcline) in nw_ref[:dcline]
                for line in dcline_lines[i]
                    @constraint(pm.model, dc_p_cost[i] >= line["slope"]*var(pm, n, h, :p_dc)[i] + line["intercept"])
                end
            end

        end
    end

    return @objective(pm.model, Min,
        sum(
            sum(
                sum( var(pm, n, h,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
                sum( var(pm, n, h, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
            for h in phase_ids(pm, n))
        for (n, nw_ref) in nws(pm))
    )
end


"Cost of building branches"
function objective_tnep_cost(pm::GenericPowerModel)
    return @objective(pm.model, Min, 
        sum(
            sum(
                sum( branch["construction_cost"]*var(pm, n, h, :branch_ne, i) for (i,branch) in nw_ref[:ne_branch] )
            for h in phase_ids(pm, n))
        for (n, nw_ref) in nws(pm))
    )
end

