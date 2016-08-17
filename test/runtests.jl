# This seems to break CI
# need master for SOCRotated constraints
# Pkg.checkout("ConicNonlinearBridge")

using PowerModels

using Ipopt
using SCS
using ConicNonlinearBridge 

# needed for OTS tests
if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)
    using AmplNLWriter
    using CoinOptServices
end

if (Pkg.installed("Gurobi") != nothing)
    using Gurobi
end

if VERSION >= v"0.5.0-dev+7720"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end


#test_ac_opf() 
#test_soc_opf() 
#test_sdp_opf() 
#test_dc_opf()

#include("output.jl")

#include("matpower.jl")


## used by OTS and Loadshed TS models
#function check_br_status(sol)
#    for (idx,val) in sol["branch"]
#        @test val["br_status"] == 0.0 || val["br_status"] == 1.0
#    end
#end


include("pf.jl")

include("opf.jl")

#include("ots.jl")

#include("misc.jl")

# TODO see if something simialr is needed in Base Test
#FactCheck.exitstatus()
