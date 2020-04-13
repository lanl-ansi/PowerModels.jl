################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################

# enables support for v[1]
Base.getindex(v::JuMP.VariableRef, i::Int64) = v


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


"adds pg_cost variables and constraints"
function objective_variable_pg_cost(pm::AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in nws(pm)
        pg_cost = var(pm, n)[:pg_cost] = Dict{Int,Any}()

        for (i,gen) in ref(pm, n, :gen)
            pg_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:gen["ncost"]], base_name="$(n)_pg_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(pg_cost_lambda) == 1.0)

            points = gen["cost"]

            pg_expr = 0.0
            pg_cost_expr = 0.0
            for i in 1:gen["ncost"]
                mw = points[2*i-1]
                cost = points[2*i]

                pg_expr += mw*pg_cost_lambda[i]
                pg_cost_expr += cost*pg_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, pg_expr == sum(var(pm, n, :pg, i)[c] for c in conductor_ids(pm, n)))
            pg_cost[i] = pg_cost_expr
        end

        report && _IM.sol_component_value(pm, n, :gen, :pg_cost, ids(pm, n, :gen), pg_cost)
    end
end


"adds p_dc_cost variables and constraints"
function objective_variable_dc_cost(pm::AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in nws(pm)
        p_dc_cost = var(pm, n)[:p_dc_cost] = Dict{Int,Any}()

        for (i,dcline) in ref(pm, n, :dcline)
            dc_p_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:dcline["ncost"]], base_name="$(n)_dc_p_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(dc_p_cost_lambda) == 1.0)

            points = dcline["cost"]

            dc_p_expr = 0.0
            dc_p_cost_expr = 0.0
            for i in 1:dcline["ncost"]
                mw = points[2*i-1]
                cost = points[2*i]

                dc_p_expr += mw*dc_p_cost_lambda[i]
                dc_p_cost_expr += cost*dc_p_cost_lambda[i]
            end
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            JuMP.@constraint(pm.model, dc_p_expr == sum(var(pm, n, :p_dc)[arc][c] for c in conductor_ids(pm, n)))
            p_dc_cost[i] = dc_p_cost_expr
        end

        report && _IM.sol_component_value(pm, n, :dcline, :p_dc_cost, ids(pm, n, :dcline), p_dc_cost)
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

