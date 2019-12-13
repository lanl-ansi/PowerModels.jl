# Kirchhoff's circuit laws as defined the current-voltage variable space.
# Even though the branch model is linear, the feasible set is non-convex
# in the context of constant-power loads or generators

""
function variable_branch_current(pm::AbstractIVRModel; kwargs...)
    variable_branch_current_rectangular(pm; kwargs...)
    variable_branch_series_current_rectangular(pm; kwargs...)
end

""
function variable_gen(pm::AbstractIVRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool=true, kwargs...)
    variable_gen_current_rectangular(pm, cnd=cnd, nw=nw, bounded=bounded; kwargs...)
    if bounded
        for (i,gen) in ref(pm, nw, :gen)
            constraint_gen_active_power_limits(pm, i, cnd=cnd, nw=nw)
            constraint_gen_reactive_power_limits(pm, i, cnd=cnd, nw=nw)
        end
    end
end

""
function variable_dcline(pm::AbstractIVRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool=true, kwargs...)
    variable_dcline_current_rectangular(pm, cnd=cnd, nw=nw, bounded=bounded; kwargs...)
    if bounded
        for (i,dcline) in ref(pm, nw, :dcline)
            constraint_dcline_power_limits_from(pm, i, cnd=cnd, nw=nw)
            constraint_dcline_power_limits_to(pm, i, cnd=cnd, nw=nw)
        end
    end
end

"""
Defines how current distributes over series and shunt impedances of a pi-model branch
"""
function constraint_current_from(pm::AbstractIVRModel, n::Int, c::Int, f_bus, f_idx, g_sh_fr, b_sh_fr, tr, ti, tm)
    vrfr = var(pm, n, c, :vr, f_bus)
    vifr = var(pm, n, c, :vi, f_bus)

    csrfr =  var(pm, n, c, :csr, f_idx)
    csifr =  var(pm, n, c, :csi, f_idx)

    crfr =  var(pm, n, c, :cr, f_idx)
    cifr =  var(pm, n, c, :ci, f_idx)

    JuMP.@constraint(pm.model, crfr == (tr*csrfr - ti*csifr + g_sh_fr*vrfr - b_sh_fr*vifr)/tm^2)
    JuMP.@constraint(pm.model, cifr == (tr*csifr + ti*csrfr + g_sh_fr*vifr + b_sh_fr*vrfr)/tm^2)
end

"""
Defines how current distributes over series and shunt impedances of a pi-model branch
"""
function constraint_current_to(pm::AbstractIVRModel, n::Int, c::Int, t_bus, f_idx, t_idx, g_sh_to, b_sh_to)
    vrto = var(pm, n, c, :vr, t_bus)
    vito = var(pm, n, c, :vi, t_bus)

    csrto =  -var(pm, n, c, :csr, f_idx)
    csito =  -var(pm, n, c, :csi, f_idx)

    crto =  var(pm, n, c, :cr, t_idx)
    cito =  var(pm, n, c, :ci, t_idx)

    JuMP.@constraint(pm.model, crto == csrto + g_sh_to*vrto - b_sh_to*vito)
    JuMP.@constraint(pm.model, cito == csito + g_sh_to*vito + b_sh_to*vrto)
end


