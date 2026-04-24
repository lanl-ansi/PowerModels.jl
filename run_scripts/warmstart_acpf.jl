include("../config.jl")
# include("./find_nearest_gens.jl")
# include("generate_dataset.jl")
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

function jacobian_submatrix(pf_data, jacobian, mapping_dict, bus_indices)
    jacobian = Matrix(jacobian)
    # obtain row indices for type 1 through 5 
    p1, p2, p5, p6, q1, q5 = [], [], [], [], [], []
    # obtain column indices for types 1 through 6 
    va1, va2, va5, va6, vm1, vm6 = [], [], [], [], [], []
    t1, t2, t5, t6 = [], [], [], []
    # fill 
    for (key, dict) in pairs(mapping_dict)
        if bus_indices[key] == 1
            push!(p1, dict["p_row"])
            push!(q1, dict["q_row"])
            push!(va1, dict["va"])
            push!(vm1, dict["vm"])
            push!(t1, key)
        elseif bus_indices[key] == 2
            push!(p2, dict["p_row"])
            push!(va2, dict["va"])
            push!(t2, key)
        elseif bus_indices[key] == 3

        elseif bus_indices[key] == 5
            push!(p5, dict["p_row"])
            push!(q5, dict["q_row"])
            push!(va5, dict["va"])
            push!(t5, key)
        elseif bus_indices[key] == 6
            push!(p6, dict["p_row"])
            push!(va6, dict["va"])
            push!(vm6, dict["vm"])
            push!(t6, key)
        end
    end
    submapping_dict = Dict() 
    submapping_dict["qv_rows"] = Dict(bus => i for (i, bus) in enumerate(vcat(t1, t5)))
    submapping_dict["qv_cols"] = Dict(bus => i for  (i,bus) in enumerate(t2))
    submat_dict = Dict("pthet" => jacobian[vcat(p1, p2, p5, p6), vcat(va1, va2, va5, va6)], 
                        "pv" => jacobian[vcat(p1, p2, p5, p6), vcat(vm1, vm6)], 
                        "qthet" => jacobian[vcat(q1, q5), vcat(va1, va2, va5, va6)], 
                        "qv" => jacobian[vcat(q1, q5), vcat(vm1, vm6)], 
                        "qv_cols" => determine_gen_cols(pf_data, t1, t2, t5),
                        "submap" => submapping_dict
                        )
    return submat_dict
end

function determine_gen_cols(pf_data, t1, t2, t5)
    vm_idx = pf_data.vm_idx 
    va_idx = pf_data.va_idx 
    neighbors = pf_data.neighbors 
    am = pf_data.am 
    function dqn_dv(i, j)
        y_ij = am.matrix[i,j]
        return vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
    end
    # for each t2 bus, create the qv column 
    gen_qvcols = []
    for gen in t2 
        qv_col = []
        for bus in t1 
            if bus in neighbors[gen]
                push!(qv_col, dqn_dv(bus, gen))
            else 
                push!(qv_col, 0)
            end
        end
        for bus in t5 
            if bus in neighbors[gen]
                push!(qv_col, dqn_dv(bus, gen))
            else 
                push!(qv_col, 0)
            end
        end
        push!(gen_qvcols, qv_col)
    end
    return gen_qvcols
end 

