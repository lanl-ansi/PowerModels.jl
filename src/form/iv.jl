""
function variable_voltage(pm::AbstractIVRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool=true, kwargs...)
    variable_voltage_real(pm; nw=nw, cnd=cnd, bounded=bounded, kwargs...)
    variable_voltage_imaginary(pm; nw=nw, cnd=cnd, bounded=bounded, kwargs...)
end
""
function variable_current(pm::AbstractIVRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    branch = ref(pm, nw, :branch)
    bus = ref(pm, nw, :bus)

    if bounded
        ub = Dict()
            for (l,i,j) in ref(pm, nw, :arcs_from)
            b = branch[l]
            rate = b["rate_a"][cnd]*b["tap"][cnd]
            yfr = abs(b["g_fr"][cnd] + im*b["b_fr"][cnd])
            yto = abs(b["g_to"][cnd] + im*b["b_to"][cnd])
            shuntcurrent = max(yfr*bus[i]["vmax"][cnd]^2, yto*bus[j]["vmax"][cnd]^2)
            seriescurrent = max(rate/bus[i]["vmin"][cnd], rate/bus[j]["vmin"][cnd])
            ub[l] = seriescurrent + shuntcurrent
        end

        var(pm, nw, cnd)[:csr] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_$(cnd)_csr",
            lower_bound = -ub[l],
            upper_bound = ub[l],
            start = comp_start_value(branch[l], "csr_start", cnd, 0.0)
        )
        var(pm, nw, cnd)[:csi] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_$(cnd)_csi",
            lower_bound = -ub[l],
            upper_bound = ub[l],
            start = comp_start_value(branch[l], "csi_start", cnd, 0.0)
        )
    else
        var(pm, nw, cnd)[:csr] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_$(cnd)_csr",
            start = comp_start_value(branch[l], "csr_start", cnd, 0.0)
        )
        var(pm, nw, cnd)[:csi] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_$(cnd)_csi",
            start = comp_start_value(branch[l], "csi_start", cnd, 0.0)
        )
    end
    #
    # if bounded
    #     var(pm, nw, cnd)[:cr] = JuMP.@variable(pm.model,
    #         [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_cr",
    #         lower_bound = -ub[l],
    #         upper_bound = ub[l],
    #         start = comp_start_value(ref(pm, nw, :branch, l), "cr_start", cnd)
    #     )
    #     var(pm, nw, cnd)[:ci] = JuMP.@variable(pm.model,
    #         [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_ci",
    #         lower_bound = -ub[l],
    #         upper_bound = ub[l],
    #         start = comp_start_value(ref(pm, nw, :branch, l), "ci_start", cnd)
    #     )
    #
    # else
    #     var(pm, nw, cnd)[:cr] = JuMP.@variable(pm.model,
    #         [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_cr",
    #         start = comp_start_value(ref(pm, nw, :branch, l), "cr_start", cnd)
    #     )
    #     var(pm, nw, cnd)[:ci] = JuMP.@variable(pm.model,
    #         [(l,i,j) in ref(pm, nw, :arcs)], base_name="$(nw)_$(cnd)_ci",
    #         start = comp_start_value(ref(pm, nw, :branch, l), "ci_start", cnd)
    #     )
    # end

    #Store total current variables as linear expressions
    cr = Dict()
    ci = Dict()
    for (l,i,j) in ref(pm, nw, :arcs_from)
        vrfr = var(pm, nw, cnd, :vr, i)
        vifr = var(pm, nw, cnd, :vi, i)

        csrfr =  var(pm, nw, cnd, :csr, (l,i,j))
        csifr =  var(pm, nw, cnd, :csi, (l,i,j))

        vrto = var(pm, nw, cnd, :vr, j)
        vito = var(pm, nw, cnd, :vi, j)

        csrto =  -var(pm, nw, cnd, :csr, (l,i,j))
        csito =  -var(pm, nw, cnd, :csi, (l,i,j))

        tr, ti = calc_branch_t(branch[l])
        g_sh_fr = branch[l]["g_fr"][cnd]
        b_sh_fr = branch[l]["b_fr"][cnd]
        g_sh_to = branch[l]["g_to"][cnd]
        b_sh_to = branch[l]["b_to"][cnd]
        tm = branch[l]["tap"][cnd]

        #expressions that define KCL
        cr[(l,i,j)] = (tr*csrfr - ti*csifr + g_sh_fr*vrfr - b_sh_fr*vifr)/tm^2
        ci[(l,i,j)] = (tr*csifr + ti*csrfr + g_sh_fr*vifr + b_sh_fr*vrfr)/tm^2
        cr[(l,j,i)] = csrto + g_sh_to*vrto - b_sh_to*vito
        ci[(l,j,i)] = csito + g_sh_to*vito + b_sh_to*vrto
    end
    var(pm, nw, cnd)[:cr] = cr
    var(pm, nw, cnd)[:ci] = ci
