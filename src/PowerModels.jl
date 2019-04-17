module PowerModels

using JSON
using InfrastructureModels
using MathProgBase
using JuMP
using Compat
using Memento

using Compat.LinearAlgebra
using Compat.SparseArrays

if VERSION < v"0.7.0-"
    import Compat: @__MODULE__

    import Compat: occursin
    import Compat: Nothing
    import Compat: round
    import Compat: findall
    import Compat: eachmatch
    import Compat: undef
    import Compat: pairs
    import Compat: stdout

    LinearAlgebra = Compat.LinearAlgebra

    mutable struct CholeskyResult
        L::Any
        p::Any
    end

    function cholesky(args...)
        v = cholfact(args...)
        return CholeskyResult(v[:L], v[:p])
    end

    function eachmatch(r::Regex, s::AbstractString; overlap::Bool=false)
        return eachmatch(r, s, overlap)
    end

    function pm_sum(v; dims::Int=0)
        return sum(v, dims)
    end
end

if VERSION > v"0.7.0-"
    pm_sum = sum

    function spdiagm(m, i::Int)
        return sparse(SparseArrays.spdiagm_internal(i => m)...)
    end

    function ind2sub(x, i)
        return Tuple(CartesianIndices(x)[i])
    end
end


# Create our module level logger (this will get precompiled)
const LOGGER = getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `PowerModels.LOGGER` won't be registered at runtime.
__init__() = Memento.register(LOGGER)

"Suppresses information and warning messages output by PowerModels, for fine grained control use the Memento package"
function silence()
    info(LOGGER, "Suppressing information and warning messages for the rest of this session.  Use the Memento package for more fine-grained control of logging.")
    setlevel!(getlogger(InfrastructureModels), "error")
    setlevel!(getlogger(PowerModels), "error")
end


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
include("core/relaxation_scheme.jl")
include("core/objective.jl")
include("core/solution.jl")
include("core/multiconductor.jl")

include("io/json.jl")

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
include("prob/opf.jl")
include("prob/opf_bf.jl")
include("prob/ots.jl")
include("prob/tnep.jl")
include("prob/test.jl")

include("util/obbt.jl")

end
