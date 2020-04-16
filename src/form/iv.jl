# Kirchhoff's circuit laws as defined the current-voltage variable space.
# Even though the branch model is linear, the feasible set is non-convex
# in the context of constant-power loads or generators

""
function variable_branch_current(pm::AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    variable_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    # store expressions in rectangular power variable space
    p = Dict()
    q = Dict()

    for (l,i,j) in ref(pm, nw, :arcs_from)
        vr_fr = var(pm, nw, :vr, i)
        vi_fr = var(pm, nw, :vi, i)
        cr_fr = var(pm, nw, :cr, (l,i,j))
        ci_fr = var(pm, nw, :ci, (l,i,j))

        vr_to = var(pm, nw, :vr, j)
        vi_to = var(pm, nw, :vi, j)
        cr_to = var(pm, nw, :cr, (l,j,i))
        ci_to = var(pm, nw, :ci, (l,j,i))
        p[(l,i,j)] = vr_fr*cr_fr  + vi_fr*ci_fr
        q[(l,i,j)] = vi_fr*cr_fr  - vr_fr*ci_fr
        p[(l,j,i)] = vr_to*cr_to  + vi_to*ci_to
        q[(l,j,i)] = vi_to*cr_to  - vr_to*ci_to
    end

    var(pm, nw)[:p] = p
    var(pm, nw)[:q] = q
    report && _IM.sol_component_value_edge(pm, nw, :branch, :pf, :pt, ref(pm, nw, :arcs_from), ref(pm, nw, :arcs_to), p)
    report && _IM.sol_component_value_edge(pm, nw, :branch, :qf, :qt, ref(pm, nw, :arcs_from), ref(pm, nw, :arcs_to), q)

    variable_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

""
function variable_gen_current(pm::AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    variable_gen_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_gen_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    # store active and reactive power expressions for use in objective + post processing
    pg = Dict()
    qg = Dict()
    for (i,gen) in ref(pm, nw, :gen)
        busid = gen["gen_bus"]
        vr = var(pm, nw, :vr, busid)
        vi = var(pm, nw, :vi, busid)
        crg = var(pm, nw, :crg, i)
        cig = var(pm, nw, :cig, i)
        pg[i] = JuMP.@NLexpression(pm.model, vr*crg  + vi*cig)
        qg[i] = JuMP.@NLexpression(pm.model, vi*crg  - vr*cig)
    end
    var(pm, nw)[:pg] = pg
    var(pm, nw)[:qg] = qg
    report && _IM.sol_component_value(pm, nw, :gen, :pg, ids(pm, nw, :gen), pg)
    report && _IM.sol_component_value(pm, nw, :gen, :qg, ids(pm, nw, :gen), qg)

    if bounded
        for (i,gen) in ref(pm, nw, :gen)
            constraint_gen_active_bounds(pm, i, nw=nw)
            constraint_gen_reactive_bounds(pm, i, nw=nw)
        end
    end
end

""
function variable_dcline_current(pm::AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    variable_dcline_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_dcline_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    # store expressions in rectangular power variable space
    p = Dict()
    q = Dict()

    for (l,i,j) in ref(pm, nw, :arcs_from_dc)
        vr_fr = var(pm, nw, :vr, i)
        vi_fr = var(pm, nw, :vi, i)
        cr_fr = var(pm, nw, :crdc, (l,i,j))
        ci_fr = var(pm, nw, :cidc, (l,i,j))

        vr_to = var(pm, nw, :vr, j)
        vi_to = var(pm, nw, :vi, j)
        cr_to = var(pm, nw, :crdc, (l,j,i))
        ci_to = var(pm, nw, :cidc, (l,j,i))

        p[(l,i,j)] = JuMP.@NLexpression(pm.model, vr_fr*cr_fr  + vi_fr*ci_fr)
        q[(l,i,j)] = JuMP.@NLexpression(pm.model, vi_fr*cr_fr  - vr_fr*ci_fr)
        p[(l,j,i)] = JuMP.@NLexpression(pm.model, vr_to*cr_to  + vi_to*ci_to)
        q[(l,j,i)] = JuMP.@NLexpression(pm.model, vi_to*cr_to  - vr_to*ci_to)
    end

    var(pm, nw)[:p_dc] = p
    var(pm, nw)[:q_dc] = q
    report && _IM.sol_component_value_edge(pm, nw, :dcline, :pf, :pt, ref(pm, nw, :arcs_from_dc), ref(pm, nw, :arcs_to_dc), p)
    report && _IM.sol_component_value_edge(pm, nw, :dcline, :qf, :qt, ref(pm, nw, :arcs_from_dc), ref(pm, nw, :arcs_to_dc), q)

    if bounded
        for (i,dcline) in ref(pm, nw, :dcline)
            constraint_dcline_power_fr_bounds(pm, i, nw=nw)
            constraint_dcline_power_to_bounds(pm, i, nw=nw)
        end
    end
end

"""
Defines how current distributes over series and shunt impedances of a pi-model branch
"""
function constraint_current_from(pm::AbstractIVRModel, n::Int, f_bus, f_idx, g_sh_fr, b_sh_fr, tr, ti, tm)
    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)

    csr_fr =  var(pm, n, :csr, f_idx[1])
    csi_fr =  var(pm, n, :csi, f_idx[1])

    cr_fr =  var(pm, n, :cr, f_idx)
    ci_fr =  var(pm, n, :ci, f_idx)

    JuMP.@constraint(pm.model, cr_fr == (tr*csr_fr - ti*csi_fr + g_sh_fr*vr_fr - b_sh_fr*vi_fr)/tm^2)
    JuMP.@constraint(pm.model, ci_fr == (tr*csi_fr + ti*csr_fr + g_sh_fr*vi_fr + b_sh_fr*vr_fr)/tm^2)
end

"""
Defines how current distributes over series and shunt impedances of a pi-model branch
"""
function constraint_current_to(pm::AbstractIVRModel, n::Int, t_bus, f_idx, t_idx, g_sh_to, b_sh_to)
    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)

    csr_to =  -var(pm, n, :csr, f_idx[1])
    csi_to =  -var(pm, n, :csi, f_idx[1])

    cr_to =  var(pm, n, :cr, t_idx)
    ci_to =  var(pm, n, :ci, t_idx)

    JuMP.@constraint(pm.model, cr_to == csr_to + g_sh_to*vr_to - b_sh_to*vi_to)
    JuMP.@constraint(pm.model, ci_to == csi_to + g_sh_to*vi_to + b_sh_to*vr_to)
end


"""
Defines voltage drop over a branch, linking from and to side complex voltage
"""
function constraint_voltage_drop(pm::AbstractIVRModel, n::Int, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)

    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)

    csr_fr =  var(pm, n, :csr, f_idx[1])
    csi_fr =  var(pm, n, :csi, f_idx[1])

    JuMP.@constraint(pm.model, vr_to == (vr_fr*tr + vi_fr*ti)/tm^2 - r*csr_fr + x*csi_fr)
    JuMP.@constraint(pm.model, vi_to == (vi_fr*tr - vr_fr*ti)/tm^2 - r*csi_fr - x*csr_fr)
