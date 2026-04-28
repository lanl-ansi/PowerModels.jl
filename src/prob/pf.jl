
using Infiltrator
using RowEchelon
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


Base.@kwdef struct SwapFlags 
    mapping = false # for basic PF: use mapping dictionary vs. using indexing
    enforce_q_lims = true # for basic PF: include q lims or not 
    obo = false  # one-by-one: can you perform one type-switch each iteration, or multiple?
    flat_start = false # flat start each iter vs. warmstart with the prev soln
    max_acpf = 50 # max iters before returning best solution thus far
    minimize_mag = true # minimize violation magnitude vs. number of violations 
    one_swap = false # only one P-PQV pair at a time; switch back between each iter
    highest_mag = true # prioritize resolving the highest mag. violation versus the smallest mag.
    grainger = false # use the grainger implementation to solve power flow
    swap_technique = "nearest_gen" # swap technique to determine the best P-PQV pairs
    debug = false
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
I added PV-PQ switching to this and the option to use a mapping dictionary
"""
function compute_ac_pf(pf_data::PowerFlowData; kwargs...)
    # store flags
    flags = SwapFlags(; kwargs...)
    mapping = flags.mapping
    enforce_q_lims = flags.enforce_q_lims
    flat_start = flags.flat_start
    filtered_kwargs = NamedTuple(filter(kv -> ~(kv[1] in [:enforce_q_lims, :mapping, :flat_start]), kwargs))
    time_start = time()
    is_feas = false
    pf_result = nothing
    acpf_counter = 0
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
    while ~is_feas
        @_debug( "computing ac pf, iteration $(acpf_counter)... ")
        if mapping
            mapping_dict, J0_map = map_types_to_variable_indices(pf_data; grainger = flags.grainger)
            push!(mapping_dicts, mapping_dict)
            if flags.grainger 
             pf_result, jacobian, x_hist = _compute_ac_pf_grainger(pf_data, mapping_dict, J0_map, flat_start=flags.flat_start)  
            else 
                pf_result, jacobian, x_hist = _compute_ac_pf(pf_data, mapping_dict, J0_map, flat_start=flags.flat_start)   
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

        if !converged
            bus_assignment = Dict(i => Dict("vm"=>-1, "va"=>-1) for i in keys(pf_data.data["bus"]))
            gen_assignment = Dict(i => Dict("pg"=>-1, "qg"=>-1) for i in keys(pf_data.data["gen"]))
            solution =   Dict(
            "per_unit" => pf_data.data["per_unit"],
            "bus" => bus_assignment,
            "gen" => gen_assignment,
            )
            push!(soln_history, solution)
            push!(prev_bus_indices, deepcopy(pf_data.bus_type_idx))
            
            @_debug( "ac power flow solver convergence failed!")
            break
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

            swap = Ref(false)
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
                    if enforce_q_lims 
                        # check qg bounds
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
                            if ~flags.obo || ~swap[]
                                @_debug( "switching PV bus $i from 2 to 1... ")
                                pf_data.bus_type_idx[i] = 1
                                is_feas = false
                                swap[] = true
                            end
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
        acpf_counter += 1
        if acpf_counter >= flags.max_acpf
            break 
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


function _compute_ac_pf(pf_data::PowerFlowData; finite_differencing=false, flat_start=false,  kwargs...)
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
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[2*i - 1]
                q_inject_idx[i] = x[2*i]
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
    for i in eachindex(am.idx_to_bus)
        if bus_type_idx[i] == 1
            x0[2*i - 1] = 1.0 # vm
        elseif bus_type_idx[i] == 2
        elseif bus_type_idx[i] == 3
        else
            @assert false
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

"""
Functions added to be able to do bus swapping 
"""


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

"with bus-type switching, the variable indexing is no longer straightforward. This 
creates a dictionary that maps each bus to the variable indices and row indices to be used in the jacobian.
"
function map_types_to_variable_indices(pf_data; first_iter = false, grainger = false)
    bus_type_idx = pf_data.bus_type_idx
    am = pf_data.am 
    neighbors = pf_data.neighbors
    # a value of 0 indicates that the feature is not a variable in the upcoming jacobian iteration.
    mapping_dict = Dict(bus_ind => Dict("va" => 0, "vm" => 0, "p" => 0, "q" => 0, 
                                        "p_row" => grainger ? 0 : 2*i - 1, "q_row"=> grainger ? 0 : 2*i) 
                        for (i, bus_ind) in enumerate(values(pf_data.am.bus_to_idx)))
    # collect the bus types
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
    # generate the row and column indices for the real and reactive power balance
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
        # the remaining reactive power will be solved for after the initial NR converges. 
        final_extrarow = 0
        for (i, bus) in enumerate(vcat(type_2, type_3, type_6))
            mapping_dict[bus]["q_row"] = final_qrow + i 
            final_extrarow = final_qrow + i
        end
    end
    # complete variable indexing for each bus type
    for ind in type_1
        mapping_dict[ind]["va"] = counter
        mapping_dict[ind]["vm"] = counter + 1
        if first_iter 
            pf_data.x0[counter + 1] = 1
        end
        counter += 2
    end
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
    for ind in type_5
        mapping_dict[ind]["va"] = counter
        counter += 1
    end
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
        if ~grainger
            for j in neighbors[i]
                mapping = mapping_dict[j]
                vars = ["p", "q", "va", "vm"]
                for var in vars 
                    if mapping[var] != 0 
                        push!(rows, f_i_r); push!(cols, mapping[var]); push!(entries, 0.0)
                        push!(rows, f_i_i); push!(cols, mapping[var]); push!(entries, 0.0)
                    end
                end 
            end
        else 
            if i in type_3
                continue 
            end 
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

    J0_map = SparseArrays.sparse(rows, cols, entries)
    #re-index the reactive power for type 2,3, and 6 and the real power for type 3
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

function _prep_best_solution_(pf_data)
    best_solution = Dict()
    best_solution["best_score"] = 1e6 
    best_solution["solution"] = nothing 
    best_solution["converged"] = false 
    best_solution["bus_type_idx"] = pf_data.bus_type_idx
    best_solution["vm_idx"] = pf_data.vm_idx
    best_solution["va_idx"] = pf_data.va_idx
    best_solution["p_inject_idx"] = pf_data.p_inject_idx
    best_solution["q_inject_idx"] = pf_data.q_inject_idx
    best_solution["p_delta_base_idx"] = pf_data.p_delta_base_idx
    best_solution["q_delta_base_idx"] = pf_data.q_delta_base_idx
    best_solution["pf_data"] = pf_data
    best_solution["p_pqv_pairs"] = Dict()
    return best_solution
end

"Runs AC-PF with bus-type switching implemented"
function compute_ac_pf_mult_buses(pf_data::PowerFlowData; kwargs...)
    # store flags
    flags = SwapFlags(; kwargs...)
    # prepare to begin 
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
    p_pqv_pairs = Dict{Int64,Int64}()
    best_solution = _prep_best_solution_(pf_data)
    non_convergence = 0
    pf_data.data["pv_bus_inds"] = [i for (i, bt) in enumerate(pf_data.bus_type_idx) if bt == 2]
    jacobian = nothing 
    pf_data.data["prev_swaps"] = Dict(bus=> [] for bus in 1:length(pf_data.bus_type_idx))
    time_start = time()
    while (~is_feas) & (acpf_counter <= flags.max_acpf)
        @_debug( "computing ac pf, iteration $(acpf_counter)... ")
        # variable mapping for jacobian
        mapping_dict, J0_map = map_types_to_variable_indices(pf_data,  grainger = flags.grainger)
        # place the previous solution into the x0 variable
        if  (~flags.flat_start ) & (acpf_counter > 1) & (length(soln_history) >= 1)
            _update_x_!(pf_data, soln_history[end], pf_data.bus_type_idx, mapping_dict, pf_data.x0)
        end
        # compute ac power flow
        pf_result, jacobian, x_hist = nothing, nothing, nothing
        try
            if flags.grainger 
                pf_result, jacobian, x_hist = _compute_ac_pf_grainger(pf_data, mapping_dict, J0_map, flat_start=flags.flat_start) 
            else 
                pf_result, jacobian, x_hist = _compute_ac_pf(pf_data, mapping_dict, J0_map; flat_start = flags.flat_start) 
            end
        catch e 
            # @infiltrate flags.debug
            rethrow(e)
            pf_result.x_converged = false
            pf_result.f_converged = false
            non_convergence = 5
        end
        # store jacobian, x, and mapping for analysis 
        jacobian_history = vcat(jacobian_history, jacobian)
        x_history = vcat(x_history, x_hist)
        push!(x_history, [])
        push!(jacobian_history, [])
        mapping_dicts = vcat(mapping_dicts, mapping_dict)
        is_feas = true # start by assuming solution has no violations
        solution = Dict("per_unit" => pf_data.data["per_unit"])
        converged = pf_result.x_converged || pf_result.f_converged 
        if !converged
            non_convergence += 1
            @_debug( "ac power flow solver convergence failed!")
            if (acpf_counter > flags.max_acpf) || (non_convergence > 5)
                solution = best_solution["solution"]
                bus_type_idx = best_solution["bus_type_idx"]
                pf_data = best_solution["pf_data"]
                best_converged = true

            elseif isnothing(best_solution["solution"])
                @_debug( "No converged state thus far.")
                bus_assignment = Dict(i => Dict("vm"=>-1, "va"=>-1) for i in keys(pf_data.data["bus"]))
                gen_assignment = Dict(i => Dict("pg"=>-1, "qg"=>-1) for i in keys(pf_data.data["gen"]))
                solution =   Dict(
                "per_unit" => pf_data.data["per_unit"],
                "bus" => bus_assignment,
                "gen" => gen_assignment,
                )
                best_converged = false
                best_solution["solution"] = solution
                push!(soln_history, solution)
                push!(bus_indices, deepcopy(pf_data.bus_type_idx))
            else
                @_debug( "continuing from best solution")
                is_feas = false 
                update_pf_data!(pf_data, best_solution)
                warm_start_prev_soln!(pf_data, best_solution["solution"])
                p_pqv_pairs = deepcopy(best_solution["p_pqv_pairs"])
            end

        else
            # analyze solution and perform swaps
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

            # collect violations from each bus type 
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
            violations = Dict("b1" => b1_violations, 
                    "b2" => b2_violations, 
                    "b6v" => b6v_violations, 
                    "b6q" => b6q_violations
                    )
            @_debug("power balance maintained? $(validate_power_balance(pf_data, gen_assignment))")
            
            if flags.one_swap 
                _one_swap_update_(pf_data, p_pqv_pairs, violations, swap)
            end
            # store the solution for current iteration and update best solution
            solution = Dict(
                "per_unit" => data["per_unit"],
                "bus" => deepcopy(bus_assignment),
                "gen" => deepcopy(gen_assignment),
            )
            push!(soln_history, solution)
            score = flags.minimize_mag ? violation_mag[] : num_violations[]
            update_best_solution!(best_solution, old_pfd, score, solution, old_pairs, bus_type_idx, mapping_dict)
            # swap buses for next iteration
            perform_bus_swaps!(pf_data, mapping_dict, bus_type_idx, p_pqv_pairs, jacobian[end],
                            bus_assignment, swap, violations, flags)
            if score <= 1e-4
                @_debug( "Feasible Run")
                is_feas = true    
                break
            else 
                is_feas = ~swap[]
            end
            if is_feas  
                @_debug( "Ending with $(score), but no swap")
            end
            # warm start for next iter
            warm_start_prev_soln!(pf_data, solution)
        end
        if acpf_counter > flags.max_acpf 
            break 
        end

        acpf_counter += 1
    end
    # store info
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

"Swap back a P-PQV pair but update the new VM setpoint for the generator"
function _one_swap_update_(pf_data, p_pqv_pairs, violations, swap)
    b6v_violations = violations["b6v"]
    # swap back p-pqv pair 
    if length(p_pqv_pairs) > 0 
        p_bus = first(p_pqv_pairs).first
        pqv_bus = pop!(p_pqv_pairs, p_bus)
        # the new vm has been stored. Swap the bus types back 
        @_debug( "switching p-pqv pair $p_bus-$pqv_bus... ")
        update_bus_type!(pf_data, pqv_bus, 1)
        update_bus_type!(pf_data, p_bus, 2)
        # check to see if this bus had any violations 
        v_viol_ind = findfirst(x -> x[1] == p_bus, b6v_violations)
        if ~isnothing(v_viol_ind)
            # if v was violated, reset it to its max/min 
            v_viol = splice!(b6v_violations, v_viol_ind)
            pf_data.vm_idx[v_viol[1]] = v_viol[3]
            @_debug( "adjusting vm at $p_bus")
        end
        swap[] = true
    end
end

"Swap PV->PQ and P-PQV bus types"
function perform_bus_swaps!(pf_data, mapping_dict, bus_type_idx, p_pqv_pairs, jacobian,
                            bus_assignment, swap, violations, flags)
    # unpack violations 
    b1_violations = violations["b1"]
    b2_violations = violations["b2"]
    b6v_violations = violations["b6v"]
    b6q_violations = violations["b6q"]
    # update q violations first 
    sort_func = flags.highest_mag ? val -> -abs(val) : val -> abs(val)
    all_qs = vcat(b2_violations, b6q_violations)
    sort!(all_qs, by = x -> sort_func(x[4]))
    update_q_violations!(pf_data, all_qs, p_pqv_pairs, flags.obo, swap)
    if flags.obo & swap[] 
        return 
    end    
    # update the voltage violations at type 6 buses 
    sort!(b6v_violations, by = x -> sort_func(x[2]))
    update_vm_violations!(pf_data, b6v_violations, p_pqv_pairs, flags.obo, swap)
    if flags.obo & swap[] 
        return 
    end 
    # update the voltage violations at type 1 buses according to swapping technique
    if flags.swap_technique == "qv_inv"
        perform_bus_swaps_qv_inv!(pf_data, mapping_dict, jacobian, bus_type_idx, p_pqv_pairs, 
                                    bus_assignment, swap, b1_violations, flags)
    elseif flags.swap_technique == "sensitivity_score"
        perform_bus_swaps_sensitivity_score!(pf_data, mapping_dict, jacobian, bus_type_idx, p_pqv_pairs, 
                            bus_assignment, swap, b1_violations, flags)
    else 
        perform_bus_swaps_nearest_gen!(pf_data, bus_assignment, p_pqv_pairs, b1_violations, swap, flags)
    end
    
end

"P_PQV switching methodology based on nearby generators"
function perform_bus_swaps_nearest_gen!(pf_data, bus_assignment, p_pqv_pairs, b1_violations, swap, flags)
    sort_func = flags.highest_mag ? val -> -abs(val) : val -> abs(val)
    # find pv buses to swap 
    swap_gens = []
    for (pq_bus, viol, adjust) in b1_violations
        pv_bus = find_pv_bus(pf_data, pq_bus)
        if isnothing(pv_bus)
            continue 
        end 
        push!(swap_gens, pv_bus)
        if flags.obo 
            break 
        end
    end
    # swap buses
    stored_violations = b1_violations[1:length(swap_gens)]
    swap_pqv_buses!(pf_data, stored_violations, swap_gens, p_pqv_pairs, bus_assignment, swap)
end

"P-PQV switching methodology based on jacobian sensitivity"
function perform_bus_swaps_sensitivity_score!(pf_data, mapping_dict, jacobian, bus_type_idx, p_pqv_pairs, 
                                                bus_assignment, swap, b1_violations, flags)
    #TODO fill in
end

"P_PQV switching methodology based on maintaining LI of the QV submatrix"
function perform_bus_swaps_qv_inv!(pf_data, mapping_dict, jacobian, bus_type_idx, p_pqv_pairs, bus_assignment, 
                                            swap, b1_violations, flags)
    sort_func = flags.highest_mag ? val -> -abs(val) : val -> abs(val)
    # obtain the submatrices of the jacobian for the previous iteration
    submat_dict = _jacobian_submatrix_(pf_data, jacobian, mapping_dict, bus_type_idx)
    if length(submat_dict["qv_cols"]) == 0
        @_debug("No generators left to switch with. Continuing.")
        return 
    end
    # get the generator inverse matrix 
    inv_qv = nothing 
    try 
        inv_qv = inv(submat_dict["qv"])
    catch e 
        @_debug("singular QV submatrix. Continuing")
        return
    end
    gen_invs = Float64.(reduce(hcat, [inv_qv * vec for vec in submat_dict["qv_cols"]]))
    # get violated rows and cols
    sort!(b1_violations, by = x -> sort_func(x[2])) # sort violations 
    violated_rows = [submat_dict["submap"]["qv_rows"][i[1]] for i in b1_violations]
    num_gens = length(submat_dict["qv_cols"])
    # find LI pivot cols
    F = nothing
    try
        F = qr(reshape(gen_invs[violated_rows, :], length(violated_rows), num_gens), ColumnNorm())
    catch e 
        @infiltrate flags.debug
        rethrow(e)
    end
    pivot_cols, swap_candidates = _find_matching_viols_(gen_invs, pf_data.data["prev_swaps"], b1_violations, submat_dict, F.p)

    # bus-type switching 
    swap_pqv_buses!(pf_data, b1_violations[pivot_cols], swap_candidates, p_pqv_pairs, bus_assignment, swap)
    return
end

function _find_matching_viols_(gen_invs, prev_swaps, b1_violations, submat_dict, perms)
    pivot_cols = []
    pivot_gens =[]
    for (i, viol) in enumerate(b1_violations) 
        bus = viol[1] 
        bad_gens = prev_swaps[bus]
        bad_gis = [gen in keys(submat_dict["submap"]["qv_cols"]) ? submat_dict["submap"]["qv_cols"][gen] : 0 for gen in bad_gens]
        for gen in setdiff(perms, bad_gis)
            if gen in pivot_gens 
                continue 
            end 
            if abs(gen_invs[submat_dict["submap"]["qv_rows"][bus], gen]) < 1e-3
                continue 
            end 
            push!(pivot_cols, i)
            push!(pivot_gens, gen)
            break
        end
    end

    swap_candidates = [collect(keys(submat_dict["submap"]["qv_cols"]))[findfirst(x -> x == v, collect(values(submat_dict["submap"]["qv_cols"])))] for v in pivot_gens]
    return pivot_cols, swap_candidates
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

" Warm-start pf data with previous solution values"
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

" Compare this iteration's score to the best so far (lower = better)"
function update_best_solution!(best_solution, pf_data, score, solution, p_pqv_pairs, bus_type_idx, mapping_dict; converged = true)
    if score > best_solution["best_score"]
        return 
    end 
    @_debug( "minimal violation count: $(score)")
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
    @_debug( "best solution stored. Best p-pqv-pairs: $p_pqv_pairs")
    best_solution["mapping_dict"] = mapping_dict
end

function validate_power_balance(pf_data, gen_assignment)
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
    balance = true
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
        balance = balance && abs(balance_real) < 1e-5
        balance = balance && abs(balance_imag) < 1e-5

    end
    return balance
end

function update_pf_data!(pf_data, best_solution)
    function update_list!(pf_data_lst, best_solution_lst)
        for i in 1:length(pf_data_lst)
            pf_data_lst[i] = best_solution_lst[i]
        end
    end
    update_list!(pf_data.bus_type_idx, best_solution["bus_type_idx"])
    update_list!(pf_data.vm_idx, best_solution["vm_idx"])
    update_list!(pf_data.va_idx, best_solution["va_idx"])
    update_list!(pf_data.p_inject_idx, best_solution["p_inject_idx"])
    update_list!(pf_data.q_inject_idx, best_solution["q_inject_idx"])
    update_list!(pf_data.p_delta_base_idx, best_solution["p_delta_base_idx"])
    update_list!(pf_data.q_delta_base_idx, best_solution["q_delta_base_idx"])
    
end

"Compute AC-Power flow using the methology outlined in Grainger-Stevenson"
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
        # store current variable values for evaluation
        for i in eachindex(am.idx_to_bus)
            mapping = mapping_dict[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = 0
                va_idx[i] = x[mapping["va"]]
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = 0
                q_inject_idx[i] = 0
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

        # real and reactive power balance at each bus
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
            if bus_type_idx[i] in [1,5]
                F[mapping_dict[i]["q_row"]] = balance_imag
            end
            if bus_type_idx[i] != 3
                F[mapping_dict[i]["p_row"]] = balance_real
            end
            
        end
    end

    # jacobian partial derivatives
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

        # store partial derivates WRT real and reactive power balance at each bus
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 3 
                continue 
            end 
            r_real = mapping_dict[i]["p_row"]
            r_imag = mapping_dict[i]["q_row"]

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

    # after solving for vm and va, find the reactive power for generators and real power for slack bus
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
            elseif bus_type_idx[i] == 3
            elseif bus_type_idx[i] == 5
                va_idx[i] = x[mapping["va"]]
                x_final[mapping["va"]] = x[mapping["va"]]
            elseif bus_type_idx[i] == 6
                vm_idx[i] = x[mapping["vm"]]
                va_idx[i] = x[mapping["va"]]
                q_inject_idx[i] = 0
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
                q_inject_idx[i] = -balance_imag
            end
            if bus_type_idx[i] == 3
                x_final[mapping_dict[i]["p"]] = -balance_real
                p_inject_idx[i] = -balance_real
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

    # use NLsolve to perform newton-rhapson using the above functions
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        v_inds = [md["vm"] for md in values(mapping_dict) if md["vm"] != 0]
        df = NLsolve.OnceDifferentiable(f!, jsp_mb!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; delta_v = true, v_inds=v_inds, kwargs...)
    end

    if ~(result.x_converged || result.f_converged )
        # store the step that it failed at
        x_f = result.zero
        jsp_mb!(J0, x_final)
    end
    x_final = fill_in_xfinal(result.zero)
    result.zero = x_final
    return result, jacobian_history, x_history
end

"Compute AC-Power flow using the regular methodology, but with a mapping dictionary"
function _compute_ac_pf(pf_data::PowerFlowData, mapping_dict, J0_map; 
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
    x0 =  zeros(Float64, 2*length(am.idx_to_bus))
    if flat_start || sum(x0) == 0 
        vm_indices = [val["vm"] for val in values(mapping_dict) if val["vm"] != 0]
        x0[vm_indices] .= 1.0
    end
    F0 = zeros(Float64, 2*length(am.idx_to_bus))
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
        if size(J)[1] != size(J)[2]
            @infiltrate
        end
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
                    else 
                        J[r_real, vm_col] = dpn_dv(i, j)
                        J[r_imag, vm_col] = dqn_dv(i, j)
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                    end
                elseif bus_type_idx[j] == 2 
                    q_col = mapping_dict[j]["q"]
                    va_col = mapping_dict[j]["va"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, va_col] = dpdtheta(j)
                        J[r_imag, va_col] = dqdtheta(j)
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, va_col] = dpn_dtheta(i, j)
                        J[r_imag, va_col] = dqn_dtheta(i, j)
                    end
                elseif bus_type_idx[j] == 3
                    q_col = mapping_dict[j]["q"]
                    p_col = mapping_dict[j]["p"]
                    if i == j 
                        J[r_real, q_col] = dpdq(j)
                        J[r_imag, q_col] = dqdq(j)
                        J[r_real, p_col] = dpdp(j)
                        J[r_imag, p_col] = dqdp(j)
                    else 
                        J[r_real, q_col] = 0
                        J[r_imag, q_col] = 0
                        J[r_real, p_col] = 0
                        J[r_imag, p_col] = 0
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
                x0[mapping["q"]] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[mapping["va"]] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3
                x0[mapping["q"]] = -q_inject[bid]
                x0[mapping["p"]] = -p_inject[bid]
            elseif bus_type_idx[i] == 5 
                if haskey(bus, "va_start")
                    x0[mapping["va"]] = bus["va_start"]
                end   
            elseif bus_type_idx[i] == 6
                x0[mapping["q"]] = -q_inject[bid]
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


"""
Functions patched over from NLsolve to be able to use the grainger power flow implementation, 
which requires updating the |V| slightly differently.
"""
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
