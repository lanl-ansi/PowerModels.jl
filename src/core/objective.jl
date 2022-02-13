################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

# enables support for v[1]
Base.getindex(v::JuMP.VariableRef, i::Int) = v


"""
Checks that all cost models are of the same type
"""
function check_cost_models(pm::AbstractPowerModel)
    gen_model = check_gen_cost_models(pm)
    dcline_model = check_dcline_cost_models(pm)

    if dcline_model == nothing
        return gen_model
    end

    if gen_model == nothing
        return dcline_model
    end

    if gen_model != dcline_model
        Memento.error(_LOGGER, "generator and dcline cost models are inconsistent, the generator model is $(gen_model) however dcline model $(dcline_model)")
    end

    return gen_model
end


"""
Checks that all generator cost models are of the same type
"""
function check_gen_cost_models(pm::AbstractPowerModel)
    model = nothing

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            if haskey(gen, "cost")
                if model == nothing
                    model = gen["model"]
                else
                    if gen["model"] != model
                        Memento.error(_LOGGER, "cost models are inconsistent, the typical model is $(model) however model $(gen["model"]) is given on generator $(i)")
                    end
                end
            else
                Memento.error(_LOGGER, "no cost given for generator $(i)")
            end
        end
    end

    return model
end


"""
Checks that all dcline cost models are of the same type
"""
function check_dcline_cost_models(pm::AbstractPowerModel)
    model = nothing

    for (n, nw_ref) in nws(pm)
        for (i,dcline) in nw_ref[:dcline]
            if haskey(dcline, "model")
                if model == nothing
                    model = dcline["model"]
                else
                    if dcline["model"] != model
                        Memento.error(_LOGGER, "cost models are inconsistent, the typical model is $(model) however model $(dcline["model"]) is given on dcline $(i)")
                    end
                end
            else
                Memento.error(_LOGGER, "no cost given for dcline $(i)")
            end
        end
    end

    return model
end


""
function objective_min_fuel_and_flow_cost(pm::AbstractPowerModel; kwargs...)
    model = check_cost_models(pm)

    if model == 1
        return objective_min_fuel_and_flow_cost_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_and_flow_cost_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end


""
function objective_min_fuel_cost(pm::AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_cost_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end


""
function objective_min_fuel_and_flow_cost_polynomial(pm::AbstractPowerModel; kwargs...)
    order = calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_fuel_and_flow_cost_polynomial_linquad(pm; kwargs...)
    else
        return _objective_min_fuel_and_flow_cost_polynomial_nl(pm; kwargs...)
    end
end

""
function _objective_min_fuel_and_flow_cost_polynomial_linquad(pm::AbstractPowerModel; report::Bool=true)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n) )

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
            p_dc = sum( var(pm, n, :p_dc, from_idx[i])[c] for c in conductor_ids(pm, n) )

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

    return JuMP.@objective(pm.model, Min,
        sum(
            sum(    gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] ) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline] )
        for (n, nw_ref) in nws(pm))
    )
end


"Adds lifted variables to turn a quadatic objective into a linear one; needed for conic solvers that only support linear objectives"
function _objective_min_fuel_and_flow_cost_polynomial_linquad(pm::AbstractConicModels, report::Bool=true)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)

        var(pm, n)[:pg_sqr] = Dict()
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n) )

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

                pg_sqr = var(pm, n, :pg_sqr)[i] = JuMP.@variable(pm.model,
                    base_name="$(n)_pg_sqr_$(i)",
                    lower_bound = pg_sqr_lb,
                    upper_bound = pg_sqr_ub,
                    start = 0.0
                )
                if report
                    sol(pm, n, :gen, i)[:pg_sqr] = pg_sqr
                end

                JuMP.@constraint(pm.model, [0.5, pg_sqr, pg] in JuMP.RotatedSecondOrderCone())

                gen_cost[(n,i)] = gen["cost"][1]*pg_sqr + gen["cost"][2]*pg + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])

        var(pm, n)[:p_dc_sqr] = Dict()
        for (i,dcline) in nw_ref[:dcline]
            p_dc = sum( var(pm, n, :p_dc, from_idx[i])[c] for c in conductor_ids(pm, n) )

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

                p_dc_sqr = var(pm, n, :p_dc_sqr)[i] = JuMP.@variable(pm.model,
                    base_name="$(n)_p_dc_sqr_$(i)",
                    lower_bound = p_dc_sqr_lb,
                    upper_bound = p_dc_sqr_ub,
                    start = 0.0
                )
                if report
                    sol(pm, n, :gen, i)[:p_dc_sqr] = p_dc_sqr
                end

                JuMP.@constraint(pm.model, [0.5, p_dc_sqr, p_dc] in JuMP.RotatedSecondOrderCone())

                dcline_cost[(n,i)] = dcline["cost"][1]*p_dc_sqr + dcline["cost"][2]*p_dc + dcline["cost"][3]
            else
                dcline_cost[(n,i)] = 0.0
            end
        end
    end

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] ) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline] )
        for (n, nw_ref) in nws(pm))
    )
