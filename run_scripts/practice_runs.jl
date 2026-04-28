include("../config.jl")
include("find_nearest_gens.jl")
include("generate_dataset.jl")
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
# Pkg.instantiate
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
Random.seed!(1)


# pull in a test case 
case_name = "case300"
file_pth = joinpath(DATA_PATH, "test_cases/network_info/$case_name/$(case_name).m")
test_case = PowerModels.parse_file(file_pth)
test_case = prepare_test_case(test_case, case_name, file_pth)

# pull in a load if you want 
max_pg = sum([gen["pmax"] for gen in values(test_case["gen"])])
base_load = sum([load["pd"] for load in values(test_case["load"])])
delta = round(0.85*max_pg/base_load - 1, digits=2)
delta -= 0.03
load_data = DataFrame(XLSX.readtable(joinpath(TESTCASE_PATH, "data/$(case_name)/loads/$delta.xlsx"), "loads"))
data_ind = 5
loads = load_data[data_ind, :]
for (load_ind, load) in pairs(test_case["load"])
    load["pd"] = loads["pd_$load_ind"]
    load["qd"] = loads["qd_$load_ind"]
end
for (gen_ind, gen) in pairs(test_case["gen"])
    gen["pg"] = loads["pg_$gen_ind"]
end

# compute acpf 
PowerModels.logger_config!("debug")
nearest_gens = find_nearest_generators_khop(file_pth)
test_case["pv_pairs"] = nearest_gens
result = PowerModels.compute_ac_pf_mult_buses(test_case, grainger = true,  swap_technique = "nearest_gen", debug = true, obo = false)

