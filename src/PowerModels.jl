isdefined(Base, :__precompile__) && __precompile__()

module PowerModels

using JSON
using MathProgBase
using JuMP

include("io/matpower.jl")

include("core/base.jl")
include("core/var.jl")
include("core/constraint.jl")
include("core/relaxation_scheme.jl")
include("core/objective.jl")
include("core/common.jl")

include("form/acp.jl")
include("form/dcp.jl")
include("form/wr.jl")

include("prob/opf.jl")
#include("prob/ots.jl")
#include("prob/pf.jl")
#include("prob/misc.jl")





using Ipopt
export test_ac_opf, test_soc_opf, test_sdp_opf, test_dc_opf

function test_ac_opf()
    data = parse_matpower("../test/data/case30.m")

    pm = ACPPowerModel(data)
    setsolver(pm, IpoptSolver())

    post_opf(pm)
    sol = solve(pm)

    dump(sol)
end


function test_soc_opf()
    data = parse_matpower("../test/data/case30.m")

    pm = SOCWRPowerModel(data; solver = IpoptSolver())

    post_opf(pm)
    sol = solve(pm)

    dump(sol)
end


function test_sdp_opf()
    data = parse_matpower("../test/data/case30.m")

    pm = SDPWRPowerModel(data; solver = IpoptSolver())

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