end


"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint(pm::AbstractIVRModel, n::Int, c::Int, i, vm)
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)

    JuMP.@constraint(pm.model, (vr^2 + vi^2) == vm^2)
end

"`vmin <= vm[i] <= vmax`"
function constraint_voltage_magnitude(pm::AbstractIVRModel, n::Int, c::Int, i, vmin, vmax)
    @assert vmin <= vmax
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)

    JuMP.@constraint(pm.model, vmin^2 <= (vr^2 + vi^2))
    JuMP.@constraint(pm.model, vmax^2 >= (vr^2 + vi^2))
end

function constraint_voltage_magnitude(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    bus = ref(pm, nw, :bus, i)
    constraint_voltage_magnitude(pm, nw, cnd, i, bus["vmin"], bus["vmax"])
end


"reference bus angle constraint"
function constraint_theta_ref(pm::AbstractIVRModel, n::Int, c::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, c, :vi)[i] == 0)
end

# ""
# function constraint_current_from(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
#     branch = ref(pm, nw, :branch, i)
#     f_bus = branch["f_bus"]
#     t_bus = branch["t_bus"]
#     f_idx = (i, f_bus, t_bus)
#
#     tr, ti = calc_branch_t(branch)
#     g_fr = branch["g_fr"][cnd]
#     b_fr = branch["b_fr"][cnd]
#     tm = branch["tap"][cnd]
#
#     constraint_current_from(pm, nw, cnd, f_bus, f_idx, g_fr, b_fr, tr[cnd], ti[cnd], tm)
# end
#
#
# ""
# function constraint_current_to(pm::GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
#     branch = ref(pm, nw, :branch, i)
#     f_bus = branch["f_bus"]
#     t_bus = branch["t_bus"]
#     f_idx = (i, f_bus, t_bus)
#     t_idx = (i, t_bus, f_bus)
#
#     tr, ti = calc_branch_t(branch)
#     g_to = branch["g_to"][cnd]
#     b_to = branch["b_to"][cnd]
#     tm = branch["tap"][cnd]
#
#     constraint_current_to(pm, nw, cnd, t_bus, f_idx, t_idx, g_to, b_to)
# end


