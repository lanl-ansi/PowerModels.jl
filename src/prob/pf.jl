
using Infiltrator
using Random
using Graphs
using SparseArrays
using OrderedCollections 
using LinearAlgebra
using DataStructures
using Printf
using NLsolve
import NLsolve: nlsolve, trust_region, trust_region_, 
                NonDifferentiable, OnceDifferentiable, 
                NewtonTrustRegionCache, SolverTrace, SolverResults,
                value_jacobian!!, value, value!, check_isfinite, 
                assess_convergence, jacobian, jacobian!, 
                wnorm, dogleg!, @trustregiontrace, euclidean
Infiltrator.toggle_async_check(false)
debug = true
verbose = true
"solves the AC Power Flow in polar coordinates using a JuMP model"
function solve_ac_pf(file, optimizer; kwargs...)
    return solve_pf(file, ACPPowerModel, optimizer; kwargs...)
end

"solves the linear DC Power Flow using a JuMP model"
function solve_dc_pf(file, optimizer; kwargs...)
    return solve_pf(file, DCPPowerModel, optimizer; kwargs...)
end

"solves a formulation-agnostic Power Flow using a JuMP model"
function solve_pf(file, model_type::Type, optimizer; kwargs...)
    return solve_model(file, model_type, optimizer, build_pf; kwargs...)
end

"specification of the formulation agnostic Power Flow model"
function build_pf(pm::AbstractPowerModel)
    variable_bus_voltage(pm, bounded = false)
    variable_gen_power(pm, bounded = false)
    variable_dcline_power(pm, bounded = false)

    for i in ids(pm, :branch)
        expression_branch_power_ohms_yt_from(pm, i)
        expression_branch_power_ohms_yt_to(pm, i)
    end

    constraint_model_voltage(pm)

    for (i,bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_theta_ref(pm, i)
        constraint_voltage_magnitude_setpoint(pm, i)

        # if multiple generators, fix power generation degeneracies
        if length(ref(pm, :bus_gens, i)) > 1
            for j in collect(ref(pm, :bus_gens, i))[2:end]
                constraint_gen_setpoint_active(pm, j)
                constraint_gen_setpoint_reactive(pm, j)
            end
        end
    end

    for (i,bus) in ref(pm, :bus)
        constraint_power_balance(pm, i)

        # PV Bus Constraints
        if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            constraint_voltage_magnitude_setpoint(pm, i)
            for j in ref(pm, :bus_gens, i)
                constraint_gen_setpoint_active(pm, j)
            end
        end
    end


    for (i,dcline) in ref(pm, :dcline)
        #constraint_dcline_power_losses(pm, i) not needed, active power flow fully defined by dc line setpoints
        constraint_dcline_setpoint_active(pm, i)

        f_bus = ref(pm, :bus)[dcline["f_bus"]]
        if f_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, f_bus["index"])
        end

        t_bus = ref(pm, :bus)[dcline["t_bus"]]
        if t_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, t_bus["index"])
        end
    end
end



function compute_dc_pf(file::String; kwargs...)
    data = parse_file(file)
    return compute_dc_pf(data, kwargs...)
end

"""
computes a linear DC power flow based on the susceptance matrix of the network
data using Julia's native linear equation solvers.

returns a solution data structure in PowerModels Dict format
"""
function compute_dc_pf(data::Dict{String,<:Any})
    time_start = time()
    #TODO check single connected component and ref bus

    ref_bus = reference_bus(data)

    bi = calc_bus_injection_active(data)

    # accounts for vm = 1.0 assumption
    for (i,shunt) in data["shunt"]
        if shunt["status"] != 0 && !isapprox(shunt["gs"], 0.0)
            bi[shunt["shunt_bus"]] += shunt["gs"]
        end
    end

    sm = calc_susceptance_matrix(data)

    bi_idx = [bi[bus_id] for bus_id in sm.idx_to_bus]

    ref_idx = sm.bus_to_idx[ref_bus["index"]]

    theta_idx = solve_theta(sm, ref_idx, bi_idx)

    bus_assignment= Dict{String,Any}()
    for (i,bus) in data["bus"]
        va = NaN
        if haskey(sm.bus_to_idx, bus["index"])
            va = theta_idx[sm.bus_to_idx[bus["index"]]]
        end
        bus_assignment[i] = Dict("va" => va)
    end

    solution = Dict("per_unit" => data["per_unit"], "bus" => bus_assignment)

    result = Dict(
        "optimizer" => string(\),
        "termination_status" => true,
        "objective" => 0.0,
        "solution" => solution,
        "solve_time" => time() - time_start
    )

    return result
end




"""
internal data required used solving an ac power flow

the primary use of this data structure is to prevent re-allocation of memory
between successive power flow solves

* `data` -- a power models data dictionary
* `bus_gens` -- for each bus id, a list of active generators
* `am` -- an admittance matrix computed from the data dictionary
* `bus_type_idx` -- bus types (i.e., 1, 2, 3)
* `p_delta_base_idx` -- fixed active power delta at a bus
* `q_delta_base_idx` -- fixed reactive power delta at a bus
* `p_inject_idx` -- variable active power generator injection at a bus
* `q_inject_idx` -- variable reactive power generator injection at a bus
* `vm_idx` -- variable voltage magnitude at a bus
* `va_idx` -- variable voltage angle at a bus
* `neighbors` -- neighboring buses to a given bus
* `x0` -- 2*|N| variables, one for each bus, varies based on bus type
* `F0` -- 2*|N| bus power balance evaluation values, active power followed by reactive power
* `J0` -- a sparse matrix holding the Jacobian of the F0 power balance evaluation function

The postfix `_idx` indicates the admittance matrix indexing convention.
"""
struct PowerFlowData
    data::Dict{String,<:Any}
    bus_gens::Dict{Int,Vector}
    am::AdmittanceMatrix{Complex{Float64}}
    bus_type_idx::Vector{Int}
    p_delta_base_idx::Vector{Float64}
    q_delta_base_idx::Vector{Float64}
    p_inject_idx::Vector{Float64}
    q_inject_idx::Vector{Float64}
    vm_idx::Vector{Float64}
    va_idx::Vector{Float64}
    neighbors::Vector{Set{Int}}
    x0::Vector{Float64}
    F0::Vector{Float64}
    J0::SparseArrays.SparseMatrixCSC{Float64,Int}
end


function instantiate_pf_data(data::Dict{String,<:Any})
    p_delta, q_delta = calc_bus_injection(data)

    # remove gen injections from slack and pv buses
    for (i,gen) in data["gen"]
        gen_bus = data["bus"]["$(gen["gen_bus"])"]
        if gen["gen_status"] != 0
            if gen_bus["bus_type"] == 3
                p_delta[gen_bus["index"]] -= gen["pg"]
                q_delta[gen_bus["index"]] -= gen["qg"]
            elseif gen_bus["bus_type"] == 2
                q_delta[gen_bus["index"]] -= gen["qg"]
            else
                @assert false
            end
        end
    end


    bus_gens = Dict{Int,Array{Any}}()
    for (i,gen) in data["gen"]
        # skip inactive generators
        if gen["gen_status"] == 0
            continue
        end

        gen_bus_id = gen["gen_bus"]
        if !haskey(bus_gens, gen_bus_id)
            bus_gens[gen_bus_id] = []
        end
        push!(bus_gens[gen_bus_id], gen)
    end

    for (bus_id, gens) in bus_gens
        sort!(gens, by=x -> (x["qmax"] - x["qmin"], x["index"]))
    end


    am = calc_admittance_matrix(data)

    bus_type_idx = Int[data["bus"]["$(bus_id)"]["bus_type"] for bus_id in am.idx_to_bus]

    p_delta_base_idx = Float64[-p_delta[bus_id] for bus_id in am.idx_to_bus]
    q_delta_base_idx = Float64[-q_delta[bus_id] for bus_id in am.idx_to_bus]

    p_inject_idx = [0.0 for bus_id in am.idx_to_bus]
    q_inject_idx = [0.0 for bus_id in am.idx_to_bus]

    vm_idx = [1.0 for bus_id in am.idx_to_bus]
    va_idx = [0.0 for bus_id in am.idx_to_bus]

    # for buses with non-1.0 bus voltages
    for (i,bus) in data["bus"]
        if bus["bus_type"] == 2 || bus["bus_type"] == 3
            vm_idx[am.bus_to_idx[bus["index"]]] = bus["vm"]
        end
    end


    neighbors = [Set{Int}([i]) for i in eachindex(am.idx_to_bus)]
    I, J, V = SparseArrays.findnz(am.matrix)
    for nz in eachindex(V)
        push!(neighbors[I[nz]], J[nz])
        push!(neighbors[J[nz]], I[nz])
    end

    x0 = [0.0 for i in 1:2*length(am.idx_to_bus)]
    F0 = [0.0 for i in 1:2*length(am.idx_to_bus)]
    # F0 = similar(x0)

    J0_I = Int[]
    J0_J = Int[]
    J0_V = Float64[]

    for i in eachindex(am.idx_to_bus)
        f_i_r = 2*i - 1
        f_i_i = 2*i

        for j in neighbors[i]
            x_j_fst = 2*j - 1
            x_j_snd = 2*j

            push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            push!(J0_I, f_i_r); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
            push!(J0_I, f_i_i); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            push!(J0_I, f_i_i); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
        end
    end
    J0 = SparseArrays.sparse(J0_I, J0_J, J0_V)
    return PowerFlowData(data, bus_gens, am, bus_type_idx, p_delta_base_idx, q_delta_base_idx, p_inject_idx, q_inject_idx, vm_idx, va_idx, neighbors, x0, F0, J0)
end

function compute_ac_pf(file::String; kwargs...)
    data = parse_file(file)
    return compute_ac_pf(data; kwargs...)
end

function compute_ac_pf(data::Dict{String,<:Any}; kwargs...)
    # TODO check invariants
    # single connected component
    # all buses of type 2/3 have generators on them

    pf_data = instantiate_pf_data(data)
    return compute_ac_pf(pf_data; kwargs...)
end

function compute_ac_pf_mult_buses(data::Dict{String,<:Any}; kwargs...)
    pf_data = instantiate_pf_data(data)
    return compute_ac_pf_mult_buses(pf_data; kwargs...)
end


"""
Computes a nonlinear AC power flow in polar coordinates based on the admittance
matrix of the network data using the NLsolve package.  See the NLsolve
documentation for solver configuration parameters.

Returns a solution data structure in PowerModels Dict format
"""
function compute_ac_pf(pf_data::PowerFlowData; mapping=false, distributed_slack = false, 
                    active_constraint=false, grainger = false, kwargs...)
    time_start = time()
    is_feas = false
    pf_result = nothing
    acpf_counter = 0
    enforce_q_lims = get(kwargs, :enforce_q_lims, false)
    flat_start = get(kwargs, :flat_start, true)
    filtered_kwargs = NamedTuple(filter(kv -> kv[1] != :enforce_q_lims, kwargs))
    prev_bus_indices = []
    converged = nothing
    solution = nothing
    active_set = nothing
    jacobian_history = []
    x_history = []
    vm_history = []
    q_history = []
    soln_history = []
    mapping_dicts = []
    if distributed_slack
        basic_network = PowerModels.make_basic_network(pf_data.data)
        pf_data.data["ptdf"] = PowerModels.calc_basic_ptdf_matrix(basic_network)
        pf_data = distributed_slack_acpf(pf_data)
        # for (i, bus) in enumerate(pf_data.bus_type_idx)
        #     if bus == 3
        #         pf_data.bus_type_idx[i] = 2
        #     end
        # end
    end

    while ~is_feas
        bound_lst = []
        if active_constraint 
            # add bounds to all vms on load buses 
            for (bus_i, bus) in pairs(pf_data.data["bus"])
                bus_ind = pf_data.am.bus_to_idx[parse(Int, bus_i)]
                if pf_data.bus_type_idx[bus_ind] == 1
                    push!(bound_lst, [bus_ind, "vm"])
                end
            end
            # add bounds to all qgs on gen buses 
            for (gen_i, gen) in pairs(pf_data.data["gen"])
                bus_ind = pf_data.am.bus_to_idx[gen["gen_bus"]]
                if pf_data.bus_type_idx[bus_ind] in [2,3]
                    push!(bound_lst, [bus_ind, "q"])
                end
            end
        end
        if mapping
            mapping_dict, J0_map = map_types_to_variable_indices(pf_data; grainger = grainger)
            var_bounds = Dict()
            if active_constraint 
                for bound in bound_lst 
                    og_var = mapping_dict[bound[1]][bound[2]]
                    bus_ind = pf_data.am.idx_to_bus[bound[1]]
                    bus = pf_data.data["bus"][string(bus_ind)]
                    R, mp, S = 0, 0, 0
                    if bound[2] == "vm"
                        R = (bus["vmax"] - bus["vmin"])/2 
                        mp = bus["vmin"] + R
                        S = 1
                    else 
                        gen = pf_data.bus_gens[bus_ind][1] 
                        R = (gen["qmax"] - gen["qmin"])/2 
                        mp = gen["qmin"] + R 
                        S = 10
                    end
                    var_bounds[og_var] = [mp, R, S]
                end
            end
            push!(mapping_dicts, mapping_dict)
            if active_constraint
                pf_result, jacobian, x_hist, vm_hist, q_hist = _compute_ac_pf_bounded(pf_data, mapping_dict, J0_map, flat_start=true; 
                                            var_bounds = var_bounds, filtered_kwargs...) 
                vm_history = vcat(vm_history, vm_hist)
                push!(vm_history, [])
                q_history = vcat(q_history, q_hist)
                push!(q_history, [])
            elseif grainger 
             pf_result, jacobian, x_hist = _compute_ac_pf_grainger(pf_data, mapping_dict, J0_map, flat_start=false; 
                                            filtered_kwargs...)  
            else 
                pf_result, jacobian, x_hist = _compute_ac_pf(pf_data, mapping_dict, J0_map, flat_start=true; 
                                            filtered_kwargs...)   
            end            
            x_history = vcat(x_history, x_hist)
            push!(x_history, [])

            jacobian_history = vcat(jacobian_history, jacobian)
            push!(jacobian_history, [])
        else
            pf_result, jacobian, x_hist = _compute_ac_pf(pf_data, flat_start=flat_start; filtered_kwargs...)
            x_history = vcat(x_history, x_hist)
            push!(x_history, [])
            jacobian_history = vcat(jacobian_history, jacobian)
            push!(jacobian_history, [])

        end 
        
        acpf_counter += 1
        is_feas = true
        solution = Dict("per_unit" => pf_data.data["per_unit"])

        converged = pf_result.x_converged || pf_result.f_converged
        # is_feas = pf_result.x_converged || pf_result.f_converged

        if !converged
            bus_assignment = Dict(i => Dict("vm"=>-1, "va"=>-1) for i in keys(pf_data.data["bus"]))
            gen_assignment = Dict(i => Dict("pg"=>-1, "qg"=>-1) for i in keys(pf_data.data["gen"]))
            solution =   Dict(
            "per_unit" => pf_data.data["per_unit"],
            "bus" => bus_assignment,
            "gen" => gen_assignment,
            )
            
            @_debug( "ac power flow solver convergence failed!  use `show_trace = true` for more details")
        else
            data = pf_data.data
            bus_gens = pf_data.bus_gens
            am = pf_data.am
            bus_type_idx = pf_data.bus_type_idx
            pv_bus_inds = [i for i in range(1,length(bus_type_idx)) if bus_type_idx[i] == 2]
            push!(prev_bus_indices, deepcopy(pf_data.bus_type_idx))
            bus_assignment= Dict{String,Any}()
            for (i,bus) in data["bus"]
                if bus["bus_type"] != 4
                    bus_idx = am.bus_to_idx[bus["index"]]
                    bus_assignment[i] = Dict{String,Float64}(
                        "vm" => pf_data.vm_idx[bus_idx],
                        "va" => pf_data.va_idx[bus_idx]
                    )
                end
            end

            gen_assignment= Dict{String,Any}()
            for (i,gen) in data["gen"]
                if gen["gen_status"] != 0
                    gen_assignment[i] = Dict{String,Float64}(
                        "pg" => gen["pg"],
                        "qg" => gen["qg"]
                    )
                end
            end


            for (i,bid) in enumerate(am.idx_to_bus)
        
                bus = bus_assignment["$(bid)"]

                if bus_type_idx[i] == 1
                    if ~enforce_q_lims
                        @assert !haskey(bus_gens, bid)
                    end
                    if ~mapping
                        bus["vm"] = pf_result.zero[2*i - 1]
                        bus["va"] = pf_result.zero[2*i]
                    else
                        bus["vm"] = pf_result.zero[mapping_dict[i]["vm"]]
                        bus["va"] = pf_result.zero[mapping_dict[i]["va"]]
                    end

                elseif bus_type_idx[i] == 2
                    for gen in bus_gens[bid]
                        sol_gen = gen_assignment["$(gen["index"])"]
                        sol_gen["qg"] = 0.0
                    end
                    if ~mapping
                        qg_remaining = -pf_result.zero[2*i - 1]
                    else
                        qg_remaining = -pf_result.zero[mapping_dict[i]["q"]]
                    end
                    _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
                    if enforce_q_lims && is_feas
                        # check if any buses have exceeded the qg bounds 
                        bus_feas = true
                        for gen in bus_gens[bid]
                            qg = gen_assignment["$(gen["index"])"]["qg"]
                            if qg < gen["qmin"] 
                                bus_feas = false
                                gen["qg"] = gen["qmin"]
                                pf_data.q_inject_idx[i] += qg
                                pf_data.q_inject_idx[i] -= gen["qg"]
                            elseif qg > gen["qmax"]
                                bus_feas = false
                                gen["qg"] = gen["qmax"]
                                pf_data.q_inject_idx[i] += qg
                                pf_data.q_inject_idx[i] -= gen["qg"]
                            end
                        end
                        # if bounds are exceeded, switch to pq bus
                        if ~bus_feas 
                            if verbose 
                                @_debug( "switching PV bus $i from 2 to 1... ")
                            end
                            pf_data.bus_type_idx[i] = 1
                            is_feas = false
                        end
                    end
                    if ~mapping
                        bus["va"] = pf_result.zero[2*i]
                    else
                        bus["va"] = pf_result.zero[mapping_dict[i]["va"]]
                    end

                elseif bus_type_idx[i] == 3
                    for gen in bus_gens[bid]
                        sol_gen = gen_assignment["$(gen["index"])"]
                        sol_gen["pg"] = 0.0
                        sol_gen["qg"] = 0.0
                    end
                    if ~mapping
                        pg_remaining = -pf_result.zero[2*i - 1]
                    else
                        pg_remaining = -pf_result.zero[mapping_dict[i]["p"]]
                    end
                    _assign_pg!(gen_assignment, bus_gens[bid], pg_remaining)

                    if ~mapping 
                        qg_remaining = -pf_result.zero[2*i]
                    else 
                        qg_remaining = -pf_result.zero[mapping_dict[i]["q"]]
                    end
                    _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
                else
                    @assert false
                end
            end

            solution = Dict(
                "per_unit" => data["per_unit"],
                "bus" => deepcopy(bus_assignment),
                "gen" => deepcopy(gen_assignment),
            )
            push!(soln_history, solution)
        end
    end
    solution["acpf_counter"] = acpf_counter
    result = Dict(
        "optimizer" => "NLsolve",
        "bus indices" => pf_data.bus_type_idx,
        "prev_bus_indices" => prev_bus_indices,
        "termination_status" => converged,
        "objective" => 0.0,
        "solution" => solution,
        "solution_history" => soln_history,
        "solve_time" => time() - time_start,
        "pf_data" => pf_data,
        "jacobian_history" => jacobian_history, 
        "x_history" => x_history,
        "vm_history" => vm_history,
        "q_history" => q_history,
        "mapping_dicts" => mapping_dicts
    )

    return result
