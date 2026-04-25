using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
# Pkg.instantiate
using Revise
using PowerModels
include("../config.jl")
include("./find_nearest_gens.jl")
push!(LOAD_PATH, DATA_PATH)
using Infiltrator
Infiltrator.toggle_async_check(false)
using DataFrames
using OrderedCollections 
using DataStructures
using JSON
using XLSX
using Ipopt
using Infiltrator
using JuMP
using Plots
using LinearAlgebra
using Distributions
using Random 
Random.seed!(2)

function _determine_acpf_feasibility(test_case, viol_dict; epsilon=1e-5)
    total_violations, total_vm_violations, total_q_violations, total_branch_violations = 0, 0, 0, 0
    # Check flow limits 
    flows = PowerModels.calc_branch_flow_ac(test_case)["branch"]
    for (ind, flow) in pairs(flows)
        viol_dict["lf_viol_$ind"] =   Int((flow["pf"]^2  + flow["qf"]^2 <= test_case["branch"][ind]["rate_a"]^2 + epsilon) && 
                                        (flow["pt"]^2  + flow["qt"]^2 <= test_case["branch"][ind]["rate_a"]^2 + epsilon))
        total_violations += 1 - viol_dict["lf_viol_$ind"]
        total_branch_violations += 1 - viol_dict["lf_viol_$ind"]
    end

    # Check angle limits
    for (ind, branch) in pairs(test_case["branch"])
        viol_dict["la_viol_$ind"] =  Int((abs(test_case["bus"][string(branch["f_bus"])]["va"] - 
                                        test_case["bus"][string(branch["t_bus"])]["va"]) <= branch["angmax"] + epsilon) && 
                                        (abs(test_case["bus"][string(branch["f_bus"])]["va"] - 
                                        test_case["bus"][string(branch["t_bus"])]["va"]) >= branch["angmin"] - epsilon))
        total_violations += 1 - viol_dict["la_viol_$ind"]
        total_branch_violations += 1 - viol_dict["la_viol_$ind"]
    end

    # Voltage magnitude limits
    for (ind, bus) in pairs(test_case["bus"])
        viol_dict["vmviol_$ind"] =  Int(bus["vm"] <= bus["vmax"] + epsilon &&
                                 bus["vm"] + epsilon >= bus["vmin"])
        total_violations += 1 - viol_dict["vmviol_$ind"]
        total_vm_violations += 1 - viol_dict["vmviol_$ind"]
    end 

    # Reactive power limits
    for (ind, gen) in pairs(test_case["gen"])
        viol_dict["qviol_$ind"] =  Int(gen["qg"] <= gen["qmax"] + epsilon &&
                                gen["qg"] >= gen["qmin"] - epsilon)
        total_violations += 1 - viol_dict["qviol_$ind"]
        total_q_violations += 1 - viol_dict["qviol_$ind"]
    end

    # add other values 
    viol_dict["total_violations"] = total_violations 
    viol_dict["total_branch_violations"] = total_branch_violations 
    viol_dict["total_vm_violations"] = total_vm_violations 
    viol_dict["total_q_violations"] = total_q_violations 
    return viol_dict
end

function solution_feasibility(data, sol_dict, viol_dict; epsilon = 1e-5)
    # place values in data (un- PU)
    for (ind, val) in pairs(sol_dict["gen"])
        data["gen"][ind]["pg"] = val["pg"]
        data["gen"][ind]["qg"] = val["qg"]
    end
    for (ind, val) in pairs(sol_dict["bus"])
        data["bus"][ind]["va"] = val["va"]
        data["bus"][ind]["vm"] = val["vm"]
    end
    # determine feasibility 
    viol_dict =  _determine_acpf_feasibility(data, viol_dict; epsilon = epsilon)
    return  viol_dict
end

function perturb_load(test_case, loads, delta, max_pd; qd_loads = nothing)
    # get max and min total generation 
    max_gen = sum([gen["pmax"] for gen in values(test_case["gen"])])
    min_gen = sum([gen["pmin"] for gen in values(test_case["gen"])])
    rands = rand(Uniform(max(1-delta, 0), 1+delta))
    # perturb load 
    for load in values(test_case["load"])
        load["pd"] = rands * load["og_pd"]
        loads[load["index"]] = load["pd"]
    end
    if qd_loads !== nothing 
        # get max and min reactive generation 
        max_qg = sum([gen["qmax"] for gen in values(test_case["gen"])])
        min_qg = sum([gen["qmin"] for gen in values(test_case["gen"])])
        # perturb qd load 
        for load in values(test_case["load"])
            load["qd"] = rands * load["og_qd"]
            qd_loads[load["index"]] = load["qd"]
        end
    end
    # verify load is realistic before returning
    if isnothing(qd_loads)
        if !(_verify_loads_(test_case, loads, max_gen, min_gen, max_pd))
            return perturb_load(test_case, loads, delta, max_pd)
        end 
    else 
        if !(_verify_loads_(test_case, loads, max_gen, min_gen, max_pd, qd_loads = qd_loads, max_qg = max_qg, min_qg = min_qg))
            return perturb_load(test_case, loads, delta, max_pd, qd_loads = qd_loads)
        end 
    end
    return test_case, loads, qd_loads
