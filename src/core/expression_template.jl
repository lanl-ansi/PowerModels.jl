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
function expression_voltage(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    @assert haskey(var(pm, nw), :inj_p)
    @assert haskey(var(pm, nw), :inj_q)

    if !haskey(var(pm, nw), :va)
        var(pm, nw)[:va] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw), :vm)
        var(pm, nw)[:vm] = Dict{Int,Any}()
    end

    am_inv = ref(pm, nw, :am_inv)
    expression_voltage(pm, nw, i, am_inv)
end


### Power Balance Expressions ###

"""
defines power injection at each bus
"""
function expression_power_injection(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if !haskey(var(pm, nw), :inj_p)
        var(pm, nw)[:inj_p] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw), :inj_q)
        var(pm, nw)[:inj_q] = Dict{Int,Any}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    expression_power_injection(pm, nw, i, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end



""
function expression_branch_flow_yt_from(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if !haskey(var(pm, nw), :p)
        var(pm, nw)[:p] = Dict{Tuple{Int,Int,Int},Any}()
    end
    if !haskey(var(pm, nw), :q)
        var(pm, nw)[:q] = Dict{Tuple{Int,Int,Int},Any}()
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    expression_branch_flow_yt_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end


""
function expression_branch_flow_yt_to(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if !haskey(var(pm, nw), :p)
        var(pm, nw)[:p] = Dict{Tuple{Int,Int,Int},Any}()
    end
    if !haskey(var(pm, nw), :q)
        var(pm, nw)[:q] = Dict{Tuple{Int,Int,Int},Any}()
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    expression_branch_flow_yt_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end



""
function expression_branch_flow_yt_from_ptdf(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if !haskey(var(pm, nw), :p)
        var(pm, nw)[:p] = Dict{Tuple{Int,Int,Int},Any}()
    end
    if !haskey(var(pm, nw), :q)
        var(pm, nw)[:q] = Dict{Tuple{Int,Int,Int},Any}()
    end

    if !haskey(var(pm, nw), :va)
        var(pm, nw)[:va] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw), :vm)
        var(pm, nw)[:vm] = Dict{Int,Any}()
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    sm = ref(pm, nw, :sm)
    if !haskey(var(pm, nw, :va), f_bus)
        expression_voltage(pm, nw, f_bus, sm)
    end
    if !haskey(var(pm, nw, :va), t_bus)
        expression_voltage(pm, nw, t_bus, sm)
    end

    expression_branch_flow_yt_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end


""
function expression_branch_flow_yt_to_ptdf(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if !haskey(var(pm, nw), :p)
        var(pm, nw)[:p] = Dict{Tuple{Int,Int,Int},Any}()
    end
    if !haskey(var(pm, nw), :q)
        var(pm, nw)[:q] = Dict{Tuple{Int,Int,Int},Any}()
    end

    if !haskey(var(pm, nw), :va)
        var(pm, nw)[:va] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw), :vm)
        var(pm, nw)[:vm] = Dict{Int,Any}()
    end

    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    tr, ti = calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    sm = ref(pm, nw, :sm)
    if !haskey(var(pm, nw, :va), f_bus)
        expression_voltage(pm, nw, f_bus, sm)
    end
    if !haskey(var(pm, nw, :va), t_bus)
        expression_voltage(pm, nw, t_bus, sm)
    end

    expression_branch_flow_yt_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end