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
    data_string = readall(open("../test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = ACPPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


function test_soc_opf()
    data_string = readall(open("../test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = SOCWRPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


function test_sdp_opf()
    data_string = readall(open("../test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = SDPWRPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


function test_dc_opf()
    data_string = readall(open("../test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = DCPPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


end