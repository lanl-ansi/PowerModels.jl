include("../powermodels/src/PowerModels.jl")
include("../../../../../config.jl")
include("./find_nearest_gens.jl")
include("./qv_sensitivity.jl")
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

# helper functions 
function _determine_acpf_feasibility(test_case, bus_indices; epsilon=1e-5)
    # Check flow limits 
    flows = PowerModels.calc_branch_flow_ac(test_case)["branch"]
    # line_flows = trues(length(flows))
    line_flows = Dict{String, Bool}(line => true for line in keys(test_case["branch"]))
    for (ind, flow) in pairs(flows)
        line_flows[ind] =   (flow["pf"]^2  + flow["qf"]^2 <= test_case["branch"][ind]["rate_a"]^2 + epsilon) && 
                                        (flow["pt"]^2  + flow["qt"]^2 <= test_case["branch"][ind]["rate_a"]^2 + epsilon)
    end

    # Check angle limits
    # line_angles = trues(length(test_case["branch"]))
    line_angles = Dict{String, Bool}(line => true for line in keys(test_case["branch"]))
    for (ind, branch) in pairs(test_case["branch"])
        line_angles[ind] =  (abs(test_case["bus"][string(branch["f_bus"])]["va"] - 
                                        test_case["bus"][string(branch["t_bus"])]["va"]) <= branch["angmax"] + epsilon) && 
                                        (abs(test_case["bus"][string(branch["f_bus"])]["va"] - 
                                        test_case["bus"][string(branch["t_bus"])]["va"]) >= branch["angmin"] - epsilon)
    end

    # Voltage magnitude limits
    # vms = trues(length(test_case["bus"]))
    vms = Dict{String, Bool}(bus => true for bus in keys(test_case["bus"]))
    false_vms = []
    for (ind, bus) in pairs(test_case["bus"])
        vms[ind] =  bus["vm"] <= bus["vmax"] + epsilon &&
                                 bus["vm"] + epsilon >= bus["vmin"]
        if ~vms[ind]
            push!(false_vms, ind)
        end
    end 

    # Reactive power limits
    qgs = Dict{String, Bool}(gen => true for gen in keys(test_case["gen"]))
    for (ind, gen) in pairs(test_case["gen"])
        qgs[ind] =  gen["qg"] <= gen["qmax"] + epsilon &&
                                gen["qg"] >= gen["qmin"] - epsilon
        # generators can have infeasible vms, since they're taken from the input
        vms[string(gen["gen_bus"])] = true
    end

    # slack bus can have qg violations 
    slack_bus = findall(x -> x == 3, bus_indices)
    slack_bus = length(slack_bus) > 0 ? slack_bus[1] : -1
    slack_gen = [ind for (ind, gen) in pairs(test_case["gen"]) if gen["gen_bus"] == slack_bus]
    if length(slack_gen) >= 1
        slack_gen = slack_gen[1]
        qgs[string(slack_gen)] = true
    end
    false_qgs = [key for (key, val) in pairs(qgs) if val==false]


    sol_dict = Dict(
        "vms" => vms, 
        "line_flow" => line_flows, 
        "line_angle" => line_angles, 
        "qgs" => qgs, 
        "feas" => Int(all(values(vms)) && all(values(line_flows)) && all(values(line_angles)) && all(values(qgs)))
    )
    return sol_dict
end

function solution_feasibility(data, sol_dict, bus_indices; epsilon = 0.0001)
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
    feas =  _determine_acpf_feasibility(data, bus_indices; epsilon = epsilon)
    return  feas
end