function find_feasible_swaps(pf_data, solution, bus_indices, submat_dict)
    bus_to_idx = pf_data.am.bus_to_idx
    # get the generator inverse matrix 
    inv_qv = inv(submat_dict["qv"])
    gen_invs = Float64.(reduce(hcat, [inv_qv * vec for vec in submat_dict["qv_cols"]]))
    # get the t1 buses with bound violations
    violated_buses = [bus_to_idx[parse(Int, bus)] for bus in keys(solution["bus"]) if (bus_indices[bus_to_idx[parse(Int, bus) ]] == 1) && 
                                                                        ((solution["bus"][bus]["vm"] > pf_data.data["bus"][bus]["vmax"]) || 
                                                                        (solution["bus"][bus]["vm"] < pf_data.data["bus"][bus]["vmin"])
                                                                        )]
    num_gens = length(submat_dict["qv_cols"])
    # obtain the LU decomposition of the sub-matrix associated with the violated t1 buses to find pivot columns
    violated_rows = [submat_dict["submap"]["qv_rows"][i] for i in violated_buses]
    F = lu(reshape(gen_invs[violated_rows, :], length(violated_rows), num_gens))
    diag_elems = diag(F.U)
    pivot_cols = findall(x -> abs(x) > 1e-3, diag_elems)
    swap_candidates = [k for (k, v) in submat_dict["submap"]["qv_cols"] if v in Set(pivot_cols)]
    return zip(violated_buses[pivot_cols], swap_candidates)
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

function plot_var(bus_ind, var_ind, var_lst, p)
    overall_vars = []
    val_counter = 0
    for iter in var_lst
        vars = [i[var_ind] for i in iter]
        overall_vars = vcat(overall_vars, vars)
        val_counter += length(vars)
        vline!(p, [val_counter], color=:black, linestyle=:dash)
    end 
    plot!(p, 1:length(overall_vars), overall_vars, label = bus_ind)
    return p   
end

function plot_var_mult(x_hist, bus_ind, var_name, mapping_dicts, p)
    if ~(var_name in keys(mapping_dicts[1][bus_ind]))
        return p
    end
    if mapping_dicts[1][bus_ind][var_name] == 0 
        return p 
    end
    # get the index for the variable at each iteration
    var_val = []
    val_counter = 0
    for (i, (x, md)) in enumerate(zip(x_hist, mapping_dicts))
        # if i < 40 
        #     continue 
        # end
        var_ind = md[bus_ind][var_name]
        if var_ind == 0 
            vals = [var_val[end] for _ in 1:length(x)]
            # vals = [var_val[end]]
        else
            vals = [lst[var_ind] for lst in x][1:length(x)]
            # vals = [x[end][var_ind]]
        end
        var_val = vcat(var_val, vals)
        val_counter += length(vals)
        vline!(p, [val_counter], color=:black, linestyle=:dash)
        vspan!(p, [val_counter-0.1, val_counter+0.1], color=:gray, alpha=0.2, label="")

    end
    plot!(p, 1:length(var_val), var_val, label = bus_ind)
    return p
end

