### rectangular form of the non-convex AC equations

export
    ACRPowerModel, StandardACRForm

""
abstract type AbstractACRForm <: AbstractPowerFormulation end

""
abstract type StandardACRForm <: AbstractACRForm end

""
const ACRPowerModel = GenericPowerModel{StandardACRForm}

"default rectangular AC constructor"
ACRPowerModel(data::Dict{String,Any}; kwargs...) = 
    GenericPowerModel(data, StandardACRForm; kwargs...)


""
function variable_voltage{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...)
    variable_voltage_real(pm, n; kwargs...)
    variable_voltage_imaginary(pm, n; kwargs...)
end


"add constraints for voltage magnitude"
function constraint_voltage{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int)
    vr = pm.var[:nw][n][:vr]
    vi = pm.var[:nw][n][:vi]

    for (i,bus) in pm.ref[:nw][n][:bus]
        @constraint(pm.model, bus["vmin"]^2 <= (vr[i]^2 + vi[i]^2))
        @constraint(pm.model, bus["vmax"]^2 >= (vr[i]^2 + vi[i]^2))
    end

    # does not seem to improve convergence
    #wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:buspairs])
    #for bp in keys(pm.ref[:buspairs])
    #    i,j = bp
    #    @constraint(pm.model, wr_min[bp] <= vr[i]*vr[j] + vi[i]*vi[j])
    #    @constraint(pm.model, wr_max[bp] >= vr[i]*vr[j] + vi[i]*vi[j])
    #
    #    @constraint(pm.model, wi_min[bp] <= vi[i]*vr[j] - vr[i]*vi[j])
    #    @constraint(pm.model, wi_max[bp] >= vi[i]*vr[j] - vr[i]*vi[j])
    #end
end


"`v[i] == vm`"
function constraint_voltage_magnitude_setpoint{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int, i, vm)
    vr = pm.var[:nw][n][:vr][i]
    vi = pm.var[:nw][n][:vi][i]

    @constraint(pm.model, (vr^2 + vi^2) == vm^2)
end


"reference bus angle constraint"
function constraint_theta_ref{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int, i::Int)
    @constraint(pm.model, pm.var[:nw][n][:vi][i] == 0)
end


function constraint_kcl_shunt{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    vr = pm.var[:nw][n][:vr][i]
    vi = pm.var[:nw][n][:vi][i]
    p = pm.var[:nw][n][:p]
    q = pm.var[:nw][n][:q]
    pg = pm.var[:nw][n][:pg]
    qg = pm.var[:nw][n][:qg]
    p_dc = pm.var[:nw][n][:p_dc]
    q_dc = pm.var[:nw][n][:q_dc]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*(vr^2 + vi^2))
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*(vr^2 + vi^2))
end


"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_from{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]
    vr_fr = pm.var[:nw][n][:vr][f_bus]
    vr_to = pm.var[:nw][n][:vr][t_bus]
    vi_fr = pm.var[:nw][n][:vi][f_bus]
    vi_to = pm.var[:nw][n][:vi][t_bus]

    @constraint(pm.model, p_fr ==        g/tm*(vr_fr^2 + vi_fr^2) + (-g*tr+b*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr-g*ti)/tm*(vi_fr*vr_to - vr_fr*vi_to) )
    @constraint(pm.model, q_fr == -(b+c/2)/tm*(vr_fr^2 + vi_fr^2) - (-b*tr-g*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr+b*ti)/tm*(vi_fr*vr_to - vr_fr*vi_to) )
end

"""
Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
"""
function constraint_ohms_yt_to{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_to = pm.var[:nw][n][:p][t_idx]
    q_to = pm.var[:nw][n][:q][t_idx]
    vr_fr = pm.var[:nw][n][:vr][f_bus]
    vr_to = pm.var[:nw][n][:vr][t_bus]
    vi_fr = pm.var[:nw][n][:vi][f_bus]
    vi_to = pm.var[:nw][n][:vi][t_bus]

    @constraint(pm.model, p_to ==        g*(vr_to^2 + vi_to^2) + (-g*tr-b*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-b*tr+g*ti)/tm*(-(vi_fr*vr_to - vr_fr*vi_to)) )
    @constraint(pm.model, q_to == -(b+c/2)*(vr_to^2 + vi_to^2) - (-b*tr+g*ti)/tm*(vr_fr*vr_to + vi_fr*vi_to) + (-g*tr-b*ti)/tm*(-(vi_fr*vr_to - vr_fr*vi_to)) )
end


"""
branch phase angle difference bounds
"""
function constraint_voltage_angle_difference{T <: AbstractACRForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, angmin, angmax)
    vr_fr = pm.var[:nw][n][:vr][f_bus]
    vr_to = pm.var[:nw][n][:vr][t_bus]
    vi_fr = pm.var[:nw][n][:vi][f_bus]
    vi_to = pm.var[:nw][n][:vi][t_bus]

    @constraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) <= tan(angmax)*(vr_fr*vr_to + vi_fr*vi_to))
    @constraint(pm.model, (vi_fr*vr_to - vr_fr*vi_to) >= tan(angmin)*(vr_fr*vr_to + vi_fr*vi_to))
end


"extracts voltage set points from rectangular voltage form and converts into polar voltage form"
function add_bus_voltage_setpoint{T <: AbstractACRForm}(sol, pm::GenericPowerModel{T})
    sol_dict = get(sol, "bus", Dict{String,Any}())

    if pm.data["multinetwork"]
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
        sol_item["vm"] = NaN
        sol_item["va"] = NaN
        try
            vr = getvalue(var(pm, :vr)[idx])
            vi = getvalue(var(pm, :vi)[idx])
            
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