""
function constraint_voltage_difference(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tr, ti = calc_branch_t(branch)
    r = branch["br_r"][cnd]
    x = branch["br_x"][cnd]
    tm = branch["tap"][cnd]

    constraint_voltage_difference(pm, nw, cnd, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
end



# """
# Defines branch flow model power flow equations
# """
# function constraint_current_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, f_idx, g_sh_fr, b_sh_fr, tr, ti, tm) where T <: IVRForm
#     vrfr = var(pm, n, c, :vr, f_bus)
#     vifr = var(pm, n, c, :vi, f_bus)
#
#     csrfr =  var(pm, n, c, :csr, f_idx)
#     csifr =  var(pm, n, c, :csi, f_idx)
#
#     crfr =  var(pm, n, c, :cr, f_idx)
#     cifr =  var(pm, n, c, :ci, f_idx)
#
#     JuMP.@constraint(pm.model, crfr == (tr*csrfr - ti*csifr + g_sh_fr*vrfr - b_sh_fr*vifr)/tm^2)
#     JuMP.@constraint(pm.model, cifr == (tr*csifr + ti*csrfr + g_sh_fr*vifr + b_sh_fr*vrfr)/tm^2)
#
# end
#
# """
# Defines branch flow model power flow equations
# """
# function constraint_current_to(pm::GenericPowerModel{T}, n::Int, c::Int, t_bus, f_idx, t_idx, g_sh_to, b_sh_to) where T <: IVRForm
#     vrto = var(pm, n, c, :vr, t_bus)
#     vito = var(pm, n, c, :vi, t_bus)
#
#     csrto =  -var(pm, n, c, :csr, f_idx)
#     csito =  -var(pm, n, c, :csi, f_idx)
#
#     crto =  var(pm, n, c, :cr, t_idx)
#     cito =  var(pm, n, c, :ci, t_idx)
#
#     JuMP.@constraint(pm.model, crto == csrto + g_sh_to*vrto - b_sh_to*vito)
#     JuMP.@constraint(pm.model, cito == csito + g_sh_to*vito + b_sh_to*vrto)
# end


"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_voltage_difference(pm::AbstractIVRModel, n::Int, c::Int, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
    vrfr = var(pm, n, c, :vr, f_bus)
    vifr = var(pm, n, c, :vi, f_bus)

    vrto = var(pm, n, c, :vr, t_bus)
    vito = var(pm, n, c, :vi, t_bus)

    csr =  var(pm, n, c, :csr, f_idx)
    csi =  var(pm, n, c, :csi, f_idx)

    JuMP.@constraint(pm.model, vrto == (vrfr*tr + vifr*ti)/tm^2 - r*csr + x*csi)
    JuMP.@constraint(pm.model, vito == (vifr*tr - vrfr*ti)/tm^2 - r*csi - x*csr)
end



function constraint_voltage_angle_difference(pm::AbstractIVRModel, n::Int, c::Int, f_idx,  angmin, angmax)
    i, f_bus, t_bus = f_idx
    t_idx = (i, t_bus, f_bus)


    vrf = var(pm, n, c, :vr, f_bus)
    vif = var(pm, n, c, :vi, f_bus)
    vrt = var(pm, n, c, :vr, t_bus)
    vit = var(pm, n, c, :vi, t_bus)
    vvr = vrf*vrt + vif*vit
    vvi = vif*vrt - vrf*vit
    #TODO are angle limits applied to Pi section part only?
    JuMP.@constraint(pm.model,
        tan(angmin)*vvr <= vvi
        )
    JuMP.@constraint(pm.model,
        tan(angmax)*vvr >= vvi
        )
end

function constraint_current_balance(pm::AbstractIVRModel, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_loads, bus_gs, bus_bs)
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)

    cr =  var(pm, n, c, :cr)
    ci =  var(pm, n, c, :ci)
    crdc = var(pm, n, c, :crdc)
    cidc = var(pm, n, c, :cidc)
    crd = var(pm, n, c, :crd)
    cid = var(pm, n, c, :cid)
    crg = var(pm, n, c, :crg)
    cig = var(pm, n, c, :cig)

    JuMP.@constraint(pm.model, sum(cr[a] for a in bus_arcs) + sum(crdc[d] for d in bus_arcs_dc) == sum(crg[g] for g in bus_gens) - sum(crd[d] for d in bus_loads) - sum(gs for gs in values(bus_gs))*vr + sum(bs for bs in values(bus_bs))*vi )
    JuMP.@constraint(pm.model, sum(ci[a] for a in bus_arcs) + sum(cidc[d] for d in bus_arcs_dc) == sum(cig[g] for g in bus_gens) - sum(cid[d] for d in bus_loads) - sum(gs for gs in values(bus_gs))*vi - sum(bs for bs in values(bus_bs))*vr )
end

"`p[f_idx]^2 + q[f_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_from(pm::AbstractIVRModel, n::Int, c::Int, f_idx, rate_a)
    f_bus = f_idx[2]
    vr = var(pm, n, c, :vr, f_bus)
    vi = var(pm, n, c, :vi, f_bus)
    cr =  var(pm, n, c, :cr, f_idx)
    ci =  var(pm, n, c, :ci, f_idx)
    csrfr =  var(pm, n, c, :csr, f_idx)
    csifr =  var(pm, n, c, :csi, f_idx)
    #
    branch = ref(pm, n, :branch, f_idx[1])
    g_sh = branch["g_fr"][c]
    b_sh = branch["b_fr"][c]
    tr, ti = calc_branch_t(branch)
    tm = branch["tap"][c]

    crf = JuMP.@NLexpression(pm.model, (tr*csrfr - ti*csifr + g_sh*vr - b_sh*vi)/tm^2)
    cif = JuMP.@NLexpression(pm.model, (tr*csifr + ti*csrfr + g_sh*vi + b_sh*vr)/tm^2)

    #
    # JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)
    # *(
    #   ((tr*csrfr - ti*csifr + g_sh*vr - b_sh*vi)/tm^2)^2
    # + ((tr*csifr + ti*csrfr + g_sh*vi + b_sh*vr)/tm^2)^2
    # ) <= rate_a^2)
    JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)*(crf^2 + cif^2) <= rate_a^2)

