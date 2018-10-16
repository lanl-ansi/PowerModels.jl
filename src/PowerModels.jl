isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using InfrastructureModels
using MathProgBase
using JuMP
using Compat
using Memento

import Compat: @__MODULE__

if VERSION < v"0.7.0-"
    import Compat: occursin
    import Compat: Nothing
    import Compat: round
end

if VERSION > v"0.7.0-"
    using LinearAlgebra
    using SparseArrays
end


# Create our module level logger (this will get precompiled)
const LOGGER = getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `PowerModels.LOGGER` won't be registered at runtime.
__init__() = Memento.register(LOGGER)

include("io/matpower.jl")
include("io/common.jl")
include("io/pti.jl")
include("io/psse.jl")

include("core/data.jl")
include("core/ref.jl")
include("core/base.jl")
include("core/variable.jl")
include("core/constraint_template.jl")
include("core/constraint.jl")
include("core/relaxation_scheme.jl")
include("core/objective.jl")
include("core/solution.jl")
include("core/multiconductor.jl")

include("form/acp.jl")
include("form/acr.jl")
include("form/act.jl")
include("form/dcp.jl")
include("form/bf.jl")
include("form/wr.jl")
include("form/wrm.jl")
include("form/shared.jl")

include("prob/opb.jl")
include("prob/pf.jl")
include("prob/pf_bf.jl")
include("prob/opf.jl")
include("prob/opf_bf.jl")
include("prob/ots.jl")
include("prob/tnep.jl")
include("prob/test.jl")

include("util/obbt.jl")

end