end

"""
Bounds the voltage angle difference between bus pairs
"""
function constraint_voltage_angle_difference(pm::AbstractIVRModel, n::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)
    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)
    vvr = vr_fr*vr_to + vi_fr*vi_to
    vvi = vi_fr*vr_to - vr_fr*vi_to

    JuMP.@constraint(pm.model, tan(angmin)*vvr <= vvi)
    JuMP.@constraint(pm.model, tan(angmax)*vvr >= vvi)
end

"""
Kirchhoff's current law applied to buses
`sum(cr + im*ci) = 0`
"""
function constraint_current_balance(pm::AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    cr =  var(pm, n, :cr)
    ci =  var(pm, n, :ci)
    crdc = var(pm, n, :crdc)
    cidc = var(pm, n, :cidc)

    crg = var(pm, n, :crg)
    cig = var(pm, n, :cig)

    JuMP.@NLconstraint(pm.model, sum(cr[a] for a in bus_arcs)
                                + sum(crdc[d] for d in bus_arcs_dc)
                                ==
                                sum(crg[g] for g in bus_gens)
                                - (sum(pd for pd in values(bus_pd))*vr + sum(qd for qd in values(bus_qd))*vi)/(vr^2 + vi^2)
                                - sum(gs for gs in values(bus_gs))*vr + sum(bs for bs in values(bus_bs))*vi
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                + sum(cidc[d] for d in bus_arcs_dc)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - (sum(pd for pd in values(bus_pd))*vi - sum(qd for qd in values(bus_qd))*vr)/(vr^2 + vi^2)
                                - sum(gs for gs in values(bus_gs))*vi - sum(bs for bs in values(bus_bs))*vr
                                )
end

"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::AbstractIVRModel, n::Int, f_idx, rate_a)
    (l, f_bus, t_bus) = f_idx

    vr = var(pm, n, :vr, f_bus)
    vi = var(pm, n, :vi, f_bus)
    crf = var(pm, n, :cr, f_idx)
    cif = var(pm, n, :ci, f_idx)

    JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)*(crf^2 + cif^2) <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::AbstractIVRModel, n::Int, t_idx, rate_a)
    (l, t_bus, f_bus) = t_idx

    vr = var(pm, n, :vr, t_bus)
    vi = var(pm, n, :vi, t_bus)
    crt = var(pm, n, :cr, t_idx)
    cit = var(pm, n, :ci, t_idx)

    JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)*(crt^2 + cit^2) <= rate_a^2)
