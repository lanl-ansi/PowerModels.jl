""
function objective_min_fuel_and_flow_cost(pm::AbstractPowerModel; kwargs...)
    expression_pg_cost(pm; kwargs...)
    expression_p_dc_cost(pm; kwargs...)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
            sum( var(pm, n, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
        for (n, nw_ref) in nws(pm))
    )
end


""
function objective_min_fuel_cost(pm::AbstractPowerModel; kwargs...)
    expression_pg_cost(pm; kwargs...)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen])
        for (n, nw_ref) in nws(pm))
    )
end


"""
cleans up raw pwl cost points in preparation for building a mathamatical model.

The key mathematical properties,
- the first and last points are strictly outside of the pmin-to-pmax range
- pmin and pmax occur in the first and last line segments.
"""
function calc_pwl_points(ncost::Int, cost::Vector{<:Real}, pmin::Real, pmax::Real; tolerance=1e-2)
    @assert ncost >= 1 && length(cost) >= 2
    @assert 2*ncost == length(cost)
    @assert pmin <= pmax

    if isinf(pmin) || isinf(pmax)
        Memento.error(_LOGGER, "a bounded operating range is required for modeling pwl costs.  Given active power range in $(pmin) - $(pmax)")
    end

    points = []
    for i in 1:ncost
        push!(points, (mw=cost[2*i-1], cost=cost[2*i]))
    end

    first_active = 0
    for i in 1:(ncost-1)
        #mw_0 = points[i].mw
        mw_1 = points[i+1].mw
        first_active = i
        if pmin <= mw_1
            break
        end
    end

    last_active = 0
    for i in 1:(ncost-1)
        mw_0 = points[end - i].mw
        #mw_1 = points[end - i + 1].mw
        last_active = ncost - i + 1
        if pmax >= mw_0
            break
        end
    end

    points = points[first_active : last_active]


    x1 = points[1].mw
    y1 = points[1].cost
    x2 = points[2].mw
    y2 = points[2].cost

    if x1 > pmin
        x0 = pmin - tolerance

        m = (y2 - y1)/(x2 - x1)

        if !isnan(m)
            y0 = y2 - m*(x2 - x0)
            points[1] = (mw=x0, cost=y0)
        else
            points[1] = (mw=x0, cost=y1)
        end

        modified = true
    end


    x1 = points[end-1].mw
    y1 = points[end-1].cost
    x2 = points[end].mw
    y2 = points[end].cost

    if x2 < pmax
        x3 = pmax + tolerance

        m = (y2 - y1)/(x2 - x1)

        if !isnan(m)
            y3 = m*(x3 - x1) + y1

            points[end] = (mw=x3, cost=y3)
        else
            points[end] = (mw=x3, cost=y2)
        end
    end

    return points
end



"adds pg_cost variables and constraints"
function expression_pg_cost(pm::AbstractPowerModel; report::Bool=true)
    for (n, nw_ref) in nws(pm)
        pg_cost = var(pm, n)[:pg_cost] = Dict{Int,Any}()

        for (i,gen) in ref(pm, n, :gen)
            pg_terms = [var(pm, n, :pg, i)]

            if gen["model"] == 1
                if isa(pg_terms, Array{JuMP.VariableRef})
                    pmin = sum(JuMP.lower_bound.(pg_terms))
                    pmax = sum(JuMP.upper_bound.(pg_terms))
                else
                    pmin = gen["pmin"]
                    pmax = gen["pmax"]
                end

                points = calc_pwl_points(gen["ncost"], gen["cost"], pmin, pmax)
                pg_cost[i] = _pwl_cost_expression(pm, pg_terms, points, nw=n, id=i, var_name="pg")

            elseif gen["model"] == 2
                cost_rev = reverse(gen["cost"])

                pg_cost[i] = _polynomial_cost_expression(pm, pg_terms, cost_rev, nw=n, id=i, var_name="pg")
            else
                Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model) on generator $(i)")
            end
        end

        report && sol_component_value(pm, n, :gen, :pg_cost, ids(pm, n, :gen), pg_cost)
    end
