isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using MathProgBase
using JuMP

include("io/matpower.jl")
include("io/json.jl")

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





using Ipopt
export test_ac_opf, test_soc_opf, test_sdp_opf, test_dc_opf

function test_ac_opf()
    data = parse_matpower("../test/data/case30.m")

    pm = ACPPowerModel(data; solver = IpoptSolver())

    post_opf(pm)
    sol = solve(pm)

    dump(sol)
end


using ConicNonlinearBridge 
function test_soc_opf()
    data = parse_matpower("../test/data/case30.m")

    pm = SOCWRPowerModel(data)
    setsolver(pm, ConicNLPWrapper(nlp_solver=IpoptSolver()))

    post_opf(pm)
    sol = solve(pm)

    dump(sol)
end

using SCS
function test_sdp_opf()
    # too slow for unit testing
    #data = parse_matpower("../test/data/case30.m")
    data = parse_json("../test/data/case3.json")

    pm = SDPWRMPowerModel(data; solver = SCSSolver())

    post_opf(pm)
    sol = solve(pm)

    dump(sol)
end


function test_dc_opf()
    data = parse_matpower("../test/data/case30.m")

    pm = DCPPowerModel(data; solver = IpoptSolver())

    post_opf(pm)
    sol = solve(pm)

    dump(sol)
end


end