end


""
function _objective_min_fuel_and_flow_cost_polynomial_nl(pm::AbstractPowerModel; report::Bool=true)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2 + sum( v*pg^(d+3) for (d,v) in enumerate(cost_rev_nl)) )
            else
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, 0.0)
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])

        for (i,dcline) in nw_ref[:dcline]
            p_dc = sum( var(pm, n, :p_dc, from_idx[i])[c] for c in conductor_ids(pm, n))

            cost_rev = reverse(dcline["cost"])
            if length(cost_rev) == 1
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc)
            elseif length(cost_rev) == 3
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[3]*p_dc^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[3]*p_dc^2 + sum( v*p_dc^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
            else
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, 0.0)
            end
        end
    end

    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen]) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline])
        for (n, nw_ref) in nws(pm))
    )
end


""
function objective_min_fuel_cost_polynomial(pm::AbstractPowerModel; kwargs...)
    order = calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_fuel_cost_polynomial_linquad(pm; kwargs...)
    else
        return _objective_min_fuel_cost_polynomial_nl(pm; kwargs...)
    end
end

""
function _objective_min_fuel_cost_polynomial_linquad(pm::AbstractPowerModel; report::Bool=true)
    gen_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n) )

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

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
        for (n, nw_ref) in nws(pm))
    )
end


""
function _objective_min_fuel_cost_polynomial_nl(pm::AbstractPowerModel; report::Bool=true)
    gen_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2 + sum( v*pg^(d+3) for (d,v) in enumerate(cost_rev_nl)) )
            else
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, 0.0)
            end
        end
    end

    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
        for (n, nw_ref) in nws(pm))
    )
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
function objective_variable_pg_cost(pm::AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in nws(pm)
        pg_cost = var(pm, n)[:pg_cost] = Dict{Int,Any}()

        for (i,gen) in ref(pm, n, :gen)
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
        end

        report && sol_component_value(pm, n, :gen, :pg_cost, ids(pm, n, :gen), pg_cost)
    end
end


"adds p_dc_cost variables and constraints"
function objective_variable_dc_cost(pm::AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in nws(pm)
        p_dc_cost = var(pm, n)[:p_dc_cost] = Dict{Int,Any}()

        for (i,dcline) in ref(pm, n, :dcline)
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            p_dc_vars = [var(pm, n, :p_dc)[arc][c] for c in conductor_ids(pm, n)]
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
        end

        report && sol_component_value(pm, n, :dcline, :p_dc_cost, ids(pm, n, :dcline), p_dc_cost)
    end
end


""
function objective_min_fuel_and_flow_cost_pwl(pm::AbstractPowerModel; kwargs...)
    objective_variable_pg_cost(pm; kwargs...)
    objective_variable_dc_cost(pm; kwargs...)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
            sum( var(pm, n, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
        for (n, nw_ref) in nws(pm))
    )
end


""
function objective_min_fuel_cost_pwl(pm::AbstractPowerModel; kwargs...)
    objective_variable_pg_cost(pm; kwargs...)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen])
        for (n, nw_ref) in nws(pm))
    )
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

