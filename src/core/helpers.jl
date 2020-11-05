nw_ids(pm::AbstractPowerModel) = _IM.nw_ids(pm, :ep)
nws(pm::AbstractPowerModel) = _IM.nws(pm, :ep)

ids(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.ids(pm, :ep, nw, key)
ids(pm::AbstractPowerModel, key::Symbol; nw::Int=pm.cnw) = _IM.ids(pm, :ep, key; nw = nw)

ref(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.ref(pm, :ep, nw)
ref(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.ref(pm, :ep, nw, key)
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.ref(pm, :ep, nw, key, idx)
ref(pm::AbstractPowerModel, nw::Int, key::Symbol, idx, param::String) = _IM.ref(pm, :ep, nw, key, idx, param)
ref(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.ref(pm, :ep, key; nw = nw)
ref(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.ref(pm, :ep, key, idx; nw = nw)
ref(pm::AbstractPowerModel, key::Symbol, idx, param::String; nw::Int = pm.cnw) = _IM.ref(pm, :ep, key, idx, param; nw = nw)

var(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.var(pm, :ep, nw)
var(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.var(pm, :ep, nw, key)
var(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.var(pm, :ep, nw, key, idx)
var(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.var(pm, :ep, key; nw = nw)
var(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.var(pm, :ep, key, idx; nw = nw)

con(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.con(pm, :ep; nw = nw)
con(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.con(pm, :ep, nw, key)
con(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.con(pm, :ep, nw, key, idx)
con(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.con(pm, :ep, key; nw = nw)
con(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.con(pm, :ep, key, idx; nw = nw)

sol(pm::AbstractPowerModel, nw::Int = pm.cnw) = _IM.sol(pm, :ep; nw = nw)
sol(pm::AbstractPowerModel, nw::Int, key::Symbol) = _IM.sol(pm, :ep, nw, key)
sol(pm::AbstractPowerModel, nw::Int, key::Symbol, idx) = _IM.sol(pm, :ep, nw, key, idx)
sol(pm::AbstractPowerModel, key::Symbol; nw::Int = pm.cnw) = _IM.sol(pm, :ep, key; nw = nw)
sol(pm::AbstractPowerModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.sol(pm, :ep, key, idx; nw = nw)

ismultinetwork(pm::AbstractPowerModel) = _IM.ismultinetwork(pm, :ep)