end

function _update_x_!(pf_data, prev_soln, prev_bti, mapping_dict, x)
    # construct the x for the prev solution + new values 
    am = pf_data.am
    bti = pf_data.bus_type_idx
    for (i, (bt, prv_bt)) in enumerate(zip(bti, prev_bti))
        bus_str = string(am.idx_to_bus[i])
        gen_str = nothing 
        if bt in [2, 3, 6]
            gen_str = string(pf_data.bus_gens[am.idx_to_bus[i]][1]["index"])
        end
        if bt == 1
            x[mapping_dict[i]["va"]] = prev_soln["bus"][bus_str]["va"] 
            if prv_bt == 2
                # pv-pq switch: store the vm from the prev solution
                x[mapping_dict[i]["vm"]] = prev_soln["bus"][bus_str]["vm"]
            elseif prv_bt == 5 
                # pqv-pq switch: store the vm that's been set 
                x[mapping_dict[i]["vm"]] = pf_data.vm_idx[i]
            else 
                x[mapping_dict[i]["vm"]] = prev_soln["bus"][bus_str]["vm"]
            end
        elseif bt == 2 
            x[mapping_dict[i]["va"]] = prev_soln["bus"][bus_str]["va"]
            x[mapping_dict[i]["q"]] = prev_soln["gen"][gen_str]["qg"]
        elseif bt == 3 
            x[mapping_dict[i]["q"]] = prev_soln["gen"][gen_str]["qg"]
            x[mapping_dict[i]["p"]] = prev_soln["gen"][gen_str]["pg"]
        elseif bt == 5 
            x[mapping_dict[i]["va"]] = prev_soln["bus"][bus_str]["va"]
        elseif bt == 6 
            x[mapping_dict[i]["va"]] = prev_soln["bus"][bus_str]["va"]   
            x[mapping_dict[i]["q"]] = prev_soln["gen"][gen_str]["qg"]
            x[mapping_dict[i]["vm"]] = prev_soln["bus"][bus_str]["vm"]
        end
    end
end
function compute_acpf_sensitivity(pf_data, prev_soln,  prev_bti; eps = 1e-3)
    mapping_dict, J0 = map_types_to_variable_indices(pf_data)
    x = zeros(Float64, 2*length(pf_data.am.idx_to_bus))
    _update_x_!(pf_data, prev_soln, prev_bti, mapping_dict, x)
    # compute the delta x with the slight changes in x and system values 
    delta_x = _ac_pf_sensitivity(pf_data, mapping_dict, J0, x)
    #  see which values of x changed
    delta_indices = findall(val -> abs(val) >= eps, delta_x)
    return delta_indices
end 

function map_types_to_variable_indices(pf_data; first_iter = false, bounded_vars = [], 
                                        grainger = false)
    bus_type_idx = pf_data.bus_type_idx
    am = pf_data.am 
    neighbors = pf_data.neighbors
    # as you go, update the x0
    mapping_dict = Dict(bus_ind => Dict("va" => 0, "vm" => 0, "p" => 0, "q" => 0, 
                                        "p_row" => grainger ? 0 : 2*i - 1, "q_row"=> grainger ? 0 : 2*i) 
                        for (i, bus_ind) in enumerate(values(pf_data.am.bus_to_idx)))
    type_1, type_2, type_3, type_5, type_6 = [], [], [], [], []
    for (ind, type) in enumerate(bus_type_idx)
        if type == 1
            push!(type_1, ind)
        elseif type == 2
            push!(type_2, ind)
        elseif type == 3
            push!(type_3, ind)
        elseif type == 5
            push!(type_5, ind)
        elseif type == 6
            push!(type_6, ind)
        else 
            @assert false 
        end
    end
    counter, g_counter = 1, 1
    if grainger 
        # only type 1, 2, 5, and 6 will have real power balance equations.
        final_prow = 0
        for (i, bus) in enumerate(vcat(type_1,type_2, type_5, type_6))
            mapping_dict[bus]["p_row"] = i 
            final_prow = i
        end 
        # only type 1, and 5 will have reactive power balance equations. 
        final_qrow = 0
        for (i, bus) in enumerate(vcat(type_1, type_5))
            mapping_dict[bus]["q_row"] = final_prow + i
            final_qrow = final_prow + i
        end
        # the remaining bus types will have leftover variables at the end of the list  
        final_extrarow = 0
        for (i, bus) in enumerate(vcat(type_2, type_3, type_6))
            mapping_dict[bus]["q_row"] = final_qrow + i 
            final_extrarow = final_qrow + i
        end
    end
    # type 1 first 
    for ind in type_1
        mapping_dict[ind]["va"] = counter
        mapping_dict[ind]["vm"] = counter + 1
        if first_iter 
            pf_data.x0[counter + 1] = 1
        end
        counter += 2
    end
    # type 2 
    for ind in type_2
        if grainger 
            mapping_dict[ind]["va"] = counter 
            mapping_dict[ind]["q"] = g_counter
            g_counter += 1
            counter += 1 
        else
            mapping_dict[ind]["q"] = counter
            mapping_dict[ind]["va"] = counter + 1
            counter += 2
        end
    end
    # type 3
    for ind in type_3
        if ~grainger
            mapping_dict[ind]["p"] = counter
            mapping_dict[ind]["q"] = counter + 1
            counter += 2
        else 
            mapping_dict[ind]["p"] = g_counter
            mapping_dict[ind]["q"] = g_counter + 1
            g_counter += 2            
        end
    end
    # type 5 
    for ind in type_5
        mapping_dict[ind]["va"] = counter
        counter += 1
    end
    # type 6
    for ind in type_6
        if grainger 
            mapping_dict[ind]["va"] = counter 
            mapping_dict[ind]["vm"] = counter + 1
            mapping_dict[ind]["q"] = g_counter
            counter += 2
            g_counter += 1
        else
            mapping_dict[ind]["q"] = counter
            mapping_dict[ind]["va"] = counter + 1
            mapping_dict[ind]["vm"] = counter + 2
            if first_iter 
                pf_data.x0[counter + 2] = 1
            end
            counter += 3
        end
    end
    # re-create J0 matrix for pf data with new indices 
    cols = Int[]
    rows = Int[]
    entries = Float64[]
    for i in eachindex(am.idx_to_bus)
        f_i_r = mapping_dict[i]["p_row"]
        f_i_i = mapping_dict[i]["q_row"]
        if i in type_3
            continue 
        end 
        if ~grainger
            for j in neighbors[i]
                mapping = mapping_dict[j]
                if mapping["p"] != 0
                    push!(rows, f_i_r); push!(cols, mapping["p"]); push!(entries, 0.0)
                    if bus_type_idx[i] in [1,6]
                        push!(rows, f_i_i); push!(cols, mapping["p"]); push!(entries, 0.0)
                    end
                end
                if mapping["q"] != 0
                    push!(rows, f_i_r); push!(cols, mapping["q"]); push!(entries, 0.0)
                    if bus_type_idx[i] in [1,6]
                        push!(rows, f_i_i); push!(cols, mapping["q"]); push!(entries, 0.0)
                    end
                end
                if mapping["va"] != 0
                    push!(rows, f_i_r); push!(cols, mapping["va"]); push!(entries, 0.0)
                    if bus_type_idx[i] in [1,6]
                        push!(rows, f_i_i); push!(cols, mapping["va"]); push!(entries, 0.0)   
                    end
                end
                if mapping["vm"] != 0
                    push!(rows, f_i_r); push!(cols, mapping["vm"]); push!(entries, 0.0)
                    if bus_type_idx[i] in [1,6]
                        push!(rows, f_i_i); push!(cols, mapping["vm"]); push!(entries, 0.0)   
                    end
                end      
            end
        else 
            for j in neighbors[i] 
                mapping = mapping_dict[j] 
                if bus_type_idx[j] != 3 
                    # add vas to mapping 
                    push!(rows, f_i_r); push!(cols, mapping["va"]); push!(entries, 0.0)
                    if bus_type_idx[i] in [1,5]
                        push!(rows, f_i_i); push!(cols, mapping["va"]); push!(entries, 0.0)   
                    end  
                    # add vms to mapping   
                    if bus_type_idx[j] in [1,6] 
                        push!(rows, f_i_r); push!(cols, mapping["vm"]); push!(entries, 0.0)
                        if bus_type_idx[i] in [1,5]
                            push!(rows, f_i_i); push!(cols, mapping["vm"]); push!(entries, 0.0)   
                        end      
                    end                            
                end
            end 

        end
    end
    if length(bounded_vars) > 0
        final_row = 2*length(bus_type_idx)
        # add bounded variables and equations 
        for (i, bv) in enumerate(bounded_vars) 
            var_ind = mapping_dict[bv[1]][bv[2]] # variable to be bounded 
            mapping_dict[bv[1]]["$(bv[2])_bound"] = final_row + i # add bounding variable 
            push!(rows, final_row + i); push!(cols, var_ind); push!(entries, 0.0) # add new equation (related to OG variable)
            push!(rows, final_row + i); push!(cols, final_row + i); push!(entries, 0.0) # add new equation (related to bound variable)
        end
    end
    J0_map = SparseArrays.sparse(rows, cols, entries)
    if grainger 
        num_vars = sum([1 for val in values(mapping_dict) if val["vm"] != 0]) + sum([1 for val in values(mapping_dict) if val["va"] != 0]) 
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] in [2,3,6]
                mapping_dict[i]["q"] += num_vars
                if bus_type_idx[i] == 3 
                    mapping_dict[i]["p"] += num_vars
                end
            end 
        end
    end
    return mapping_dict, J0_map
end


function determine_reduced_J(pf_data, J::SparseArrays.SparseMatrixCSC{Float64,Int}; vm_idx=nothing, va_idx=nothing)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    n_buses = length(bus_type_idx)
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = vm_idx === nothing ? pf_data.vm_idx : vm_idx
    va_idx = va_idx === nothing ? pf_data.va_idx : va_idx
    neighbors = pf_data.neighbors
    # functions for each type of derivative
    function dpdv(i)
        y_ii = am.matrix[i, i]
        return 2*real(y_ii)*vm_idx[i] + sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
    end
    function dqdv(i)
        y_ii = am.matrix[i, i]
        return -2*imag(y_ii)*vm_idx[i] + sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
    end
    function dpdtheta(i)
        return vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
    end
    function dqdtheta(i)
        return vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
    end
    function dpdp(i)
        return 1
    end
    function dqdp(i)
        return 0
    end
    function dpdq(i)
        return 0
    end
    function dqdq(i)
        return 1
    end
    function dpn_dv(i, j)
        y_ij = am.matrix[i,j]
        return vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
    end
    function dqn_dv(i, j)
        y_ij = am.matrix[i,j]
        return vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
    end
    function dpn_dtheta(i, j)
        y_ij = am.matrix[i,j]
        return vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
    end
    function dqn_dtheta(i, j)
        y_ij = am.matrix[i,j]
        return vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
    end
    # iterate through each power balance equation
    for i in eachindex(am.idx_to_bus)
        r_real = i
        r_imag = n_buses + i 
        for j in neighbors[i]
            vm_ind = n_buses + j
            va_ind = j
            if i == j 
                J[r_real, vm_ind] = dpdv(i)
                J[r_real, va_ind] = dpdtheta(i)
                J[r_imag, vm_ind] = dqdv(i)
                J[r_imag, va_ind] = dqdtheta(i)
            else 
                J[r_real, vm_ind] = dpn_dv(i, j)
                J[r_real, va_ind] = dpn_dtheta(i, j)
                J[r_imag, vm_ind] = dqn_dv(i, j)
                J[r_imag, va_ind] = dqn_dtheta(i, j)
            end
        end 
    end 
    # get sub-matrices 
    J_pthet = J[1:n_buses, 1:n_buses]
    J_pv = J[1:n_buses, n_buses+1:2*n_buses]
    J_qthet = J[n_buses+1 : 2*n_buses, 1:n_buses]
    J_qv = J[n_buses + 1 : 2 * n_buses, n_buses + 1 : 2 * n_buses]
    return J, J_pthet, J_pv, J_qthet, J_qv
    # # calculate J_reduced 
    # J_r = J_qv - J_qthet * J_pthet \ J_pv
    # return J_r
end

