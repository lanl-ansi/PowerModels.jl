
facts("test output api") do
    context("24-bus rts case") do
        result = run_opf_file(; file = "../test/data/case24.json")

        @fact haskey(result, "solver") --> true
        @fact haskey(result, "status") --> true
        @fact haskey(result, "objective") --> true
        @fact haskey(result, "objective_lb") --> true
        @fact haskey(result, "solve_time") --> true
        @fact haskey(result, "machine") --> true
        @fact haskey(result, "data") --> true
        @fact haskey(result, "solution") --> true
        @fact haskey(result["solution"], "branch") --> false
        
        @fact length(result["solution"]["bus"]) --> 24
        @fact length(result["solution"]["gen"]) --> 33
        
    end
end

facts("test line flow output") do
    context("24-bus rts case opf") do
        result = run_power_model_file("../test/data/case24.json", AC_OPF, build_solver(IPOPT_SOLVER), Dict("output" => Dict("line_flows" => true)))

        @fact haskey(result, "solver") --> true
        @fact haskey(result, "status") --> true
        @fact haskey(result, "objective") --> true
        @fact haskey(result, "objective_lb") --> true
        @fact haskey(result, "solve_time") --> true
        @fact haskey(result, "machine") --> true
        @fact haskey(result, "data") --> true
        @fact haskey(result, "solution") --> true
        @fact haskey(result["solution"], "branch") --> true
        
        @fact length(result["solution"]["bus"]) --> 24
        @fact length(result["solution"]["gen"]) --> 33
        @fact length(result["solution"]["branch"]) --> 38
        
    end
end