end

function _verify_loads_(test_case, loads, max_gen, min_gen, max_pd; qd_loads = nothing, max_qg = nothing, min_qg = nothing)
    # check total load 
    if (sum(loads) > max_gen) || (sum(loads) < min_gen)
        return false
    end 
    if !isnothing(qd_loads)
        # check total qd
        if sum(qd_loads) > max_qg || sum(qd_loads) < min_qg
            return false
        end
    end
    # check load at each bus 
    for bus in values(test_case["bus"])
        if "bus_loads" ∉ keys(bus)
            continue
        end
        bus_load = sum([loads[index] for index in Set(bus["bus_loads"])])
        if bus_load > max_pd[string(bus["index"])]
            return false
        end
    end
    return true
end

function prepare_test_case_perturbations(test_case)
    for load in values(test_case["load"])
        load["og_pd"] = load["pd"]
        load["og_qd"] = load["qd"]
        if "bus_loads" ∉ keys(test_case["bus"][string(load["load_bus"])])
            test_case["bus"][string(load["load_bus"])]["bus_loads"] = [load["index"]]
        else 
            push!(test_case["bus"][string(load["load_bus"])]["bus_loads"], load["index"])
        end
    end
    max_pd = Dict{String, Float64}(bus => 0 for bus in keys(test_case["bus"]))
    for branch in values(test_case["branch"])
        max_pd[string(branch["f_bus"])] = max_pd[string(branch["f_bus"])] + branch["rate_a"]
        max_pd[string(branch["t_bus"])] = max_pd[string(branch["t_bus"])] + branch["rate_a"]  
    end
    return test_case, max_pd
end

function prepare_test_case(test_case, case_name, file_pth; solve_acpf = false)
    # set generator vm bounds so they're not immediately violated
    for (gen_ind, gen) in pairs(test_case["gen"])
        gen_bus = gen["gen_bus"]
        test_case["bus"][string(gen_bus)]["vmax"] = max(gen["vg"], test_case["bus"][string(gen_bus)]["vmax"])
    end
    # update line limits
    if isfile(joinpath(DATA_PATH, "test_cases/network_info/$case_name/pg_line_limits.txt"))
        line_lim_pth = joinpath(DATA_PATH, "test_cases/network_info/$case_name/pg_line_limits.txt")
        line_limits = read(line_lim_pth, String)
        line_limits = split(line_limits, ' ')[1:end-1]
        for (i, line) in enumerate(line_limits)
            test_case["branch"][string(i)]["rate_a"] = parse(Int, line)
        end
    end
    if solve_acpf
        # find nearest gens 
        nearest_gens = find_nearest_generators_khop(file_pth)
        test_case["pv_pairs"] = nearest_gens
    end
    return test_case
end


function store_load!(df, test_case, counter)
    dp_dict = Dict()
    for (gen_ind, gen) in pairs(test_case["gen"])
        dp_dict["pg_$gen_ind"] = gen["pg"]
    end
    for (i, (load_ind, load)) in enumerate(pairs(test_case["load"]))
       dp_dict["pd_$load_ind"] = load["pd"]
       dp_dict["qd_$load_ind"] = load["qd"]
    end
    dp_dict["datapoint"] = counter
    push!(df, dp_dict)
end

