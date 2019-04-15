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
                if model == nothing
                    model = gen["model"]
                else
                    if gen["model"] != model
                        error(LOGGER, "cost models are inconsistent, the typical model is $(model) however model $(gen["model"]) is given on generator $(i)")
                    end
                end
            else
                error(LOGGER, "no cost given for generator $(i)")
            end
        end

        for (i,dcline) in nw_ref[:dcline]
            if haskey(dcline, "model")
                if model == nothing
                    model = dcline["model"]
                else
                    if dcline["model"] != model
                        error(LOGGER, "cost models are inconsistent, the typical model is $(model) however model $(dcline["model"]) is given on dcline $(i)")
                    end
                end
            else
                error(LOGGER, "no cost given for dcline $(i)")
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
        error(LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end


""
function objective_min_gen_fuel_cost(pm::GenericPowerModel)
    model = check_cost_models(pm)

    if model == 1
        return objective_min_gen_pwl_fuel_cost(pm)
    elseif model == 2
        return objective_min_gen_polynomial_fuel_cost(pm)
    else
        error(LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end


""
function objective_min_polynomial_fuel_cost(pm::GenericPowerModel)
    order = calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_polynomial_fuel_cost_linquad(pm)
    else
        return _objective_min_polynomial_fuel_cost_nl(pm)
    end
end


function _objective_min_polynomial_fuel_cost_quadratic(pm::GenericPowerModel)
    warn(LOGGER, "call to depreciated function _objective_min_polynomial_fuel_cost_quadratic")
    _objective_min_polynomial_fuel_cost_linquad(pm)
end

function _objective_min_polynomial_fuel_cost_linear(pm::GenericPowerModel)
    warn(LOGGER, "call to depreciated function _objective_min_polynomial_fuel_cost_linear")
    _objective_min_polynomial_fuel_cost_linquad(pm)
end

""
function _objective_min_polynomial_fuel_cost_linquad(pm::GenericPowerModel)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n) )

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = gen["cost"][1]*pg + gen["cost"][2]
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = gen["cost"][1]*pg^2 + gen["cost"][2]*pg + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])
        for (i,dcline) in nw_ref[:dcline]
            p_dc = sum( var(pm, n, c, :p_dc, from_idx[i]) for c in conductor_ids(pm, n) )
            
            if length(dcline["cost"]) == 1
                dcline_cost[(n,i)] = dcline["cost"][1]
            elseif length(dcline["cost"]) == 2
                dcline_cost[(n,i)] = dcline["cost"][1]*p_dc + dcline["cost"][2]
            elseif length(dcline["cost"]) == 3
                dcline_cost[(n,i)] = dcline["cost"][1]*p_dc^2 + dcline["cost"][2]*p_dc + dcline["cost"][3]
            else
                dcline_cost[(n,i)] = 0.0
            end
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum(    gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] ) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline] )
        for (n, nw_ref) in nws(pm))
    )
end


