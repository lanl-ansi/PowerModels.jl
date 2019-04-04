### rectangular form of the non-convex AC equations

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractACRForm
    variable_voltage_real(pm; kwargs...)
    variable_voltage_imaginary(pm; kwargs...)
end


"add constraints for voltage magnitude"
function constraint_voltage(pm::GenericPowerModel{T}, n::Int, c::Int) where T <: AbstractACRForm
    vr = var(pm, n, c, :vr)
    vi = var(pm, n, c, :vi)

    for (i,bus) in ref(pm, n, :bus)
        @constraint(pm.model, bus["vmin"][c]^2 <= (vr[i]^2 + vi[i]^2))
        @constraint(pm.model, bus["vmax"][c]^2 >= (vr[i]^2 + vi[i]^2))
    end

    # does not seem to improve convergence
    #wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])
    #for bp in ids(pm, nw, :buspairs)
    #    i,j = bp
    #    @constraint(pm.model, wr_min[bp] <= vr[i]*vr[j] + vi[i]*vi[j])
    #    @constraint(pm.model, wr_max[bp] >= vr[i]*vr[j] + vi[i]*vi[j])
    #
    #    @constraint(pm.model, wi_min[bp] <= vi[i]*vr[j] - vr[i]*vi[j])
    #    @constraint(pm.model, wi_max[bp] >= vi[i]*vr[j] - vr[i]*vi[j])
    #end
end


"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint(pm::GenericPowerModel{T}, n::Int, c::Int, i, vm) where T <: AbstractACRForm
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)

    @constraint(pm.model, (vr^2 + vi^2) == vm^2)
end


"reference bus angle constraint"
function constraint_theta_ref(pm::GenericPowerModel{T}, n::Int, c::Int, i::Int) where T <: AbstractACRForm
    @constraint(pm.model, var(pm, n, c, :vi)[i] == 0)
    @constraint(pm.model, var(pm, n, c, :vr)[i] >= 0)
end


function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractACRForm
    vr = var(pm, n, c, :vr, i)
    vi = var(pm, n, c, :vi, i)
    p  = var(pm, n, c, :p)
    q  = var(pm, n, c, :q)
    pg = var(pm, n, c, :pg)
    qg = var(pm, n, c, :qg)
    p_dc = var(pm, n, c, :p_dc)
    q_dc = var(pm, n, c, :q_dc)

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*(vr^2 + vi^2))
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*(vr^2 + vi^2))
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractACRForm
    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    vr_fr = var(pm, n, c, :vr, f_bus)
    vr_to = var(pm, n, c, :vr, t_bus)
    vi_fr = var(pm, n, c, :vi, f_bus)
    vi_to = var(pm, n, c, :vi, t_bus)

    @constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(vr_fr^2 + vi_fr^2) + (-g*tr+b*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr-g*ti)/tm^2*(vi_fr*vr_to - vr_fr*vi_to) )
    @constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(vr_fr^2 + vi_fr^2) - (-b*tr-g*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr+b*ti)/tm^2*(vi_fr*vr_to - vr_fr*vi_to) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractACRForm
    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    vr_fr = var(pm, n, c, :vr, f_bus)
    vr_to = var(pm, n, c, :vr, t_bus)
    vi_fr = var(pm, n, c, :vi, f_bus)
    vi_to = var(pm, n, c, :vi, t_bus)

    @constraint(pm.model, p_to ==  (g+g_to)*(vr_to^2 + vi_to^2) + (-g*tr-b*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr+g*ti)/tm^2*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    @constraint(pm.model, q_to == -(b+b_to)*(vr_to^2 + vi_to^2) - (-b*tr+g*ti)/tm^2*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr-b*ti)/tm^2*(-(vi_fr*vr_to - vr_fr*vi_to)) )
end


function constraint_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, c_rating_a) where T <: AbstractACRForm
    l,i,j = f_idx
    t_idx = (l,j,i)

    vr_fr = var(pm, n, c, :vr, i)
    vr_to = var(pm, n, c, :vr, j)
    vi_fr = var(pm, n, c, :vi, i)
    vi_to = var(pm, n, c, :vi, j)

    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    @constraint(pm.model, p_fr^2 + q_fr^2 <= (vr_fr^2 + vi_fr^2)*c_rating_a^2)

    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    @constraint(pm.model, p_to^2 + q_to^2 <= (vr_to^2 + vi_to^2)*c_rating_a^2)
end


"""
branch voltage angle difference bounds
"""
function constraint_voltage_angle_difference(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, angmin, angmax) where T <: AbstractACRForm
    i, f_bus, t_bus = f_idx

    vr_fr = var(pm, n, c, :vr, f_bus)
    vr_to = var(pm, n, c, :vr, t_bus)
    vi_fr = var(pm, n, c, :vi, f_bus)
    vi_to = var(pm, n, c, :vi, t_bus)

    @constraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) <= tan(angmax)*(vr_fr*vr_to + vi_fr*vi_to))
    @constraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) >= tan(angmin)*(vr_fr*vr_to + vi_fr*vi_to))
end


"extracts voltage set points from rectangular voltage form and converts into polar voltage form"
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractACRForm
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
                vr = getvalue(var(pm, :vr, cnd=c)[idx])
                vi = getvalue(var(pm, :vi, cnd=c)[idx])

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
