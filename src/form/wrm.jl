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
variable_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int=0; kwargs...) = variable_voltage_product_matrix(pm, n; kwargs...)

""
function variable_voltage_product_matrix{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int)
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(pm.ref[:nw][n][:buspairs])

    w_index = 1:length(keys(pm.ref[:nw][n][:bus]))
    lookup_w_index = Dict([(bi,i) for (i,bi) in enumerate(keys(pm.ref[:nw][n][:bus]))])

    WR = pm.var[:nw][n][:WR] = @variable(pm.model, 
        [1:length(keys(pm.ref[:nw][n][:bus])), 1:length(keys(pm.ref[:nw][n][:bus]))], Symmetric, basename="WR"
    )
    WI = pm.var[:nw][n][:WI] = @variable(pm.model, 
        [1:length(keys(pm.ref[:nw][n][:bus])), 1:length(keys(pm.ref[:nw][n][:bus]))], basename="WI"
    )

    # bounds on diagonal
    for (i, bus) in pm.ref[:nw][n][:bus]
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        setlowerbound(wr_ii, bus["vmin"]^2)
        setupperbound(wr_ii, bus["vmax"]^2)

        #this breaks SCS on the 3 bus exmple
        #setlowerbound(wi_ii, 0)
        #setupperbound(wi_ii, 0)
    end

    # bounds on off-diagonal
    for (i,j) in keys(pm.ref[:nw][n][:buspairs])
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
        setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

        setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
        setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
    end

    pm.ext[:nw][n][:lookup_w_index] = lookup_w_index
    return WR, WI
end

""
function constraint_voltage{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int=0)
    WR = pm.var[:nw][n][:WR]
    WI = pm.var[:nw][n][:WI]

    c = @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in keys(pm.ref[:nw][n][:buspairs])
    #    relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
    return Set([c])
end

"Do nothing, no way to represent this in these variables"
constraint_theta_ref{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, ref_bus::Int) = Set()

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

    c1 = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == sum(pg[g] for g in bus_gens) - pd - gs*w)
    c2 = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == sum(qg[g] for g in bus_gens) - qd + bs*w)
    return Set([c1, c2])
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

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    return Set([c1, c2])
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

    c1 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

""
function constraint_phase_angle_difference{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, angmin, angmax)
    w_fr_index = pm.ext[:nw][n][:lookup_w_index][f_bus]
    w_to_index = pm.ext[:nw][n][:lookup_w_index][t_bus]

    w_fr = pm.var[:nw][n][:WR][w_fr_index, w_fr_index]
    w_to = pm.var[:nw][n][:WR][w_to_index, w_to_index]
    wr   = pm.var[:nw][n][:WR][w_fr_index, w_to_index]
    wi   = pm.var[:nw][n][:WI][w_fr_index, w_to_index]

    c1 = @constraint(pm.model, wi <= tan(angmax)*wr)
    c2 = @constraint(pm.model, wi >= tan(angmin)*wr)

    c3 = cut_complex_product_and_angle_difference(pm.model, w_fr, w_to, wr, wi, angmin, angmax)

    return Set([c1, c2, c3])
end

""
function add_bus_voltage_setpoint{T <: AbstractWRMForm}(sol, pm::GenericPowerModel{T}, n::String)
    add_setpoint(sol, pm, n, "bus", "bus_i", "vm", :WR; scale = (x,item) -> sqrt(x), extract_var = (var,idx,item) -> var[pm.ext[:lookup_w_index][idx], pm.ext[:lookup_w_index][idx]])

    # What should the default value be?
    #add_setpoint(sol, pm, n, "bus", "bus_i", "va", :t; default_value = 0)
end