function distributed_slack_acpf(pf_data::PowerFlowData)
    # step 1: find total losses 
    p_inj = [0.0 for _ in 1:length(pf_data.data["bus"])] # net power injection (real)
    gen_pg = [0.0 for _ in 1:length(pf_data.data["gen"])]
    for (l, load) in pairs(pf_data.data["load"])
        bus = pf_data.am.bus_to_idx[load["load_bus"]]
        p_inj[bus] -= load["pd"]
    end 
    for (g, gen) in pairs(pf_data.data["gen"])
        bus = pf_data.am.bus_to_idx[gen["gen_bus"]]
        gen_pg[parse(Int, g)] = gen["pg"]
        p_inj[bus] += gen["pg"]
    end 
    # p_ref = transpose([branch["pf"] for branch in values(PowerModels.calc_branch_flow_dc(pf_data.data)["branch"])]) # reference branch flows 
    p_ref = transpose(pf_data.data["ptdf"] * p_inj) # reference branch flows
    res = transpose([branch["br_r"] for branch in values(pf_data.data["branch"])]) # line resistance 
    lambda_T = 2 * [sum(transpose(res .* p_ref) .* pf_data.data["ptdf"][:,i]) for i in 1:length(pf_data.data["bus"])] # lambda line flows 
    l_ref = sum(r*p^2 for (r, p) in zip(res, p_ref)) # reference loss 
    l_tot = (transpose(lambda_T) * p_inj)[1] - l_ref # total line losses 
    # println("total loss: $l_tot")
    # println("gen setpoints before DS: $([gen["pg"] for gen in values(pf_data.data["gen"])])")
    #step 2: update headroom 
    headroom = zeros(length(pf_data.data["gen"]))
    total_pmax = 0
    for (g, gen) in pairs(pf_data.data["gen"])
        g = parse(Int, g)
        headroom[g] = max(gen["pmax"] - gen["pg"], 0)
        total_pmax += gen["pmax"]
    end
    # step 3: update participation factors 
    participation = zeros(length(pf_data.data["gen"]))
    total_headroom = sum(headroom)
    pmax = total_headroom == 0
    for (g, gen) in pairs(pf_data.data["gen"])
        g = parse(Int, g)
        participation[g] = pmax ? gen["pmax"]/total_pmax : headroom[g]/total_headroom
    end
    # step 4: update generation setpoints 
    for (g, gen) in pairs(pf_data.data["gen"])
        g = parse(Int, g)
        pf_data.data["gen"]["$g"]["pg"] = gen["pg"] + participation[g] * l_tot
    end
    # println("gen setpoints after DS: $([gen["pg"] for gen in values(pf_data.data["gen"])])")
    # return updated test case 
    return pf_data
end

function compute_ac_pf_mult_buses(pf_data::PowerFlowData; obo = false,  update_qlim = true, q_first = true, flat_start = true,
                                      distributed_slack = false, control_areas = false, clusters = nothing, 
                                      max_acpf = 100, minimize_mag = true, one_swap = true, highest_mag = true, grainger = false, kwargs...)
    
    is_feas = false
    pf_result = nothing
    acpf_counter = 1
    converged = nothing
    best_converged = nothing
    solution = nothing
    jacobian_history = []
    x_history = []
    soln_history = []
    mapping_dicts = []
    bus_indices = []
    delta_x = []
    neighbors = pf_data.neighbors
    best_solution = Dict()
    best_solution["best_score"] = 1e6 
    best_solution["solution"] = solution 
    best_solution["converged"] = false 
    # update pf data values 
    best_solution["bus_type_idx"] = pf_data.bus_type_idx
    best_solution["vm_idx"] = pf_data.vm_idx
    best_solution["va_idx"] = pf_data.va_idx
    best_solution["p_inject_idx"] = pf_data.p_inject_idx
    best_solution["q_inject_idx"] = pf_data.q_inject_idx
    best_solution["p_delta_base_idx"] = pf_data.p_delta_base_idx
    best_solution["q_delta_base_idx"] = pf_data.q_delta_base_idx
    best_solution["pf_data"] = pf_data
    best_solution["p_pqv_pairs"] = Dict()
    p_pqv_pairs = Dict{Int64,Int64}()
    non_convergence = 0
    pf_data.data["pv_bus_inds"] = [i for (i, bt) in enumerate(pf_data.bus_type_idx) if bt == 2]
    jacobian = nothing 
    if grainger  
        pf_data.data["prev_swaps"] = Dict(bus=> [] for bus in 1:length(pf_data.bus_type_idx))
    end
    if control_areas
        pf_data.data["clusters"] = clusters 
    end
    if distributed_slack
        basic_network = PowerModels.make_basic_network(pf_data.data)
        pf_data.data["ptdf"] = PowerModels.calc_basic_ptdf_matrix(basic_network)
    end
    time_start = time()
    while (~is_feas) & (acpf_counter <= max_acpf)
        if distributed_slack
            pf_data = distributed_slack_acpf(pf_data)
        end
        if verbose 
            @_debug( "computing ac pf, iteration $(acpf_counter)... ")
        end
        mapping_dict, J0_map = map_types_to_variable_indices(pf_data,  grainger = grainger)
        if  (~flat_start ) & (acpf_counter > 1) & (length(soln_history) >= 1)
            _update_x_!(pf_data, soln_history[end], pf_data.bus_type_idx, mapping_dict, pf_data.x0)
        end
        try
            if grainger 
                pf_result, jacobian, x_hist = _compute_ac_pf_grainger(pf_data, mapping_dict, J0_map, flat_start=false; 
                                            kwargs...) 
            else 
                pf_result, jacobian, x_hist = _compute_ac_pf(pf_data, mapping_dict, J0_map; flat_start = flat_start,  kwargs...) 
            end
            jacobian_history = vcat(jacobian_history, jacobian)
            x_history = vcat(x_history, x_hist)
            push!(x_history, [])
            push!(jacobian_history, [])
            mapping_dicts = vcat(mapping_dicts, mapping_dict)
        catch e 
            rethrow(e)
            pf_result.x_converged = false
            pf_result.f_converged = false
            non_convergence = 5
        end
        is_feas = true
        solution = Dict("per_unit" => pf_data.data["per_unit"])
        converged = pf_result.x_converged || pf_result.f_converged 
        if !converged
            non_convergence += 1
            if verbose
                @_debug( "ac power flow solver convergence failed!")
            end
            if (acpf_counter > max_acpf) || (non_convergence > 5)
                solution = best_solution["solution"]
                bus_type_idx = best_solution["bus_type_idx"]
                pf_data = best_solution["pf_data"]
                best_converged = true
            else
                if verbose  
                    @_debug( "continuing from best solution")
                    @_debug( "Restoring p-pqv-pairs: $(best_solution["p_pqv_pairs"])")
                end
                is_feas = false 
                update_pf_data!(pf_data.bus_type_idx, best_solution["bus_type_idx"])
                update_pf_data!(pf_data.vm_idx, best_solution["vm_idx"])
                update_pf_data!(pf_data.va_idx, best_solution["va_idx"])
                update_pf_data!(pf_data.p_inject_idx, best_solution["p_inject_idx"])
                update_pf_data!(pf_data.q_inject_idx, best_solution["q_inject_idx"])
                update_pf_data!(pf_data.p_delta_base_idx, best_solution["p_delta_base_idx"])
                update_pf_data!(pf_data.q_delta_base_idx, best_solution["q_delta_base_idx"])
                warm_start_prev_soln!(pf_data, best_solution["solution"])
                p_pqv_pairs = deepcopy(best_solution["p_pqv_pairs"])
            end
            if isnothing(best_solution)
                if verbose
                    @_debug( "No converged state thus far.")
                end
                bus_assignment = Dict(i => Dict("vm"=>-1, "va"=>-1) for i in keys(pf_data.data["bus"]))
                gen_assignment = Dict(i => Dict("pg"=>-1, "qg"=>-1) for i in keys(pf_data.data["gen"]))
                solution =   Dict(
                "per_unit" => pf_data.data["per_unit"],
                "bus" => bus_assignment,
                "gen" => gen_assignment,
                )
                best_converged = false
                best_solution = solution
            end

        else
            data = pf_data.data
            bus_gens = pf_data.bus_gens
            am = pf_data.am
            bus_type_idx = deepcopy(pf_data.bus_type_idx)
            old_pfd = deepcopy(pf_data)
            old_pairs = deepcopy(p_pqv_pairs)
            push!(bus_indices, deepcopy(pf_data.bus_type_idx))


            # assign buses bus variables
            bus_assignment= Dict{String,Any}()
            for (i,bus) in data["bus"]
                if bus["bus_type"] != 4
                    bus_idx = am.bus_to_idx[bus["index"]]

                    bus_assignment[i] = Dict{String,Float64}(
                        "vm" => pf_data.vm_idx[bus_idx],
                        "va" => pf_data.va_idx[bus_idx],
                        "bus_idx" => bus["index"],
                        "vmin" => bus["vmin"],
                        "vmax" => bus["vmax"]
                    )
                end
            end

            # assign generators gen variables
            gen_assignment= Dict{String,Any}()
            for (i,gen) in data["gen"]
                if gen["gen_status"] != 0
                    gen_assignment[i] = Dict{String,Float64}(
                        "pg" => gen["pg"],
                        "qg" => gen["qg"]
                    )
                end
            end

            # update each bus type 
            swap = Ref(false)
            violation_mag = Ref(0.0)
            num_violations = Ref(0.0)
            is_feas = Ref(true)
            b1_violations = Vector{Tuple{Int64, Float64, Float64}}()
            b2_violations = Vector{}()
            b6v_violations = Vector{}()
            b6q_violations = Vector{}()
            for (i, bt) in enumerate(bus_type_idx)
                i = Int(i)
                if bt == 1
                    update_bt1!(i, pf_data, pf_result, mapping_dict, bus_assignment, is_feas, 
                                num_violations, violation_mag; b_violations = b1_violations)
                elseif bt == 2
                    update_bt2!(i, pf_data, pf_result, mapping_dict, bus_assignment, gen_assignment, is_feas,  
                                num_violations, violation_mag, b2_violations)
                elseif bt == 3
                    update_bt3!(i, pf_data, pf_result, mapping_dict, bus_assignment, gen_assignment)
                elseif bt == 5 
                    update_bt5!(i, pf_data, pf_result, mapping_dict, bus_assignment)
                elseif bt == 6 
                    update_bt6!(i, pf_data, pf_result, mapping_dict, bus_assignment, gen_assignment, 
                                is_feas, num_violations,  violation_mag, b6v_violations, b6q_violations)
                end
            end

            if control_areas & ~one_swap
                b1_violations = update_pilot_buses!(pf_data, b1_violations, bus_assignment, swap)
            end
            # swap back p-pqv pair 
            if one_swap 
                if length(p_pqv_pairs) > 0 
                    p_bus = first(p_pqv_pairs).first
                    pqv_bus = pop!(p_pqv_pairs, p_bus)
                    # the new vm has been stored. Swap the bus types back 
                    if verbose 
                        @_debug( "switching p-pqv pair $p_bus-$pqv_bus... ")
                    end
                    update_bus_type!(pf_data, pqv_bus, 1)
                    update_bus_type!(pf_data, p_bus, 2)
                    # check to see if this bus had any violations 
                    v_viol_ind = findfirst(x -> x[1] == p_bus, b6v_violations)
                    if ~isnothing(v_viol_ind)
                        # if v was violated, reset it to its max/min 
                        v_viol = splice!(b6v_violations, v_viol_ind)
                        pf_data.vm_idx[v_viol[1]] = v_viol[3]
                        if verbose 
                            @_debug( "adjusting vm at $p_bus")
                        end
                    end
                    swap[] = true
                end
            end
            # store the solution for current iteration
            solution = Dict(
                "per_unit" => data["per_unit"],
                "bus" => deepcopy(bus_assignment),
                "gen" => deepcopy(gen_assignment),
            )
            push!(soln_history, solution)
            score = minimize_mag ? violation_mag[] : num_violations[]
            update_best_solution!(best_solution, old_pfd, score, solution, old_pairs, bus_type_idx, mapping_dict)

            # swap buses for next iteration
            if grainger 
                perform_bus_swaps_grainger!(pf_data, mapping_dict, jacobian[end], bus_type_idx, p_pqv_pairs, bus_assignment, swap, 
                                            b1_violations, b2_violations, b6v_violations, b6q_violations, 
                                            obo)
            else
                perform_bus_swaps!(pf_data, bus_assignment, p_pqv_pairs, b1_violations, b2_violations, 
                                b6v_violations, b6q_violations, swap, obo = obo, 
                                qfirst = q_first, one_pair = one_swap, highest_mag=highest_mag)
            end


            if score <= 1e-4
                if verbose 
                    @_debug( "Feasible Run")
                end    
                is_feas = true    
                break
            else 
                is_feas = ~swap[]
            end
            if is_feas  
                if verbose 
                    @_debug( "Ending with $(score), but no swap")
                end
            end
        end
        if acpf_counter > max_acpf 
            break 
        end
        # warm start 
        warm_start_prev_soln!(pf_data, solution)
        acpf_counter += 1
    end
    best_solution["acpf_counter"] = acpf_counter
    result = Dict(
        "optimizer" => "NLsolve",
        "bus indices" => best_solution["bus_type_idx"],
        "prev_bus_indices" => bus_indices,
        "termination_status" => best_solution["converged"],
        "objective" => 0.0,
        "solution" => best_solution["solution"],
        "solution_history" => soln_history,
        "solve_time" => time() - time_start, 
        "pf_data" => best_solution["pf_data"],
        "jacobian_history" => jacobian_history, 
        "x_history" => x_history,
        "mapping_dicts" => mapping_dicts, 
        "delta_x" => delta_x
    )

    return result
end

function _print_violations_(viol_lst)
    count = length(viol_lst)
    viols = [elem[end - 1] for elem in viol_lst]
    return "count: $count \n violations: $viols"
end

function perform_bus_swaps_grainger!(pf_data, mapping_dict, jacobian, bus_type_idx, p_pqv_pairs, bus_assignment, swap, 
                                        b1_violations, b2_violations, b6v_violations, b6q_violations, 
                                        obo)
    # update q violations first
    all_qs = vcat(b2_violations, b6q_violations)
    sort!(all_qs, by = x -> sort_func(x[4]))
    update_q_violations!(pf_data, all_qs, p_pqv_pairs, obo, swap)
    if obo & swap[] 
        return 
    end
    # update the voltage violations at type 6 buses 
    sort!(b6v_violations, by = x -> sort_func(x[2]))
    update_vm_violations!(pf_data, b6v_violations, p_pqv_pairs, obo, swap)
    if obo & swap[] 
        return 
    end 
    # update the voltage violations at type 1 buses
    submat_dict = _jacobian_submatrix_(pf_data, jacobian, mapping_dict, bus_type_idx)
    # get the generator inverse matrix 
    inv_qv = inv(submat_dict["qv"])
    gen_invs = Float64.(reduce(hcat, [inv_qv * vec for vec in submat_dict["qv_cols"]]))
    # get violated rows and cols
    num_gens = length(submat_dict["qv_cols"])
    sort!(b1_violations, by = x -> sort_func(x[2])) # sort violations by highest magnitude first
    violated_rows = [submat_dict["submap"]["qv_rows"][i[1]] for i in b1_violations]
    violated_rows, gen_ordering = _reorder_cols_(pf_data.data["prev_swaps"], b1_violations, violated_rows, submat_dict)
    # identify pivot columns (LI generators to swap out buses)
    F = lu(reshape(gen_invs[violated_rows, gen_ordering], length(violated_rows), num_gens))
    diag_elems = diag(F.U)
    pivot_cols = findall(x -> abs(x) > 1e-3, diag_elems)
    swap_candidates = [k for (k, v) in submat_dict["submap"]["qv_cols"] if v in gen_ordering[pivot_cols]]
    # bus-type switching 
    swap_pqv_buses_grainger!(pf_data, b1_violations[pivot_cols], swap_candidates, p_pqv_pairs, bus_assignment, swap)
    return
end

function _reorder_cols_(prev_swaps, b1_violations, violated_rows, submat_dict)
    qv_cols = submat_dict["submap"]["qv_cols"]
    # get the initial ordering
    gen_ordering = zeros(length(qv_cols))
    for (gen, ind) in pairs(qv_cols)
        gen_ordering[ind] = gen 
    end
    # make sure no pairs exist between the violation and the generator 
    num_viols = length(b1_violations)
    for (i, viol) in enumerate(b1_violations) 
        bus = viol[1]
        bad_gens = prev_swaps[bus]
        if length(bad_gens) == 0
            # this bus has no off-limits generators
            continue 
        end
        if !(gen_ordering[i] in bad_gens)
            # this bus can be matched with this generator 
            continue 
        end
        if length(bad_gens) == length(gen_ordering)
            # this violation has no remaining feasible generators
            filter!(x -> x == submat_dict["submap"]["qv_rows"][bus], violated_rows)
            continue 
        end

        # if there are more generators than b1 violations, swaps are easy 
        if num_viols < length(gen_ordering)
            viable_gens = setdiff(gen_ordering[(num_viols + 1):end], bad_gens)
            swap_ind = findall(x -> x == viable_gens[1], gen_ordering)[1]
            gen_ordering[swap_ind] = gen_ordering[i] 
            gen_ordering[i] = viable_gens[1]
        end
    end
    gens = [qv_cols[i] for i in gen_ordering]
    return violated_rows, gens