function generate_solutions(case_name, delta, test_case, load_data; num_samples = 1000)
    PowerModels.logger_config!("debug")
    # prep structures to store outputs
    cols = [("datapoint", Int64), ("run_id", Int64), 
            ("pf_type", String), ("obo", Int64), 
            ("swap_technique", String), ("grainger", Int64), ("time", Float64),
            ("swap_iters", Int64), ("jac_iters", Int64)]
    run_df = DataFrame([name => type[] for (name, type) in cols]) 
    cols = vcat(["datapoint" ,"run_id", "iter", "jac_iter", "final_iter"], 
                ["qg_$gen_ind" for gen_ind in keys(test_case["gen"])],
                ["pg_$gen_ind" for gen_ind in keys(test_case["gen"])], 
                ["va_$bus_ind" for bus_ind in keys(test_case["bus"])], 
                ["vm_$bus_ind" for bus_ind in keys(test_case["bus"])])
    soln_df = DataFrame([name => Float64[] for name in cols])
    cols = vcat(["datapoint", "run_id", "iter"], 
                ["total_violations", "total_vm_violations", "total_q_violations", "total_branch_violations"],
                ["qviol_$gen_ind" for gen_ind in keys(test_case["gen"])],
                ["vmviol_$bus_ind" for bus_ind in keys(test_case["bus"])],
                ["lf_viol_$branch_ind" for branch_ind in keys(test_case["branch"])],
                ["la_viol_$branch_ind" for branch_ind in keys(test_case["branch"])]
                )
    violations_df = DataFrame([name => Float64[] for name in cols])
    cols = vcat(["datapoint", "run_id", "iter"], 
            ["bt_$bus_ind" for bus_ind in keys(test_case["bus"])]
            )
    bi_df = DataFrame([name => Float64[] for name in cols])
    # iterate through acpf combos 
    run_id = 0
    for pf_type in ["baseline", "qlim", "mbuses"]
        for obo in [0,1]
            if pf_type in ["baseline", "qlim"]
                run_id += 1 
                run_flags = Dict("run_id" => run_id, "pf_type" => pf_type, 
                            "obo" => obo, "swap_technique" => "none", "grainger" => 0)
                println("Running ID $run_id: pf_type = $pf_type, obo = $obo")
                run_pf!(test_case, load_data, run_flags, run_df, soln_df, violations_df, bi_df, num_samples)
            else
                for swap_technique in ["qv_inv", "nearest_gen"]
                    for grainger in [0,1]
                        run_id += 1 
                        run_flags = Dict("run_id" => run_id, "pf_type" => pf_type, 
                                    "obo" => obo, "swap_technique" => swap_technique, "grainger" => grainger
                                    )
                        println("Running ID $run_id: pf_type = $pf_type, obo = $obo, swap_technique = $swap_technique, grainger = $grainger")
                        run_pf!(test_case, load_data, run_flags, run_df, soln_df, violations_df, bi_df, num_samples)
                    end
                end
            end
        end
    end
    # write out data 
    filename = joinpath(RESULTS_PATH, "$(case_name)/$delta.xlsx")
    dir_path = dirname(filename)
    mkpath(dir_path)
    if isfile(filename)
        rm(filename)
    end
    XLSX.openxlsx(filename, mode="w") do xf
        sheet1 = XLSX.addsheet!(xf, "run_info")
        XLSX.writetable!(sheet1, Tables.columntable(run_df))
        sheet2 = XLSX.addsheet!(xf, "solns")
        XLSX.writetable!(sheet2, Tables.columntable(soln_df))
        sheet3 = XLSX.addsheet!(xf, "bus_types")
        XLSX.writetable!(sheet3, Tables.columntable(bi_df))
        sheet4 = XLSX.addsheet!(xf, "violations")
        XLSX.writetable!(sheet4, Tables.columntable(violations_df))
    end
end

function run_pf!(test_case, load_data, run_flags, run_df, soln_df, violations_df, bi_df, num_samples)
    for (i, loads) in enumerate(eachrow(load_data))
        if i > num_samples 
            break 
        end
        # add values to test case 
        for (load_ind, load) in pairs(test_case["load"])
            load["pd"] = loads["pd_$load_ind"]
            load["qd"] = loads["qd_$load_ind"]
        end
        for (gen_ind, gen) in pairs(test_case["gen"])
            gen["pg"] = loads["pg_$gen_ind"]
        end
        # run ac power flow 
        results = nothing
        if run_flags["pf_type"] in ["qlim", "baseline"]
            results = PowerModels.compute_ac_pf(test_case, mapping = true,
                                enforce_q_lims = run_flags["pf_type"] == "qlim")
        else
            results = PowerModels.compute_ac_pf_mult_buses(test_case, mapping = true, 
                                    swap_technique = run_flags["swap_technique"], 
                                    obo = Bool(run_flags["obo"]), grainger = Bool(run_flags["grainger"]), debug = true)
        end
        # parse results 
        parse_results!(test_case, results, run_flags, loads["datapoint"],  run_df, soln_df, violations_df, bi_df)
    end
end

