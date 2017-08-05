### rectangular form of the non-convex AC equations

export
    ACRPowerModel, StandardACRForm

""
@compat abstract type AbstractACRForm <: AbstractPowerFormulation end

""
@compat abstract type StandardACRForm <: AbstractACRForm end

""
const ACRPowerModel = GenericPowerModel{StandardACRForm}

"default rectangular AC constructor"
ACRPowerModel(data::Dict{String,Any}; kwargs...) = 
    GenericPowerModel(data, StandardACRForm; kwargs...)


""
function variable_voltage{T <: AbstractACRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_real(pm; kwargs...)
    variable_voltage_imaginary(pm; kwargs...)
end


"add constraints for voltage magnitude"
function constraint_voltage{T <: AbstractACRForm}(pm::GenericPowerModel{T}; kwargs...)
    vr = pm.var[:vr]
    vi = pm.var[:vi]

    cs = Set([])
    for (i,bus) in pm.ref[:bus]
        c1 = @constraint(pm.model, bus["vmin"]^2 <= (vr[i]^2 + vi[i]^2))
        c2 = @constraint(pm.model, bus["vmax"]^2 >= (vr[i]^2 + vi[i]^2))
        push!(cs, Set([c1, c2]))
    end

    # does not seem to improve convergence
    #wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])
    #for bp in keys(pm.ref[:buspairs])
    #    i,j = bp
    #    c1 = @constraint(pm.model, wr_min[bp] <= vr[i]*vr[j] + vi[i]*vi[j])
    #    c2 = @constraint(pm.model, wr_max[bp] >= vr[i]*vr[j] + vi[i]*vi[j])
    #
    #    c3 = @constraint(pm.model, wi_min[bp] <= vi[i]*vr[j] - vr[i]*vi[j])
    #    c4 = @constraint(pm.model, wi_max[bp] >= vi[i]*vr[j] - vr[i]*vi[j])
    #
    #    push!(cs, Set([c1, c2, c3, c4]))
    #end

    return cs
end


"reference bus angle constraint"
function constraint_theta_ref{T <: AbstractACRForm}(pm::GenericPowerModel{T}, ref_bus::Int)
    c = @constraint(pm.model, pm.var[:vi][ref_bus] == 0)
    return Set([c])
end


function constraint_kcl_shunt{T <: AbstractACRForm}(pm::GenericPowerModel{T}, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    vr = pm.var[:vr][i]
    vi = pm.var[:vi][i]
    p = pm.var[:p]
    q = pm.var[:q]
    pg = pm.var[:pg]
    qg = pm.var[:qg]
    p_dc = pm.var[:p_dc]
    q_dc = pm.var[:q_dc]

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*(vr^2 + vi^2))
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*(vr^2 + vi^2))
    return Set([c1, c2])
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from{T <: AbstractACRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = pm.var[:p][f_idx]
    q_fr = pm.var[:q][f_idx]
    vr_fr = pm.var[:vr][f_bus]
    vr_to = pm.var[:vr][t_bus]
    vi_fr = pm.var[:vi][f_bus]
    vi_to = pm.var[:vi][t_bus]

    c1 = @NLconstraint(pm.model, p_fr ==        g/tm*(vr_fr^2 + vi_fr^2) + (-g*tr+b*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr-g*ti)/tm*(vi_fr*vr_to - vr_fr*vi_to) )
    c2 = @NLconstraint(pm.model, q_fr == -(b+c/2)/tm*(vr_fr^2 + vi_fr^2) - (-b*tr-g*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr+b*ti)/tm*(vi_fr*vr_to - vr_fr*vi_to) )
    return Set([c1, c2])
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to{T <: AbstractACRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_to = pm.var[:p][t_idx]
    q_to = pm.var[:q][t_idx]
    vr_fr = pm.var[:vr][f_bus]
    vr_to = pm.var[:vr][t_bus]
    vi_fr = pm.var[:vi][f_bus]
    vi_to = pm.var[:vi][t_bus]

    c1 = @NLconstraint(pm.model, p_to ==        g*(vr_to^2 + vi_to^2) + (-g*tr-b*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr+g*ti)/tm*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    c2 = @NLconstraint(pm.model, q_to == -(b+c/2)*(vr_to^2 + vi_to^2) - (-b*tr+g*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr-b*ti)/tm*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    return Set([c1, c2])
end


"""
branch phase angle difference bounds
"""
function constraint_phase_angle_difference{T <: AbstractACRForm}(pm::GenericPowerModel{T}, f_bus, t_bus, angmin, angmax)
    vr_fr = pm.var[:vr][f_bus]
    vr_to = pm.var[:vr][t_bus]
    vi_fr = pm.var[:vi][f_bus]
    vi_to = pm.var[:vi][t_bus]

    # this form appears to be more numerically stable than the one below
    c1 = @NLconstraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to)/(vr_fr*vr_to + vi_fr*vi_to) <= tan(angmax))
    c2 = @NLconstraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to)/(vr_fr*vr_to + vi_fr*vi_to) >= tan(angmin))

    #c1 = @NLconstraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) <= tan(angmax)*(vr_fr*vr_to + vi_fr*vi_to))
    #c2 = @NLconstraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) >= tan(angmin)*(vr_fr*vr_to + vi_fr*vi_to))

    return Set([c1, c2])
end


"extracts voltage set points from rectangular voltage form and converts into polar voltage form"
function add_bus_voltage_setpoint{T <: AbstractACRForm}(sol, pm::GenericPowerModel{T})
    sol_dict = sol["bus"] = get(sol, "bus", Dict{String,Any}())
    for (i,item) in pm.data["bus"]
        idx = Int(item["bus_i"])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item["vm"] = NaN
        sol_item["va"] = NaN
        try
            vr = getvalue(pm.var[:vr][idx])
            vi = getvalue(pm.var[:vi][idx])
            
            vm = sqrt(vr^2 + vi^2)
            sol_item["vm"] = vm

            if vr == 0.0
                if vi >= 0
                    va = pi/2
                else
                    va = 3*pi/2
                end
            else
                va = atan(vi/vr)
            end
            sol_item["va"] = va
        catch
        end
    end
end

