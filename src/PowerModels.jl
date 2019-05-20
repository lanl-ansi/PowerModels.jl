module PowerModels

import LinearAlgebra, SparseArrays

import InfrastructureModels
import JSON
import JuMP
import Memento

import MathOptInterface
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

# Create our module level logger (this will get precompiled)
const LOGGER = Memento.getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `PowerModels.LOGGER` won't be registered at runtime.
__init__() = Memento.register(LOGGER)

"Suppresses information and warning messages output by PowerModels, for fine grained control use the Memento package"
function silence()
    Memento.info(LOGGER, "Suppressing information and warning messages for the rest of this session.  Use the Memento package for more fine-grained control of logging.")
    Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
    Memento.setlevel!(Memento.getlogger(PowerModels), "error")
end

include("io/matpower.jl")
include("io/common.jl")
include("io/pti.jl")
include("io/psse.jl")

include("core/export.jl")
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
