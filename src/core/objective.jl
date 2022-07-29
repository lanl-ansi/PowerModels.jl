# enables support for v[1]
Base.getindex(v::JuMP.VariableRef, i::Int) = v

"""
Checks if any generator cost model will require a JuMP nonlinear expression
"""
function check_nl_gen_cost_models(pm::AbstractPowerModel)
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            if haskey(gen, "cost")
                if gen["model"] == 2 && length(gen["cost"]) > 3
                    return true
                end
            end
        end
    end
    return false
end

"""
Checks if any dcline cost model will require a JuMP nonlinear expression
"""
function check_nl_dcline_cost_models(pm::AbstractPowerModel)
    for (n, nw_ref) in nws(pm)
        for (i,dcline) in nw_ref[:dcline]
            if haskey(dcline, "cost")
                if dcline["model"] == 2 && length(dcline["cost"]) > 3
                    return true
                end
            end
        end
    end
    return false
end


""
function objective_min_fuel_and_flow_cost(pm::AbstractPowerModel; kwargs...)
    nl_gen = check_nl_gen_cost_models(pm)
    nl_dc = check_nl_dcline_cost_models(pm)

    nl = nl_gen || nl_dc

    expression_pg_cost(pm; nonlinear=nl, kwargs...)
    expression_p_dc_cost(pm; nonlinear=nl, kwargs...)

    if !nl
        return JuMP.@objective(pm.model, Min,
            sum(
                sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
                sum( var(pm, n, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
            for (n, nw_ref) in nws(pm))
        )
    else
        return JuMP.@NLobjective(pm.model, Min,
            sum(
                sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
                sum( var(pm, n, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
            for (n, nw_ref) in nws(pm))
        )
    end
end


""
function objective_min_fuel_cost(pm::AbstractPowerModel; kwargs...)
    nl = check_nl_gen_cost_models(pm)

    expression_pg_cost(pm; nonlinear=nl, kwargs...)

    if !nl
        return JuMP.@objective(pm.model, Min,
            sum(
                sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen])
            for (n, nw_ref) in nws(pm))
        )
    else
        return JuMP.@NLobjective(pm.model, Min,
            sum(
                sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen])
            for (n, nw_ref) in nws(pm))
        )
    end
end


"""
cleans up raw pwl cost points in preparation for building a mathamatical model.

The key mathematical properties,
- the first and last points are strickly outside of the pmin-to-pmax range
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
function expression_pg_cost(pm::AbstractPowerModel; nonlinear::Bool=false, report::Bool=true)
    for (n, nw_ref) in nws(pm)
        pg_cost = var(pm, n)[:pg_cost] = Dict{Int,Any}()

        for (i,gen) in ref(pm, n, :gen)
            if gen["model"] == 1
                pg_vars = [var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n)]
                pmin = sum(JuMP.lower_bound.(pg_vars))
                pmax = sum(JuMP.upper_bound.(pg_vars))

                # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
                points = calc_pwl_points(gen["ncost"], gen["cost"], pmin, pmax)

                pg_cost_lambda = JuMP.@variable(pm.model,
                    [i in 1:length(points)], base_name="$(n)_pg_cost_lambda",
                    lower_bound = 0.0,
                    upper_bound = 1.0
                )
                JuMP.@constraint(pm.model, sum(pg_cost_lambda) == 1.0)

                pg_expr = 0.0
                pg_cost_expr = 0.0
                for (i,point) in enumerate(points)
                    pg_expr += point.mw*pg_cost_lambda[i]
                    pg_cost_expr += point.cost*pg_cost_lambda[i]
                end
                JuMP.@constraint(pm.model, pg_expr == sum(pg_vars))
                pg_cost[i] = pg_cost_expr

            elseif gen["model"] == 2
                pg = sum( var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n))

                cost_rev = reverse(gen["cost"])
                if length(cost_rev) == 0
                    pg_cost[i] = 0.0
                elseif length(cost_rev) == 1
                    pg_cost[i] = cost_rev[1]
                elseif length(cost_rev) == 2
                    pg_cost[i] = cost_rev[1] + cost_rev[2]*pg
                elseif length(cost_rev) == 3
                    pg_cost[i] = cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2
                else # length(cost_rev) >= 4
                    cost_rev_nl = cost_rev[4:end]
                    pg_cost[i] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2 + sum( v*pg^(d+3) for (d,v) in enumerate(cost_rev_nl)) )
                end
            else
                Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model) on generator $(i)")
            end
        end

        report && sol_component_value(pm, n, :gen, :pg_cost, ids(pm, n, :gen), pg_cost)
    end
end


"adds p_dc_cost variables and constraints"
function expression_p_dc_cost(pm::AbstractPowerModel; nonlinear::Bool=false, report::Bool=true)
    for (n, nw_ref) in nws(pm)
        p_dc_cost = var(pm, n)[:p_dc_cost] = Dict{Int,Any}()

        for (i,dcline) in ref(pm, n, :dcline)
            arc = (i, dcline["f_bus"], dcline["t_bus"])

            if dcline["model"] == 1
                p_dc_vars = [var(pm, n, :p_dc, arc)[c] for c in conductor_ids(pm, n)]
                pmin = sum(JuMP.lower_bound.(p_dc_vars))
                pmax = sum(JuMP.upper_bound.(p_dc_vars))

                # note pmin/pmax may be different from dcline["pminf"]/dcline["pmaxf"] in the on/off case
                points = calc_pwl_points(dcline["ncost"], dcline["cost"], pmin, pmax)

                dc_p_cost_lambda = JuMP.@variable(pm.model,
                    [i in 1:length(points)], base_name="$(n)_dc_p_cost_lambda",
                    lower_bound = 0.0,
                    upper_bound = 1.0
                )
                JuMP.@constraint(pm.model, sum(dc_p_cost_lambda) == 1.0)

                dc_p_expr = 0.0
                dc_p_cost_expr = 0.0
                for (i,point) in enumerate(points)
                    dc_p_expr += point.mw*dc_p_cost_lambda[i]
                    dc_p_cost_expr += point.cost*dc_p_cost_lambda[i]
                end

                JuMP.@constraint(pm.model, dc_p_expr == sum(p_dc_vars))
                p_dc_cost[i] = dc_p_cost_expr

            elseif dcline["model"] == 2
                p_dc = sum( var(pm, n, :p_dc, arc) for c in conductor_ids(pm, n))

                cost_rev = reverse(dcline["cost"])
                if length(cost_rev) == 0
                    p_dc_cost[i] = 0.0
                elseif length(cost_rev) == 1
                    p_dc_cost[i] = cost_rev[1]
                elseif length(cost_rev) == 2
                    p_dc_cost[i] = cost_rev[1] + cost_rev[2]*p_dc
                elseif length(cost_rev) == 3
                    p_dc_cost[i] = cost_rev[1] + cost_rev[2]*p_dc + cost_rev[3]*p_dc^2
                else # length(cost_rev) >= 4
                    cost_rev_nl = cost_rev[4:end]
                    p_dc_cost[i] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[3]*p_dc^2 + sum( v*p_dc^(d+3) for (d,v) in enumerate(cost_rev_nl)) )
                end
            else
                Memento.error(_LOGGER, "only cost models of types 1 and 2 are supported at this time, given cost model type of $(model) on dcline $(i)")
            end
        end

        report && sol_component_value(pm, n, :dcline, :p_dc_cost, ids(pm, n, :dcline), p_dc_cost)
    end
end



function objective_max_loadability(pm::AbstractPowerModel)
    nws = nw_ids(pm)

    @assert all(!ismulticonductor(pm, n) for n in nws)

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

