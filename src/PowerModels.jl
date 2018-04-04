isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using InfrastructureModels
using MathProgBase
using JuMP
using Compat
using Memento

import Compat: @__MODULE__

# Create our module level logger (this will get precompiled)
const LOGGER = getlogger(@__MODULE__)
setlevel!(LOGGER, "info")

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `PowerModels.LOGGER` won't be registered at runtime.
__init__() = Memento.register(LOGGER)

include("io/matpower.jl")
include("io/json.jl")
include("io/common.jl")
include("io/pti.jl")

include("core/data.jl")
include("core/base.jl")
include("core/variable.jl")
include("core/constraint_template.jl")
include("core/constraint.jl")
include("core/relaxation_scheme.jl")
include("core/objective.jl")
include("core/solution.jl")

include("form/acp.jl")
include("form/acr.jl")
include("form/act.jl")
include("form/dcp.jl")
include("form/wr.jl")
include("form/wrm.jl")
include("form/shared.jl")

include("prob/pf.jl")
include("prob/opf.jl")
include("prob/ots.jl")
include("prob/tnep.jl")

end