"Adds lifted variables to turn a quadatic objective into a linear one; needed for conic solvers that only support linear objectives"
function _objective_min_polynomial_fuel_cost_linquad(pm::GenericPowerModel{T}) where T <: AbstractConicForms
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)

        var(pm, n)[:pg_sqr] = Dict()
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n) )

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = gen["cost"][1]*pg + gen["cost"][2]
            elseif length(gen["cost"]) == 3
                pmin = sum(gen["pmin"][c] for c in conductor_ids(pm, n))
                pmax = sum(gen["pmax"][c] for c in conductor_ids(pm, n))

                pg_sqr_ub = max(pmin^2, pmax^2)
                pg_sqr_lb = 0.0
                if pmin > 0.0
                    pg_sqr_lb = pmin^2
                end
                if pmax < 0.0
                    pg_sqr_lb = pmax^2
                end

                pg_sqr = var(pm, n, :pg_sqr)[i] = @variable(pm.model,
                    basename="$(n)_pg_sqr_$(i)",
                    lowerbound = pg_sqr_lb,
                    upperbound = pg_sqr_ub
                )
                @constraint(pm.model, norm([2*pg, pg_sqr-1]) <= pg_sqr+1)

                gen_cost[(n,i)] = gen["cost"][1]*pg_sqr + gen["cost"][2]*pg + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])

        var(pm, n)[:p_dc_sqr] = Dict()
        for (i,dcline) in nw_ref[:dcline]
            p_dc = sum( var(pm, n, c, :p_dc, from_idx[i]) for c in conductor_ids(pm, n) )

            if length(dcline["cost"]) == 1
                dcline_cost[(n,i)] = dcline["cost"][1]
            elseif length(dcline["cost"]) == 2
                dcline_cost[(n,i)] = dcline["cost"][1]*p_dc + dcline["cost"][2]
            elseif length(dcline["cost"]) == 3
                pmin = sum(dcline["pminf"][c] for c in conductor_ids(pm, n))
                pmax = sum(dcline["pmaxf"][c] for c in conductor_ids(pm, n))

                p_dc_sqr_ub = max(pmin^2, pmax^2)
                p_dc_sqr_lb = 0.0
                if pmin > 0.0
                    p_dc_sqr_lb = pmin^2
                end
                if pmax < 0.0
                    p_dc_sqr_lb = pmax^2
                end

                p_dc_sqr = var(pm, n, :p_dc_sqr)[i] = @variable(pm.model,
                    basename="$(n)_p_dc_sqr_$(i)",
                    lowerbound = p_dc_sqr_lb,
                    upperbound = p_dc_sqr_ub
                )
                @constraint(pm.model, norm([2*p_dc, p_dc_sqr-1]) <= p_dc_sqr+1)

                dcline_cost[(n,i)] = dcline["cost"][1]*p_dc_sqr + dcline["cost"][2]*p_dc + dcline["cost"][3]
            else
                dcline_cost[(n,i)] = 0.0
            end
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] ) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline] )
        for (n, nw_ref) in nws(pm))
    )
end


""
function _objective_min_polynomial_fuel_cost_nl(pm::GenericPowerModel)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[2]*pg^2 + sum( v*pg^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
            else
                gen_cost[(n,i)] = @NLexpression(pm.model, 0.0)
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])

        for (i,dcline) in nw_ref[:dcline]
            p_dc = sum( var(pm, n, c, :p_dc, from_idx[i]) for c in conductor_ids(pm, n))

            cost_rev = reverse(dcline["cost"])
            if length(cost_rev) == 1
                dcline_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                dcline_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc)
            elseif length(cost_rev) == 3
                dcline_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[3]*p_dc^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                dcline_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[2]*p_dc^2 + sum( v*p_dc^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
            else
                dcline_cost[(n,i)] = @NLexpression(pm.model, 0.0)
            end
        end
    end

    return @NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen]) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline])
        for (n, nw_ref) in nws(pm))
    )
end




""
function objective_min_gen_polynomial_fuel_cost(pm::GenericPowerModel)
    order = calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_gen_polynomial_fuel_cost_linquad(pm)
    else
        return _objective_min_gen_polynomial_fuel_cost_nl(pm)
    end
end

function _objective_min_gen_polynomial_fuel_cost_quadratic(pm::GenericPowerModel)
    warn(LOGGER, "call to depreciated function _objective_min_gen_polynomial_fuel_cost_quadratic")
    _objective_min_gen_polynomial_fuel_cost_linquad(pm)
end

function _objective_min_gen_polynomial_fuel_cost_linear(pm::GenericPowerModel)
    warn(LOGGER, "call to depreciated function _objective_min_gen_polynomial_fuel_cost_linear")
    _objective_min_gen_polynomial_fuel_cost_linquad(pm)
end

""
function _objective_min_gen_polynomial_fuel_cost_linquad(pm::GenericPowerModel)
    gen_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n) )

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = gen["cost"][1]*pg + gen["cost"][2]
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = gen["cost"][1]*pg^2 + gen["cost"][2]*pg + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
        for (n, nw_ref) in nws(pm))
    )
end


