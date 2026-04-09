module PowerModels

import InfrastructureModels as _IM
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default
import JSON
import JuMP
import LinearAlgebra
import Logging
import NLsolve
import PrecompileTools
import SparseArrays

global _LOGGER

function __init__()
    logger_config!("info")
    return
end

silence() = logger_config!("error")

function _meta_formatter(l::Logging.LogLevel, _module, ::Any, id, file, line)
    color = Logging.default_logcolor(l)
    prefix = "$(_module) | $l]:"
    if Logging.Info <= l < Logging.Warn
        return color, prefix, ""
    end
    suffix = string("@ $(_module) ", Base.contractuser(file), ":$line")
    return color, prefix, suffix
end

function logger_config!(level::Logging.LogLevel)
    global _LOGGER =
        Logging.ConsoleLogger(stdout, level; meta_formatter = _meta_formatter)
    return
end

function logger_config!(level::String)
    if level == "error"
        logger_config!(Logging.Error)
    elseif level == "warn"
        logger_config!(Logging.Warn)
    elseif level == "info"
        logger_config!(Logging.Info)
    else
        @assert level == "debug"
        logger_config!(Logging.Debug)
    end
    return
end

macro _error(msg)
    return quote
        Logging.with_logger(() -> @error($msg), _LOGGER)
        error($msg)
    end |> esc
end

macro _warn(msg)
    return :(Logging.with_logger(() -> @warn($msg), _LOGGER)) |> esc
end

macro _debug(msg)
    return :(Logging.with_logger(() -> @debug($msg), _LOGGER)) |> esc
end

macro _info(msg)
    return :(Logging.with_logger(() -> @info($msg), _LOGGER)) |> esc
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
