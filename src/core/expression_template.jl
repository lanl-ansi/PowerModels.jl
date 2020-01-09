#
# Expression Template Definitions
#
# Expression templates help simplify model definition across multiple Power
# Flow formulations by populating expressions for network quantities that
# do not already have an explicit definition in a model.  The expression
# template's job is to extract the required parameters from a given network
# data structure and pass the data as named arguments to the Power Flow
# formulation implementations
#
# Expression templates should always be defined over "AbstractPowerModel"
# and should never refer to model variables
#


### Voltage Expressions ###

"""
defines va in terms of power injections
"""
function expression_voltage(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    @assert haskey(var(pm, nw, cnd), :inj_p)
    @assert haskey(var(pm, nw, cnd), :inj_q)

    if !haskey(var(pm, nw, cnd), :va)
        var(pm, nw, cnd)[:va] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw, cnd), :vm)
        var(pm, nw, cnd)[:vm] = Dict{Int,Any}()
    end

    am_inv = ref(pm, nw, :am_inv)
    expression_voltage(pm, nw, cnd, i, am_inv)
end


### Power Balance Expressions ###

"""
defines power injection at each bus
"""
function expression_power_injection(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(var(pm, nw, cnd), :inj_p)
        var(pm, nw, cnd)[:inj_p] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw, cnd), :inj_q)
        var(pm, nw, cnd)[:inj_q] = Dict{Int,Any}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd", cnd) for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd", cnd) for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs", cnd) for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs", cnd) for k in bus_shunts)

    expression_power_injection(pm, nw, cnd, i, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end



""
function expression_branch_flow_from(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(var(pm, nw, cnd), :p)
        var(pm, nw, cnd)[:p] = Dict{Tuple{Int,Int,Int},Any}()
    end
    if !haskey(var(pm, nw, cnd), :q)
        var(pm, nw, cnd)[:q] = Dict{Tuple{Int,Int,Int},Any}()
    end

    if !haskey(var(pm, nw, cnd), :va)
        var(pm, nw, cnd)[:va] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw, cnd), :vm)
        var(pm, nw, cnd)[:vm] = Dict{Int,Any}()
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"][cnd]
    b_fr = branch["b_fr"][cnd]
    tm = branch["tap"][cnd]

    if haskey(branch, "rate_a")
        #sm_inv = ref(pm, nw, :sm_inv)
        sm = ref(pm, nw, :sm)
        expression_voltage(pm, nw, cnd, f_bus, sm)
        expression_voltage(pm, nw, cnd, t_bus, sm)

        expression_branch_flow_from(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_fr, b_fr, tr[cnd], ti[cnd], tm)
    end
end


""
function expression_branch_flow_to(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(var(pm, nw, cnd), :p)
        var(pm, nw, cnd)[:p] = Dict{Tuple{Int,Int,Int},Any}()
    end
    if !haskey(var(pm, nw, cnd), :q)
        var(pm, nw, cnd)[:q] = Dict{Tuple{Int,Int,Int},Any}()
    end

    if !haskey(var(pm, nw, cnd), :va)
        var(pm, nw, cnd)[:va] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw, cnd), :vm)
        var(pm, nw, cnd)[:vm] = Dict{Int,Any}()
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"][cnd]
    b_to = branch["b_to"][cnd]
    tm = branch["tap"][cnd]

    if haskey(branch, "rate_a")
        #sm_inv = ref(pm, nw, :sm_inv)
        sm = ref(pm, nw, :sm)
        expression_voltage(pm, nw, cnd, f_bus, sm)
        expression_voltage(pm, nw, cnd, t_bus, sm)

        expression_branch_flow_to(pm, nw, cnd, f_bus, t_bus, f_idx, t_idx, g[cnd,cnd], b[cnd,cnd], g_to, b_to, tr[cnd], ti[cnd], tm)
    end
end