""
function _objective_min_gen_polynomial_fuel_cost_nl(pm::GenericPowerModel)
    gen_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = @NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2 + sum( v*pg^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
            else
                gen_cost[(n,i)] = @NLexpression(pm.model, 0.0)
            end
        end
    end

    return @NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
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

        line = Dict(
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
                error(LOGGER, "non-convex pwl function found in points $(comp["cost"])\nlines: $(line_data)")
            end
        end
    end
    return lines
end


""
function objective_min_pwl_fuel_cost(pm::GenericPowerModel)

    for (n, nw_ref) in nws(pm)
        gen_lines = get_lines(nw_ref[:gen])
        pg_cost_start = Dict{Int64,Float64}()
        for (i, gen) in nw_ref[:gen]
            pg_value = sum(JuMP.getvalue(var(pm, n, c, :pg, i)) for c in conductor_ids(pm, n))
            pg_cost_value = -Inf
            for line in gen_lines[i]
                pg_cost_value = max(pg_cost_value, line["slope"]*pg_value + line["intercept"])
            end
            pg_cost_start[i] = pg_cost_value
        end

        #println(pg_cost_start)

        pg_cost = var(pm, n)[:pg_cost] = @variable(pm.model,
            [i in ids(pm, n, :gen)], basename="$(n)_pg_cost",
            start=pg_cost_start[i]
        )

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            for line in gen_lines[i]
                @constraint(pm.model, pg_cost[i] >= line["slope"]*sum(var(pm, n, c, :pg, i) for c in conductor_ids(pm, n)) + line["intercept"])
            end
        end


        dcline_lines = get_lines(nw_ref[:dcline])
        dc_p_cost_start = Dict{Int64,Float64}()
        for (i, dcline) in nw_ref[:dcline]
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            dc_p_value = sum(JuMP.getvalue(var(pm, n, c, :p_dc)[arc]) for c in conductor_ids(pm, n))
            dc_p_cost_value = -Inf
            for line in dcline_lines[i]
                dc_p_cost_value = max(dc_p_cost_value, line["slope"]*dc_p_value + line["intercept"])
            end
            dc_p_cost_start[i] = dc_p_cost_value
        end

        dc_p_cost = var(pm, n)[:p_dc_cost] = @variable(pm.model,
            [i in ids(pm, n, :dcline)], basename="$(n)_dc_p_cost",
            start=dc_p_cost_start[i]
        )

        # dcline pwl cost
        for (i, dcline) in nw_ref[:dcline]
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            for line in dcline_lines[i]
                @constraint(pm.model, dc_p_cost[i] >= line["slope"]*sum(var(pm, n, c, :p_dc)[arc] for c in conductor_ids(pm, n)) + line["intercept"])
            end
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
            sum( var(pm, n, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
        for (n, nw_ref) in nws(pm))
    )
end


""
function objective_min_gen_pwl_fuel_cost(pm::GenericPowerModel)

    for (n, nw_ref) in nws(pm)
        pg_cost = var(pm, n)[:pg_cost] = @variable(pm.model,
            [i in ids(pm, n, :gen)], basename="$(n)_pg_cost"
        )

        # pwl cost
        gen_lines = get_lines(nw_ref[:gen])
        for (i, gen) in nw_ref[:gen]
            for line in gen_lines[i]
                @constraint(pm.model, pg_cost[i] >= line["slope"]*sum(var(pm, n, c, :pg, i) for c in conductor_ids(pm, n)) + line["intercept"])
            end
        end
    end

    return @objective(pm.model, Min,
        sum(
            sum( var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen])
        for (n, nw_ref) in nws(pm))
    )
end


"Cost of building branches"
function objective_tnep_cost(pm::GenericPowerModel)
    return @objective(pm.model, Min,
        sum(
            sum(
                sum( branch["construction_cost"]*var(pm, n, c, :branch_ne, i) for (i,branch) in nw_ref[:ne_branch] )
            for c in conductor_ids(pm, n))
        for (n, nw_ref) in nws(pm))
    )
end

