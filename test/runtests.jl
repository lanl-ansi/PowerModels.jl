using PowerModels

using Ipopt
using SCS

# needed for OTS tests
using AmplNLWriter
using CoinOptServices

if (Pkg.installed("Gurobi") != nothing)
    using Gurobi
end

if VERSION >= v"0.5.0-dev+7720"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

include("output.jl")

include("matpower.jl")


# used by OTS and Loadshed TS models
function check_br_status(sol)
    for (idx,val) in sol["branch"]
        @test val["br_status"] == 0.0 || val["br_status"] == 1.0
    end
end


include("pf.jl")

include("opf.jl")

include("ots.jl")

include("misc.jl")

include("loadshed.jl")

# TODO see if something simialr is needed in Base Test
#FactCheck.exitstatus()