function find_infeas_point(test_case, delta)
    test_case, max_pd = prepare_test_case(test_case)
    feas = true 
    pf_data = nothing
    while feas 
        # perturb test case load 
        loads = zeros(length(test_case["load"]))
        qd_loads = zeros(length(test_case["load"]))
        test_case, load, qd_loads = perturb_load(test_case, loads, delta, max_pd, qd_loads=qd_loads)
        # verify test case is dcopf-feasible 
        model_dc, _ = PowerModels.solve_dc_opf(deepcopy(test_case), ipopt)
        if model_dc["termination_status"] != LOCALLY_SOLVED
            continue
        end 
        # verify test case is acopf-feasible (to guarantee feasible adjustment later)
        model_ac, _ = PowerModels.solve_ac_opf(deepcopy(test_case), ipopt)
        if model_ac["termination_status"] != LOCALLY_SOLVED
            continue
        end 
        # place pg setpoints into model 
        for (ind, val) in model_dc["solution"]["gen"] 
            test_case["gen"][ind]["pg"] = val["pg"]
        end
        # run ac pf with q lims 
        pf_model = PowerModels.compute_ac_pf(deepcopy(test_case), mapping=true, enforce_q_lims = true)
        feas_dict = solution_feasibility(deepcopy(test_case), pf_model["solution"], pf_model["bus indices"])
        # determine vm violations 
        if sum([feas_dict["vms"][i] for i in keys(test_case["bus"])]) < length(test_case["bus"])
            pf_data = pf_model["pf_data"]
            feas = false
        end
    end
    return test_case
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

function prepare_test_case(test_case)
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

function find_pilot_buses(clusters, test_case, map_to_bus, map_to_ind)
    # obtain distance matrix 
    S_qv, mapping_dict = create_sensitivity_matrix(test_case)
    dist_mat = create_distance_matrix(S_qv, type = "similarity")
    # within each cluster, find the pilot that minimizes the electrical distance with other nodes in that cluster 
    for (c, cluster) in pairs(clusters)
        min_dist = 1e6
        min_node = -1
        # iterate through each node in cluster
        for pilot in cluster 
            pilot = map_to_ind[Int(pilot)]
            pilot_dist = 0
            # sum distance with other nodes in cluster
            for other in cluster
                other = map_to_ind[Int(other)]
                pilot_dist += (dist_mat[pilot, other])^2
            end
            # store best node
            if pilot_dist < min_dist 
                min_dist = pilot_dist 
                min_node = map_to_bus[pilot]
            end 
        end 
        clusters[string(min_node)] = cluster
    end
    return clusters
end

function parse_datapoint(data, bi_data, bus_indices, loads, soln, feas_dict, test_case, counter, pf_type, solve_time, st, prev_indices; 
                        qd_loads = nothing, cluster_ind = -1, update_qlim = true, q_first = true)
    # data consists of loads, pf setpoint, and violations/no violations 
    data = _add_to_dict_(data, "datapoint", counter)
    data = _add_to_dict_(data, "pf_type", pf_type)
    bi_data = _add_to_dict_(bi_data, "datapoint", counter)
    bi_data = _add_to_dict_(bi_data, "pf_type", pf_type)
    data = _add_to_dict_(data, "time", solve_time)
    data = _add_to_dict_(data, "swap", st)
    data = _add_to_dict_(data, "cluster ind", cluster_ind)
    data = _add_to_dict_(data, "qlim", update_qlim)
    data = _add_to_dict_(data, "q_first", q_first)
    for (ind, bi) in enumerate(bus_indices)
        bi_data = _add_to_dict_(bi_data, "bus_$ind", bi)
        prev = [p[ind] for p in prev_indices]
        bi_data = _add_to_dict_(bi_data, "pb_$ind", prev)
    end
    # loads 
    for (ind, load) in enumerate(loads)
        data = _add_to_dict_(data, "pd_$ind", load)
    end
    if !isnothing(qd_loads)
        for (ind, load) in enumerate(qd_loads)
            data = _add_to_dict_(data, "qd_$ind", load)
        end
    end
    # generator setpoints
    for (ind, gen) in pairs(soln["gen"])
        data = _add_to_dict_(data, "pg_$ind", gen["pg"])
        data = _add_to_dict_(data, "qg_$ind", gen["qg"])
    end
    # bus setpoints
    for (ind, bus) in pairs(soln["bus"])
        data = _add_to_dict_(data, "va_$ind", bus["va"])
        data = _add_to_dict_(data, "vm_$ind", bus["vm"])
    end
    # violations 
    total_vm_violations = 0
    for ind in keys(test_case["bus"])
        total_vm_violations += 1 - Int(feas_dict["vms"][ind])
        data = _add_to_dict_(data, "vm_violation_$ind", Int(feas_dict["vms"][ind]))
    end
    total_branch_violations = 0
    for ind in keys(test_case["branch"])
        total_branch_violations += 1 - Int(feas_dict["line_flow"][ind])
        total_branch_violations += 1 - Int(feas_dict["line_angle"][ind])
        data = _add_to_dict_(data, "lf_violation_$ind", Int(feas_dict["line_flow"][ind]))
        data = _add_to_dict_(data, "la_violation_$ind", Int(feas_dict["line_angle"][ind]))
    end
    total_q_violations = 0
    for ind in keys(test_case["gen"])
        total_q_violations += 1 - Int(feas_dict["qgs"][ind])
        data = _add_to_dict_(data, "qg_violation_$ind", Int(feas_dict["qgs"][ind]))
    end
    data = _add_to_dict_(data, "total_violations", total_vm_violations + total_branch_violations + total_q_violations)
    data = _add_to_dict_(data, "total_vm_violations", total_vm_violations)
    data = _add_to_dict_(data, "total_branch_violations", total_branch_violations)
    data = _add_to_dict_(data, "total_q_violations", total_q_violations)
    data["num_points"] = data["num_points"] + 1
    return data, bi_data
