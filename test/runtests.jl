using PowerModels
using FactCheck
using Base.Test

include("solvers.jl")

include("output.jl")

include("matpower.jl")


# used by OTS and Loadshed TS models
function check_br_status(sol)
    for (idx,val) in sol["branch"]
        @fact val["br_status"] --> anyof(0.0, 1.0)
    end
end


include("pf.jl")

include("opf.jl")

include("ots.jl")

include("misc.jl")

FactCheck.exitstatus()