end


"adds p_dc_cost variables and constraints"
function expression_p_dc_cost(pm::AbstractPowerModel; report::Bool=true)
    for (n, nw_ref) in nws(pm)
        p_dc_cost = var(pm, n)[:p_dc_cost] = Dict{Int,Any}()

        for (i,dcline) in ref(pm, n, :dcline)
            arc = (i, dcline["f_bus"], dcline["t_bus"])

            p_dc_terms = [var(pm, n, :p_dc, arc)]

            if dcline["model"] == 1
                if isa(p_dc_terms, Array{JuMP.VariableRef})
                    pmin = sum(JuMP.lower_bound.(p_dc_terms))
                    pmax = sum(JuMP.upper_bound.(p_dc_terms))
                else
                    pmin = dcline["pminf"]
                    pmax = dcline["pmaxf"]
                end

                # note pmin/pmax may be different from dcline["pminf"]/dcline["pmaxf"] in the on/off case
                points = calc_pwl_points(dcline["ncost"], dcline["cost"], pmin, pmax)
                p_dc_cost[i] = _pwl_cost_expression(pm, p_dc_terms, points, nw=n, id=i, var_name="dc_p")

            elseif dcline["model"] == 2
                cost_rev = reverse(dcline["cost"])
                p_dc_cost[i] = _polynomial_cost_expression(pm, p_dc_terms, cost_rev, nw=n, id=i, var_name="dc_p")
            else
                Memento.error(_LOGGER, "only cost models of types 1 and 2 are supported at this time, given cost model type of $(model) on dcline $(i)")
            end
        end

        report && sol_component_value(pm, n, :dcline, :p_dc_cost, ids(pm, n, :dcline), p_dc_cost)
    end
end


function _pwl_cost_expression(pm::AbstractPowerModel, x_list::Array{JuMP.VariableRef}, points; nw=0, id=1, var_name="x")
    cost_lambda = JuMP.@variable(pm.model,
        [i in 1:length(points)], base_name="$(nw)_$(var_name)_cost_lambda_$(id)",
        lower_bound = 0.0,
        upper_bound = 1.0
    )
    JuMP.@constraint(pm.model, sum(cost_lambda) == 1.0)

    expr = 0.0
    cost_expr = 0.0
    for (i,point) in enumerate(points)
        expr += point.mw*cost_lambda[i]
        cost_expr += point.cost*cost_lambda[i]
    end
    JuMP.@constraint(pm.model, expr == sum(x_list))

    return cost_expr
end

function _pwl_cost_expression(pm::AbstractPowerModel, x_list, points; nw=0, id=1, var_name="x")
    cost_lambda = JuMP.@variable(pm.model,
        [i in 1:length(points)], base_name="$(nw)_$(var_name)_cost_lambda_$(id)",
        lower_bound = 0.0,
        upper_bound = 1.0
    )
    JuMP.@constraint(pm.model, sum(cost_lambda) == 1.0)

    expr = 0.0
    cost_expr = 0.0
    for (i,point) in enumerate(points)
        expr += point.mw*cost_lambda[i]
        cost_expr += point.cost*cost_lambda[i]
    end
    JuMP.@constraint(pm.model, expr == sum(x for x in x_list))

    return cost_expr
end



# note that `cost_terms` should be providing in ascending order (the reverse of the Matpower spec.)
function _polynomial_cost_expression(pm::AbstractPowerModel, x_list::Array{JuMP.VariableRef}, cost_terms; nw=0, id=1, var_name="x")
    x = sum(x_list)
    if length(cost_terms) == 0
        return 0.0
    elseif length(cost_terms) == 1
        return cost_terms[1]
    elseif length(cost_terms) == 2
        return cost_terms[1] + cost_terms[2]*x
    elseif length(cost_terms) == 3
        return cost_terms[1] + cost_terms[2]*x + cost_terms[3]*x^2
    else # length(cost_terms) >= 4
        cost_nl = cost_terms[4:end]
        return JuMP.@expression(pm.model, cost_terms[1] + cost_terms[2]*x + cost_terms[3]*x^2 + sum( v*x^(d+2) for (d,v) in enumerate(cost_nl)) )
    end
