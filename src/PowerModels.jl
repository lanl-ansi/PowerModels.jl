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
include("core_relaxation_scheme.jl")
include("core_obj.jl")

include("acp.jl")
include("dcp.jl")
include("wr.jl")

include("opf.jl")
#include("ots.jl")
#include("pf.jl")
#include("misc.jl")


using Ipopt

function test_ac_opf()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = ACPPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end

function test_soc_opf()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = SOCWRPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end

function test_sdp_opf()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = SDPWRPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


function test_dc_opf()
    data_string = readall(open("/Users/cjc/.julia/v0.4/PowerModels/test/data/case30.m"))
    data = parse_matpower(data_string)

    apm = DCPPowerModel(data)
    post_opf(apm)

    setsolver(apm, IpoptSolver())
    solve(apm)
end


end