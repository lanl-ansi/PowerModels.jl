module PowerModels

import InfrastructureModels as _IM
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default
import JSON
import JuMP
import LinearAlgebra
import Logging
import LoggingExtras
import NLsolve
import PrecompileTools
import SparseArrays

# Setup Logging
include("core/logging.jl")
_DEFAULT_LOGGER = Logging.current_logger()
_LOGGER = Logging.ConsoleLogger(; meta_formatter=PowerModels._pm_metafmt)
function __init__()
    global _DEFAULT_LOGGER = Logging.current_logger()
    global _LOGGER = Logging.ConsoleLogger(; meta_formatter=PowerModels._pm_metafmt)

    Logging.global_logger(_LOGGER)
end

"Suppresses information and warning messages output by PowerModels, for fine grained control use the Logging standard library"
function silence()
    silence!()
end

"allows the user to set the logging level without the need to add Logging"
function logger_config!(level)
    set_logging_level!(Symbol(uppercase(level[1]) * level[2:end]))
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

# this must come last to support automated export
include("core/export.jl")

PrecompileTools.@setup_workload begin
    logger_config!("error")  # Turn off logging for this precompile block
    case3 = joinpath(dirname(@__DIR__), "test/data/matpower/case3.m")
    case9 = joinpath(dirname(@__DIR__), "test/data/matpower/case9.m")
    PrecompileTools.@compile_workload begin
        for case in [case3, case9]
            data = parse_file(case)
            _ = instantiate_model(data, ACPPowerModel, build_opf)
            _ = instantiate_model(data, ACPPowerModel, build_pf)
            _ = instantiate_model(data, DCPPowerModel, build_opf)
            _ = instantiate_model(data, DCPPowerModel, build_pf)
        end
        _ = compute_ac_pf(case9)
        _ = compute_dc_pf(case9)
    end
    logger_config!("info")   # Re-enable default logging
end

# Deprecations to be removed in the next breaking release

@deprecate resolve_swithces! resolve_switches!

# This import was retained for anyone using PowerModels.InfrastructureModels.
# The suggested approach is for users to import InfrastructureModels in their
# own code.
import InfrastructureModels

end  # module PowerModels