end

# note that `cost_terms` should be providing in ascending order (the reverse of the Matpower spec.)
function _polynomial_cost_expression(pm::AbstractConicModels, x_list::Array{JuMP.VariableRef}, cost_terms; nw=0, id=1, var_name="x")
    x = sum(x_list)
    if length(cost_terms) == 0
        return 0.0
    elseif length(cost_terms) == 1
        return cost_terms[1]
    elseif length(cost_terms) == 2
        return cost_terms[1] + cost_terms[2]*x
    elseif length(cost_terms) == 3
        x_lb = sum(JuMP.lower_bound.(x_list))
        x_ub = sum(JuMP.upper_bound.(x_list))

        x_sqr_lb = 0.0
        x_sqr_ub = max(x_lb^2, x_ub^2)
        if x_lb > 0.0
            x_sqr_lb = x_lb^2
        end
        if x_ub < 0.0
            x_sqr_lb = x_ub^2
        end

        x_sqr = JuMP.@variable(pm.model,
            base_name="$(nw)_$(var_name)_sqr_$(id)",
            lower_bound = x_sqr_lb,
            upper_bound = x_sqr_ub,
            start = 0.0
        )
        JuMP.@constraint(pm.model, [0.5, x_sqr, x] in JuMP.RotatedSecondOrderCone())

        return cost_terms[1] + cost_terms[2]*x + cost_terms[3]*x_sqr
    else # length(cost_terms) >= 4
        Memento.error(_LOGGER, "the network cost data features a polynomial cost function that is not compatible with conic mathematical programs.")
    end
end

# note that `cost_terms` should be providing in ascending order (the reverse of the Matpower spec.)
function _polynomial_cost_expression(pm::AbstractPowerModel, x_list, cost_terms; nw=0, id=1, var_name="x")
    x = JuMP.@expression(pm.model, sum(x for x in x_list))
    if length(cost_terms) == 0
        return 0.0
    elseif length(cost_terms) == 1
        return cost_terms[1]
    elseif length(cost_terms) == 2
        return JuMP.@expression(pm.model, cost_terms[1] + cost_terms[2]*x)
    elseif length(cost_terms) == 3
        return JuMP.@expression(pm.model, cost_terms[1] + cost_terms[2]*x + cost_terms[3]*x^2)
    else # length(cost_terms) >= 4
        cost_nl = cost_terms[4:end]
        return JuMP.@expression(pm.model, cost_terms[1] + cost_terms[2]*x + cost_terms[3]*x^2 + sum( v*x^(d+2) for (d,v) in enumerate(cost_nl)) )
    end
end






function objective_max_loadability(pm::AbstractPowerModel)
    nws = nw_ids(pm)

    z_demand = Dict(n => var(pm, n, :z_demand) for n in nws)
    z_shunt = Dict(n => var(pm, n, :z_shunt) for n in nws)
    time_elapsed = Dict(n => get(ref(pm, n), :time_elapsed, 1) for n in nws)

    load_weight = Dict(n =>
        Dict(i => get(load, "weight", 1.0) for (i,load) in ref(pm, n, :load)) 
    for n in nws)

    #println(load_weight)

    return JuMP.@objective(pm.model, Max,
        sum( 
            ( 
            time_elapsed[n]*(
                sum(z_shunt[n][i] for (i,shunt) in ref(pm, n, :shunt)) +
                sum(load_weight[n][i]*abs(load["pd"])*z_demand[n][i] for (i,load) in ref(pm, n, :load))
                )
            )
            for n in nws)
        )
end