end

function append_datapoint(test_case, loads,  dp_ind, pf_type, solve_time, prev_solns, prev_indices; 
                        qd_loads = nothing,  update_qlim = true, q_first = true)
    # solution dict for the final solution and datapoint information
    soln_dict = Dict()
    for (gen_ind, gen) in pairs(test_case["gen"])
        soln_dict["qg_$gen_ind"] = [prev_solns[end]["gen"][gen_ind]["qg"]]
        soln_dict["pg_$gen_ind"] = [prev_solns[end]["gen"][gen_ind]["pg"]]
    end
    for (i, (bus_ind, bus)) in enumerate(pairs(test_case["bus"]))
        soln_dict["va_$bus_ind"] = [prev_solns[end]["bus"][bus_ind]["va"]]
        soln_dict["vm_$bus_ind"] = [prev_solns[end]["bus"][bus_ind]["vm"]]
        soln_dict["bi_$bus_ind"] = [prev_indices[end][i]]
    end
    for (i, (load_ind, load)) in enumerate(pairs(test_case["load"]))
        soln_dict["pd_$load_ind"] = [loads[i]]
        if ~isnothing(qd_loads)
            soln_dict["qd_$load_ind"] = [qd_loads[i]]
        end
    end
    soln_dict["solve_time"] = [solve_time]
    soln_dict["pf_type"] = [pf_type]
    soln_dict["update_qlim"] = [update_qlim]
    soln_dict["q_first"] = [q_first]
    soln_dict["datapoint"] = [dp_ind]
    # create solution dict for solution history 
    hist_dict = Dict()
    sol_feas = [solution_feasibility(test_case, soln, bi) for (soln, bi) in zip(prev_solns, prev_indices)]
    for (i, (gen_ind, gen)) in enumerate(pairs(test_case["gen"]))
        hist_dict["qg_$gen_ind"] = [soln["gen"][gen_ind]["qg"] for soln in prev_solns]
        hist_dict["pg_$gen_ind"] = [soln["gen"][gen_ind]["pg"] for soln in prev_solns]
        hist_dict["qviol_$gen_ind"] = [feas["qgs"][gen_ind] for feas in sol_feas]
    end
    for (i, (bus_ind, bus)) in enumerate(pairs(test_case["bus"]))
        hist_dict["va_$bus_ind"] = [soln["bus"][bus_ind]["va"] for soln in prev_solns]
        hist_dict["vm_$bus_ind"] = [soln["bus"][bus_ind]["vm"] for soln in prev_solns]
        hist_dict["bi_$bus_ind"] = [bi[i] for bi in prev_indices]
        hist_dict["vmviol_$bus_ind"] = [feas["vms"][bus_ind] for feas in sol_feas]
    end

    hist_dict["datapoint"] = [dp_ind for _ in 1:length(prev_solns)]
    hist_dict["pf_type"] = [pf_type for _ in 1:length(prev_solns)]
    hist_dict["update_qlim"] = [update_qlim for _ in 1:length(prev_solns)]
    hist_dict["q_first"] = [q_first for _ in 1:length(prev_solns)]
    hist_dict["iter"] = 1:length(prev_solns)
    try
        return DataFrame(soln_dict), DataFrame(hist_dict)
    catch e 
        @infiltrate 
        rethrow(e)
    end 
