isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using MathProgBase
using JuMP

include("io/matlab.jl")
include("io/matpower.jl")
include("io/json.jl")
include("io/common.jl")

include("core/base.jl")
include("core/data.jl")
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