end

function _jacobian_submatrix_(pf_data, jacobian, mapping_dict, bus_indices)
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
                        "qv_cols" => _determine_gen_cols_(pf_data, t1, t2, t5),
                        "submap" => submapping_dict
                        )
    return submat_dict
end

function _determine_gen_cols_(pf_data, t1, t2, t5)
    vm_idx = pf_data.vm_idx 
    va_idx = pf_data.va_idx 
    neighbors = pf_data.neighbors 
    am = pf_data.am 
    function dqn_dv(i, j)
        y_ij = am.matrix[i,j]
        return vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
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

function perform_bus_swaps!(pf_data, bus_assignment, p_pqv_pairs, b1_violations, b2_violations, 
                                b6v_violations, b6q_violations, swap; obo = false, qfirst = false, one_pair=false, highest_mag=true)
    if verbose
        @_debug( "p-pqv pairs: $p_pqv_pairs")
    end
    sort_func = highest_mag ? val -> -abs(val) : val -> abs(val)
    if qfirst 
        # sort q violations between type 2 and 6 by largest violation to smallest
        all_qs = vcat(b2_violations, b6q_violations)
        sort!(all_qs, by = x -> sort_func(x[4]))
        update_q_violations!(pf_data, all_qs, p_pqv_pairs, obo, swap)
        if obo & swap[] 
            return 
        end
        if ~one_pair
            # sort vm violations in type 6 from largest to smallest 
            sort!(b6v_violations, by = x -> sort_func(x[2]))
            update_vm_violations!(pf_data, b6v_violations, p_pqv_pairs, obo, swap)
            if obo & swap[] 
                return 
            end 
        end
        # finally, sort vm violations in type 1 from largest to smallest 
        sort!(b1_violations, by = x -> sort_func(x[2]))
        swap_pqv_buses!(pf_data, obo, b1_violations, p_pqv_pairs, bus_assignment, swap)
        return
    else 
        # create dictionary of all violations 
        b2_viol = Dict("b2-$i"=>sort_func(x[4]) for (i,x) in enumerate(b2_violations))
        b6q_viol = Dict("b6q-$i"=>sort_func(x[4]) for (i,x) in enumerate(b6q_violations))
        b6v_viol = Dict("b6v-$i"=>sort_func(x[2]) for (i,x) in enumerate(b6v_violations))
        b1_viol = Dict("b1-$i"=>sort_func(x[2]) for (i,x) in enumerate(b1_violations))
        viol_dict = one_pair ? merge(b2_viol, b6q_viol,  b1_viol) : merge(b2_viol, b6q_viol, b6v_viol, b1_viol)
        sorted_viols = sort(collect(viol_dict), by = x -> x.second)
        # iterate violations 
        for pair in sorted_viols
            viol_type, viol_ind = split(pair[1], "-")
            viol_ind = parse(Int, viol_ind)
            viol_list = [] 
            if viol_type == "b2"
                viol_list = [b2_violations[viol_ind]]
                update_q_violations!(pf_data, viol_list, p_pqv_pairs, obo, swap)
            elseif viol_type == "b6q"
                viol_list = [b6q_violations[viol_ind]]
                update_q_violations!(pf_data, viol_list, p_pqv_pairs, obo, swap)
            elseif viol_type == "b6v"
                viol_list = [b6v_violations[viol_ind]]
                update_vm_violations!(pf_data, viol_list, p_pqv_pairs, obo, swap)
            elseif viol_type == "b1"
                viol_list = [b1_violations[viol_ind]]
                swap_pqv_buses!(pf_data, obo, viol_list, p_pqv_pairs, bus_assignment, swap)
            end
            if obo & swap[]
                break
            end
        end
    end
end

function warm_start_prev_soln!(pf_data, soln)
    data = pf_data.data 
    am = pf_data.am
    # for each bus, add starts for vm and va 
    for (bus_ind, bus) in pairs(soln["bus"])
        data["bus"][bus_ind]["vm_start"] = bus["vm"]
        data["bus"][bus_ind]["va_start"] = bus["va"]
    end
    # for each generator, add starts for qg (and if slack, add starts for pg)
    for (gen_ind, gen) in pairs(soln["gen"])
        data["gen"][gen_ind]["qg_start"] = gen["qg"]
        gen_bus = am.bus_to_idx[data["gen"][gen_ind]["gen_bus"]]
        if pf_data.bus_type_idx[gen_bus] == 3 
            data["gen"][gen_ind]["pg_start"] = gen["pg"]
        end
    end
end


function update_best_solution!(best_solution, pf_data, score, solution, p_pqv_pairs, bus_type_idx, mapping_dict; converged = true)
    if score > best_solution["best_score"]
        return 
    end 
    if verbose 
        @_debug( "minimal violation count: $(score)")
    end 
    # update values 
    best_solution["best_score"] = score 
    best_solution["solution"] = solution 
    best_solution["converged"] = converged 
    # update pf data values 
    best_solution["bus_type_idx"] = bus_type_idx
    best_solution["vm_idx"] = pf_data.vm_idx
    best_solution["va_idx"] = pf_data.va_idx
    best_solution["p_inject_idx"] = pf_data.p_inject_idx
    best_solution["q_inject_idx"] = pf_data.q_inject_idx
    best_solution["p_delta_base_idx"] = pf_data.p_delta_base_idx
    best_solution["q_delta_base_idx"] = pf_data.q_delta_base_idx
    best_solution["pf_data"] = deepcopy(pf_data)
    best_solution["p_pqv_pairs"] = deepcopy(p_pqv_pairs)
    if verbose 
        @_debug( "best solution stored. Best p-pqv-pairs: $p_pqv_pairs")
    end
    best_solution["mapping_dict"] = mapping_dict
end

function update_pf_data!(pf_data_lst, best_solution_lst)
    for i in 1:length(pf_data_lst)
        pf_data_lst[i] = best_solution_lst[i]
    end
end

