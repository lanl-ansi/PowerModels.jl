module PowerModels

import LinearAlgebra, SparseArrays

import JSON
import Memento

import NLsolve

import JuMP
import MathOptInterface
const _MOI = MathOptInterface

import InfrastructureModels
import InfrastructureModels: ids, ref, var, con, sol, nw_ids, nws, optimize_model!, @im_fields
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


include("io/matpower.jl")
include("io/common.jl")
include("io/pti.jl")
include("io/psse.jl")

include("core/data.jl")
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


# this must come last to support automated export
include("core/export.jl")

# deprecate section
@deprecate run_nfa_opb(file, optimizer; kwargs...) solve_nfa_opb(file, optimizer; kwargs...)
@deprecate run_opb(file, model_type::Type, optimizer; kwargs...) solve_opb(file, model_type::Type, optimizer; kwargs...)
@deprecate run_opf_bf(file, model_type::Type{T}, optimizer; kwargs...) where T <: AbstractBFModel solve_opf_bf(file, model_type::Type{T}, optimizer; kwargs...) where T <: AbstractBFModel
@deprecate run_mn_opf_bf(file, model_type::Type, optimizer; kwargs...) solve_mn_opf_bf(file, model_type::Type, optimizer; kwargs...) 
@deprecate run_opf_iv(file, model_constructor, optimizer; kwargs...) solve_opf_iv(file, model_constructor, optimizer; kwargs...)
@deprecate run_ac_opf(file, optimizer; kwargs...) solve_ac_opf(file, optimizer; kwargs...)
@deprecate run_dc_opf(file, optimizer; kwargs...) solve_dc_opf(file, optimizer; kwargs...)
@deprecate run_opf(file, model_type::Type, optimizer; kwargs...) solve_opf(file, model_type::Type, optimizer; kwargs...)
@deprecate run_mn_opf(file, model_type::Type, optimizer; kwargs...) solve_mn_opf(file, model_type::Type, optimizer; kwargs...)
@deprecate run_mn_opf_strg(file, model_type::Type, optimizer; kwargs...) solve_mn_opf_strg(file, model_type::Type, optimizer; kwargs...)
@deprecate run_opf_ptdf(file, model_type::Type, optimizer; full_inverse=false, kwargs...) solve_opf_ptdf(file, model_type::Type, optimizer; full_inverse=false, kwargs...)
@deprecate run_pf_bf(file, model_type::Type, optimizer; kwargs...) solve_pf_bf(file, model_type::Type, optimizer; kwargs...)
@deprecate run_pf_iv(file, model_constructor, optimizer; kwargs...) solve_pf_iv(file, model_constructor, optimizer; kwargs...)
@deprecate run_tnep(file, model_type::Type, optimizer; kwargs...) solve_tnep(file, model_type::Type, optimizer; kwargs...)

end
