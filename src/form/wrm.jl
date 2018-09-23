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

    num_buses = length(keys(pm.ref[:nw][n][:bus]))

    w_index = 1:num_buses
    lookup_w_index = Dict([(bi,i) for (i,bi) in enumerate(keys(pm.ref[:nw][n][:bus]))])

    wr_start = ones(num_buses, num_buses)
    wi_start = zeros(num_buses, num_buses)

    WR = pm.var[:nw][n][:WR] = @variable(pm.model,
        [i=1:num_buses, j=1:num_buses], Symmetric, basename="$(n)_WR",
        start=wr_start[i,j]
    )
    WI = pm.var[:nw][n][:WI] = @variable(pm.model,
        [i=1:num_buses, j=1:num_buses], basename="$(n)_WI",
        start=wr_start[i,j]
    )

    # bounds on diagonal
    for (i, bus) in pm.ref[:nw][n][:bus]
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        if bounded
            set_lower_bound(wr_ii, bus["vmin"]^2)
            set_upper_bound(wr_ii, bus["vmax"]^2)

            #this breaks SCS on the 3 bus exmple
            #set_lower_bound(wi_ii, 0)
            #set_upper_bound(wi_ii, 0)
        else
             set_lower_bound(wr_ii, 0)
        end
    end

    # bounds on off-diagonal
    for (i,j) in keys(pm.ref[:nw][n][:buspairs])
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        if bounded
            set_upper_bound(WR[wi_idx, wj_idx], wr_max[(i,j)])
            set_lower_bound(WR[wi_idx, wj_idx], wr_min[(i,j)])

            set_upper_bound(WI[wi_idx, wj_idx], wi_max[(i,j)])
            set_lower_bound(WI[wi_idx, wj_idx], wi_min[(i,j)])
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


    @constraint(pm.model, [WR WI; -WI WR] in PSDCone())

    # place holder while debugging sdp constraint
    #for (i,j) in keys(pm.ref[:nw][n][:buspairs])
    #    InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
end
