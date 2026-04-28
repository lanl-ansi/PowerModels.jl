include("../config.jl")
include("./find_nearest_gens.jl")
include("./generate_dataset.jl")
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Revise
using PowerModels
push!(LOAD_PATH, DATA_PATH)
using Infiltrator
Infiltrator.toggle_async_check(false)
using DataFrames
using OrderedCollections 
using DataStructures
using JSON
using XLSX
using Ipopt
using Graphs 
using Infiltrator
using JuMP
using LinearAlgebra
using Random 

function solution_check(sol1, sol2)
    # validate bus setpoints 
    same = true
    for (b1, b2) in zip(values(sol1["bus"]), values(sol2["bus"]))
        same = same && abs(b1["vm"] - b2["vm"]) < 1e-5
        same = same && abs(b1["va"] - b2["va"]) < 1e-5
    end
    # validate gen setpoints
    for (b1, b2) in zip(values(sol1["gen"]), values(sol2["gen"]))
        same = same && abs(b1["pg"] - b2["pg"]) < 1e-5
        same = same && abs(b1["qg"] - b2["qg"]) < 1e-5
    end
    return same
end
statement = x -> x ? "\t solns are the same! \n " : "\t solns diverge \n"

for case_name in ["case14", "case57", "case300"]
    println("validating case $case_name...")
    # pull in test case 
    file_pth = joinpath(DATA_PATH, "test_cases/network_info/$case_name/$(case_name).m")
    test_case = PowerModels.parse_file(file_pth)
    test_case = prepare_test_case(test_case, case_name, file_pth)
    PowerModels.logger_config!("warn")


    println("\t checking original pf against original pf with mapping dict...")
    res1 = PowerModels.compute_ac_pf(test_case, mapping = false, enforce_q_lims = false)
    res2 = PowerModels.compute_ac_pf(test_case, mapping = true, enforce_q_lims = false)
    is_equal = solution_check(res1["solution"], res2["solution"])
    println(statement(is_equal))

    println("\t checking pf with original NLsolve versus with grainger ...")
    res1 = PowerModels.compute_ac_pf(test_case, mapping = true, enforce_q_lims = false)
    res2 = PowerModels.compute_ac_pf(test_case, mapping = true, enforce_q_lims = false, grainger = true)
    is_equal = solution_check(res1["solution"], res2["solution"])
    println(statement(is_equal))

    println("\t checking mbuses pf with nlsolve against mbuses pf with grainger...")
    res1 = PowerModels.compute_ac_pf_mult_buses(test_case, obo = true, grainger = false)
    nearest_gens = find_nearest_generators_khop(file_pth)
    test_case["pv_pairs"] = nearest_gens
    res2 = PowerModels.compute_ac_pf_mult_buses(test_case, obo = true, grainger = true)
    is_equal = solution_check(res1["solution"], res2["solution"])
    println(statement(is_equal))
end