end

    

function _add_to_dict_(data, key, val)
    if key in keys(data)
        push!(data[key], val)
    else 
        data[key] = [val]
    end
    return data 
end

function run_pf(test_case, data, feas_data, bi_data, loads, qd_loads, counter, pf_type, conv_counter, file_pth;  
                     swapping_technique="nothing", control_areas = false, q_first = true, update_qlim = true, paths = nothing, 
                     cluster_ind = -1)
    pf_model = nothing
    if pf_type == "baseline"
        nearest_gens = find_nearest_generators_khop(file_pth)
        test_case["pv_pairs"] = nearest_gens
        pf_model = PowerModels.compute_ac_pf(test_case, mapping=true, distributed_slack = false)
    elseif pf_type == "qlim"
        nearest_gens = find_nearest_generators_khop(file_pth)
        test_case["pv_pairs"] = nearest_gens
        pf_model = PowerModels.compute_ac_pf(test_case, mapping=true, enforce_q_lims = true,  distributed_slack = false)
    elseif pf_type == "mbuses"
        nearest_gens = find_nearest_generators_khop(file_pth)
        test_case["pv_pairs"] = nearest_gens
        pf_model = PowerModels.compute_ac_pf_mult_buses(test_case, distributed_slack = false, 
                                                        control_areas = control_areas, clusters = paths, 
                                                        q_first = q_first, update_qlim = update_qlim, max_acpf = 150, one_swap=true)
    elseif pf_type == "mb_obo"
        nearest_gens = find_nearest_generators_khop(file_pth)
        test_case["pv_pairs"] = nearest_gens
        pf_model = PowerModels.compute_ac_pf_mult_buses(test_case, obo = true, distributed_slack = false, 
                                                        control_areas = control_areas, clusters = paths, 
                                                        q_first = q_first, update_qlim = update_qlim, max_acpf = 150, one_swap=true)
    else 
        @assert false
    end
    # if (~pf_model["termination_status"]) && (pf_model["solution"]["bus"]["1"]["vm"] == -1)
    #     conv_counter += 1
    # end
    # feas_dict = solution_feasibility(test_case, pf_model["solution"], pf_model["bus indices"])
    # if pf_model["termination_status"]
    #     if !Bool(feas_dict["feas"])
    #         pf_model["termination_status"] = false
    #     end
    # end
    # # store feasibility 
    # if pf_model["termination_status"]
    #     feas_data, bi_data = parse_datapoint(feas_data, bi_data, pf_model["bus indices"],
    #                                 loads, pf_model["solution"], feas_dict, test_case, 
    #                                 counter, pf_type, pf_model["solve_time"], swapping_technique,  pf_model["prev_bus_indices"], 
    #                                 qd_loads=qd_loads, cluster_ind = cluster_ind, update_qlim = update_qlim, q_first = q_first)
    # else
    #     data, bi_data = parse_datapoint(data, bi_data, pf_model["bus indices"],
    #                                     loads, pf_model["solution"], feas_dict, test_case, 
    #                                     counter, pf_type, pf_model["solve_time"], swapping_technique,  pf_model["prev_bus_indices"],  
    #                                     qd_loads=qd_loads, cluster_ind = cluster_ind, update_qlim = update_qlim, q_first = q_first)
    # end
    
    # return data, feas_data, bi_data, conv_counter
    temp_feas, temp_bi = append_datapoint(test_case, loads, counter, pf_type, pf_model["solve_time"], 
        pf_model["solution_history"], pf_model["prev_bus_indices"], qd_loads=qd_loads, q_first=q_first, update_qlim=update_qlim)
    data = vcat(data, temp_feas)
    bi_data = vcat(bi_data, temp_bi)
    return data, feas_data, bi_data, conv_counter
end

