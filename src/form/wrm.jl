export
    SDPWRMPowerModel, SDPWRMForm

""
abstract type AbstractWRMForm <: AbstractConicPowerFormulation end

""
abstract type SDPWRMForm <: AbstractWRMForm end

"""
Semi-definite relaxation of AC OPF

Originally proposed by:
```
@article{BAI2008383,
  author = "Xiaoqing Bai and Hua Wei and Katsuki Fujisawa and Yong Wang",
  title = "Semidefinite programming for optimal power flow problems",
  journal = "International Journal of Electrical Power & Energy Systems",
  volume = "30",
  number = "6",
  pages = "383 - 392",
  year = "2008",
  issn = "0142-0615",
  doi = "https://doi.org/10.1016/j.ijepes.2007.12.003",
  url = "http://www.sciencedirect.com/science/article/pii/S0142061507001378",
}
```
First paper to use "W" variables in the BIM of AC OPF:
```
@INPROCEEDINGS{6345272,
  author={S. Sojoudi and J. Lavaei},
  title={Physics of power networks makes hard optimization problems easy to solve},
  booktitle={2012 IEEE Power and Energy Society General Meeting},
  year={2012},
  month={July},
  pages={1-8},
  doi={10.1109/PESGM.2012.6345272},
  ISSN={1932-5517}
}
```
"""
const SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}

""
SDPWRMPowerModel(data::Dict{String,Any}; kwargs...) = GenericPowerModel(data, SDPWRMForm; kwargs...)


""
function variable_voltage(pm::GenericPowerModel{T}; nw::Int=pm.cnw, cnd::Int=pm.ccnd, bounded = true) where T <: AbstractWRMForm
    wr_min, wr_max, wi_min, wi_max = calc_voltage_product_bounds(ref(pm, nw, :buspairs), cnd)
    bus_ids = ids(pm, nw, :bus)

    w_index = 1:length(bus_ids)
    lookup_w_index = Dict([(bi,i) for (i,bi) in enumerate(bus_ids)])

    WR = var(pm, nw, cnd)[:WR] = @variable(pm.model,
        [1:length(bus_ids), 1:length(bus_ids)], Symmetric, basename="$(nw)_$(cnd)_WR"
    )
    WI = var(pm, nw, cnd)[:WI] = @variable(pm.model,
        [1:length(bus_ids), 1:length(bus_ids)], basename="$(nw)_$(cnd)_WI"
    )

    # bounds on diagonal
    for (i, bus) in ref(pm, nw, :bus)
        w_idx = lookup_w_index[i]
        wr_ii = WR[w_idx,w_idx]
        wi_ii = WR[w_idx,w_idx]

        if bounded
            setlowerbound(wr_ii, (bus["vmin"][cnd])^2)
            setupperbound(wr_ii, (bus["vmax"][cnd])^2)

            #this breaks SCS on the 3 bus exmple
            #setlowerbound(wi_ii, 0)
            #setupperbound(wi_ii, 0)
        else
             setlowerbound(wr_ii, 0)
        end
    end

    # bounds on off-diagonal
    for (i,j) in ids(pm, nw, :buspairs)
        wi_idx = lookup_w_index[i]
        wj_idx = lookup_w_index[j]

        if bounded
            setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
            setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

            setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
            setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
        end
    end

    var(pm, nw, cnd)[:w] = Dict{Int,Any}()
    for (i, bus) in ref(pm, nw, :bus)
        w_idx = lookup_w_index[i]
        var(pm, nw, cnd, :w)[i] = WR[w_idx,w_idx]
    end

    var(pm, nw, cnd)[:wr] = Dict{Tuple{Int,Int},Any}()
    var(pm, nw, cnd)[:wi] = Dict{Tuple{Int,Int},Any}()
    for (i,j) in ids(pm, nw, :buspairs)
        w_fr_index = lookup_w_index[i]
        w_to_index = lookup_w_index[j]

        var(pm, nw, cnd, :wr)[(i,j)] = WR[w_fr_index, w_to_index]
        var(pm, nw, cnd, :wi)[(i,j)] = WI[w_fr_index, w_to_index]
    end

end


""
function constraint_voltage(pm::GenericPowerModel{T}, nw::Int, cnd::Int) where T <: AbstractWRMForm
    WR = var(pm, nw, cnd)[:WR]
    WI = var(pm, nw, cnd)[:WI]

    @SDconstraint(pm.model, [WR WI; -WI WR] >= 0)

    # place holder while debugging sdp constraint
    #for (i,j) in ids(pm, nw, :buspairs)
    #    InfrastructureModels.relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    #end
end


""
function constraint_current_limit(pm::GenericPowerModel{T}, n::Int, c::Int, f_idx, c_rating_a) where T <: AbstractWRMForm
    l,i,j = f_idx
    t_idx = (l,j,i)

    w_fr = var(pm, n, c, :w, i)
    w_to = var(pm, n, c, :w, j)

    p_fr = var(pm, n, c, :p, f_idx)
    q_fr = var(pm, n, c, :q, f_idx)
    @constraint(pm.model, norm([2*p_fr; 2*q_fr; w_fr*c_rating_a^2-1]) <= w_fr*c_rating_a^2+1)

    p_to = var(pm, n, c, :p, t_idx)
    q_to = var(pm, n, c, :q, t_idx)
    @constraint(pm.model, norm([2*p_to; 2*q_to; w_to*c_rating_a^2-1]) <= w_to*c_rating_a^2+1)
end


