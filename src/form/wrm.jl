export
    SDPWRMPowerModel, SDPWRMForm

""
@compat abstract type AbstractWRMForm <: AbstractConicPowerFormulation end

""
@compat abstract type SDPWRMForm <: AbstractWRMForm end

""
const SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}

""
SDPWRMPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPWRMForm; kwargs...)

""
function variable_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int=pm.cnw; kwargs...)
    variable_voltage_product_matrix(pm, n; kwargs...)
end

""
function variable_voltage_product_matrix{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int=pm.cnw; bounded = true)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:nw][n][:buspairs])

    w_index = 1:length(keys(pm.ref[:nw][n][:bus]))
    lookup_w_index = Dict([(bi,i) for (i,bi) in enumerate(keys(pm.ref[:nw][n][:bus]))])

    WR = pm.var[:nw][n][:WR] = @variable(pm.model, 
        [1:length(keys(pm.ref[:nw][n][:bus])), 1:length(keys(pm.ref[:nw][n][:bus]))], Symmetric, basename="$(n)_WR"
    )
    WI = pm.var[:nw][n][:WI] = @variable(pm.model, 
        [1:length(keys(pm.ref[:nw][n][:bus])), 1:length(keys(pm.ref[:nw][n][:bus]))], basename="$(n)_WI"
    )

    # bounds on diagonal
    for (i, bus) in pm.ref[:nw][n][:bus]
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        if bounded
            setlowerbound(wr_ii, bus["vmin"]^2)
            setupperbound(wr_ii, bus["vmax"]^2)

            #this breaks SCS on the 3 bus exmple
            #setlowerbound(wi_ii, 0)
            #setupperbound(wi_ii, 0)
        else
             setlowerbound(wr_ii, 0)
        end
    end

    # bounds on off-diagonal
    for (i,j) in keys(pm.ref[:nw][n][:buspairs])
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        if bounded
            setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
            setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

            setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
            setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
        end
    end

    if !haskey(pm.ext, :nw)
        pm.ext[:nw] = Dict{Int,Any}()
    end
    if !haskey(pm.ext[:nw], n)
        pm.ext[:nw][n] = Dict{Symbol,Any}()
    end
    pm.ext[:nw][n][:lookup_w_index] = lookup_w_index
end


""
function constraint_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int)
    WR = pm.var[:nw][n][:WR]
    WI = pm.var[:nw][n][:WI]

    @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in keys(pm.ref[:nw][n][:buspairs])
    #    relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
end

"Do nothing, no way to represent this in these variables"
function constraint_theta_ref{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, ref_bus::Int)
end

""
function constraint_kcl_shunt{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, i, bus_arcs, bus_arcs_dc, bus_gens, pd, qd, gs, bs)
    w_index = pm.ext[:nw][n][:lookup_w_index][i]
    w = pm.var[:nw][n][:WR][w_index, w_index]

    p = pm.var[:nw][n][:p]
    q = pm.var[:nw][n][:q]
    pg = pm.var[:nw][n][:pg]
    qg = pm.var[:nw][n][:qg]
    p_dc = pm.var[:nw][n][:p_dc]
    q_dc = pm.var[:nw][n][:q_dc]

    @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
end

"Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)"
function constraint_ohms_yt_from{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    p_fr = pm.var[:nw][n][:p][f_idx]
    q_fr = pm.var[:nw][n][:q][f_idx]

    w_fr_index = pm.ext[:nw][n][:lookup_w_index][f_bus]
    w_to_index = pm.ext[:nw][n][:lookup_w_index][t_bus]

    w_fr = pm.var[:nw][n][:WR][w_fr_index, w_fr_index]
    w_to = pm.var[:nw][n][:WR][w_to_index, w_to_index]
    wr   = pm.var[:nw][n][:WR][w_fr_index, w_to_index]
    wi   = pm.var[:nw][n][:WI][w_fr_index, w_to_index]

    @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
end

""
function constraint_ohms_yt_to{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, c, tr, ti, tm)
    q_to = pm.var[:nw][n][:q][t_idx]
    p_to = pm.var[:nw][n][:p][t_idx]

    w_fr_index = pm.ext[:nw][n][:lookup_w_index][f_bus]
    w_to_index = pm.ext[:nw][n][:lookup_w_index][t_bus]

    w_fr = pm.var[:nw][n][:WR][w_fr_index, w_fr_index]
    w_to = pm.var[:nw][n][:WR][w_to_index, w_to_index]
    wr   = pm.var[:nw][n][:WR][w_fr_index, w_to_index]
    wi   = pm.var[:nw][n][:WI][w_fr_index, w_to_index]

    @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

""
function constraint_voltage_angle_difference{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, angmin, angmax)
    w_fr_index = pm.ext[:nw][n][:lookup_w_index][f_bus]
    w_to_index = pm.ext[:nw][n][:lookup_w_index][t_bus]

    w_fr = pm.var[:nw][n][:WR][w_fr_index, w_fr_index]
    w_to = pm.var[:nw][n][:WR][w_to_index, w_to_index]
    wr   = pm.var[:nw][n][:WR][w_fr_index, w_to_index]
    wi   = pm.var[:nw][n][:WI][w_fr_index, w_to_index]

    @constraint(pm.model, wi <= tan(angmax)*wr)
    @constraint(pm.model, wi >= tan(angmin)*wr)

    cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)
end

""
function add_bus_voltage_setpoint{T <: AbstractWRMForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "vm", :WR; scale = (x,item) -> sqrt(x), extract_var = (var,idx,item) -> var[pm.ext[:nw][pm.cnw][:lookup_w_index][idx], pm.ext[:nw][pm.cnw][:lookup_w_index][idx]])

    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "va", :va; default_value = 0)
end

""
function constraint_voltage_magnitude_setpoint{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, i, vm)
    w_index = pm.ext[:nw][n][:lookup_w_index][i]
    w = pm.var[:nw][n][:WR][w_index, w_index]

    @constraint(pm.model, w == vm^2)
end

