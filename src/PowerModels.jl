isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using MathProgBase
using JuMP

include("io/matpower.jl")
include("io/json.jl")
include("io/common.jl")

include("core/base.jl")
include("core/variable.jl")
include("core/constraint.jl")
include("core/relaxation_scheme.jl")
include("core/objective.jl")
include("core/common.jl")

include("form/acp.jl")
include("form/dcp.jl")
include("form/wr.jl")
include("form/wrm.jl")

include("prob/opf.jl")
#include("prob/ots.jl")
#include("prob/pf.jl")
#include("prob/misc.jl")

end