function compute_ac_pf_mult_buses1(pf_data::PowerFlowData; obo_qlim=false, obo = false, verbose = false,
                                     debug=debug, swapping_technique = nothing,
                                     pqpv_paths = nothing, bus_info = nothing, distributed_slack = false,
                                     kwargs...)
    
    is_feas = false
    pf_result = nothing
    acpf_counter = 1
    converged = nothing
    best_converged = nothing
    solution = nothing
    bus_type_idx = deepcopy(pf_data.bus_type_idx)
    bus_indices = []
    neighbors = pf_data.neighbors
    best_solution = nothing
    best_score = 1e6
    best_bti = deepcopy(pf_data.bus_type_idx) 
    p_pvq_links = Dict{Int64, Tuple{Int, Float64}}()
    prev_pvq_buses = []
    prev_p_buses = []
    # prepare data dict 
    data_dict = Dict{String, Any}(
                    "pv_bus_inds" => Dict{Int, Int}(i => 1 for i in 1:length(pf_data.data["bus"]) if bus_type_idx[i] == 2)
                )
    if swapping_technique == "dof"
        data_dict["dof"] = determine_dof(bus_type_idx, neighbors, collect(1:length(pf_data.data["bus"])))
    end
    if swapping_technique in ["nearest", "furthest"]
        nearest, furthest = rank_proximity(pf_data.am.matrix, length(pf_data.data["bus"]), debug=debug)
        data_dict["nearest"] = nearest
        data_dict["furthest"] = furthest
    end
    if ~isnothing(pqpv_paths)
        data_dict["pqpv_paths"] = pqpv_paths
    end
    if ~isnothing(bus_info)
        data_dict["bus_info"] = bus_info
    end
    if (swapping_technique == "informed") & (isnothing(pqpv_paths) || isnothing(bus_info))
        if verbose 
            @_debug( "informed swappping method requires pqpv paths and bus info")
        end
        @assert false 
    end
    if verbose 
        @_debug( "swap type = $swapping_technique")
    end
    # @infiltrate debug
    if distributed_slack
        basic_network = PowerModels.make_basic_network(pf_data.data)
        pf_data.data["ptdf"] = PowerModels.calc_basic_ptdf_matrix(basic_network)
    end
    time_start = time()
    while ~is_feas
        if distributed_slack
            pf_data = distributed_slack_acpf(pf_data)
        end
        if verbose 
            @_debug( "computing ac pf, iteration $(acpf_counter)...")
            @_debug( "p_pvq_links $(p_pvq_links)...")
        end
        mapping_dict, J0_map = map_types_to_variable_indices(pf_data, debug=debug)
        pf_result = _compute_ac_pf(pf_data, mapping_dict, J0_map; flat_start = true,  kwargs...) 
        push!(bus_indices, deepcopy(pf_data.bus_type_idx))
        is_feas = true
        solution = Dict("per_unit" => pf_data.data["per_unit"])


        converged = pf_result.x_converged || pf_result.f_converged 
        if acpf_counter >= 20
            converged = false
        end
        if !converged
            if verbose
                @_debug( "ac power flow solver convergence failed!")
            end
            solution = best_solution
            bus_type_idx = best_bti
            best_converged = true
            if isnothing(best_solution)
                if verbose
                    @_debug( "No converged state thus far.")
                end
                bus_assignment = Dict(i => Dict("vm"=>-1, "va"=>-1) for i in keys(pf_data.data["bus"]))
                gen_assignment = Dict(i => Dict("pg"=>-1, "qg"=>-1) for i in keys(pf_data.data["gen"]))
                solution =   Dict(
                "per_unit" => pf_data.data["per_unit"],
                "bus" => bus_assignment,
                "gen" => gen_assignment,
                )
                best_converged = false
                best_solution = solution
            end

        else
            data = pf_data.data
            bus_gens = pf_data.bus_gens
            am = pf_data.am
            bus_type_idx = pf_data.bus_type_idx
            
            num_violations = 0

            # assign buses bus variables
            bus_assignment= Dict{String,Any}()
            for (i,bus) in data["bus"]
                if bus["bus_type"] != 4
                    bus_idx = am.bus_to_idx[bus["index"]]

                    bus_assignment[i] = Dict{String,Float64}(
                        "vm" => pf_data.vm_idx[bus_idx],
                        "va" => pf_data.va_idx[bus_idx],
                        "bus_idx" => bus["index"],
                        "vmin" => bus["vmin"],
                        "vmax" => bus["vmax"]
                    )
                end
            end

            # assign generators gen variables
            gen_assignment= Dict{String,Any}()
            for (i,gen) in data["gen"]
                if gen["gen_status"] != 0
                    gen_assignment[i] = Dict{String,Float64}(
                        "pg" => gen["pg"],
                        "qg" => gen["qg"]
                    )
                end
            end

            # validate solution, starting with qg violations 
            pv_bus_inds = []
            type_1, type_2, type_3, type_5, type_6 = [], [], [], [], []
            for (ind, type) in enumerate(bus_type_idx)
                if type == 1
                    push!(type_1, ind)
                elseif type == 2
                    push!(pv_bus_inds, ind)
                    push!(type_2, ind)
                elseif type == 3
                    push!(type_3, ind)
                elseif type == 5
                    push!(type_5, ind)
                elseif type == 6
                    push!(type_6, ind)
                else 
                    @assert false 
                end
            end
            shuffle!(pv_bus_inds)
            if swapping_technique == "dof"
                data_dict["dof"] = rank_best_dofs(pv_bus_inds, data_dict["dof"])
            end

            # 2: buses where P and V are specified; solve for Q and VA
            for i in type_2
                bid = am.idx_to_bus[i]
                bus = bus_assignment["$(bid)"]
                mapping = mapping_dict[i]
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["qg"] = 0.0
                end
                qg_remaining = -pf_result.zero[mapping["q"]]
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
                # check if any gens have exceeded the qg bounds 
                bus_feas = true
                for gen in bus_gens[bid]
                    qg = gen_assignment["$(gen["index"])"]["qg"]
                    if qg < gen["qmin"] 
                        bus_feas = false
                        gen["qg"] = gen["qmin"]
                        gen_assignment["$(gen["index"])"]["qg"] = gen["qmin"]
                        pf_data.q_inject_idx[bid] += qg
                        pf_data.q_inject_idx[bid] -= gen["qg"]
                    elseif qg > gen["qmax"]
                        bus_feas = false
                        gen["qg"] = gen["qmax"]
                        gen_assignment["$(gen["index"])"]["qg"] = gen["qmax"]
                        pf_data.q_inject_idx[bid] += qg
                        pf_data.q_inject_idx[bid] -= gen["qg"]
                    end
                    if ~bus_feas 
                        num_violations += 1
                    end
                end
                # if obo, check if change has already been made 
                if obo_qlim 
                    if ~is_feas
                        if ~bus_feas 
                            bus_feas = true
                            if verbose 
                                @_debug( "Q violation at bus $bid but change already occurred. Waiting...")
                            end
                        end
                    end
                end
                # if bounds are exceeded, switch to pq bus
                if ~bus_feas 
                    if verbose 
                        @_debug( "Q violation at bus $i. PV bus $i becoming PQ")
                    end
                    pf_data.bus_type_idx[i] = 1
                    # remove from list of pv
                    filter!(e -> e != i, pv_bus_inds)
                    pop!(data_dict["pv_bus_inds"], i)
                    if swapping_technique == "dof"
                        # add dof to neighboring nodes 
                        for n in neighbors[i]
                            if n == i
                                continue 
                            end 
                            data_dict["dof"][n] += 1
                        end
                    end
                    if swapping_technique == "informed"
                        # this bus can now be used in paths to other buses 
                        for lst in data_dict["bus_info"][i]
                            # if this path currently isn't feasible
                            if ~(lst[3] in data_dict["pqpv_paths"][lst[1]][lst[2]][0])
                                if data_dict["pqpv_paths"][lst[1]][lst[2]][0] == [-1]
                                    continue 
                                end
                                # remove from infeasible bus list
                                filter!(x -> x != i, data_dict["pqpv_paths"][lst[1]][lst[2]][-1][lst[3]])
                                # if list is empty, this path is now feasible
                                if length(data_dict["pqpv_paths"][lst[1]][lst[2]][-1][lst[3]]) == 0
                                    push!(data_dict["pqpv_paths"][lst[1]][lst[2]][0], lst[3])
                                end
                            end
                        end
                    end
                    is_feas = false
                end
                bus["va"] = pf_result.zero[mapping["va"]]
            end
            # 6: buses where only P is specified; solve for Q, VA, VM 
            for i in type_6
                bid = am.idx_to_bus[i]
                bus = bus_assignment["$(bid)"]
                mapping = mapping_dict[i]
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["qg"] = 0.0
                end
                qg_remaining = -pf_result.zero[mapping["q"]] 
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
                bus["va"] = pf_result.zero[mapping["va"]]
                bus["vm"] = pf_result.zero[mapping["vm"]]
                # check if any Q limits or VM limits have exceeded bounds
                bus_feas = true
                vm_violation = false
                q_violation = false 
                feas_vm, feas_qg, infeas_qg = 0, 0, 0
                pqv_bus = nothing
                if (bus["vm"] < bus["vmin"]) || (bus["vm"] > bus["vmax"])
                    bus_feas = false
                    vm_violation = true
                    idx = pop!(p_pvq_links, i)
                    pqv_bus = idx[1]
                    bus["vm"] = idx[2]
                end
                if bus_feas
                    for gen in bus_gens[bid]
                        qg = gen_assignment["$(gen["index"])"]["qg"]
                        if qg < gen["qmin"] 
                            bus_feas = false
                            gen["qg"] = gen["qmin"]
                            gen_assignment["$(gen["index"])"]["qg"] = gen["qmin"]
                            pf_data.q_inject_idx[bid] += qg
                            pf_data.q_inject_idx[bid] -= gen["qg"]
                        elseif qg > gen["qmax"]
                            bus_feas = false
                            gen["qg"] = gen["qmax"]
                            gen_assignment["$(gen["index"])"]["qg"] = gen["qmax"]
                            pf_data.q_inject_idx[bid] += qg
                            pf_data.q_inject_idx[bid] -= gen["qg"]
                        end
                    end
                    if ~bus_feas 
                        idx = pop!(p_pvq_links, i)
                        pqv_bus = idx[1]
                        bus["vm"] = idx[2]
                    end
                end
                if ~bus_feas 
                    num_violations += 1 
                end
                # if obo, check if change has already been made 
                if obo_qlim 
                    if ~is_feas
                        if ~bus_feas 
                            bus_feas = true
                            if verbose 
                                @_debug( "Q violation at bus $bid but change already occurred. Waiting...")
                            end
                        end
                    end
                end
                # if bounds are exceeded, switch to PQ or PV bus
                if ~bus_feas 
                    pf_data.bus_type_idx[i] = vm_violation ? 2 : 1
                    pqv_bus = -1
                    if vm_violation 
                        # voltage violation
                        idx = pop!(p_pvq_links, i) # remove from list
                        pqv_bus = idx[1] # store the other pair
                        bus["vm"] = idx[2] # update voltage
                        data_dict["pv_bus_inds"][i] = 1
                    else 
                        # q violation 
                        idx = pop!(p_pvq_links, i) # remove from list 
                        pqv_bus = idx[1] # store the other pai

                    end
                    # the connected PQV bus goes back to PQ 
                    pf_data.bus_type_idx[pqv_bus] = 1
                    if swapping_technique == "informed"
                        if vm_violation
                            # the pv bus should no longer be used in other paths 
                            for lst in data_dict["bus_info"][i]
                                # remove the path from list of feasible paths 
                                gen_dict = data_dict["pqpv_paths"][lst[1]][lst[2]]
                                if lst[3] in gen_dict[0] 
                                    filter!(x -> x != lst[3], gen_dict[0])
                                end
                            end
                        end
                        # the pqv bus can now be used in paths to other buses 
                        for lst in data_dict["bus_info"][pqv_bus]
                            # if this path currently isn't feasible
                            if ~(lst[3] in data_dict["pqpv_paths"][lst[1]][lst[2]][0])
                                if data_dict["pqpv_paths"][lst[1]][lst[2]][0] == [-1]
                                    continue 
                                end
                                # remove from infeasible bus list
                                filter!(x -> x != pqv_bus, data_dict["pqpv_paths"][lst[1]][lst[2]][-1][lst[3]])
                                # if list is empty, this path is now feasible
                                if length(data_dict["pqpv_paths"][lst[1]][lst[2]][-1][lst[3]]) == 0
                                    push!(data_dict["pqpv_paths"][lst[1]][lst[2]][0], lst[3])
                                end
                            end
                        end
                        # the pqv bus should not be used with this p bus ever again 
                        data_dict["pqpv_paths"][pqv_bus][i][0] = [-1]
                    end
                    if verbose 
                        violation_type = vm_violation ? "VM" : "Q"
                        bus_type = vm_violation ? "PV" : "PQ"
                        @_debug( "$violation_type violation at bus $i. P bus $i becoming $bus_type. PVQ bus $(pqv_bus) becoming PQ.")
                    end
                    is_feas = false
                end
            end
            # 1: buses where P and Q are specified; solve for VM and VA
            bus_violations = []
            # step 1: see if bounds are violated
            for i in type_1
                bid = am.idx_to_bus[i]
                bus = bus_assignment["$(bid)"]
                mapping = mapping_dict[i]
                bus["vm"] = pf_result.zero[mapping["vm"]]
                bus["va"] = pf_result.zero[mapping["va"]]
                # check if bus has exceeded VM bounds and if there are any DF leftover
                bus_feas = true
                if bus["vm"] < bus["vmin"]
                    bus_feas = false
                    pf_data.vm_idx[i] = bus["vmin"]
                    push!(bus_violations, [i, bus["vmin"] - bus["vm"]])
                end
                if bus["vm"] > bus["vmax"]
                    bus_feas = false
                    pf_data.vm_idx[i] = bus["vmax"]
                    push!(bus_violations, [i, bus["vm"] - bus["vmax"]])
                end
                if ~bus_feas 
                    num_violations += 1 
                end
                # # if this bus has previously been pvq, don't try again 
                # if i in prev_pvq_buses
                #     if verbose 
                #         @_debug( "VM violation at bus $bid, but previously PVQ. Continuing.")
                #     end
                #     bus_feas = true 
                # end
                # # if doing alterations one-by-one, see if this bus should be changed yet 
                # if obo
                #     if ~is_feas 
                #         if ~bus_feas 
                #             bus_feas = true
                #             if verbose 
                #                 @_debug( "VM violation at bus $bid, but change already occured. Waiting for the next round...")
                #             end
                #         end
                #     end
                # end
                # if ~bus_feas
                #     if length(data_dict["pv_bus_inds"]) == 0
                #         if verbose 
                #             @_debug( "VM violation at bus $bid but no DOF left. Continuing.")
                #         end
                #     else
                #         is_feas = false
                #         # this bus becomes type 5
                #         pf_data.bus_type_idx[i] = 5
                #         # the next PV bus becomes type 6, and is removed from PV list
                #         pv_bus = swap_pv_pq(data_dict, i, swap_technique=swapping_technique)
                #         if verbose 
                #             @_debug( "VM violation at bus $bid. Becoming PVQ bus. PV bus $(am.idx_to_bus[pv_bus]) becoming P.")
                #         end
                #         pf_data.bus_type_idx[pv_bus] = 6
                #         if swapping_technique == "dof"
                #             # add dof back to neighbors of p bus 
                #             for n in neighbors[pv_bus]
                #                 if n == pv_bus 
                #                     continue 
                #                 end 
                #                 data_dict["dof"][n] += 1
                #             end
                #             # remove dof from neighbors of pqv bus 
                #             for n in neighbors[i]
                #                 if n == i 
                #                     continue 
                #                 end 
                #                 data_dict["dof"][n] -= 1
                #             end                            
                #         end
                #         # store the pair 
                #         p_pvq_links[pv_bus] = i 
                #         push!(prev_pvq_buses, i)
                #     end
                # end

            end
            # step 2: if bounds are violated, fix them (starting with easiest one)
            if length(bus_violations) > 0 
                violations = rank_worst_violations(bus_violations)
                # violations = rank_best_violations(bus_violations, data_dict, debug = debug)
                if verbose
                    @_debug( "VM violations, ranked: $violations")
                end
                cont = true
                # verify q limits are not being changed
                if ~is_feas 
                    if verbose 
                        @_debug( "VM violations, but PQ has changed. Waiting...")
                    end 
                    cont = false
                end

                # change only one element for obo
                bus_change = false 
                while (~bus_change) && (length(violations) > 0) && cont
                    # see if available pv buses 
                    if length(data_dict["pv_bus_inds"]) == 0
                        if verbose 
                            @_debug( "VM violation but no DOF left. Continuing.")
                        end  
                        cont = false 
                        break
                    end
                    busv = popfirst!(violations)
                    i = Int64(busv[1])
                    bid = am.idx_to_bus[i]
                    # # check to see this bus wasn't previously changed
                    # if i in prev_pvq_buses
                    #     if verbose 
                    #         @_debug( "VM violation at bus $bid, but previously PVQ. Continuing.")
                    #     end
                    #     continue
                    # end  
                    # grab pv bus 
                    pf_data.bus_type_idx[i] = 5
                    # the next PV bus becomes type 6, and is removed from PV list
                    # @infiltrate debug
                    pv_bus = swap_pv_pq(data_dict, i, swap_technique=swapping_technique, debug=debug, verbose=verbose, bus_type_idx = pf_data.bus_type_idx)
                    if isnothing(pv_bus)
                        # no swap; turn back to pq
                        pf_data.bus_type_idx[i] = 1
                        if verbose 
                            @_debug( "VM violation at bus $i, but no good PV to swap with.")
                        end
                    else
                        if verbose 
                            @_debug( "VM violation at bus $i. Becoming PVQ bus. PV bus $(pv_bus) becoming P.")
                        end
                        pf_data.bus_type_idx[pv_bus] = 6
                        if swapping_technique == "dof"
                            # add dof back to neighbors of p bus 
                            for n in neighbors[pv_bus]
                                if n == pv_bus 
                                    continue 
                                end 
                                data_dict["dof"][n] += 1
                            end
                            # remove dof from neighbors of pqv bus 
                            for n in neighbors[i]
                                if n == i 
                                    continue 
                                end 
                                data_dict["dof"][n] -= 1
                            end                            
                        end
                        # store the pair 
                        pv_bid = am.idx_to_bus[pv_bus]
                        pvvbus = bus_assignment["$(pv_bid)"]
                        p_pvq_links[pv_bus] = (Int64(i), pvvbus["vm"]) 
                        push!(prev_pvq_buses, i) 
                        is_feas = false
                        # if changing one by one, skip after this one   
                        bus_change = obo     
                    end              
                end 
            end
            # 3: slack bus where VM and VA are specified; solve for P and Q
            for i in type_3
                bid = am.idx_to_bus[i]
                bus = bus_assignment["$(bid)"]
                mapping = mapping_dict[i]
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["pg"] = 0.0
                    sol_gen["qg"] = 0.0
                end

                pg_remaining = -pf_result.zero[mapping["p"]]
                _assign_pg!(gen_assignment, bus_gens[bid], pg_remaining)

                qg_remaining = -pf_result.zero[mapping["q"]]
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
            end
            # 5: buses where P, Q, and VM are specified; solve for VA
            for i in type_5
                bid = am.idx_to_bus[i]
                bus = bus_assignment["$(bid)"]
                mapping = mapping_dict[i]
                bus["va"] = pf_result.zero[mapping["va"]]
            end

            # @infiltrate debug
            solution = Dict(
                "per_unit" => data["per_unit"],
                "bus" => bus_assignment,
                "gen" => gen_assignment,
            )
            if num_violations <= best_score
                if verbose 
                    @_debug( "minimal violation count: $num_violations")
                end     
                best_score = num_violations
                best_solution = solution
                best_bti = deepcopy(bus_type_idx)
                best_converged = true
            end
            if num_violations == 0 
                if verbose 
                    @_debug( "Feasible Run")
                end        
            end
        end
        acpf_counter += 1
    end
    best_solution["acpf_counter"] = acpf_counter
    result = Dict(
        "optimizer" => "NLsolve",
        "bus indices" => best_bti,
        "prev_bus_indices" => bus_indices,
        "termination_status" => best_converged,
        "objective" => 0.0,
        "solution" => best_solution,
        "solve_time" => time() - time_start
    )

    return result
end

function determine_bounds!(pf_data::PowerFlowData)
    bounds = Dict()
    for i in eachindex(pf_data.am.idx_to_bus)
        bus_ind = pf_data.am.idx_to_bus[i]
        constr_ind = 2*i
        var_ind = -1
        var_bounds = [0.0,0.0]
        # for loads, grab the voltage 
        if pf_data.bus_type_idx[i] == 1
            var_ind = 2*i - 1
            var_bounds[1] = pf_data.data["bus"][string(bus_ind)]["vmin"]
            var_bounds[2] = pf_data.data["bus"][string(bus_ind)]["vmax"]
        # for generators, grab the reactive power
        elseif pf_data.bus_type_idx[i] == 2
            var_ind = 2*i - 1 
            var_bounds[1] = pf_data.bus_gens[bus_ind][1]["qmin"]
            var_bounds[2] = pf_data.bus_gens[bus_ind][1]["qmax"]
        # for slack bus, grab the reactive power
        elseif pf_data.bus_type_idx[i] == 3
            var_ind = 2*i
            var_bounds[1] = pf_data.bus_gens[bus_ind][1]["qmin"]
            var_bounds[2] = pf_data.bus_gens[bus_ind][1]["qmax"]
        end
        # add to bound dictionary 
        if var_ind != -1
            bounds[var_ind] = [var_bounds, constr_ind]
        end
    end
    # store in data 
    pf_data.data["bounds"] = bounds
end

"pre-calculation: determine buses nearest and furthest from each bus, using row index"
function rank_worst_violations(bus_list)
    return sort(bus_list, by = x -> abs(x[2]))
end

"this is slow we should redo this"
function rank_best_violations(bus_list, data_dict; debug = false)
    # for each violated bus, find the shortest path to an available pv bus 
    bus_and_path = []
    for (bus, viol) in bus_list 
        shortest_path = 1e6
        for pv_bus in keys(data_dict["pv_bus_inds"])
            if data_dict["pqpv_paths"][bus][pv_bus][0] == [-1]
                continue 
            end
            feas_pths = pop!(data_dict["pqpv_paths"][bus][pv_bus], 0)
            pths = collect(values(data_dict["pqpv_paths"][bus][pv_bus]))
            # get shortest path
            pth = minimum(length.(pths))
            if pth <= shortest_path
                shortest_path = pth 
            end
            data_dict["pqpv_paths"][bus][pv_bus][0] = feas_pths
        end
        push!(bus_and_path, [bus, shortest_path])
    end
    # sort list by shortest path 
    return sort(bus_and_path, by = x -> x[2])
end

"return an ordered list of buses, from most DOF to least DOF"
function rank_best_dofs(bus_inds, dof_dict)
    # dof_partial = dof_dict[bus_inds]
    dof_p = OrderedDict(sort(collect(dof_dict), by = x -> x[2], rev = true))
    return dof_p
end

function determine_dof(bus_type_idx, neighbors, bus_inds)
    buses = OrderedDict{Int, Int}()
    for bus in bus_inds
        dof = 0
        for i in neighbors[bus]
            if ~(bus_type_idx[i] in [2,3, 5])
                dof += 1
            end
        end
        buses[bus] = dof 
    end 
    buses = OrderedDict(sort(collect(buses), by = x -> x[2], rev = true))
    return buses
end

"return the optimal PV bus to swap with, removing it from list of PV buses"
function swap_pv_pq(data_dict, violated_pq; swap_technique="random", debug=false, verbose = false, bus_type_idx = nothing)
    # swap with any available PV
    if swap_technique == "random"
        pv_bus = rand(keys(data_dict["pv_bus_inds"]))
        pop!(data_dict["pv_bus_inds"], pv_bus)
        return pv_bus
    # swap with PV with the highest DOF
    elseif swap_technique == "dof"
        for pv in keys(data_dict["dof"])
            if pv in keys(data_dict["pv_bus_inds"])
                pop!(data_dict["pv_bus_inds"], pv)
                return pv
            end
        end
    # swap with PV closest to violated bus
    elseif swap_technique == "nearest"
        for pv in keys(data_dict["nearest"][violated_pq])
            if pv in keys(data_dict["pv_bus_inds"])
                pop!(data_dict["pv_bus_inds"], pv)
                return pv
            end           
        end
    # swap with PV furthest from violated bus
    elseif swap_technique == "furthest"
        for pv in keys(data_dict["furthest"][violated_pq])
            if pv in keys(data_dict["pv_bus_inds"])
                pop!(data_dict["pv_bus_inds"], pv)
                return pv
            end
        end
    # swap with a feasible path
    elseif swap_technique == "informed"
        # find a pv bus with a feasible path 
        best_pv = nothing 
        best_pth = nothing
        shortest_path = 1e6
        for pv in keys(data_dict["pv_bus_inds"])
            if pv in keys(data_dict["pqpv_paths"][violated_pq])
                # obtain path between buses
                if (length(data_dict["pqpv_paths"][violated_pq][pv][0]) == 0) ||
                    (data_dict["pqpv_paths"][violated_pq][pv][0] == [-1])
                    # no feasibile paths remaining
                    continue 
                end
                # temporarily store list of feasible and infeasible paths 
                feas_pths = pop!(data_dict["pqpv_paths"][violated_pq][pv], 0)
                infeas_pths = pop!(data_dict["pqpv_paths"][violated_pq][pv], -1)
                pths = collect(values(data_dict["pqpv_paths"][violated_pq][pv]))
                # get shortest path
                pth = pths[argmin(length.(pths))]
                data_dict["pqpv_paths"][violated_pq][pv][0] = feas_pths
                data_dict["pqpv_paths"][violated_pq][pv][-1] = infeas_pths
                if length(pth) <= shortest_path 
                    best_pv = pv
                    best_pth = pth 
                    shortest_path = length(pth)
                end
            
            end
        end
        if isnothing(best_pv)
            return nothing 
        end
        if verbose 
            if ~isnothing(bus_type_idx)
                pth_dict = Dict(b => bus_type_idx[b] for b in best_pth)
                @_debug( "path from $violated_pq to $best_pv: $pth_dict")
            else
                @_debug( "path from $violated_pq to $best_pv: $best_pth")
            end
        end
        # for each bus in the path, remove all other paths that use that bus
        for bus in best_pth 
            for lst in data_dict["bus_info"][bus]
                # remove the path from list of feasible paths 
                gen_dict = data_dict["pqpv_paths"][lst[1]][lst[2]]
                if lst[3] in gen_dict[0] 
                    filter!(x -> x != lst[3], gen_dict[0])
                end
                # append bus to infeasible paths 
                if lst[3] in keys(gen_dict[-1])
                    push!(gen_dict[-1][lst[3]], bus)
                else 
                    gen_dict[-1][lst[3]] = [bus]
                end
            end
        end
        # return pv 
        pop!(data_dict["pv_bus_inds"], best_pv)
        return best_pv
    end
    return nothing
