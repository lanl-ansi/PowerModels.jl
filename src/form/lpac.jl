### the LPAC approximation

""
function variable_voltage(pm::GenericPowerModel{T}; kwargs...) where T <: AbstractLPACForm
    variable_voltage_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)
    variable_cosine(pm; kwargs...)
end

""
function variable_voltage_magnitude(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: AbstractLPACForm
    if bounded
        var(pm, nw, cnd)[:phi] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_phi",
            lower_bound = ref(pm, nw, :bus, i, "vmin", cnd) - 1.0,
            upper_bound = ref(pm, nw, :bus, i, "vmax", cnd) - 1.0,
            start = getval(ref(pm, nw, :bus, i), "phi_start", cnd)
        )
    else
        var(pm, nw, cnd)[:vm] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_vm",
            lower_bound = -1.0,
            start = getval(ref(pm, nw, :bus, i), "phi_start", cnd)
        )
    end
end

""
function constraint_voltage(pm::GenericPowerModel{T}, n::Int, c::Int) where T <: AbstractLPACForm
    t = var(pm, n, c, :va)
    cs = var(pm, n, c, :cs)

    for (bp, buspair) in ref(pm, n, :buspairs)
        i,j = bp
        vad_max = max(abs(buspair["angmin"]), abs(buspair["angmax"]))
        JuMP.@constraint(pm.model, cs[bp] <= 1 - (1-cos(vad_max))/vad_max^2*(t[i] - t[j])^2)
   end
end


""
function constraint_kcl_shunt(pm::GenericPowerModel{T}, n::Int, c::Int, i, bus_arcs, bus_arcs_dc, bus_gens, bus_pd, bus_qd, bus_gs, bus_bs) where T <: AbstractLPACForm
    phi  = var(pm, n, c, :phi, i)
    pg   = var(pm, n, c, :pg)
    qg   = var(pm, n, c, :qg)
    p    = var(pm, n, c, :p)
    q    = var(pm, n, c, :q)
    p_dc = var(pm, n, c, :p_dc)
    q_dc = var(pm, n, c, :q_dc)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*(1.0 + 2*phi))
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*(1.0 + 2*phi))
end


""
function constraint_ohms_yt_from(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm) where T <: AbstractLPACForm
    p_fr   = var(pm, n, c, :p, f_idx)
    q_fr   = var(pm, n, c, :q, f_idx)
    phi_fr = var(pm, n, c, :phi, f_bus)
    phi_to = var(pm, n, c, :phi, t_bus)
    va_fr  = var(pm, n, c, :va, f_bus)
    va_to  = var(pm, n, c, :va, t_bus)
    cs     = var(pm, n, c, :cs, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*(1.0 + 2*phi_fr) + (-g*tr+b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr-g*ti)/tm^2*(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*(1.0 + 2*phi_fr) - (-b*tr-g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr+b*ti)/tm^2*(va_fr-va_to) )
end

""
function constraint_ohms_yt_to(pm::GenericPowerModel{T}, n::Int, c::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm) where T <: AbstractLPACForm
    p_to   = var(pm, n, c, :p, t_idx)
    q_to   = var(pm, n, c, :q, t_idx)
    phi_fr = var(pm, n, c, :phi, f_bus)
    phi_to = var(pm, n, c, :phi, t_bus)
    va_fr  = var(pm, n, c, :va, f_bus)
    va_to  = var(pm, n, c, :va, t_bus)
    cs     = var(pm, n, c, :cs, (f_bus, t_bus))

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*(1.0 + 2*phi_to) + (-g*tr-b*ti)/tm^2*(cs + phi_fr + phi_to) + (-b*tr+g*ti)/tm^2*-(va_fr-va_to) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*(1.0 + 2*phi_to) - (-b*tr+g*ti)/tm^2*(cs + phi_fr + phi_to) + (-g*tr-b*ti)/tm^2*-(va_fr-va_to) )
end


""
function add_bus_voltage_setpoint(sol, pm::GenericPowerModel{T}) where T <: AbstractLPACForm
    add_setpoint(sol, pm, "bus", "vm", :phi; scale = (x,item,cnd) -> 1.0+x)
    add_setpoint(sol, pm, "bus", "va", :va)
end