PROJECT_NAME = "ACPF_adjust"
RUN_NAME = "load_adjust"
CASE_NAME = "case14"
file_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/$(CASE_NAME).m")
test_case = PowerModels.parse_file(file_pth)
if isfile(joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/pg_line_limits.txt"))
    line_lim_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/pg_line_limits.txt")
    line_limits = read(line_lim_pth, String)
    line_limits = split(line_limits, ' ')[1:end-1]
    for (i, line) in enumerate(line_limits)
        test_case["branch"][string(i)]["rate_a"] = parse(Int, line)
    end
end

for (gen_ind, gen) in pairs(test_case["gen"])
    gen_bus = gen["gen_bus"]
    test_case["bus"][string(gen_bus)]["vmax"] = max(gen["vg"], test_case["bus"][string(gen_bus)]["vmax"])
end
PowerModels.logger_config!("debug")
# result = PowerModels.compute_ac_pf(test_case, mapping = true, grainger = false)
result = PowerModels.compute_ac_pf_mult_buses(test_case, update_qlim = false, q_first = false, 
                                                one_swap = false, grainger = true)
# result_ng = PowerModels.compute_ac_pf(test_case, mapping = true, grainger = false)
# nearest_gens = find_nearest_generators_khop(file_pth)
# test_case["pv_pairs"] = nearest_gens
# result = PowerModels.compute_ac_pf_mult_buses(test_case, obo = true, flat_start = true, max_acpf = 50)
# is_feas = false 
# is_converged = true 
# soln_hist = []
# x_history = []
# iter_counter = 1
# max_counter = 1
# bus_type_idx = nothing
# result = nothing
# while ~is_feas && is_converged 
#     global iter_counter, is_converged, is_feas, x_history, bus_type_idx, result
#     print(" iteration $iter_counter: \n")
#     # run ac pf 
#     result = PowerModels.compute_ac_pf(test_case, flat_start = false)
#     soln = result["solution"]
#     x_history = vcat(x_history, result["x_history"])
#     # check for feasibility 
#     feas = solution_feasibility(test_case, soln, result["pf_data"].bus_type_idx; epsilon = 0)
#     if bus_type_idx === nothing
#         bus_type_idx = result["pf_data"].bus_type_idx 
#     end
#     push!(soln_hist, [soln, feas])
#     is_feas = Bool(feas["feas"])
#     is_converged = result["termination_status"]
#     if ~is_feas
#         num_vms = length(feas["vms"]) - sum(values(feas["vms"]))
#         num_qgs = length(feas["qgs"]) - sum(values(feas["qgs"]))
#         print(" \t vm violations: $(num_vms) qg violations: $(num_qgs) \n")
#     end
#     # warm-start the vms and qgs 
#     for (bus_i, bus) in pairs(test_case["bus"])
#         vm_feas = feas["vms"][bus_i]
#         if vm_feas == 1 
#             # feasible vms get flat-started
#             test_case["bus"][bus_i]["vm_start"] = 1 
#         else 
#             # if infeasible, warm-start at the opposite place
#             if soln["bus"][bus_i]["vm"] > bus["vmax"]
#                 test_case["bus"][bus_i]["vm_start"] = bus["vmin"]
#             else 
#                 test_case["bus"][bus_i]["vm_start"] = bus["vmax"]
#             end
#         end
#     end

#     for (gen_i, gen) in pairs(test_case["gen"])
#         qg_feas = feas["qgs"][gen_i]
#         if qg_feas == 1 
#             # feasible vms get flat-started
#             test_case["gen"][gen_i]["qg_start"] = 0 
#         else 
#             # if infeasible, warm-start at the opposite place
#             if soln["gen"][gen_i]["qg"] > gen["qmax"]
#                 test_case["gen"][gen_i]["qg_start"] = gen["qmin"]
#             else 
#                 test_case["gen"][gen_i]["qg_start"] = gen["qmax"]
#             end
#         end
#     end
#     iter_counter += 1
#     if iter_counter >= max_counter
#         break
#     end
# end

# submat_dict = jacobian_submatrix(result["pf_data"], result["jacobian_history"][end-1], result["mapping_dicts"][end], result["bus indices"])
# p_pqv_pairs = find_feasible_swaps(result["pf_data"], result["solution"], result["bus indices"], submat_dict)
# calculate the inverse for each gen 

# # plot the vms  over the iterations 
# x_history = result["x_history"]
# # vm_history = result["vm_history"]
# # q_history = result["q_history"]
# bus_type_idx = result["pf_data"].bus_type_idx 
# mapping_dict = result["mapping_dicts"][end]
# p = plot(title="Bus vms", legend=:outertopright, ylims = (0.9, 1.1))
# q = plot(title="Gen qgs", legend=:outertopright, ylims = (-0.75, 0.5))
# x_hist = parse_jacobian_history(x_history; is_mat = false)
# jacobian_history = parse_jacobian_history(result["jacobian_history"]; is_mat = true)

# for i in 1:length(test_case["bus"])
#     global p, q
#     if bus_type_idx[i] in [1, 6]
#         p = plot_var_mult(x_hist, i, "vm", result["mapping_dicts"], p)
#     elseif bus_type_idx[i] in [2]
#         q = plot_var_mult(x_hist, i, "q", result["mapping_dicts"], q)
#     end
# end
# display(p)
# display(q)