end

"""
Bounds the current magnitude at both from and to side of a branch
`cr[f_idx]^2 + ci[f_idx]^2 <= c_rating^2`
`cr[t_idx]^2 + ci[t_idx]^2 <= c_rating^2`
"""
function constraint_current_limit(pm::AbstractIVRModel, n::Int, f_idx, c_rating)
    (l, f_bus, t_bus) = f_idx
    t_idx = (l, t_bus, f_bus)

    crf =  var(pm, n, :cr, f_idx)
    cif =  var(pm, n, :ci, f_idx)

    crt =  var(pm, n, :cr, t_idx)
    cit =  var(pm, n, :ci, t_idx)

    JuMP.@constraint(pm.model, crf^2 + cif^2 <= c_rating^2)
    JuMP.@constraint(pm.model, crt^2 + cit^2 <= c_rating^2)
end

"""
`pmin <= Re(v*cg') <= pmax`
"""
function constraint_gen_active_bounds(pm::AbstractIVRModel, n::Int, i, bus, pmax, pmin)
    @assert pmin <= pmax

    vr = var(pm, n, :vr, bus)
    vi = var(pm, n, :vi, bus)
    cr = var(pm, n, :crg, i)
    ci = var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, pmin <= vr*cr  + vi*ci)
    JuMP.@constraint(pm.model, pmax >= vr*cr  + vi*ci)
end

"""
`qmin <= Im(v*cg') <= qmax`
"""
function constraint_gen_reactive_bounds(pm::AbstractIVRModel, n::Int, i, bus, qmax, qmin)
    @assert qmin <= qmax

    vr = var(pm, n, :vr, bus)
    vi = var(pm, n, :vi, bus)
    cr = var(pm, n, :crg, i)
    ci = var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, qmin <= vi*cr  - vr*ci)
    JuMP.@constraint(pm.model, qmax >= vi*cr  - vr*ci)
end

