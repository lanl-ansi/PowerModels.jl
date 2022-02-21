module PowerModels

import LinearAlgebra, SparseArrays

import JSON
import Memento

import NLsolve

import JuMP

import InfrastructureModels
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default
const _IM = InfrastructureModels

# Create our module level logger (this will get precompiled)
const _LOGGER = Memento.getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `PowerModels._LOGGER` won't be registered at runtime.
__init__() = Memento.register(_LOGGER)

"Suppresses information and warning messages output by PowerModels, for fine grained control use the Memento package"
function silence()
    Memento.info(_LOGGER, "Suppressing information and warning messages for the rest of this session.  Use the Memento package for more fine-grained control of logging.")
    Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
    Memento.setlevel!(Memento.getlogger(PowerModels), "error")
end

"alows the user to set the logging level without the need to add Memento"
function logger_config!(level)
    Memento.config!(Memento.getlogger("PowerModels"), level)
end

const _pm_global_keys = Set(["time_series", "per_unit"])
const pm_it_name = "pm"
const pm_it_sym = Symbol(pm_it_name)


include("io/matpower.jl")
include("io/common.jl")
include("io/pti.jl")
include("io/psse.jl")

include("core/data.jl")
include("core/data_basic.jl")
include("core/ref.jl")
include("core/base.jl")
include("core/types.jl")
include("core/variable.jl")
include("core/constraint_template.jl")
include("core/constraint.jl")
include("core/expression_template.jl")
include("core/relaxation_scheme.jl")
include("core/objective.jl")
include("core/solution.jl")
include("core/admittance_matrix.jl")

include("io/json.jl")

include("form/iv.jl")

include("form/acp.jl")
include("form/acr.jl")
include("form/act.jl")
include("form/apo.jl")
include("form/dcp.jl")
include("form/lpac.jl")
include("form/bf.jl")
include("form/wr.jl")
include("form/wrm.jl")
include("form/shared.jl")

include("prob/opb.jl")
include("prob/pf.jl")
include("prob/pf_bf.jl")
include("prob/pf_iv.jl")
include("prob/opf.jl")
include("prob/opf_bf.jl")
include("prob/opf_iv.jl")
include("prob/ots.jl")
include("prob/tnep.jl")
include("prob/test.jl")

include("util/obbt.jl")
include("util/flow_limit_cuts.jl")


# function deprecation warnings
# can be removed in a breaking release after 09/01/2022
function run_model(args...; kwargs...)
    @warn("the function run_model has been replaced with solve_model", maxlog=1)
    solve_model(args...; kwargs...)
end

function run_pf(args...; kwargs...)
    @warn("the function run_pf has been replaced with solve_pf", maxlog=1)
    solve_pf(args...; kwargs...)
end
function run_ac_pf(args...; kwargs...)
    @warn("the function run_ac_pf has been replaced with solve_ac_pf", maxlog=1)
    solve_ac_pf(args...; kwargs...)
end
function run_dc_pf(args...; kwargs...)
    @warn("the function run_dc_pf has been replaced with solve_dc_pf", maxlog=1)
    solve_dc_pf(args...; kwargs...)
end
function run_pf_bf(args...; kwargs...)
    @warn("the function run_pf_bf has been replaced with solve_pf_bf", maxlog=1)
    solve_pf_bf(args...; kwargs...)
end
function run_pf_iv(args...; kwargs...)
    @warn("the function run_pf_iv has been replaced with solve_pf_iv", maxlog=1)
    solve_pf_iv(args...; kwargs...)
end


function run_opf(args...; kwargs...)
    @warn("the function run_opf has been replaced with solve_opf", maxlog=1)
    solve_opf(args...; kwargs...)
end
function run_ac_opf(args...; kwargs...)
    @warn("the function run_ac_opf has been replaced with solve_ac_opf", maxlog=1)
    solve_ac_opf(args...; kwargs...)
end
function run_dc_opf(args...; kwargs...)
    @warn("the function run_dc_opf has been replaced with solve_dc_opf", maxlog=1)
    solve_dc_opf(args...; kwargs...)
end

function run_mn_opf(args...; kwargs...)
    @warn("the function run_mn_opf has been replaced with solve_mn_opf", maxlog=1)
    solve_mn_opf(args...; kwargs...)
end
function run_mn_opf_strg(args...; kwargs...)
    @warn("the function run_mn_opf_strg has been replaced with solve_mn_opf_strg", maxlog=1)
    solve_mn_opf_strg(args...; kwargs...)
end
function run_opf_ptdf(args...; kwargs...)
    @warn("the function run_opf_ptdf has been replaced with solve_opf_ptdf", maxlog=1)
    solve_opf_ptdf(args...; kwargs...)
end

function run_opf_bf(args...; kwargs...)
    @warn("the function run_opf_bf has been replaced with solve_opf_bf", maxlog=1)
    solve_opf_bf(args...; kwargs...)
end
function run_mn_opf_bf_strg(args...; kwargs...)
    @warn("the function run_mn_opf_bf_strg has been replaced with solve_mn_opf_bf_strg", maxlog=1)
    solve_mn_opf_bf_strg(args...; kwargs...)
end
function run_opf_iv(args...; kwargs...)
    @warn("the function run_opf_iv has been replaced with solve_opf_iv", maxlog=1)
    solve_opf_iv(args...; kwargs...)
end

function run_opb(args...; kwargs...)
    @warn("the function run_opb has been replaced with solve_opb", maxlog=1)
    solve_opb(args...; kwargs...)
end
function run_nfa_opb(args...; kwargs...)
    @warn("the function run_nfa_opb has been replaced with solve_nfa_opb", maxlog=1)
    solve_nfa_opb(args...; kwargs...)
end

function run_ots(args...; kwargs...)
    @warn("the function run_ots has been replaced with solve_ots", maxlog=1)
    solve_ots(args...; kwargs...)
end
function run_tnep(args...; kwargs...)
    @warn("the function run_tnep has been replaced with solve_tnep", maxlog=1)
    solve_tnep(args...; kwargs...)
end

function run_opf_branch_power_cuts(args...; kwargs...)
    @warn("the function run_opf_branch_power_cuts has been replaced with solve_opf_branch_power_cuts", maxlog=1)
    solve_opf_branch_power_cuts(args...; kwargs...)
end
function run_opf_branch_power_cuts!(args...; kwargs...)
    @warn("the function run_opf_branch_power_cuts! has been replaced with solve_opf_branch_power_cuts!", maxlog=1)
    solve_opf_branch_power_cuts!(args...; kwargs...)
end
function run_opf_ptdf_branch_power_cuts(args...; kwargs...)
    @warn("the function run_opf_ptdf_branch_power_cuts has been replaced with solve_opf_ptdf_branch_power_cuts", maxlog=1)
    solve_opf_ptdf_branch_power_cuts(args...; kwargs...)
end
function run_opf_ptdf_branch_power_cuts!(args...; kwargs...)
    @warn("the function run_opf_ptdf_branch_power_cuts! has been replaced with solve_opf_ptdf_branch_power_cuts!", maxlog=1)
    solve_opf_ptdf_branch_power_cuts!(args...; kwargs...)
end
function run_obbt_opf!(args...; kwargs...)
    @warn("the function run_obbt_opf! has been replaced with solve_obbt_opf!", maxlog=1)
    solve_obbt_opf!(args...; kwargs...)
end


# this must come last to support automated export
include("core/export.jl")

end