end

"`p[t_idx]^2 + q[t_idx]^2 <= rate_a^2`"
function constraint_thermal_limit_to(pm::AbstractIVRModel, n::Int, c::Int, t_idx, rate_a)
    t_bus = t_idx[2]
    f_idx = (t_idx[1], t_idx[3], t_idx[2])

    branch = ref(pm, n, :branch, t_idx[1])
    g_sh = branch["g_to"][c]
    b_sh = branch["b_to"][c]

    vr = var(pm, n, c, :vr, t_bus)
    vi = var(pm, n, c, :vi, t_bus)
    csrfr =  var(pm, n, c, :csr, f_idx)
    csifr =  var(pm, n, c, :csi, f_idx)

    crt = JuMP.@NLexpression(pm.model, -csrfr + g_sh*vr - b_sh*vi)
    cit = JuMP.@NLexpression(pm.model, -csifr + g_sh*vi + b_sh*vr)

    JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)*(crt^2 + cit^2) <= rate_a^2)

    # JuMP.@NLconstraint(pm.model, (vr^2 + vi^2)
    # *(
    # (-csrfr + g_sh*vr - b_sh*vi)^2
    # + (-csifr + g_sh*vi + b_sh*vr)^2
    # )
    # <= rate_a^2)
end



function constraint_gen(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    gen = ref(pm, nw, :gen, i)
    bus = gen["gen_bus"]
    constraint_gen(pm, nw, cnd, i, bus, gen["pmax"], gen["pmin"], gen["qmax"], gen["qmin"])

end

function constraint_load(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    load = ref(pm, nw, :load, i)
    bus = load["load_bus"]

    constraint_load(pm, nw, cnd, i, bus, load["pd"], load["qd"])

end

function constraint_load(pm::AbstractIVRModel, n::Int, c::Int, i, bus, pref, qref)
    vr = var(pm, n, c, :vr, bus)
    vi = var(pm, n, c, :vi, bus)
    cr = var(pm, n, c, :crd, i)
    ci = var(pm, n, c, :cid, i)

    JuMP.@constraint(pm.model, pref == vr*cr  + vi*ci)
    JuMP.@constraint(pm.model, qref == vi*cr  - vr*ci)

end


function constraint_gen(pm::AbstractIVRModel, n::Int, c::Int, i, bus, pmax, pmin, qmax, qmin)
    @assert pmin <= pmax
    @assert qmin <= qmax

    vr = var(pm, n, c, :vr, bus)
    vi = var(pm, n, c, :vi, bus)
    cr = var(pm, n, c, :crg, i)
    ci = var(pm, n, c, :cig, i)

    JuMP.@constraint(pm.model, pmin <= vr*cr  + vi*ci)
    JuMP.@constraint(pm.model, pmax >= vr*cr  + vi*ci)

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

    dcline = ref(pm, n, :dcline, f_idx[1])

    pmaxf = dcline["pmaxf"]
    pminf = dcline["pminf"]
    pmaxt = dcline["pmaxt"]
    pmint = dcline["pmint"]

    qmaxf = dcline["qmaxf"]
    qminf = dcline["qminf"]
    qmaxt = dcline["qmaxt"]
    qmint = dcline["qmint"]

    pf = vrf*crdcf + vif*cidcf
    qf = vif*crdcf - vrf*cidcf
    pt = vrt*crdct + vit*cidct
    qt = vit*crdct - vrt*cidct

    JuMP.@constraint(pm.model, pf + pt == loss0 + loss1*pf )

    JuMP.@constraint(pm.model, pmaxf >= pf)
    JuMP.@constraint(pm.model, pminf <= pf)

    JuMP.@constraint(pm.model, pmaxt >= pt)
    JuMP.@constraint(pm.model, pmint <= pt)

    JuMP.@constraint(pm.model, qmaxf >= qf)
    JuMP.@constraint(pm.model, qminf <= qf)

    JuMP.@constraint(pm.model, qmaxt >= qt)
    JuMP.@constraint(pm.model, qmint <= qt)

end

"`pf[i] == pf, pt[i] == pt`"
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



"variable: `crg[j]`, `cig[j]` for `j` in `gen`"
function variable_gen(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    gen = ref(pm, nw, :gen)
    bus = ref(pm, nw, :bus)

    if bounded
        ub = Dict()
        for (i, g) in gen
            vmin = bus[g["gen_bus"]]["vmin"]
            @assert vmin>0
            s = sqrt(max(abs(g["pmax"]), abs(g["pmin"]))^2 + max(abs(g["qmax"]), abs(g["qmin"]))^2)
            ub[i] = s/vmin
        end

        var(pm, nw, cnd)[:crg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_crg",
            lower_bound = -ub[i],
            upper_bound = ub[i],
            start = comp_start_value(ref(pm, nw, :gen, i), "crg_start", cnd)
        )
        var(pm, nw, cnd)[:cig] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_cig",
            lower_bound = -ub[i],
            upper_bound = ub[i],
            start = comp_start_value(ref(pm, nw, :gen, i), "cig_start", cnd)
        )
    else
        var(pm, nw, cnd)[:crg] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_crg",
            start = comp_start_value(ref(pm, nw, :gen, i), "crg_start", cnd)
        )
        var(pm, nw, cnd)[:cig] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :gen)], base_name="$(nw)_$(cnd)_cig",
            start = comp_start_value(ref(pm, nw, :gen, i), "cig_start", cnd)
        )
    end