"`pg[i] == pg`"
function constraint_gen_setpoint_active(pm::AbstractIVRModel, n::Int, i, pgref)
    gen = ref(pm, n, :gen, i)
    bus = gen["gen_bus"]
    vr = var(pm, n, :vr, bus)
    vi = var(pm, n, :vi, bus)
    cr = var(pm, n, :crg, i)
    ci = var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, pgref == vr*cr  + vi*ci)
end

"`qq[i] == qq`"
function constraint_gen_setpoint_reactive(pm::AbstractIVRModel, n::Int, i, qgref)
    gen = ref(pm, n, :gen, i)
    bus = gen["gen_bus"]
    vr = var(pm, n, :vr, bus)
    vi = var(pm, n, :vi, bus)
    cr = var(pm, n, :crg, i)
    ci = var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, qgref == vi*cr  - vr*ci)
end

function constraint_dcline_power_losses(pm::AbstractIVRModel, n::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)

    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)

    crdc_fr = var(pm, n, :crdc, f_idx)
    cidc_fr = var(pm, n, :cidc, f_idx)

    crdc_to = var(pm, n, :crdc, t_idx)
    cidc_to = var(pm, n, :cidc, t_idx)

    p_fr = vr_fr*crdc_fr + vi_fr*cidc_fr
    p_to = vr_to*crdc_to + vi_to*cidc_to

    JuMP.@constraint(pm.model, p_fr + p_to == loss0 + loss1*p_fr)
end

"`pmin <= p_fr <= pmax, qmin <= q_fr <= qmax, `"
function constraint_dcline_power_fr_bounds(pm::AbstractIVRModel, n::Int, i, f_bus, f_idx, pmax, pmin, qmax, qmin)
    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)

    crdc_fr = var(pm, n, :crdc, f_idx)
    cidc_fr = var(pm, n, :cidc, f_idx)

    p_fr = vr_fr*crdc_fr + vi_fr*cidc_fr
    q_fr = vi_fr*crdc_fr - vr_fr*cidc_fr

    JuMP.@constraint(pm.model, pmax >= p_fr)
    JuMP.@constraint(pm.model, pmin <= p_fr)

    JuMP.@constraint(pm.model, qmax >= q_fr)
    JuMP.@constraint(pm.model, qmin <= q_fr)
end


"`pmin <= p_to <= pmax, qmin <= q_to <= qmax, `"
function constraint_dcline_power_to_bounds(pm::AbstractIVRModel, n::Int, i, t_bus, t_idx, pmax, pmin, qmax, qmin)
    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)

    crdc_to = var(pm, n, :crdc, t_idx)
    cidc_to = var(pm, n, :cidc, t_idx)

    p_to = vr_to*crdc_to + vi_to*cidc_to
    q_to = vi_to*crdc_to - vr_to*cidc_to

    JuMP.@constraint(pm.model, pmax >= p_to)
    JuMP.@constraint(pm.model, pmin <= p_to)

    JuMP.@constraint(pm.model, qmax >= q_to)
    JuMP.@constraint(pm.model, qmin <= q_to)
end

"`p_fr[i] == pref_fr, p_to[i] == pref_to`"
function constraint_dcline_setpoint_active(pm::AbstractIVRModel, n::Int, f_idx, t_idx, pref_fr, pref_to)
    (l, f_bus, t_bus) = f_idx
    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)

    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)

    crdc_fr = var(pm, n, :crdc, f_idx)
    cidc_fr = var(pm, n, :cidc, f_idx)

    crdc_to = var(pm, n, :crdc, t_idx)
    cidc_to = var(pm, n, :cidc, t_idx)

    JuMP.@constraint(pm.model, pref_fr == vr_fr*crdc_fr + vi_fr*cidc_fr)
    JuMP.@constraint(pm.model, pref_to == vr_to*crdc_to + vi_to*cidc_to)
end