end


function compute_ac_pf!(data::Dict{String,<:Any}; kwargs...)
    # TODO check invariants
    # single connected component
    # all buses of type 2/3 have generators on them

    pf_data = instantiate_pf_data(data)
    compute_ac_pf!(pf_data; kwargs...)
end


"""
similar to compute_ac_pf but places the solution in the power model's data
dict instead of a separate result object
"""
function compute_ac_pf!(pf_data::PowerFlowData; kwargs...)
    pf_result = _compute_ac_pf(pf_data; kwargs...)

    if !(pf_result.x_converged || pf_result.f_converged)
        @_debug( "ac power flow solver convergence failed!  use `show_trace = true` for more details")
    end

    data = pf_data.data
    bus_gens = pf_data.bus_gens
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx


    for (i,bid) in enumerate(am.idx_to_bus)
        bus = data["bus"]["$(bid)"]

        bus["vm"] = pf_data.vm_idx[i]
        bus["va"] = pf_data.va_idx[i]

        if bus_type_idx[i] == 1
            @assert !haskey(bus_gens, bid)
            #update covered by default update

        elseif bus_type_idx[i] == 2
            for gen in bus_gens[bid]
                gen["qg"] = 0.0
            end

            qg_remaining = -pf_result.zero[2*i - 1]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)

        elseif bus_type_idx[i] == 3
            for gen in bus_gens[bid]
                gen["pg"] = 0.0
                gen["qg"] = 0.0
            end

            pg_remaining = -pf_result.zero[2*i - 1]
            _assign_pg!(data["gen"], bus_gens[bid], pg_remaining)

            qg_remaining = -pf_result.zero[2*i]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)
        else
            @assert false
        end
    end
end


function _assign_pg!(sol_gens::Dict{String,<:Any}, bus_gens::Vector, pg_remaining::Float64)
    for gen in bus_gens[1:end-1]
        pmin = gen["pmin"]
        pmax = gen["pmax"]

        if (pg_remaining <= 0.0 && pmin >= 0.0) || (pg_remaining >= 0.0 && pmax <= 0.0)
            # keep pg assignment as zero
            continue
        end

        sol_gen = sol_gens["$(gen["index"])"]
        if pg_remaining < pmin
            sol_gen["pg"] = pmin
        elseif pg_remaining > pmax
            sol_gen["pg"] = pmax
        else
            sol_gen["pg"] = pg_remaining
            pg_remaining = 0.0
            break
        end
        pg_remaining -= sol_gen["pg"]
    end
    if !isapprox(pg_remaining, 0.0)
        gen = bus_gens[end]
        sol_gen = sol_gens["$(gen["index"])"]
        sol_gen["pg"] = pg_remaining
    end
end


function _assign_qg!(sol_gens::Dict{String,<:Any}, bus_gens::Vector, qg_remaining::Float64)
    for gen in bus_gens[1:end-1]
        qmin = gen["qmin"]
        qmax = gen["qmax"]

        if (qg_remaining <= 0.0 && qmin >= 0.0) || (qg_remaining >= 0.0 && qmax <= 0.0)
            # keep qg assignment as zero
            continue
        end

        sol_gen = sol_gens["$(gen["index"])"]
        if qg_remaining < qmin
            sol_gen["qg"] = qmin
        elseif qg_remaining > qmax
            sol_gen["qg"] = qmax
        else
            sol_gen["qg"] = qg_remaining
            qg_remaining = 0.0
            break
        end
        qg_remaining -= sol_gen["qg"]
    end
    if !isapprox(qg_remaining, 0.0)
        gen = bus_gens[end]
        sol_gen = sol_gens["$(gen["index"])"]
        sol_gen["qg"] = qg_remaining
    end
end