function generate_dataset(test_case, num_points, delta, file_pth; paths = nothing, buses = nothing)
    # prepare test case 
    debug = true
    test_case, max_pd = prepare_test_case(test_case)
    data = DataFrame()
    feas_data = DataFrame()
    bi_data = DataFrame()
    counter = 0
    cc = 0
    convergence_counter = 0
    pf_model = nothing
    infeas_acopf = 0
    sorted_pairs = sort(collect(test_case["bus"]); by = x -> parse(Int, x.first))
    map_to_bus = [parse(Int64, i) for (i, bus) in sorted_pairs if bus["bus_type"] == 1]
    map_to_ind = Dict(val => i for (i, val) in enumerate(map_to_bus))
    # while (data["num_points"] < num_points) && (feas_data["num_points"] < num_points)
    while counter < num_points
        # if cc >= 5
        #     break 
        # end
        # if counter >= 75
        #     break
        # end
        if counter % 5 == 0
            println("counter = $counter  \t infeas data = $(size(data)[1]) ")
        end
        cc += 1
        # perturb test case load 
        loads = zeros(length(test_case["load"]))
        qd_loads = zeros(length(test_case["load"]))
        test_case, loads, qd_loads = perturb_load(test_case, loads, delta, max_pd, qd_loads=qd_loads)
        # verify test case is dcopf-feasible 
        model_dc, _ = PowerModels.solve_dc_opf(test_case, ipopt)
        if model_dc["termination_status"] != LOCALLY_SOLVED
            continue
        end 
        # verify test case is acopf-feasible (to guarantee feasible adjustment later)
        model_ac, _ = PowerModels.solve_ac_opf(test_case, ipopt)
        if model_ac["termination_status"] != LOCALLY_SOLVED
            infeas_acopf += 1
            continue
        end 

        # place pg setpoints into model 
        for (ind, val) in model_dc["solution"]["gen"]
            test_case["gen"][ind]["pg"] = val["pg"]
            # test_case["gen"][ind]["qg_start"] = 0k
        end
        # run ac-pf with pg setpoints 
        # ["random", "dof", "nearest", "furthest", "informed"]
        # ["baseline", "qlim", "mbuses","mb_obo"]
        if ~isnothing(paths) 
            for (cluster_ind, clusters) in pairs(paths)
                if "0" in keys(clusters)
                    pop!(clusters, "0")
                end
                paths[cluster_ind] = find_pilot_buses(clusters, test_case, map_to_bus, map_to_ind)
            end
        end
        # ["baseline", "qlim", "mbuses", "mb_obo"]
        for pf_type in [ "baseline", "qlim",  "mb_obo"]
            if pf_type in ["mbuses", "mb_obo"]
                for update_q in [true]
                    for q_first in [true, false]
                        if ~isnothing(paths)
                            for cluster_ind in -1:1
                                if cluster_ind == 0
                                    continue 
                                end
                                if cluster_ind in 1:5
                                    cluster = paths[string(cluster_ind)]
                                    if "0" in keys(cluster)
                                        pop!(cluster, "0")
                                    end
                                else 
                                    cluster = nothing 
                                end
                                data, feas_data, bi_data, convergence_counter = run_pf(deepcopy(test_case), data, feas_data, bi_data,
                                                                                loads, qd_loads, counter, pf_type, 
                                                                                convergence_counter, file_pth, control_areas = ~(cluster_ind == -1),
                                                                                q_first = q_first, update_qlim = update_q, paths = cluster, cluster_ind = cluster_ind)                               
                            end
                        else
                            data, feas_data, bi_data, convergence_counter = run_pf(deepcopy(test_case), data, feas_data, bi_data,
                                                                            loads, qd_loads, counter, pf_type, 
                                                                            convergence_counter, file_pth, 
                                                                            q_first = q_first, update_qlim = update_q)
                        end
                    end
                end

            else 
                data, feas_data, bi_data, convergence_counter = run_pf(deepcopy(test_case), data, feas_data, bi_data,
                                                loads, qd_loads, counter, pf_type, 
                                                convergence_counter, file_pth) 
            end
        end
        # break
        # if convergence_counter >= 20
        #     println("convergence counter = $convergence_counter")
        #     break
        # end
        counter = counter + 1
    end
    return data, feas_data, bi_data
