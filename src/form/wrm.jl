export
    SDPWRMPowerModel, SDPWRMForm

""
abstract type AbstractWRMForm <: AbstractConicPowerFormulation end

""
abstract type SDPWRMForm <: AbstractWRMForm end

""
const SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}

""
SDPWRMPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPWRMForm; kwargs...)


""
function variable_voltage(pm::GenericPowerModel{T}, n::Int=pm.cnw; bounded = true) where T <: AbstractWRMForm
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
            setlower_bound(wr_ii, bus["vmin"]^2)
            setupper_bound(wr_ii, bus["vmax"]^2)

            #this breaks SCS on the 3 bus exmple
            #setlower_bound(wi_ii, 0)
            #setupper_bound(wi_ii, 0)
        else
             setlower_bound(wr_ii, 0)
        end
    end

    # bounds on off-diagonal
    for (i,j) in keys(pm.ref[:nw][n][:buspairs])
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        if bounded
            setupper_bound(WR[wi_idx, wj_idx], wr_max[(i,j)])
            setlower_bound(WR[wi_idx, wj_idx], wr_min[(i,j)])

            setupper_bound(WI[wi_idx, wj_idx], wi_max[(i,j)])
            setlower_bound(WI[wi_idx, wj_idx], wi_min[(i,j)])
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

end


""
function constraint_voltage(pm::GenericPowerModel{T}, n::Int) where T <: AbstractWRMForm
    WR = pm.var[:nw][n][:WR]
    WI = pm.var[:nw][n][:WI]

    @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in keys(pm.ref[:nw][n][:buspairs])
    #    InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
end