function _ac_pf_sensitivity(pf_data, mapping_dict, J0_map, x)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    F0 = zeros(Float64, 2*length(am.idx_to_bus)) 
    J0 = J0_map 
        # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[mapping["q"]]
                va_idx[i] = x[mapping["va"]]
                # println("bus $i: q = $(2*i - 1) \t va = $(2*i)")
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[mapping["p"]]
                q_inject_idx[i] = x[mapping["q"]]
                # println("bus $i: p = $(2*i - 1) \t q = $(2*i)")
            elseif bus_type_idx[i] == 5
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 6
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
                q_inject_idx[i] = x[mapping["q"]]
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
            
        end
        # complex variant of above
        # for i in eachindex(am.idx_to_bus)
        #     balance = p_inject_idx[i] + q_inject_idx[i]im
        #     for j in neighbors[i]
        #         balance += vm_idx[i] * vm_idx[j] * (am.matrix[i,j] * (cos(va_idx[i] - va_idx[j]) + sin(va_idx[i] - va_idx[j])im))
        #     end
        #     F[2*i - 1] = real(balance)
        #     F[2*i] = imag(balance)
        # end
    end

    function jsp_mb!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        # functions for each type of derivative
        function dpdv(i)
            y_ii = am.matrix[i, i]
            return 2*real(y_ii)*vm_idx[i] + sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dqdv(i)
            y_ii = am.matrix[i, i]
            return -2*imag(y_ii)*vm_idx[i] + sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dpdtheta(i)
            return vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dqdtheta(i)
            return vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dpdp(i)
            return 1
        end
        function dqdp(i)
            return 0
        end
        function dpdq(i)
            return 0
        end
        function dqdq(i)
            return 1
        end
        function dpn_dv(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
        end
        function dqn_dv(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
        end
        function dpn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end
        function dqn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end

        # iterate through each power balance equation
        for i in eachindex(am.idx_to_bus)
            r_real = 2*i - 1
            r_imag = 2*i
            # iterate through each bus connected to get related variables 
            for j in neighbors[i]
                if bus_type_idx[j] == 1
                    vm_col = mapping_dict[j]["vm"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, vm_col] = dpdv(j)
                        J[r_imag, vm_col] = dqdv(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        # println("J[$r_real, $vm_col] = dpdv($j)")
                        # println("J[$r_imag, $vm_col] = dqdv($j)")
                        # println("J[$r_real, $va_col] = dpdtheta($j)")
                        # println("J[$r_imag, $va_col] = dqdtheta($j)")
                    else 
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        # println(" 
                        #     J[$r_real, $vm_col] = dpn_dv($i, $j)
                        #     J[$r_imag, $vm_col] = dqn_dv($i, $j) 
                        # ")
                        #     J[$r_real, $va_col] = dpn_dtheta($i, $j) 
                        #     J[$r_imag, $va_col] = dqn_dtheta($i, $j)  
                        # ")
                    end
                elseif bus_type_idx[j] == 2 
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        # println(" 
                        #     J[$r_real, $q_col] = dpdq($j) 
                        #     J[$r_imag, $q_col] = dqdq($j) 
                        #     J[$r_real, $va_col] = dpdtheta($j) 
                        #     J[$r_imag, $va_col] = dqdtheta($j)                        
                        # ")
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        # println(" 
                        #     J[$r_real, $q_col] = 0 
                        #     J[$r_imag, $q_col] = 0 
                        #     J[$r_real, $va_col] = dpn_dtheta($i, $j) 
                        #     J[$r_imag, $va_col] = dqn_dtheta($i, $j)                        
                        # ")
                    end
                elseif bus_type_idx[j] == 3
                    q_col = mapping_dict[j]["q"]
                    p_col = mapping_dict[j]["p"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, p_col] = dpdp(j)
                        J[r_imag, p_col] = dqdp(j)
                        # println("
                        #     J[$r_real, $q_col] = dpdq($j) 
                        #     J[$r_imag, $q_col] = dqdq($j) 
                        #     J[$r_real, $p_col] = dpdp($j) 
                        #     J[$r_imag, $p_col] = dqdp($j)                        
                        # ")
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, p_col] = 0
                        J[r_imag, p_col] = 0
                        # println("
                        #     J[$r_real, $q_col] = 0 
                        #     J[$r_imag, $q_col] = 0 
                        #     J[$r_real, $p_col] = 0 
                        #     J[$r_imag, $p_col] = 0                        
                        # ")
                    end   

                elseif bus_type_idx[j] == 5       
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                    else 
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                    end     
                elseif bus_type_idx[j] == 6
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    vm_col = mapping_dict[j]["vm"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        J[r_real, vm_col] = dpdv(j)
                        J[r_imag, vm_col] = dqdv(j)
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                    end                                               
                end
            end
        end
    end

    # compute updated J 
    jsp_mb!(J0, x)
    # compute updated F 
    f!(F0, x)
    # compute delta x 
    delta_x = nothing 
    try 
        delta_x = inv(Matrix(J0))*F0
    catch e 
        delta_x = pinv(Matrix(J0))*F0
    end 
    return -delta_x
end

function _compute_ac_pf_bounded(pf_data::PowerFlowData, mapping_dict, J0_map; 
                        finite_differencing=false, flat_start=true, var_bounds = nothing, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    x0 = flat_start ? zeros(Float64, 2*length(am.idx_to_bus)) : pf_data.x0
    if flat_start 
        vm_indices = [val["vm"] for val in values(mapping_dict) if val["vm"] != 0]
        x0[vm_indices] .= 0 # will map to 1
        q_indices = [val["q"] for val in values(mapping_dict) if val["q"] != 0]
        x0[q_indices] .= -.35 # will map to qmin
    end
    F0 = flat_start ? zeros(Float64, 2*length(am.idx_to_bus)) : pf_data.F0
    J0 = J0_map
    jacobian_history = Vector{SparseMatrixCSC{Float64, Int64}}()
    x_history = Vector{Vector{Float64}}()
    vm_history = Vector{Vector{Float64}}()
    q_history = Vector{Vector{Float64}}()
    var_bounds = var_bounds

    function b(var_val, var_ind)
        bound_info = var_bounds[var_ind]
        mp = bound_info[1]
        R = bound_info[2]
        S = bound_info[3]
        num = var_val/(R*S)
        denom = (1 + num^10)^0.1
        return (num/denom)*R + mp     
    end

    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = b(x[mapping["vm"]], mapping["vm"])
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = b(x[mapping["q"]], mapping["q"])
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[mapping["p"]]
                q_inject_idx[i] = b(x[mapping["q"]], mapping["q"])
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
        end
        push!(vm_history, deepcopy(vm_idx))
        push!(q_history, deepcopy(q_inject_idx))

    end

    function jsp_mb!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        # functions for each type of derivative
        function dbound_dvar(bus_ind)
            x_ind = mapping_dict[bus_ind]["vm"]
            x_val = x[x_ind]
            bound_info = var_bounds[x_ind]
            mp = bound_info[1]
            R = bound_info[2]
            S = bound_info[3]
            inner = 1 + (x_val/(R*S))^10
            num1 = inner^0.1/(S*R)
            num2 = (x_val * (x_val/(S*R))^9)/((S*R)^2 * inner^0.9)
            denom = inner^0.2
            deriv = (num1 + num2)/denom
            # deriv = (R/S) * cos(x_val/S) 
            # # if derivative is near 0, push it forward 
            # if abs(deriv) <= 1e-5
            #     deriv = sign(deriv) * 1e-3
            # elseif deriv == 0 
            #     deriv = 1e-3 
            # end
            return deriv
        end
        function dpdv(i)
            y_ii = am.matrix[i, i]
            deriv = 2*real(y_ii)*vm_idx[i] + sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
            return dbound_dvar(i) * deriv
        end
        function dqdv(i)
            y_ii = am.matrix[i, i]
            deriv = -2*imag(y_ii)*vm_idx[i] + sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
            return dbound_dvar(i) * deriv
        end
        function dpdtheta(i)
            return vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dqdtheta(i)
            return vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dpdp(i)
            return 1
        end
        function dqdp(i)
            return 0
        end
        function dpdq(i)
            return 0
        end
        function dqdq(i)
            return 1
        end
        function dpn_dv(i, j)
            y_ij = am.matrix[i,j]
            deriv = vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
            return dbound_dvar(j) * deriv
        end
        function dqn_dv(i, j)
            y_ij = am.matrix[i,j]
            deriv = vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
            return dbound_dvar(j) * deriv
        end
        function dpn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end
        function dqn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end

        # iterate through each power balance equation
        for i in eachindex(am.idx_to_bus)
            r_real = 2*i - 1
            r_imag = 2*i
            # iterate through each bus connected to get related variables 
            for j in neighbors[i]
                if bus_type_idx[j] == 1
                    vm_col = mapping_dict[j]["vm"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, vm_col] = dpdv(j)
                        J[r_imag, vm_col] = dqdv(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        # println("J[$r_real, $vm_col] = dpdv($j)")
                        # println("J[$r_imag, $vm_col] = dqdv($j)")
                        # println("J[$r_real, $va_col] = dpdtheta($j)")
                        # println("J[$r_imag, $va_col] = dqdtheta($j)")
                    else 
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        # println(" 
                        #     J[$r_real, $vm_col] = dpn_dv($i, $j)
                        #     J[$r_imag, $vm_col] = dqn_dv($i, $j) 
                        # ")
                        #     J[$r_real, $va_col] = dpn_dtheta($i, $j) 
                        #     J[$r_imag, $va_col] = dqn_dtheta($i, $j)  
                        # ")
                    end
                elseif bus_type_idx[j] == 2 
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        # println(" 
                        #     J[$r_real, $q_col] = dpdq($j) 
                        #     J[$r_imag, $q_col] = dqdq($j) 
                        #     J[$r_real, $va_col] = dpdtheta($j) 
                        #     J[$r_imag, $va_col] = dqdtheta($j)                        
                        # ")
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        # println(" 
                        #     J[$r_real, $q_col] = 0 
                        #     J[$r_imag, $q_col] = 0 
                        #     J[$r_real, $va_col] = dpn_dtheta($i, $j) 
                        #     J[$r_imag, $va_col] = dqn_dtheta($i, $j)                        
                        # ")
                    end
                elseif bus_type_idx[j] == 3
                    q_col = mapping_dict[j]["q"]
                    p_col = mapping_dict[j]["p"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, p_col] = dpdp(j)
                        J[r_imag, p_col] = dqdp(j)
                        # println("
                        #     J[$r_real, $q_col] = dpdq($j) 
                        #     J[$r_imag, $q_col] = dqdq($j) 
                        #     J[$r_real, $p_col] = dpdp($j) 
                        #     J[$r_imag, $p_col] = dqdp($j)                        
                        # ")
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, p_col] = 0
                        J[r_imag, p_col] = 0
                        # println("
                        #     J[$r_real, $q_col] = 0 
                        #     J[$r_imag, $q_col] = 0 
                        #     J[$r_real, $p_col] = 0 
                        #     J[$r_imag, $p_col] = 0                        
                        # ")
                    end   

                elseif bus_type_idx[j] == 5       
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                    else 
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                    end     
                elseif bus_type_idx[j] == 6
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    vm_col = mapping_dict[j]["vm"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        J[r_real, vm_col] = dpdv(j)
                        J[r_imag, vm_col] = dqdv(j)
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                    end                                               
                end
            end
        end

        push!(jacobian_history, deepcopy(J))
        push!(x_history, deepcopy(x))
    end


    # basic init point
    if flat_start
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                # x0[mapping["vm"]] = 1.0 # vm
            elseif bus_type_idx[i] == 2
            elseif bus_type_idx[i] == 3
            elseif bus_type_idx[i] == 5
            elseif bus_type_idx[i] == 6
            else
                @assert false
            end
        end
    end
 
    # this is where the magic happens
    
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        df = NLsolve.OnceDifferentiable(f!, jsp_mb!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; factor = 0.1, kwargs...)
    end
    # x_final = result.zero
    # jsp_mb!(J0, x_final)
    if ~(result.x_converged || result.f_converged )
        x_final = result.zero
        jsp_mb!(J0, x_final)
    end
    return result, jacobian_history, x_history, vm_history, q_history
end

function _compute_ac_pf_grainger(pf_data::PowerFlowData, mapping_dict, J0_map; 
                        finite_differencing=false, flat_start=true, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    num_vars = sum([1 for val in values(mapping_dict) if val["vm"] != 0]) + sum([1 for val in values(mapping_dict) if val["va"] != 0]) 
    x0 = zeros(Float64, num_vars)
    vm_indices = [val["vm"] for val in values(mapping_dict) if val["vm"] != 0]
    x0[vm_indices] .= 1.0
    x_final = zeros(Float64, 2*length(keys(mapping_dict)))
    F0 = zeros(Float64, num_vars)
    J0 = J0_map
    jacobian_history = Vector{SparseMatrixCSC{Float64, Int64}}()
    x_history = Vector{Vector{Float64}}()
    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = 0
                va_idx[i] = x[mapping["va"]]
                # println("bus $i: q = $(2*i - 1) \t va = $(2*i)")
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = 0
                q_inject_idx[i] = 0
                # println("bus $i: p = $(2*i - 1) \t q = $(2*i)")
            elseif bus_type_idx[i] == 5
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 6
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
                q_inject_idx[i] = 0
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            if bus_type_idx[i] == 1
                F[mapping_dict[i]["q_row"]] = balance_imag
            end
            if bus_type_idx[i] != 3
                F[mapping_dict[i]["p_row"]] = balance_real
            end
            
        end
    end

    function jsp_mb!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        # functions for each type of derivative
        function dpdtheta(i)
            return vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dqdtheta(i)
            return vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dpn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end
        function dqn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end

        # iterate through each power balance equation
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 3 
                continue 
            end 
            r_real = mapping_dict[i]["p_row"]
            r_imag = mapping_dict[i]["q_row"]

            # iterate through each bus connected to get related variables 
            for j in neighbors[i]
                vm_col = mapping_dict[j]["vm"]
                va_col = mapping_dict[j]["va"]
                if i == j 
                    M_ii = dpdtheta(i)
                    N_ii = dqdtheta(i)
                    if bus_type_idx[i] != 3
                        J[r_real, va_col] = M_ii 
                    end
                    if bus_type_idx[i] == 1
                        J[r_imag, vm_col] = -M_ii - 2*vm_idx[i]^2 * imag(am.matrix[i,i])
                        J[r_imag, va_col] = N_ii 
                    end 
                    if bus_type_idx[j] in [1, 6]
                        J[r_real, vm_col] = N_ii + 2 * vm_idx[i]^2 * real(am.matrix[i,i])
                    end
                else 
                    M_ij = dpn_dtheta(i,j)
                    N_ij = dqn_dtheta(i,j)
                    if bus_type_idx[j] != 3
                        J[r_real, va_col] = M_ij 
                    end
                    if (bus_type_idx[i] in [1,5]) & (bus_type_idx[j] in [1,6])
                        J[r_imag, vm_col] = M_ij 
                    end 
                    if (bus_type_idx[i] in [1,5]) & (bus_type_idx[j] != 3)
                        J[r_imag, va_col] = N_ij
                    end 
                    if bus_type_idx[j] in [1,6]
                        J[r_real, vm_col] = -N_ij
                    end
                end

            end

        end
        push!(jacobian_history, deepcopy(J))
        push!(x_history, deepcopy(x))
    end

    function fill_in_xfinal(x) 
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
                x_final[mapping["vm"]] = x[mapping["vm"]]
                x_final[mapping["va"]] = x[mapping["va"]]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = 0
                va_idx[i] = x[mapping["va"]]
                x_final[mapping["va"]] = x[mapping["va"]]
                # println("bus $i: q = $(2*i - 1) \t va = $(2*i)")
            elseif bus_type_idx[i] == 3
                # println("bus $i: p = $(2*i - 1) \t q = $(2*i)")
            elseif bus_type_idx[i] == 5
                va_idx[i] = x[mapping["va"]]
                x_final[mapping["va"]] = x[mapping["va"]]
            elseif bus_type_idx[i] == 6
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
                q_inject_idx[i] =0
                x_final[mapping["vm"]] = x[mapping["vm"]]
                x_final[mapping["va"]] = x[mapping["va"]]
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] in [1,5]
                continue 
            end
            balance_real = p_delta_base_idx[i]
            balance_imag = q_delta_base_idx[i] 
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            if bus_type_idx[i] in [1, 2, 3, 6]
                x_final[mapping_dict[i]["q"]] = -balance_imag
            end
            if bus_type_idx[i] == 3
                x_final[mapping_dict[i]["p"]] = -balance_real
            end
        end
        return x_final
    end

    # basic init point
    if flat_start
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                x0[mapping["vm"]] = 1.0 # vm
            elseif bus_type_idx[i] == 2
            elseif bus_type_idx[i] == 3
            elseif bus_type_idx[i] == 5
            elseif bus_type_idx[i] == 6
            else
                @assert false
            end
        end
    end
 
    # warm-start point
    if !flat_start
        p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        for (i,gen) in data["gen"]
            if gen["gen_status"] != 0
                if haskey(gen, "pg_start")
                    p_inject[gen["gen_bus"]] += gen["pg_start"]
                end
                if haskey(gen, "qg_start")
                    q_inject[gen["gen_bus"]] += gen["qg_start"]
                end
            end
        end

        for (i,shunt) in data["shunt"]
            if shunt["status"] != 0
                bus = data["bus"]["$(shunt["shunt_bus"])"]
                if haskey(bus, "vm_start")
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
                else
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]
                end
            end
        end

        for (i,bid) in enumerate(am.idx_to_bus)
            bus = data["bus"]["$(bid)"]
            mapping = mapping_dict[am.bus_to_idx[bid]]
            if bus_type_idx[i] == 1
                if haskey(bus, "vm_start")
                    x0[mapping["vm"]] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[mapping["va"]] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 2
                if haskey(bus, "va_start")
                    x0[mapping["va"]] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3

            elseif bus_type_idx[i] == 5 
                if haskey(bus, "va_start")
                    x0[mapping["va"]] = bus["va_start"]
                end   
            elseif bus_type_idx[i] == 6
                if haskey(bus, "vm_start")
                    x0[mapping["vm"]] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[mapping["va"]] = bus["va_start"]
                end   
            else
                @assert false
            end
        end
    end

    # this is where the magic happens
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        v_inds = [md["vm"] for md in values(mapping_dict) if md["vm"] != 0]
        df = NLsolve.OnceDifferentiable(f!, jsp_mb!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; delta_v = true, v_inds=v_inds, kwargs...)
    end
    # x_final = result.zero
    # jsp_mb!(J0, x_final)
    if ~(result.x_converged || result.f_converged )
        x_f = result.zero
        jsp_mb!(J0, x_final)
    end
    x_final = fill_in_xfinal(result.zero)
    result.zero = x_final
    return result, jacobian_history, x_history
end


function _compute_ac_pf(pf_data::PowerFlowData, mapping_dict, J0_map; 
                        finite_differencing=false, flat_start=true,  bounded_vars = false, var_bounds = nothing, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    additional_x_len = bounded_vars ? length(var_bounds) : 0
    x0 = flat_start ? zeros(Float64, 2*length(am.idx_to_bus) + additional_x_len) : pf_data.x0
    if flat_start 
        vm_indices = [val["vm"] for val in values(mapping_dict) if val["vm"] != 0]
        x0[vm_indices] .= 1.0
    end
    F0 = flat_start ? zeros(Float64, 2*length(am.idx_to_bus) + additional_x_len) : pf_data.F0
    J0 = J0_map
    jacobian_history = Vector{SparseMatrixCSC{Float64, Int64}}()
    x_history = Vector{Vector{Float64}}()
    var_bounds = var_bounds
    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[mapping["q"]]
                va_idx[i] = x[mapping["va"]]
                # println("bus $i: q = $(2*i - 1) \t va = $(2*i)")
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[mapping["p"]]
                q_inject_idx[i] = x[mapping["q"]]
                # println("bus $i: p = $(2*i - 1) \t q = $(2*i)")
            elseif bus_type_idx[i] == 5
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 6
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
                q_inject_idx[i] = x[mapping["q"]]
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
        end


    end

    function jsp_mb!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        # functions for each type of derivative
        function dpdv(i)
            y_ii = am.matrix[i, i]
            return 2*real(y_ii)*vm_idx[i] + sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dqdv(i)
            y_ii = am.matrix[i, i]
            return -2*imag(y_ii)*vm_idx[i] + sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dpdtheta(i)
            return vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dqdtheta(i)
            return vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
        end
        function dpdp(i)
            return 1
        end
        function dqdp(i)
            return 0
        end
        function dpdq(i)
            return 0
        end
        function dqdq(i)
            return 1
        end
        function dpn_dv(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
        end
        function dqn_dv(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
        end
        function dpn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end
        function dqn_dtheta(i, j)
            y_ij = am.matrix[i,j]
            return vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
        end

        function dbound_dvar(i)
            return -1 
        end 

        # function dbound_dbvar(x_og)
        #     x_ind, bv = var_bounds[x_og] # grab bound variable and range
        #     mp, R, S = bv
        #     xval = x[x_ind] # current value for bound variable
        #     # inside piece 
        #     inside = 1 + (xval/(S*R))^10
        #     # numerator
        #     n1 = (inside)^(1/10)/(S*R) 
        #     n2 = (xval * (xval/(S*R))^9)/((S*R)^2 * inside^(9/10))
        #     num = n1 - n2 
        #     # denominator
        #     denom = inside^(1/5)
        #     return num/denom * R, x_ind
        # end

        function dbound_dbvar(x_og)
            x_ind, bv = var_bounds[x_og] # grab bound variable and range
            mp, R, S = bv
            xval = x[x_ind] # current value for bound variable
            deriv = (R/S) * cos(xval/S) 
            # if derivative is near 0, push it forward 
            if abs(deriv) <= 1e-5
                deriv = sign(deriv) * 1e-3
            elseif deriv == 0 
                deriv = 1e-3 
            end
            return deriv, x_ind
        end

        # iterate through each power balance equation
        for i in eachindex(am.idx_to_bus)
            r_real = 2*i - 1
            r_imag = 2*i
            # iterate through each bus connected to get related variables 
            for j in neighbors[i]
                if bus_type_idx[j] == 1
                    vm_col = mapping_dict[j]["vm"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, vm_col] = dpdv(j)
                        J[r_imag, vm_col] = dqdv(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        # println("J[$r_real, $vm_col] = dpdv($j)")
                        # println("J[$r_imag, $vm_col] = dqdv($j)")
                        # println("J[$r_real, $va_col] = dpdtheta($j)")
                        # println("J[$r_imag, $va_col] = dqdtheta($j)")
                    else 
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        # println(" 
                        #     J[$r_real, $vm_col] = dpn_dv($i, $j)
                        #     J[$r_imag, $vm_col] = dqn_dv($i, $j) 
                        # ")
                        #     J[$r_real, $va_col] = dpn_dtheta($i, $j) 
                        #     J[$r_imag, $va_col] = dqn_dtheta($i, $j)  
                        # ")
                    end
                elseif bus_type_idx[j] == 2 
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        # println(" 
                        #     J[$r_real, $q_col] = dpdq($j) 
                        #     J[$r_imag, $q_col] = dqdq($j) 
                        #     J[$r_real, $va_col] = dpdtheta($j) 
                        #     J[$r_imag, $va_col] = dqdtheta($j)                        
                        # ")
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        # println(" 
                        #     J[$r_real, $q_col] = 0 
                        #     J[$r_imag, $q_col] = 0 
                        #     J[$r_real, $va_col] = dpn_dtheta($i, $j) 
                        #     J[$r_imag, $va_col] = dqn_dtheta($i, $j)                        
                        # ")
                    end
                elseif bus_type_idx[j] == 3
                    q_col = mapping_dict[j]["q"]
                    p_col = mapping_dict[j]["p"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, p_col] = dpdp(j)
                        J[r_imag, p_col] = dqdp(j)
                        # println("
                        #     J[$r_real, $q_col] = dpdq($j) 
                        #     J[$r_imag, $q_col] = dqdq($j) 
                        #     J[$r_real, $p_col] = dpdp($j) 
                        #     J[$r_imag, $p_col] = dqdp($j)                        
                        # ")
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, p_col] = 0
                        J[r_imag, p_col] = 0
                        # println("
                        #     J[$r_real, $q_col] = 0 
                        #     J[$r_imag, $q_col] = 0 
                        #     J[$r_real, $p_col] = 0 
                        #     J[$r_imag, $p_col] = 0                        
                        # ")
                    end   

                elseif bus_type_idx[j] == 5       
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                    else 
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                    end     
                elseif bus_type_idx[j] == 6
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    vm_col = mapping_dict[j]["vm"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                        J[r_real, vm_col] = dpdv(j)
                        J[r_imag, vm_col] = dqdv(j)
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                    end                                               
                end
            end
        end

        final_row = 2*length(am.idx_to_bus)
        # add bound variables 
        if bounded_vars 
            for (i, og_var) in enumerate(keys(var_bounds))
                # add derivative WRT bound variable 
                val, var_ind = dbound_dbvar(og_var)

               # add derivative WRT real variable 
                J[var_ind, og_var] = dbound_dvar(og_var)
                J[var_ind, var_ind] = val
            end
        end
        push!(jacobian_history, deepcopy(J))
        push!(x_history, deepcopy(x))
    end


    # basic init point
    if flat_start
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                x0[mapping["vm"]] = 1.0 # vm
            elseif bus_type_idx[i] == 2
            elseif bus_type_idx[i] == 3
            elseif bus_type_idx[i] == 5
            elseif bus_type_idx[i] == 6
            else
                @assert false
            end
        end
    end


    # # warm-start point
    # if !flat_start
    #     p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
    #     q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
    #     for (i,gen) in data["gen"]
    #         if gen["gen_status"] != 0
    #             if haskey(gen, "pg_start")
    #                 p_inject[gen["gen_bus"]] += gen["pg_start"]
    #             end
    #             if haskey(gen, "qg_start")
    #                 q_inject[gen["gen_bus"]] += gen["qg_start"]
    #             end
    #         end
    #     end

    #     for (i,shunt) in data["shunt"]
    #         if shunt["status"] != 0
    #             bus = data["bus"]["$(shunt["shunt_bus"])"]
    #             if haskey(bus, "vm_start")
    #                 p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
    #                 p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
    #             else
    #                 p_inject[shunt["shunt_bus"]] += shunt["gs"]
    #                 p_inject[shunt["shunt_bus"]] -= shunt["bs"]
    #             end
    #         end
    #     end

    #     for (i,bid) in enumerate(am.idx_to_bus)
    #         bus = data["bus"]["$(bid)"]
    #         if bus_type_idx[i] == 1
    #             if haskey(bus, "vm_start")
    #                 x0[2*i - 1] = bus["vm_start"]
    #             end
    #             if haskey(bus, "va_start")
    #                 x0[2*i] = bus["va_start"]
    #             end
    #         elseif bus_type_idx[i] == 2
    #             x0[2*i - 1] = -q_inject[bid]
    #             if haskey(bus, "va_start")
    #                 x0[2*i] = bus["va_start"]
    #             end
    #         elseif bus_type_idx[i] == 3
    #             x0[2*i - 1] = -p_inject[bid]
    #             x0[2*i] = -q_inject[bid]
    #         else
    #             @assert false
    #         end
    #     end
    # end

 
    # this is where the magic happens
    
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        df = NLsolve.OnceDifferentiable(f!, jsp_mb!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; kwargs...)
    end
    # x_final = result.zero
    # jsp_mb!(J0, x_final)
    if ~(result.x_converged || result.f_converged )
        x_final = result.zero
        jsp_mb!(J0, x_final)
    end
    return result, jacobian_history, x_history
end

function _compute_ac_pf_activeset(pf_data::PowerFlowData; finite_differencing=false, flat_start=false, mult_buses=false, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    x0 = pf_data.x0
    F0 = pf_data.F0
    J0 = pf_data.J0
    bounds = data["bounds"]

    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 1
                vm_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
                # println("bus $i: vm = $(vm_idx[i])")
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
                # println("bus $i: q = $(2*i - 1) \t va = $(2*i)")
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[2*i - 1]
                q_inject_idx[i] = x[2*i]
                # println("bus $i: p = $(2*i - 1) \t q = $(2*i)")
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
        end

        # complex varaint of above
        # for i in eachindex(am.idx_to_bus)
        #     balance = p_inject_idx[i] + q_inject_idx[i]im
        #     for j in neighbors[i]
        #         balance += vm_idx[i] * vm_idx[j] * (am.matrix[i,j] * (cos(va_idx[i] - va_idx[j]) + sin(va_idx[i] - va_idx[j])im))
        #     end
        #     F[2*i - 1] = real(balance)
        #     F[2*i] = imag(balance)
        # end
    end


    # ac power flow, sparse jacobian computation
    function jsp!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            f_i_r = 2*i - 1
            f_i_i = 2*i

            for j in neighbors[i]
                x_j_fst = 2*j - 1
                x_j_snd = 2*j

                bus_type = bus_type_idx[j]
                if bus_type == 1
                    if i == j
                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_fst] =  2*real(y_ii)*vm_idx[i] +            sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_r, x_j_snd] =                          vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_fst] = -2*imag(y_ii)*vm_idx[i] +            sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_i, x_j_snd] =                          vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_fst] =             vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_fst] =             vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 2
                    if i == j
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 1.0

                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_snd] =              vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_snd] =              vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 0.0

                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 3
                    # p_inject_idx[i] = p_delta_base_idx[i] + x[2*i - 1]
                    # q_inject_idx[i] = q_delta_base_idx[i] + x[2*i]
                    if i == j
                        J[f_i_r, x_j_fst] = 1.0
                        J[f_i_r, x_j_snd] = 0.0
                        J[f_i_i, x_j_fst] = 0.0
                        J[f_i_i, x_j_snd] = 1.0
                    end
                else
                    @assert false
                end
            end
        end
    end

    function update_active_set!(x, active_indices)
        # if length(active_indices) > 0
        #     return 
        # end
        # iterate over variables with bounds 
        for (var_ind, var_info) in pairs(bounds)
            val = x[var_ind]
            val_min, val_max = var_info[1]
            val_constr = var_info[2]
            bus = cld(var_ind, 2)
            var_neighbors = vcat([[2*i, 2*i - 1] for i in neighbors[bus]]...)
            # if variable violates bounds, it becomes active variable
            if val < val_min 
                x[var_ind] = val_min 
                # remove neighbors from bounds dictionaries
                for var in var_neighbors 
                    delete!(bounds, var)
                end
                push!(active_indices, [val_constr, var_ind])
            end
            if val > val_max 
                x[var_ind] = val_max 
                # remove neighbors from bounds dictionaries
                for var in var_neighbors 
                    delete!(bounds, var)
                end
                push!(active_indices, [val_constr, var_ind])
            end
            # if length(active_indices) > 0
            #     break
            # end
        end
        
    end

    # active set wrapper 
    function active_set!(F, J, x, active_indices)
        # update the active set 
        update_active_set!(x, active_indices)

        if F !== nothing 
            # solve for the residuals and set active equations to 0
            f!(F, x)
            # F[getindex.(active_indices, 1)] .= 0.0
        end 

        if J !== nothing 
            # compute the jacobian and set active variables to 0
            jsp!(J, x)
            for (i,j) in active_indices 
                J[i, :] .= 0.0 # zero out the row of the active equation 
                J[:, j] .= 0.0 # zero out the column of the active variable 
                J[i,j] = 1.0 # maintain stability
            end
        end
    end
    # basic init point
    if ~mult_buses
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 1
                x0[2*i - 1] = 1.0 # vm
            elseif bus_type_idx[i] == 2
            elseif bus_type_idx[i] == 3
            else
                @assert false
            end
        end
    else 
        ind = length(type_5)
        for (i, bus) in enumerate(type_1)
            x0[ind + 2*i - 1] = 1.0 # vm
        end
        ind += 2*length(type_1)
        ind += 2*length(type_2)
        ind += 2*length(type_3)
        for (i, bus) in enumerate(type_6)
            x0[ind + 3*i - 2] = 1 # vm
        end  
    end

    # warm-start point
    if !flat_start
        p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        for (i,gen) in data["gen"]
            if gen["gen_status"] != 0
                if haskey(gen, "pg_start")
                    p_inject[gen["gen_bus"]] += gen["pg_start"]
                end
                if haskey(gen, "qg_start")
                    q_inject[gen["gen_bus"]] += gen["qg_start"]
                end
            end
        end

        for (i,shunt) in data["shunt"]
            if shunt["status"] != 0
                bus = data["bus"]["$(shunt["shunt_bus"])"]
                if haskey(bus, "vm_start")
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
                else
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]
                end
            end
        end

        for (i,bid) in enumerate(am.idx_to_bus)
            bus = data["bus"]["$(bid)"]
            if bus_type_idx[i] == 1
                if haskey(bus, "vm_start")
                    x0[2*i - 1] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 2
                x0[2*i - 1] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3
                x0[2*i - 1] = -p_inject[bid]
                x0[2*i] = -q_inject[bid]
            else
                @assert false
            end
        end
    end


    # this is where the magic happens
    active_set = []
    f_wrapper!(F, x) = active_set!(F, nothing, x, active_set)
    j_wrapper!(J, x) = active_set!(nothing, J, x, active_set)
    if finite_differencing
        result = NLsolve.nlsolve(f_wrapper!, x0; kwargs...)
    else
        df = NLsolve.OnceDifferentiable(f_wrapper!, j_wrapper!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; show_trace = true, kwargs...)
    end
    return result, active_set