end


if isinteractive()
    ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 1)
    # "case9","case14", "case39", "case57", "case118", "case300","case1354_pegase", "case7336"
    good_tcs = [ "case300"]
    for tc in good_tcs
        println(tc)
        # import test case
        PROJECT_NAME = "ACPF_adjust"
        RUN_NAME = "load_adjust"
        CASE_NAME = tc
        file_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/$(CASE_NAME).m")
        test_case = PowerModels.parse_file(file_pth)
        # calculate delta
        max_pg = sum([gen["pmax"] for gen in values(test_case["gen"])])
        base_load = sum([load["pd"] for load in values(test_case["load"])])
        delta = round(0.85*max_pg/base_load - 1, digits=2)
        # delta = 1.15
        if isfile(joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/pg_line_limits.txt"))
            line_lim_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/pg_line_limits.txt")
            line_limits = read(line_lim_pth, String)
            line_limits = split(line_limits, ' ')[1:end-1]
            for (i, line) in enumerate(line_limits)
                test_case["branch"][string(i)]["rate_a"] = parse(Int, line)
            end
        end
        # find nearest gens 
        nearest_gens = find_nearest_generators_khop(file_pth)
        test_case["pv_pairs"] = nearest_gens
        # get clusters 
        clusters = JSON.parsefile(joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/control_areas_similiary_sensitivity.json"))
        for i in 1:10
            println("counter $i")
            d_df, fd_df, bi_df = generate_dataset(test_case, 100, delta, file_pth);
            # d_df = DataFrame(data)
            # fd_df = DataFrame(feas_data)
            # bi_df = DataFrame(bi_data)
            # output dataset 
            filename = joinpath(TESTCASE_PATH, "datasets/$(PROJECT_NAME)/$(RUN_NAME)/$(CASE_NAME)/parse_tests/os_$(delta)_$(i).xlsx")
            if isfile(filename)
                rm(filename)
            end
            XLSX.openxlsx(filename, mode="w") do xf
                sheet1 = XLSX.addsheet!(xf, "infeas")
                XLSX.writetable!(sheet1, Tables.columntable(d_df))

                # sheet2 = XLSX.addsheet!(xf, "feas")
                # XLSX.writetable!(sheet2, Tables.columntable(fd_df))

                sheet3 = XLSX.addsheet!(xf, "bus_indices")
                XLSX.writetable!(sheet3, Tables.columntable(bi_df))
            end
        end
    end

end

    # # testing 
    # PROJECT_NAME = "ACPF_adjust"
    # RUN_NAME = "load_adjust"
    # CASE_NAME = "case14"
    # file_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/$(CASE_NAME).m")
    # test_case = PowerModels.parse_file(file_pth)
    # ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 1)

    # max_pg = sum([gen["pmax"] for gen in values(test_case["gen"])])
    # base_load = sum([load["pd"] for load in values(test_case["load"])])
    # delta = round(0.85*max_pg/base_load - 1, digits=2)
    # # delta = 1.15
    # if isfile(joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/pg_line_limits.txt"))
    #     line_lim_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/pg_line_limits.txt")
    #     line_limits = read(line_lim_pth, String)
    #     line_limits = split(line_limits, ' ')[1:end-1]
    #     for (i, line) in enumerate(line_limits)
    #         test_case["branch"][string(i)]["rate_a"] = parse(Int, line)
    #     end
    # end
    # clusters = JSON.parsefile(joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/control_areas_similiary_sensitivity.json"))
    # cluster = clusters["1"]
    # pop!(cluster, "0")
    # nearest_gens = find_nearest_generators_khop(file_pth)
    # test_case["pv_pairs"] = nearest_gens
    # pf_model = PowerModels.compute_ac_pf_mult_buses(test_case, distributed_slack = false, 
    #                                                 control_areas = false, 
    #                                                 q_first = false, update_qlim = true, obo = true, max_acpf = 100, one_swap=true)
    # # data, feas_data, bi_data = generate_dataset_known_loads(test_case, )
    # data, feas_data,  bi_data = generate_dataset(test_case, 10, delta, file_pth; paths = nothing)


    