end

"variable: `crd[j]`, `cid[j]` ` for `j` in `load`"
function variable_load(pm::AbstractPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    load = ref(pm, nw, :load)
    bus = ref(pm, nw, :bus)

    if bounded
        ub = Dict()
        for (i, l) in load
            vmin = bus[l["load_bus"]]["vmin"]
            @assert vmin>0
            s = sqrt(l["pd"]^2 + l["qd"]^2)
            ub[i] = s/vmin
        end


        var(pm, nw, cnd)[:crd] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :load)], base_name="$(nw)_$(cnd)_crd",
            lower_bound = -ub[i],
            upper_bound = ub[i],
            start = comp_start_value(ref(pm, nw, :load, i), "crd_start", cnd)
        )
        var(pm, nw, cnd)[:cid] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :load)], base_name="$(nw)_$(cnd)_cid",
            lower_bound = -ub[i],
            upper_bound = ub[i],
            start = comp_start_value(ref(pm, nw, :load, i), "cid_start", cnd)
        )
    else
        var(pm, nw, cnd)[:crd] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :load)], base_name="$(nw)_$(cnd)_crd",
            start = comp_start_value(ref(pm, nw, :load, i), "crd_start", cnd)
        )
        var(pm, nw, cnd)[:cid] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :load)], base_name="$(nw)_$(cnd)_cid",
            start = comp_start_value(ref(pm, nw, :load, i), "cid_start", cnd)
        )
    end
