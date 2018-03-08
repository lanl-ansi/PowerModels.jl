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

    pm.var[:nw][n][:w] = Dict{Int,Any}()
    for (i, bus) in pm.ref[:nw][n][:bus]
        w_idx = lookup_w_index[i]
        pm.var[:nw][n][:w][i] = WR[w_idx,w_idx]
    end

    pm.var[:nw][n][:wr] = Dict{Tuple{Int,Int},Any}()
    pm.var[:nw][n][:wi] = Dict{Tuple{Int,Int},Any}()
    for (i,j) in keys(pm.ref[:nw][n][:buspairs])
        w_fr_index = lookup_w_index[i]
        w_to_index = lookup_w_index[j]

        pm.var[:nw][n][:wr][(i,j)] = WR[w_fr_index, w_to_index]
        pm.var[:nw][n][:wi][(i,j)] = WI[w_fr_index, w_to_index]
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
function constraint_voltage_angle_difference{T <: AbstractWRMForm}(pm::GenericPowerModel{T}, n::Int, f_bus, t_bus, angmin, angmax)
    w_fr = pm.var[:nw][n][:w][f_bus]
    w_to = pm.var[:nw][n][:w][t_bus]
    wr = pm.var[:nw][n][:wr][(f_bus, t_bus)]
    wi = pm.var[:nw][n][:wi][(f_bus, t_bus)]

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

