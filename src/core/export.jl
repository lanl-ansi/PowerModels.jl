# PowerModels exports everything except internal symbols, which are defined as
# those whose name starts with an underscore. If you don't want all of these
# symbols in your environment, then use `import PowerModels` instead of
# `using PowerModels`.

# Do not add PowerModels-defined symbols to this exclude list. Instead, rename
# them with an underscore.

const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]

for sym in names(@__MODULE__, all=true)
    sym_string = string(sym)
    if sym in _EXCLUDE_SYMBOLS || startswith(sym_string, "_") || startswith(sym_string, "@_")
        continue
    end
    if !(Base.isidentifier(sym) || (startswith(sym_string, "@") &&
         Base.isidentifier(sym_string[2:end])))
       continue
    end
    #println("$(sym)")
    @eval export $sym
end


# the follow items are also exported for user-friendlyness when calling
# `using PowerModels`

# so that users do not need to import JuMP to use a solver with PowerModels
import JuMP: with_optimizer
export with_optimizer

# so that users do not need to import JuMP to use a solver with PowerModels
# note does appear to be work with JuMP v0.20, but throws "could not import" warning
import JuMP: optimizer_with_attributes
export optimizer_with_attributes

import MathOptInterface: TerminationStatusCode
export TerminationStatusCode

import MathOptInterface: ResultStatusCode
export ResultStatusCode

for status_code_enum in [TerminationStatusCode, ResultStatusCode]
    for status_code in instances(status_code_enum)
        @eval import MathOptInterface: $(Symbol(status_code))
        @eval export $(Symbol(status_code))
    end
end

# from InfrastructureModels
export ids, ref, var, con, sol, nw_ids, nws, optimize_model!

# for backward compat with previous versions, drop on PowerModels v0.16
import InfrastructureModels: sol_component_fixed, sol_component_value, sol_component_value_edge, build_solution, build_result, report_duals, ismultinetwork
export sol_component_fixed, sol_component_value, sol_component_value_edge, build_solution, build_result, report_duals, ismultinetwork