end


"variable: `crdc[j]`, `cidc[j]` for `j` in `dcline`"
function variable_dcline(pm::AbstractIVRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true)
    gen = ref(pm, nw, :gen)
    bus = ref(pm, nw, :bus)
    dcline = ref(pm, nw, :dcline)

    if bounded
        ub = Dict()
        for (l,i,j) in ref(pm, nw, :arcs_from_dc)
            vminf = bus[i]["vmin"]
            vmint = bus[j]["vmin"]
            @assert vminf>0
            @assert vmint>0
            sf = sqrt(max(abs(dcline[l]["pmaxf"]), abs(dcline[l]["pminf"]))^2 + max(abs(dcline[l]["qmaxf"]), abs(dcline[l]["qminf"]))^2)
            st = sqrt(max(abs(dcline[l]["pmaxt"]), abs(dcline[l]["pmint"]))^2 + max(abs(dcline[l]["qmaxt"]), abs(dcline[l]["qmint"]))^2)
            imax = max(sf,st)/ min(vminf, vminf)
            ub[(l,i,j)] = imax
            ub[(l,j,i)] = imax
        end

        var(pm, nw, cnd)[:crdc] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_dc)], base_name="$(nw)_$(cnd)_crdc",
            lower_bound = -ub[(l,i,j)],
            upper_bound = ub[(l,i,j)],
            start = comp_start_value(ref(pm, nw, :dcline, l), "crdc_start", cnd)
        )
        var(pm, nw, cnd)[:cidc] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_dc)], base_name="$(nw)_$(cnd)_cidc",
            lower_bound = -ub[(l,i,j)],
            upper_bound = ub[(l,i,j)],
            start = comp_start_value(ref(pm, nw, :dcline, l), "cidc_start", cnd)
        )
    else
        var(pm, nw, cnd)[:crdc] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_dc)], base_name="$(nw)_$(cnd)_crdc",
            start = comp_start_value(ref(pm, nw, :dcline, l), "crdc_start", cnd)
        )
        var(pm, nw, cnd)[:cidc] = JuMP.@variable(pm.model,
            [(l,i,j) in ref(pm, nw, :arcs_dc)], base_name="$(nw)_$(cnd)_cidc",
            start = comp_start_value(ref(pm, nw, :dcline, l), "cidc_start", cnd)
        )
    end
end

""
function constraint_current_balance(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(con(pm, nw, cnd), :kcl_cr)
        con(pm, nw, cnd)[:kcl_cr] = Dict{Int,JuMP.ConstraintRef}()
    end
    if !haskey(con(pm, nw, cnd), :kcl_ci)
        con(pm, nw, cnd)[:kcl_ci] = Dict{Int,JuMP.ConstraintRef}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", cnd) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", cnd) for k in bus_shunts)

    constraint_current_balance(pm, nw, cnd, i, bus_arcs, bus_arcs_dc, bus_gens, bus_loads, bus_gs, bus_bs)
end


"extracts voltage set points from rectangular voltage form and converts into polar voltage form"
function add_setpoint_bus_voltage!(sol, pm::AbstractIVRModel)
    sol_dict = get(sol, "bus", Dict{String,Any}())

    if ismultinetwork(pm)
        bus_dict = pm.data["nw"]["$(pm.cnw)"]["bus"]
    else
        bus_dict = pm.data["bus"]
    end

    if length(bus_dict) > 0
        sol["bus"] = sol_dict
    end

    for (i,item) in bus_dict
        idx = Int(item["bus_i"])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())

        num_conductors = length(conductor_ids(pm))
        cnd_idx = 1
        sol_item["vm"] = MultiConductorVector{Real}([NaN for i in 1:num_conductors])
        sol_item["va"] = MultiConductorVector{Real}([NaN for i in 1:num_conductors])
        for c in conductor_ids(pm)
            try
                vr = JuMP.value(var(pm, :vr, cnd=c)[idx])
                vi = JuMP.value(var(pm, :vi, cnd=c)[idx])

                vm = sqrt(vr^2 + vi^2)

                sol_item["vm"][c] = vm
                sol_item["va"][c] = atan(vi, vr)

            catch
            end
        end

        # remove MultiConductorValue, if it was not a ismulticonductor network
        if !ismulticonductor(pm)
            sol_item["vm"] = sol_item["vm"][1]
            sol_item["va"] = sol_item["va"][1]
        end
    end