"""
Defines voltage drop over a branch, linking from and to side complex voltage
"""
function constraint_voltage_drop(pm::AbstractIVRModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
    vrfr = var(pm, n, c, :vr, f_bus)
    vifr = var(pm, n, c, :vi, f_bus)

    vrto = var(pm, n, c, :vr, t_bus)
    vito = var(pm, n, c, :vi, t_bus)

    csr =  var(pm, n, c, :csr, f_idx)
    csi =  var(pm, n, c, :csi, f_idx)

    JuMP.@constraint(pm.model, vrto == (vrfr*tr + vifr*ti)/tm^2 - r*csr + x*csi)
    JuMP.@constraint(pm.model, vito == (vifr*tr - vrfr*ti)/tm^2 - r*csi - x*csr)
end

"""
Bounds the voltage angle difference between bus pairs
"""
function constraint_voltage_angle_difference(pm::AbstractIVRModel, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    vrf = var(pm, n, c, :vr, f_bus)
    vif = var(pm, n, c, :vi, f_bus)
    vrt = var(pm, n, c, :vr, t_bus)
    vit = var(pm, n, c, :vi, t_bus)
    vvr = vrf*vrt + vif*vit
    vvi = vif*vrt - vrf*vit

    JuMP.@constraint(pm.model, tan(angmin)*vvr <= vvi)
    JuMP.@constraint(pm.model, tan(angmax)*vvr >= vvi)
end

"""
Kirchhoff's current law applied to buses
`sum(cr + im*ci) = 0`
"""
function constraint_current_balance(pm::AbstractIVRModel, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs)
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)

    cr =  var(pm, n, c, :cr)
    ci =  var(pm, n, c, :ci)
    crdc = var(pm, n, c, :crdc)
    cidc = var(pm, n, c, :cidc)

    crg = var(pm, n, c, :crg)
    cig = var(pm, n, c, :cig)

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
function constraint_thermal_limit_from(pm::AbstractIVRModel, n::Int, c::Int, f_idx, rate_a)
    (l, f_bus, t_bus) = f_idx

    vr = var(pm, n, c, :vr, f_bus)
    vi = var(pm, n, c, :vi, f_bus)
    crf = var(pm, n, c, :cr, f_idx)
    cif = var(pm, n, c, :ci, f_idx)

    JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)*(crf^2 + cif^2) <= rate_a^2)
end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::AbstractIVRModel, n::Int, c::Int, t_idx, rate_a)
    (l, t_bus, f_bus) = t_idx

    vr = var(pm, n, c, :vr, t_bus)
    vi = var(pm, n, c, :vi, t_bus)
    crt = var(pm, n, c, :cr, t_idx)
    cit = var(pm, n, c, :ci, t_idx)

    JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)*(crt^2 + cit^2) <= rate_a^2)
end

"""
Bounds the current magnitude at both from and to side of a branch
`cr[f_idx]^2 + ci[f_idx]^2 <= c_rating^2`
`cr[t_idx]^2 + ci[t_idx]^2 <= c_rating^2`
"""
function constraint_current_limit(pm::AbstractIVRModel, n::Int, c::Int, f_idx, c_rating)
    (l, f_bus, t_bus) = f_idx
    t_idx = (l, t_bus, f_bus)

    crf =  var(pm, n, c, :cr, f_idx)
    cif =  var(pm, n, c, :ci, f_idx)

    crt =  var(pm, n, c, :cr, t_idx)
    cit =  var(pm, n, c, :ci, t_idx)

    JuMP.@constraint(pm.model, (crf^2 + cif^2) <= c_rating^2)
    JuMP.@constraint(pm.model, (crt^2 + cit^2) <= c_rating^2)
end

"""
`pmin <= Re(v*cg') <= pmax`
"""
function constraint_gen_active_power_limits(pm::AbstractIVRModel, n::Int, c::Int, i, bus, pmax, pmin)
    @assert pmin <= pmax

    vr = var(pm, n, c, :vr, bus)
    vi = var(pm, n, c, :vi, bus)
    cr = var(pm, n, c, :crg, i)
    ci = var(pm, n, c, :cig, i)

    JuMP.@constraint(pm.model, pmin <= vr*cr  + vi*ci)
    JuMP.@constraint(pm.model, pmax >= vr*cr  + vi*ci)
end

"""
`qmin <= Im(v*cg') <= qmax`
"""
function constraint_gen_reactive_power_limits(pm::AbstractIVRModel, n::Int, c::Int, i, bus, qmax, qmin)
    @assert qmin <= qmax

    vr = var(pm, n, c, :vr, bus)
    vi = var(pm, n, c, :vi, bus)
    cr = var(pm, n, c, :crg, i)
    ci = var(pm, n, c, :cig, i)

    JuMP.@constraint(pm.model, qmin <= vi*cr  - vr*ci)
    JuMP.@constraint(pm.model, qmax >= vi*cr  - vr*ci)
