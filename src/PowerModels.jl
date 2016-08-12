isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using MathProgBase
using JuMP

include("common.jl")
include("matpower.jl")

include("core.jl")
include("core_var.jl")
include("core_const.jl")
include("core_obj.jl")

include("acp.jl")
include("dcp.jl")

include("opf.jl")
#include("ots.jl")
#include("pf.jl")
#include("misc.jl")

end