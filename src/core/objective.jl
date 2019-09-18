################################################################################
# This file is to defines commonly used constraints for power flow models
# This will hopefully make everything more compositional
################################################################################


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
function objective_min_fuel_and_flow_cost(pm::AbstractPowerModel)
    model = check_cost_models(pm)

    if model == 1
        return objective_min_fuel_and_flow_cost_pwl(pm)
    elseif model == 2
        return objective_min_fuel_and_flow_cost_polynomial(pm)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end


""
function objective_min_fuel_cost(pm::AbstractPowerModel)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_pwl(pm)
    elseif model == 2
        return objective_min_fuel_cost_polynomial(pm)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end


""
function objective_min_fuel_and_flow_cost_polynomial(pm::AbstractPowerModel)
    order = calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_fuel_and_flow_cost_polynomial_linquad(pm)
    else
        return _objective_min_fuel_and_flow_cost_polynomial_nl(pm)
    end
end

""
function _objective_min_fuel_and_flow_cost_polynomial_linquad(pm::AbstractPowerModel)
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

    return JuMP.@objective(pm.model, Min,
        sum(
            sum(    gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] ) +
            sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline] )
        for (n, nw_ref) in nws(pm))
    )
end


"Adds lifted variables to turn a quadatic objective into a linear one; needed for conic solvers that only support linear objectives"
function _objective_min_fuel_and_flow_cost_polynomial_linquad(pm::AbstractConicModels)
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

                pg_sqr = var(pm, n, :pg_sqr)[i] = JuMP.@variable(pm.model,
                    base_name="$(n)_pg_sqr_$(i)",
                    lower_bound = pg_sqr_lb,
                    upper_bound = pg_sqr_ub,
                    start = 0.0
                )
                JuMP.@constraint(pm.model, [0.5, pg_sqr, pg] in JuMP.RotatedSecondOrderCone())

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

                p_dc_sqr = var(pm, n, :p_dc_sqr)[i] = JuMP.@variable(pm.model,
                    base_name="$(n)_p_dc_sqr_$(i)",
                    lower_bound = p_dc_sqr_lb,
                    upper_bound = p_dc_sqr_ub,
                    start = 0.0
                )
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
function _objective_min_fuel_and_flow_cost_polynomial_nl(pm::AbstractPowerModel)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[2]*pg^2 + sum( v*pg^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
            else
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, 0.0)
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])

        for (i,dcline) in nw_ref[:dcline]
            p_dc = sum( var(pm, n, c, :p_dc, from_idx[i]) for c in conductor_ids(pm, n))

            cost_rev = reverse(dcline["cost"])
            if length(cost_rev) == 1
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc)
            elseif length(cost_rev) == 3
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[3]*p_dc^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*p_dc + cost_rev[2]*p_dc^2 + sum( v*p_dc^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
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
function objective_min_fuel_cost_polynomial(pm::AbstractPowerModel)
    order = calc_max_cost_index(pm.data)-1

    if order <= 2
        return _objective_min_fuel_cost_polynomial_linquad(pm)
    else
        return _objective_min_fuel_cost_polynomial_nl(pm)
    end
end

""
function _objective_min_fuel_cost_polynomial_linquad(pm::AbstractPowerModel)
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

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
        for (n, nw_ref) in nws(pm))
    )
end


""
function _objective_min_fuel_cost_polynomial_nl(pm::AbstractPowerModel)
    gen_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( var(pm, n, c, :pg, i) for c in conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2 + sum( v*pg^(d+2) for (d,v) in enumerate(cost_rev_nl)) )
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
function objective_variable_pg_cost(pm::AbstractPowerModel)
    for (n, nw_ref) in nws(pm)
        gen_lines = calc_cost_pwl_lines(nw_ref[:gen])
        pg_cost_start = Dict{Int64,Float64}()
        for (i, gen) in nw_ref[:gen]
            pg_value = sum(JuMP.start_value(var(pm, n, c, :pg, i)) for c in conductor_ids(pm, n))
            pg_cost_value = -Inf
            for line in gen_lines[i]
                pg_cost_value = max(pg_cost_value, line.slope*pg_value + line.intercept)
            end
            pg_cost_start[i] = pg_cost_value
        end

        #println(pg_cost_start)

        pg_cost = var(pm, n)[:pg_cost] = JuMP.@variable(pm.model,
            [i in ids(pm, n, :gen)], base_name="$(n)_pg_cost",
            start=pg_cost_start[i]
        )

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            for line in gen_lines[i]
                JuMP.@constraint(pm.model, pg_cost[i] >= line.slope*sum(var(pm, n, c, :pg, i) for c in conductor_ids(pm, n)) + line.intercept)
            end
        end
    end
end


"adds p_dc_cost variables and constraints"
function objective_variable_dc_cost(pm::AbstractPowerModel)
    for (n, nw_ref) in nws(pm)
        dcline_lines = calc_cost_pwl_lines(nw_ref[:dcline])
        dc_p_cost_start = Dict{Int64,Float64}()
        for (i, dcline) in nw_ref[:dcline]
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            dc_p_value = sum(JuMP.start_value(var(pm, n, c, :p_dc)[arc]) for c in conductor_ids(pm, n))
            dc_p_cost_value = -Inf
            for line in dcline_lines[i]
                dc_p_cost_value = max(dc_p_cost_value, line.slope*dc_p_value + line.intercept)
            end
            dc_p_cost_start[i] = dc_p_cost_value
        end

        dc_p_cost = var(pm, n)[:p_dc_cost] = JuMP.@variable(pm.model,
            [i in ids(pm, n, :dcline)], base_name="$(n)_dc_p_cost",
            start=dc_p_cost_start[i]
        )

        # dcline pwl cost
        for (i, dcline) in nw_ref[:dcline]
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            for line in dcline_lines[i]
                JuMP.@constraint(pm.model, dc_p_cost[i] >= line.slope*sum(var(pm, n, c, :p_dc)[arc] for c in conductor_ids(pm, n)) + line.intercept)
            end
        end
    end
end


""
function objective_min_fuel_and_flow_cost_pwl(pm::AbstractPowerModel)
    objective_variable_pg_cost(pm)
    objective_variable_dc_cost(pm)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( var(pm, n,   :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
            sum( var(pm, n, :p_dc_cost, i) for (i,dcline) in nw_ref[:dcline])
        for (n, nw_ref) in nws(pm))
    )
end


""
function objective_min_fuel_cost_pwl(pm::AbstractPowerModel)
    objective_variable_pg_cost(pm)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen])
        for (n, nw_ref) in nws(pm))
    )
end