end

"`pg[i] == pg`"
function constraint_active_gen_setpoint(pm::AbstractIVRModel, n::Int, c::Int, i, pgref)
    gen = ref(pm, n, :gen, i)
    bus = gen["gen_bus"]
    vr = var(pm, n, c, :vr, bus)
    vi = var(pm, n, c, :vi, bus)
    cr = var(pm, n, c, :crg, i)
    ci = var(pm, n, c, :cig, i)

    JuMP.@constraint(pm.model, pgref == vr*cr  + vi*ci)
end

"`qq[i] == qq`"
function constraint_reactive_gen_setpoint(pm::AbstractIVRModel, n::Int, c::Int, i, qgref)
    gen = ref(pm, n, :gen, i)
    bus = gen["gen_bus"]
    vr = var(pm, n, c, :vr, bus)
    vi = var(pm, n, c, :vi, bus)
    cr = var(pm, n, c, :crg, i)
    ci = var(pm, n, c, :cig, i)

    JuMP.@constraint(pm.model, qgref == vi*cr  - vr*ci)
end

function constraint_dcline(pm::AbstractIVRModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, loss0, loss1)
    vrf = var(pm, n, c, :vr, f_bus)
    vif = var(pm, n, c, :vi, f_bus)

    vrt = var(pm, n, c, :vr, t_bus)
    vit = var(pm, n, c, :vi, t_bus)

    crdcf = var(pm, n, c, :crdc, f_idx)
    cidcf = var(pm, n, c, :cidc, f_idx)

    crdct = var(pm, n, c, :crdc, t_idx)
    cidct = var(pm, n, c, :cidc, t_idx)

    pf = vrf*crdcf + vif*cidcf
    pt = vrt*crdct + vit*cidct

    JuMP.@constraint(pm.model, pf + pt == loss0 + loss1*pf)
end

function constraint_dcline_power_limits_from(pm::AbstractIVRModel, n::Int, c::Int, i, f_bus, f_idx, pmax, pmin, qmax, qmin)
    vrf = var(pm, n, c, :vr, f_bus)
    vif = var(pm, n, c, :vi, f_bus)

    crdcf = var(pm, n, c, :crdc, f_idx)
    cidcf = var(pm, n, c, :cidc, f_idx)

    pf = vrf*crdcf + vif*cidcf
    qf = vif*crdcf - vrf*cidcf

    JuMP.@constraint(pm.model, pmax >= pf)
    JuMP.@constraint(pm.model, pmin <= pf)

    JuMP.@constraint(pm.model, qmax >= qf)
    JuMP.@constraint(pm.model, qmin <= qf)
end


function constraint_dcline_power_limits_to(pm::AbstractIVRModel, n::Int, c::Int, i, t_bus, t_idx, pmax, pmin, qmax, qmin)
    vrt = var(pm, n, c, :vr, t_bus)
    vit = var(pm, n, c, :vi, t_bus)

    crdct = var(pm, n, c, :crdc, t_idx)
    cidct = var(pm, n, c, :cidc, t_idx)

    pt = vrt*crdct + vit*cidct
    qt = vit*crdct - vrt*cidct

    JuMP.@constraint(pm.model, pmax >= pt)
    JuMP.@constraint(pm.model, pmin <= pt)

    JuMP.@constraint(pm.model, qmax >= qt)
    JuMP.@constraint(pm.model, qmin <= qt)
end

"`pf[i] == pfref, pt[i] == ptref`"
function constraint_active_dcline_setpoint(pm::AbstractIVRModel, n::Int, c::Int, f_idx, t_idx, pfref, ptref)
    (l, f_bus, t_bus) = f_idx
    vrf = var(pm, n, c, :vr, f_bus)
    vif = var(pm, n, c, :vi, f_bus)

    vrt = var(pm, n, c, :vr, t_bus)
    vit = var(pm, n, c, :vi, t_bus)

    crdcf = var(pm, n, c, :crdc, f_idx)
    cidcf = var(pm, n, c, :cidc, f_idx)

    crdct = var(pm, n, c, :crdc, t_idx)
    cidct = var(pm, n, c, :cidc, t_idx)

    JuMP.@constraint(pm.model, pfref == vrf*crdcf + vif*cidcf)
    JuMP.@constraint(pm.model, ptref == vrt*crdct + vit*cidct)
