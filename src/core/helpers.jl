nw_ids(pm::AbstractPowerModel) = _IM.nw_ids(pm, _pm_it_sym)
nws(pm::AbstractPowerModel) = _IM.nws(pm, _pm_it_sym)

ids(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.ids(pm, _pm_it_sym, nw, key)
ids(pm::AbstractPowerModel, key::Symbol; nw::Int=pm.cnw) = _IM.ids(pm, _pm_it_sym, key; nw = nw)

ref(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.ref(pm, _pm_it_sym, nw)
ref(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.ref(pm, _pm_it_sym, nw, key)
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.ref(pm, _pm_it_sym, nw, key, idx)
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx, param::String) = _IM.ref(pm, _pm_it_sym, nw, key, idx, param)
ref(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.ref(pm, _pm_it_sym, key; nw = nw)
ref(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.ref(pm, _pm_it_sym, key, idx; nw = nw)
ref(pm::AbstractPowerModel, key::Symbol, idx, param::String; nw::Int = pm.cnw) = _IM.ref(pm, _pm_it_sym, key, idx, param; nw = nw)

var(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.var(pm, _pm_it_sym, nw)
var(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.var(pm, _pm_it_sym, nw, key)
var(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.var(pm, _pm_it_sym, nw, key, idx)
var(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.var(pm, _pm_it_sym, key; nw = nw)
var(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.var(pm, _pm_it_sym, key, idx; nw = nw)

con(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.con(pm, _pm_it_sym; nw = nw)
con(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.con(pm, _pm_it_sym, nw, key)
con(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.con(pm, _pm_it_sym, nw, key, idx)
con(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.con(pm, _pm_it_sym, key; nw = nw)
con(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.con(pm, _pm_it_sym, key, idx; nw = nw)

sol(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.sol(pm, _pm_it_sym; nw = nw)
sol(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.sol(pm, _pm_it_sym, nw, key)
sol(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.sol(pm, _pm_it_sym, nw, key, idx)
sol(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.sol(pm, _pm_it_sym, key; nw = nw)
sol(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.sol(pm, _pm_it_sym, key, idx; nw = nw)

ismultinetwork(pm::AbstractPowerModel) = _IM.ismultinetwork(pm, _pm_it_sym)
