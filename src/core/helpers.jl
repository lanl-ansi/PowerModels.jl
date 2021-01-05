nw_ids(pm::_IM.AbstractInfrastructureModel) = _IM.nw_ids(pm, pm_it_sym)
nws(pm::_IM.AbstractInfrastructureModel) = _IM.nws(pm, pm_it_sym)

ids(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol) = _IM.ids(pm, pm_it_sym, nw, key)
ids(pm::_IM.AbstractInfrastructureModel, key::Symbol; nw::Int=pm.cnw) = _IM.ids(pm, pm_it_sym, key; nw = nw)

ref(pm::_IM.AbstractInfrastructureModel, nw::Int = pm.cnw) = _IM.ref(pm, pm_it_sym, nw)
ref(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol) = _IM.ref(pm, pm_it_sym, nw, key)
ref(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol, idx) = _IM.ref(pm, pm_it_sym, nw, key, idx)
ref(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol, idx, param::String) = _IM.ref(pm, pm_it_sym, nw, key, idx, param)
ref(pm::_IM.AbstractInfrastructureModel, key::Symbol; nw::Int = pm.cnw) = _IM.ref(pm, pm_it_sym, key; nw = nw)
ref(pm::_IM.AbstractInfrastructureModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.ref(pm, pm_it_sym, key, idx; nw = nw)
ref(pm::_IM.AbstractInfrastructureModel, key::Symbol, idx, param::String; nw::Int = pm.cnw) = _IM.ref(pm, pm_it_sym, key, idx, param; nw = nw)

var(pm::_IM.AbstractInfrastructureModel, nw::Int = pm.cnw) = _IM.var(pm, pm_it_sym, nw)
var(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol) = _IM.var(pm, pm_it_sym, nw, key)
var(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol, idx) = _IM.var(pm, pm_it_sym, nw, key, idx)
var(pm::_IM.AbstractInfrastructureModel, key::Symbol; nw::Int = pm.cnw) = _IM.var(pm, pm_it_sym, key; nw = nw)
var(pm::_IM.AbstractInfrastructureModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.var(pm, pm_it_sym, key, idx; nw = nw)

con(pm::_IM.AbstractInfrastructureModel, nw::Int = pm.cnw) = _IM.con(pm, pm_it_sym; nw = nw)
con(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol) = _IM.con(pm, pm_it_sym, nw, key)
con(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol, idx) = _IM.con(pm, pm_it_sym, nw, key, idx)
con(pm::_IM.AbstractInfrastructureModel, key::Symbol; nw::Int = pm.cnw) = _IM.con(pm, pm_it_sym, key; nw = nw)
con(pm::_IM.AbstractInfrastructureModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.con(pm, pm_it_sym, key, idx; nw = nw)

sol(pm::_IM.AbstractInfrastructureModel, nw::Int = pm.cnw) = _IM.sol(pm, pm_it_sym; nw = nw)
sol(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol) = _IM.sol(pm, pm_it_sym, nw, key)
sol(pm::_IM.AbstractInfrastructureModel, nw::Int, key::Symbol, idx) = _IM.sol(pm, pm_it_sym, nw, key, idx)
sol(pm::_IM.AbstractInfrastructureModel, key::Symbol; nw::Int = pm.cnw) = _IM.sol(pm, pm_it_sym, key; nw = nw)
sol(pm::_IM.AbstractInfrastructureModel, key::Symbol, idx; nw::Int = pm.cnw) = _IM.sol(pm, pm_it_sym, key, idx; nw = nw)

ismultinetwork(pm::_IM.AbstractInfrastructureModel) = _IM.ismultinetwork(pm, pm_it_sym)