function parse_results!(test_case, results, run_flags, datapoint, 
                        run_df, soln_df, violations_df, bi_df)
    run_id = run_flags["run_id"]
    # parse solutions 
    am = results["pf_data"].am
    num_swaps = length(results["solution_history"])
    jacobians = parse_jacobian_history(results["jacobian_history"])
    num_jacobians = sum([length(jac) for jac in jacobians])
    # add to run_df 
    run_flags["time"] = results["solve_time"]
    run_flags["swap_iters"] = num_swaps
    run_flags["jac_iters"] = num_jacobians
    run_flags["datapoint"] = datapoint 
    push!(run_df, run_flags)
    for iter in 1:num_swaps
        soln = results["solution_history"][iter]
        bus_indices = results["prev_bus_indices"][iter]
        # add to solution df 
        sol_dict = Dict("run_id" => run_id, "datapoint" => datapoint, 
                        "iter" => iter, 
                        "jac_iter" => length(jacobians[iter]), "final_iter" => iter == num_swaps)
        for (bus_ind, bus) in pairs(soln["bus"])
            sol_dict["vm_$bus_ind"] = bus["vm"]
            sol_dict["va_$bus_ind"] = bus["va"]
        end
        for (gen_ind, gen) in pairs(soln["gen"])
            sol_dict["pg_$gen_ind"] = gen["pg"]
            sol_dict["qg_$gen_ind"] = gen["qg"]
        end
        push!(soln_df, sol_dict)
        # add to bus_indices df 
        bi_dict = Dict("run_id" => run_id, "datapoint" => datapoint, "iter" => iter)
        for bus_ind in keys(soln["bus"])
            bi = am.bus_to_idx[parse(Int, bus_ind)]
            bi_dict["bt_$bus_ind"] = bus_indices[bi]
        end
        push!(bi_df, bi_dict)
        # add to violations df 
        viol_dict = Dict("run_id" => run_id, "datapoint" => datapoint, "iter" => iter)
        viol_dict = solution_feasibility(test_case, soln, viol_dict)
        push!(violations_df, viol_dict)
    end
end

function parse_jacobian_history(jacobian_history; is_mat = true)
    iteration_lst = []
    curr_iter = []
    for jac in jacobian_history
        if jac == []
            push!(iteration_lst, curr_iter)
            curr_iter = []
            continue 
        end 
        if is_mat
            push!(curr_iter, Matrix(jac))
        else 
            push!(curr_iter, jac)
        end
    end 
    return iteration_lst
end

function generate_loads(test_case, num_points, delta, case_name)
    PowerModels.logger_config!("warn")
    ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 1)
    test_case, max_pd = prepare_test_case_perturbations(test_case)
    cols = vcat(["pd_$load_ind" for load_ind in keys(test_case["load"])],
                ["qd_$load_ind" for load_ind in keys(test_case["load"])],
                ["pg_$gen_ind" for gen_ind in keys(test_case["gen"])], ["datapoint"]
            )
    data = DataFrame([name => Float64[] for name in cols])
    counter = 0
    infeas_acopf = 0
    sorted_pairs = sort(collect(test_case["bus"]); by = x -> parse(Int, x.first))
    map_to_bus = [parse(Int64, i) for (i, bus) in sorted_pairs if bus["bus_type"] == 1]
    while counter < num_points
        if counter % 5 == 0
            println("counter = $counter")
        end
        # perturb test case load 
        loads = zeros(length(test_case["load"]))
        qd_loads = zeros(length(test_case["load"]))
        test_case, loads, qd_loads = perturb_load(test_case, loads, delta, max_pd, qd_loads=qd_loads)
        # verify test case is dcopf-feasible 
        model_dc = PowerModels.solve_dc_opf(test_case, ipopt)
        if model_dc["termination_status"] != LOCALLY_SOLVED
            continue
        end 
        # verify test case is acopf-feasible (to guarantee feasible adjustment later)
        model_ac = PowerModels.solve_ac_opf(test_case, ipopt)
        if model_ac["termination_status"] != LOCALLY_SOLVED
            infeas_acopf += 1
            continue
        end 
        # place dc gen setpoints into model
        for (ind, val) in model_dc["solution"]["gen"]
            test_case["gen"][ind]["pg"] = val["pg"]
        end
        store_load!(data, test_case, counter)
        counter += 1
    end
    # store output
    filename = joinpath(TESTCASE_PATH, "data/$(case_name)/loads/$delta.xlsx")
    dir_path = dirname(filename)
    mkpath(dir_path)
    if isfile(filename)
        rm(filename)
    end
    XLSX.openxlsx(filename, mode="w") do xf
        sheet1 = XLSX.addsheet!(xf, "loads")
        XLSX.writetable!(sheet1, Tables.columntable(data))
    end
end

if isinteractive()
    # pull in test case 
    CASE_NAME = "case14"
    file_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/$(CASE_NAME).m")
    test_case = PowerModels.parse_file(file_pth)
    test_case = prepare_test_case(test_case, CASE_NAME, file_pth)
    # calculate delta
    max_pg = sum([gen["pmax"] for gen in values(test_case["gen"])])
    base_load = sum([load["pd"] for load in values(test_case["load"])])
    delta = round(0.85*max_pg/base_load - 1, digits=2)

    # pull in loads and generate dataset
    load_data = DataFrame(XLSX.readtable(joinpath(TESTCASE_PATH, "data/$(CASE_NAME)/loads/$delta.xlsx"), "loads"))
    generate_solutions(CASE_NAME, delta, test_case, load_data; num_samples = 1)
end