end

""
function add_setpoint_generator_current!(sol, pm::AbstractIVRModel)
    add_setpoint!(sol, pm, "gen", "crg", :crg, status_name="gen_status")
    add_setpoint!(sol, pm, "gen", "cig", :cig, status_name="gen_status")
end

""
function add_setpoint_branch_current!(sol, pm::AbstractIVRModel)
    # check the branch flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "branch_flows") && pm.setting["output"]["branch_flows"] == true
        add_setpoint!(sol, pm, "branch", "crf", :cr, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "branch", "cif", :ci, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "branch", "crt", :cr, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
        add_setpoint!(sol, pm, "branch", "cit", :ci, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
    end
end

""
function add_setpoint_dcline_current!(sol, pm::AbstractIVRModel)
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "branch_flows") && pm.setting["output"]["branch_flows"] == true
        add_setpoint!(sol, pm, "dcline", "crf", :crdc, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "dcline", "cif", :cidc, status_name="br_status", var_key = (idx,item) -> (idx, item["f_bus"], item["t_bus"]))
        add_setpoint!(sol, pm, "dcline", "crt", :crdc, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
        add_setpoint!(sol, pm, "dcline", "cit", :cidc, status_name="br_status", var_key = (idx,item) -> (idx, item["t_bus"], item["f_bus"]))
    end
end


function _objective_min_fuel_and_flow_cost_polynomial_linquad(pm::AbstractIVRModel)
    gen_cost = Dict()
    dcline_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            bus = gen["gen_bus"]

            #to avoid function calls inside of @NLconstraint:
            pg = [var(pm, n, c, :pg, i) for c in conductor_ids(pm, n)]
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
            p_dc = [var(pm, n, c, :p_dc, from_idx[i]) for c in conductor_ids(pm, n)]
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
function objective_variable_pg_cost(pm::AbstractIVRModel)
    for (n, nw_ref) in nws(pm)
        gen_lines = calc_cost_pwl_lines(nw_ref[:gen])

        #to avoid function calls inside of @NLconstraint
        pg_cost = var(pm, n)[:pg_cost] = JuMP.@variable(pm.model,
            [i in ids(pm, n, :gen)], base_name="$(n)_pg_cost",
        )
        nc = length(conductor_ids(pm, n))

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            pg = [var(pm, n, c, :pg, i) for c in conductor_ids(pm, n)]
            for line in gen_lines[i]
                JuMP.@NLconstraint(pm.model, pg_cost[i] >= line.slope*sum(pg[c] for c in 1:nc) + line.intercept)
            end
        end
    end
end


"adds p_dc_cost variables and constraints"
function objective_variable_dc_cost(pm::AbstractIVRModel)
    for (n, nw_ref) in nws(pm)
        dcline_lines = calc_cost_pwl_lines(nw_ref[:dcline])

        dc_p_cost = var(pm, n)[:p_dc_cost] = JuMP.@variable(pm.model,
            [i in ids(pm, n, :dcline)], base_name="$(n)_dc_p_cost",
        )
        #to avoid function calls inside of @NLconstraint:
        nc = length(conductor_ids(pm, n))
        # dcline pwl cost
        for (i, dcline) in nw_ref[:dcline]
            arc = (i, dcline["f_bus"], dcline["t_bus"])
            for line in dcline_lines[i]
                #to avoid function calls inside of @NLconstraint:
                p_dc = [var(pm, n, c, :p_dc, arc) for c in conductor_ids(pm, n)]
                JuMP.@NLconstraint(pm.model, dc_p_cost[i] >= line.slope*sum(p_dc[c] for c in 1:nc)  + line.intercept)
            end
        end
    end
end