end

function _compute_ac_pf(pf_data::PowerFlowData; finite_differencing=false, flat_start=false, mult_buses=false, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    x0 = pf_data.x0
    F0 = pf_data.F0
    J0 = pf_data.J0
    jacobian_history = Vector{SparseMatrixCSC{Float64, Int64}}()
    x_history = Vector{Vector{Float64}}()
    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 1
                vm_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
                # println("bus $i: vm = $(vm_idx[i])")
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
                # println("bus $i: q = $(2*i - 1) \t va = $(2*i)")
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[2*i - 1]
                q_inject_idx[i] = x[2*i]
                # println("bus $i: p = $(2*i - 1) \t q = $(2*i)")
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] *  real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * -imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * ( real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (-imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
        end

        # complex varaint of above
        # for i in eachindex(am.idx_to_bus)
        #     balance = p_inject_idx[i] + q_inject_idx[i]im
        #     for j in neighbors[i]
        #         balance += vm_idx[i] * vm_idx[j] * (am.matrix[i,j] * (cos(va_idx[i] - va_idx[j]) + sin(va_idx[i] - va_idx[j])im))
        #     end
        #     F[2*i - 1] = real(balance)
        #     F[2*i] = imag(balance)
        # end
    end


    # ac power flow, sparse jacobian computation
    function jsp!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            f_i_r = 2*i - 1
            f_i_i = 2*i

            for j in neighbors[i]
                x_j_fst = 2*j - 1
                x_j_snd = 2*j

                bus_type = bus_type_idx[j]
                if bus_type == 1
                    if i == j
                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_fst] =  2*real(y_ii)*vm_idx[i] +            sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_r, x_j_snd] =                          vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_fst] = -2*imag(y_ii)*vm_idx[i] +            sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_i, x_j_snd] =                          vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_fst] =             vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_fst] =             vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 2
                    if i == j
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 1.0

                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_snd] =              vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_snd] =              vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 0.0

                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 3
                    # p_inject_idx[i] = p_delta_base_idx[i] + x[2*i - 1]
                    # q_inject_idx[i] = q_delta_base_idx[i] + x[2*i]
                    if i == j
                        J[f_i_r, x_j_fst] = 1.0
                        J[f_i_r, x_j_snd] = 0.0
                        J[f_i_i, x_j_fst] = 0.0
                        J[f_i_i, x_j_snd] = 1.0
                    end
                else
                    @assert false
                end
            end
        end
        push!(jacobian_history, deepcopy(J))
        push!(x_history, deepcopy(x))
    end


    # basic init point
    if ~mult_buses
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 1
                x0[2*i - 1] = 1.0 # vm
            elseif bus_type_idx[i] == 2
            elseif bus_type_idx[i] == 3
            else
                @assert false
            end
        end
    else 
        ind = length(type_5)
        for (i, bus) in enumerate(type_1)
            x0[ind + 2*i - 1] = 1.0 # vm
        end
        ind += 2*length(type_1)
        ind += 2*length(type_2)
        ind += 2*length(type_3)
        for (i, bus) in enumerate(type_6)
            x0[ind + 3*i - 2] = 1 # vm
        end  
    end

    # warm-start point
    if !flat_start
        p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        for (i,gen) in data["gen"]
            if gen["gen_status"] != 0
                if haskey(gen, "pg_start")
                    p_inject[gen["gen_bus"]] += gen["pg_start"]
                end
                if haskey(gen, "qg_start")
                    q_inject[gen["gen_bus"]] += gen["qg_start"]
                end
            end
        end

        for (i,shunt) in data["shunt"]
            if shunt["status"] != 0
                bus = data["bus"]["$(shunt["shunt_bus"])"]
                if haskey(bus, "vm_start")
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
                else
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]
                end
            end
        end

        for (i,bid) in enumerate(am.idx_to_bus)
            bus = data["bus"]["$(bid)"]
            if bus_type_idx[i] == 1
                if haskey(bus, "vm_start")
                    x0[2*i - 1] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 2
                x0[2*i - 1] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3
                x0[2*i - 1] = -p_inject[bid]
                x0[2*i] = -q_inject[bid]
            else
                @assert false
            end
        end
    end


    # this is where the magic happens
    
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        df = NLsolve.OnceDifferentiable(f!, jsp!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; kwargs...)
    end
    return result, jacobian_history, x_history
end


function nlsolve(df::Union{NonDifferentiable, OnceDifferentiable},
                 initial_x::AbstractArray;
                 method::Symbol = :trust_region,
                 xtol::Real = zero(real(eltype(initial_x))),
                 ftol::Real = convert(real(eltype(initial_x)), 1e-8),
                 iterations::Integer = 1_000,
                 store_trace::Bool = false,
                 show_trace::Bool = false,
                 extended_trace::Bool = false,
                 linesearch = NLsolve.LineSearches.Static(),
                 linsolve=(x, A, b) -> copyto!(x, A\b),
                 factor::Real = one(real(eltype(initial_x))),
                 autoscale::Bool = true,
                 m::Integer = 10,
                 beta::Real = 1,
                 aa_start::Integer = 1,
                 droptol::Real = convert(real(eltype(initial_x)), 1e10),
                 bounds = [], 
                 delta_v = false, v_inds = [])
    if show_trace
        @printf "Iter     f(x) inf-norm    Step 2-norm \n"
        @printf "------   --------------   --------------\n"
    end
    if method == :newton
        newton(df, initial_x, xtol, ftol, iterations,
               store_trace, show_trace, extended_trace, linesearch; linsolve=linsolve, bounds=bounds)
    elseif method == :trust_region
        trust_region(df, initial_x, xtol, ftol, iterations,
                     store_trace, show_trace, extended_trace, factor,
                     autoscale; delta_v = delta_v, v_inds = v_inds)
    elseif method == :anderson
        anderson(df, initial_x, xtol, ftol, iterations,
                 store_trace, show_trace, extended_trace, m, beta, aa_start, droptol)
    elseif method == :broyden
        broyden(df, initial_x, xtol, ftol, iterations,
                store_trace, show_trace, extended_trace, linesearch)
    else
        throw(ArgumentError("Unknown method $method"))
    end
end

function trust_region(df::OnceDifferentiable,
                      initial_x::AbstractArray{T},
                      xtol::Real,
                      ftol::Real,
                      iterations::Integer,
                      store_trace::Bool,
                      show_trace::Bool,
                      extended_trace::Bool,
                      factor::Real,
                      autoscale::Bool,
                      cache = NewtonTrustRegionCache(df); 
                       delta_v = false, v_inds = []) where T
    trust_region_(df, initial_x, convert(real(T), xtol), convert(real(T), ftol), 
                    iterations, store_trace, show_trace, 
                    extended_trace, convert(real(T), factor), 
                    autoscale, cache; delta_v = delta_v, v_inds = v_inds)
end

function trust_region_(df::OnceDifferentiable,
                       initial_x::AbstractArray{T},
                       xtol::Real,
                       ftol::Real,
                       iterations::Integer,
                       store_trace::Bool,
                       show_trace::Bool,
                       extended_trace::Bool,
                       factor::Real,
                       autoscale::Bool,
                       cache = NewtonTrustRegionCache(df); 
                       delta_v = false, v_inds = []) where T
    copyto!(cache.x, initial_x)
    value_jacobian!!(df, cache.x)
    cache.r .= value(df)
    check_isfinite(cache.r)

    it = 0
    x_converged, f_converged = assess_convergence(initial_x, cache.xold, value(df), NaN, ftol)
    stopped = any(isnan, cache.x) || any(isnan, value(df)) ? true : false

    converged = x_converged || f_converged
    delta = convert(real(T), NaN)
    rho = convert(real(T), NaN)
    if converged
        tr = SolverTrace()
        name = "Trust-region with dogleg"
        if autoscale
            name *= " and autoscaling"
        end

        return SolverResults(name,
        #initial_x, reshape(cache.x, size(initial_x)...), norm(cache.r, Inf),
        initial_x, copy(cache.x), norm(cache.r, Inf),
        it, x_converged, xtol, f_converged, ftol, tr,
        first(df.f_calls), first(df.df_calls))
    end

    tr = SolverTrace()
    tracing = store_trace || show_trace || extended_trace
    @trustregiontrace convert(real(T), NaN)
    nn = length(cache.x)
    if autoscale
        for j = 1:nn
            cache.d[j] = norm(view(jacobian(df), :, j))
            if cache.d[j] == zero(cache.d[j])
                cache.d[j] = one(cache.d[j])
            end
        end
    else
        fill!(cache.d, one(real(T)))
    end

    delta = factor * wnorm(cache.d, cache.x)
    if delta == zero(delta)
        delta = factor
    end

    eta = convert(real(T), 1e-4)

    while !stopped && !converged && it < iterations
        it += 1

        # Compute proposed iteration step
        dogleg!(cache.p, cache.p_c, cache.pi, cache.r, cache.d, jacobian(df), delta)

        copyto!(cache.xold, cache.x)
        if delta_v
            # separate the v updates 
            cache.p[v_inds] = cache.p[v_inds] .* cache.xold[v_inds]
        end 
        cache.x .+= cache.p
        
        value!(df, cache.x)

        # Ratio of actual to predicted reduction (equation 11.47 in N&W)
        mul!(vec(cache.r_predict), jacobian(df), vec(cache.p))
        cache.r_predict .+= cache.r
        rho = (sum(abs2, cache.r) - sum(abs2, value(df))) / (sum(abs2, cache.r) - sum(abs2, cache.r_predict))

        if rho > eta
            # Successful iteration
            cache.r .= value(df)
            jacobian!(df, cache.x)

            # Update scaling vector
            if autoscale
                for j = 1:nn
                    cache.d[j] = max(convert(real(T), 0.1) * real(cache.d[j]), norm(view(jacobian(df), :, j)))
                end
            end

            x_converged, f_converged = assess_convergence(cache.x, cache.xold, cache.r, xtol, ftol)
            converged = x_converged || f_converged
        else
            cache.x .-= cache.p
            x_converged, converged = false, false

        end

        @trustregiontrace euclidean(cache.x, cache.xold)

        # Update size of trust region
        if rho < 0.1
            delta = delta/2
        elseif rho >= 0.9
            delta = 2 * wnorm(cache.d, cache.p)
        elseif rho >= 0.5
            delta = max(delta, 2 * wnorm(cache.d, cache.p))
        end
        stopped = any(isnan, cache.x) || any(isnan, value(df)) ? true : false
    end

    name = "Trust-region with dogleg"
    if autoscale
        name *= " and autoscaling"
    end
    return SolverResults(name,
                         initial_x, copy(cache.x), maximum(abs, cache.r),
                         it, x_converged, xtol, f_converged, ftol, tr,
                         first(df.f_calls), first(df.df_calls))
end