end


""
function add_setpoint_generator_current!(sol, pm::AbstractIVRModel)
    add_setpoint!(sol, pm, "gen", "crg", :crg, status_name="gen_status")
    add_setpoint!(sol, pm, "gen", "cig", :cig, status_name="gen_status")
end

""
function add_setpoint_load_current!(sol, pm::AbstractIVRModel)
    add_setpoint!(sol, pm, "load", "crd", :crd, status_name="status")
    add_setpoint!(sol, pm, "load", "cid", :cid, status_name="status")
end

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
function solution_opf_iv!(pm::AbstractPowerModel, sol::Dict{String,<:Any})
    add_setpoint_bus_voltage!(sol, pm)
    add_setpoint_branch_current!(sol, pm)
    add_setpoint_load_current!(sol, pm)
    add_setpoint_generator_current!(sol, pm)

    add_setpoint_dcline_flow!(sol, pm)
    # add_setpoint_storage!(sol, pm)

    # add_dual_kcl!(sol, pm)
    # add_dual_sm!(sol, pm) # Adds the duals of the transmission lines' thermal limits.
end


""
function add_setpoint_dcline_flow!(sol, pm::AbstractIVRModel)
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
            # vr = var(pm, n, c, :vr, bus)
            # crg = var(pm, n, c, :crg, i)
            # vi = var(pm, n, c, :vi, bus)
            # cig = var(pm, n, c, :cig, i)
            # pg = JuMP.@NLexpression(pm.model, sum(vr*crg + vi*cig for c in conductor_ids(pm, n) ))
            vr = var(pm, n, 1, :vr, bus) #TODO multinetwork
            vi = var(pm, n, 1, :vi, bus)
            crg = var(pm, n, 1, :crg, i)
            cig = var(pm, n, 1, :cig, i)
            pg = JuMP.@NLexpression(pm.model, vr*crg + vi*cig)

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, gen["cost"][1]*pg + gen["cost"][2])
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, gen["cost"][1]*pg^2 + gen["cost"][2]*pg + gen["cost"][3])
            else
                gen_cost[(n,i)] = 0.0
            end
        end

        from_idx = Dict(arc[1] => arc for arc in nw_ref[:arcs_from_dc])
        for (i,dcline) in nw_ref[:dcline]
            bus = dcline["f_bus"]

            # p_dc = JuMP.@NLexpression(pm.model, sum( var(pm, n, c, :vr, bus)*var(pm, n, c, :crdc, from_idx[i])+var(pm, n, c, :vi, bus)*var(pm, n, c, :cidc, from_idx[i]) for c in conductor_ids(pm, n) ))
            vr = var(pm, n, 1, :vr, bus) #TODO multinetwork
            vi = var(pm, n, 1, :vi, bus)
            crdc = var(pm, n, 1, :crdc, from_idx[i])
            cidc = var(pm, n, 1, :cidc, from_idx[i])
            p_dc = JuMP.@NLexpression(pm.model, vr*crdc+vi*cidc )

            if length(dcline["cost"]) == 1
                dcline_cost[(n,i)] = dcline["cost"][1]
            elseif length(dcline["cost"]) == 2
                dcline_cost[(n,i)] = JuMP.@NLexpression(pm.model, dcline["cost"][1]*p_dc + dcline["cost"][2])
            elseif length(dcline["cost"]) == 3
                dcline_cost[(n,i)]  = JuMP.@NLexpression(pm.model, dcline["cost"][1]*p_dc^2 + dcline["cost"][2]*p_dc + dcline["cost"][3])
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