function _objective_min_fuel_and_flow_cost_polynomial_linquad(pm::AbstractIVRModel; report::Bool=true)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            bus = gen["gen_bus"]

            #to avoid function calls inside of @NLconstraint:
            pg = [var(pm, n, :pg, i) for c in conductor_ids(pm, n)]
            nc = length(conductor_ids(pm, n))
            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, gen["cost"][1]*sum(pg[c] for c in 1:nc) + gen["cost"][2])
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, gen["cost"][1]*sum(pg[c] for c in 1:nc)^2 + gen["cost"][2]*sum(pg[c] for c in 1:nc) + gen["cost"][3])
            else
                gen_cost[(n,i)] = 0.0
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])
        for (i,dcline) in nw_ref[:dcline]
            bus = dcline["f_bus"]
            #to avoid function calls inside of @NLconstraint:
            p_dc = [var(pm, n, :p_dc, from_idx[i]) for c in conductor_ids(pm, n)]
            nc = length(conductor_ids(pm, n))

            if length(dcline["cost"]) == 1
                dcline_cost[(n,i)] = dcline["cost"][1]
            elseif length(dcline["cost"]) == 2
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, dcline["cost"][1]*sum(p_dc[c] for c in 1:nc) + dcline["cost"][2])
            elseif length(dcline["cost"]) == 3
                dcline_cost[(n,i)]  = JuMP.@NLexpression(pm.model, dcline["cost"][1]*sum(p_dc[c] for c in 1:nc)^2 + dcline["cost"][2]*sum(p_dc[c] for c in 1:nc) + dcline["cost"][3])
            else
                dcline_cost[(n,i)] = 0.0
            end
        end
    end

    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum(    gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
            + sum( dcline_cost[(n,i)] for (i,dcline) in nw_ref[:dcline] )
        for (n, nw_ref) in nws(pm))
    )
end


"adds pg_cost variables and constraints"
function objective_variable_pg_cost(pm::AbstractIVRModel; report::Bool=true)
    for (n, nw_ref) in nws(pm)
        gen_lines = calc_cost_pwl_lines(nw_ref[:gen])

        #to avoid function calls inside of @NLconstraint
        pg_cost = var(pm, n)[:pg_cost] = JuMP.@variable(pm.model,
            [i in ids(pm, n, :gen)], base_name="$(n)_pg_cost",
        )
        report && _IM.sol_component_value(pm, n, :gen, :pg_cost, ids(pm, n, :gen), pg_cost)

        nc = length(conductor_ids(pm, n))

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            pg = [var(pm, n, :pg, i) for c in conductor_ids(pm, n)]
            for line in gen_lines[i]
                JuMP.@NLconstraint(pm.model, pg_cost[i] >= line.slope*sum(pg[c] for c in 1:nc) + line.intercept)
            end
        end
    end
end


"adds p_dc_cost variables and constraints"
function objective_variable_dc_cost(pm::AbstractIVRModel; report::Bool=true)
    for (n, nw_ref) in nws(pm)
        dcline_lines = calc_cost_pwl_lines(nw_ref[:dcline])

        dc_p_cost = var(pm, n)[:p_dc_cost] = JuMP.@variable(pm.model,
            [i in ids(pm, n, :dcline)], base_name="$(n)_dc_p_cost",
        )
        report && _IM.sol_component_value(pm, n, :dcline, :p_dc_cost, ids(pm, n, :dcline), dc_p_cost)

        #to avoid function calls inside of @NLconstraint:
        nc = length(conductor_ids(pm, n))
        # dcline pwl cost
        for (i, dcline) in nw_ref[:dcline]
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            for line in dcline_lines[i]
                #to avoid function calls inside of @NLconstraint:
                p_dc = [var(pm, n, :p_dc, arc) for c in conductor_ids(pm, n)]
                JuMP.@NLconstraint(pm.model, dc_p_cost[i] >= line.slope*sum(p_dc[c] for c in 1:nc)  + line.intercept)
            end
        end
    end
end
