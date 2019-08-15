### rectangular form of the non-convex AC equations

""
function variable_voltage(pm::AbstractACRModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded::Bool=true, kwargs...)
    variable_voltage_real(pm; nw=nw, cnd=cnd, bounded=bounded, kwargs...)
    variable_voltage_imaginary(pm; nw=nw, cnd=cnd, bounded=bounded, kwargs...)

    if bounded
        vr = var(pm, nw, cnd, :vr)
        vi = var(pm, nw, cnd, :vi)
        for (i,bus) in ref(pm, nw, :bus)
            JuMP.@constraint(pm.model, bus["vmin"][cnd]^2 <= (vr[i]^2 + vi[i]^2))
            JuMP.@constraint(pm.model, bus["vmax"][cnd]^2 >= (vr[i]^2 + vi[i]^2))
        end

        # does not seem to improve convergence
        #wr_min, wr_max, wi_min, wi_max = ref_calc_voltage_product_bounds(pm.ref[:buspairs])
        #for bp in ids(pm, nw, :buspairs)
        #    i,j = bp
        #    JuMP.@constraint(pm.model, wr_min[bp] <= vr[i]*vr[j] + vi[i]*vi[j])
        #    JuMP.@constraint(pm.model, wr_max[bp] >= vr[i]*vr[j] + vi[i]*vi[j])
        #
        #    JuMP.@constraint(pm.model, wi_min[bp] <= vi[i]*vr[j] - vr[i]*vi[j])
        #    JuMP.@constraint(pm.model, wi_max[bp] >= vi[i]*vr[j] - vr[i]*vi[j])
        #end
    end
end


"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint(pm::AbstractACRModel, n::Int, c::Int, i, vm)
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)

    JuMP.@constraint(pm.model, (vr^2 + vi^2) == vm^2)
end


"reference bus angle constraint"
function constraint_theta_ref(pm::AbstractACRModel, n::Int, c::Int, i::Int)
    JuMP.@constraint(pm.model, var(pm, n, c, :vi)[i] == 0)
end


function constraint_power_balance(pm::AbstractACRModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)
    p    = get(var(pm, n, c),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n, c),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n, c),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n, c),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n, c),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n, c),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n, c),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n, c),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n, c), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n, c), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")


    con(pm, n, c, :kcl_p)[i] = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*(vr^2 + vi^2)
    )
    con(pm, n, c, :kcl_q)[i] = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*(vr^2 + vi^2)
    )
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::AbstractACRModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    vr_fr = var(pm, n, c, :vr, f_bus)
    vr_to = var(pm, n, c, :vr, t_bus)
    vi_fr = var(pm, n, c, :vi, f_bus)
    vi_to = var(pm, n, c, :vi, t_bus)

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(vr_fr^2 + vi_fr^2) + (-g*tr+b*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr-g*ti)/tm^2*(vi_fr*vr_to - vr_fr*vi_to) )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(vr_fr^2 + vi_fr^2) - (-b*tr-g*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr+b*ti)/tm^2*(vi_fr*vr_to - vr_fr*vi_to) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::AbstractACRModel, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    vr_fr = var(pm, n, c, :vr, f_bus)
    vr_to = var(pm, n, c, :vr, t_bus)
    vi_fr = var(pm, n, c, :vi, f_bus)
    vi_to = var(pm, n, c, :vi, t_bus)

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(vr_to^2 + vi_to^2) + (-g*tr-b*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr+g*ti)/tm^2*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(vr_to^2 + vi_to^2) - (-b*tr+g*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr-b*ti)/tm^2*(-(vi_fr*vr_to - vr_fr*vi_to)) )
end


function constraint_current_limit(pm::AbstractACRModel, n::Int, c::Int, f_idx, c_rating_a)
    l,i,j = f_idx
    t_idx = (l,j,i)

    vr_fr = var(pm, n, c, :vr, i)
    vr_to = var(pm, n, c, :vr, j)
    vi_fr = var(pm, n, c, :vi, i)
    vi_to = var(pm, n, c, :vi, j)

    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= (vr_fr^2 + vi_fr^2)*c_rating_a^2)

    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= (vr_to^2 + vi_to^2)*c_rating_a^2)
end


"""
branch voltage angle difference bounds
"""
function constraint_voltage_angle_difference(pm::AbstractACRModel, n::Int, c::Int, f_idx, angmin, angmax)
    i, f_bus, t_bus = f_idx

    vr_fr = var(pm, n, c, :vr, f_bus)
    vr_to = var(pm, n, c, :vr, t_bus)
    vi_fr = var(pm, n, c, :vi, f_bus)
    vi_to = var(pm, n, c, :vi, t_bus)

    JuMP.@constraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) <= tan(angmax)*(vr_fr*vr_to + vi_fr*vi_to))
    JuMP.@constraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) >= tan(angmin)*(vr_fr*vr_to + vi_fr*vi_to))
end


"extracts voltage set points from rectangular voltage form and converts into polar voltage form"
function add_setpoint_bus_voltage!(sol, pm::AbstractACRModel)
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
