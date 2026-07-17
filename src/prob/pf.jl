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

    x0 = [0.0 for i in 1:am.J_size]
    F0 = similar(x0)

    J0_I = Int[]
    J0_J = Int[]
    J0_V = Float64[]

    for i in eachindex(am.idx_to_bus)
        bus_type_i = bus_type_idx[i]
        f_i_r = am.idx_to_J_idx[i]
        f_i_i = am.idx_to_J_idx[i] + 1

        for j in neighbors[i]
            bus_type_j = bus_type_idx[j]
            x_j_fst = am.idx_to_J_idx[j]
            x_j_snd = am.idx_to_J_idx[j] + 1 

            if bus_type_i == 3 || bus_type_j == 3
                # nothing in J
            elseif bus_type_i == 2 && bus_type_j == 2
                push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            elseif bus_type_i == 2 && bus_type_j == 1
                push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
                push!(J0_I, f_i_r); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
            elseif bus_type_i == 1 && bus_type_j == 2
                push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
                push!(J0_I, f_i_i); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            elseif bus_type_i == 1 && bus_type_j == 1
                push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
                push!(J0_I, f_i_r); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
                push!(J0_I, f_i_i); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
                push!(J0_I, f_i_i); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
            else
                error("Bus types wrong")
            end
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


"""
Computes a nonlinear AC power flow in polar coordinates based on the admittance
matrix of the network data using the NLsolve package.  See the NLsolve
documentation for solver configuration parameters.

Returns a solution data structure in PowerModels Dict format
"""
function compute_ac_pf(pf_data::PowerFlowData; kwargs...)
    time_start = time()

    pf_result = _compute_ac_pf(pf_data; kwargs...)

    solution = Dict("per_unit" => pf_data.data["per_unit"])

    converged = pf_result.x_converged || pf_result.f_converged

    if !converged
        @_warn("ac power flow solver convergence failed!  use `show_trace = true` for more details")
    else
        data = pf_data.data
        bus_gens = pf_data.bus_gens
        am = pf_data.am
        bus_type_idx = pf_data.bus_type_idx

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
            J_idx = am.idx_to_J_idx[i]

            if bus_type_idx[i] == 1
                @assert !haskey(bus_gens, bid)
                bus["vm"] = pf_result.zero[J_idx]
                bus["va"] = pf_result.zero[J_idx + 1]

            elseif bus_type_idx[i] == 2
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["qg"] = 0.0
                end

                qg_remaining = -pf_data.q_inject_idx[i]
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)

                bus["va"] = pf_result.zero[J_idx]

            elseif bus_type_idx[i] == 3
                for gen in bus_gens[bid]
                    sol_gen = gen_assignment["$(gen["index"])"]
                    sol_gen["pg"] = 0.0
                    sol_gen["qg"] = 0.0
                end

                pg_remaining = -pf_data.p_inject_idx[i]
                _assign_pg!(gen_assignment, bus_gens[bid], pg_remaining)

                qg_remaining = -pf_data.q_inject_idx[i]
                _assign_qg!(gen_assignment, bus_gens[bid], qg_remaining)
            else
                @assert false
            end
        end

        solution = Dict(
            "per_unit" => data["per_unit"],
            "bus" => bus_assignment,
            "gen" => gen_assignment,
        )
    end

    result = Dict(
        "optimizer" => "NLsolve",
        "termination_status" => converged,
        "objective" => 0.0,
        "solution" => solution,
        "solve_time" => time() - time_start
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
        @_warn("ac power flow solver convergence failed!  use `show_trace = true` for more details")
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

            qg_remaining = -pf_data.q_inject_idx[i]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)

        elseif bus_type_idx[i] == 3
            for gen in bus_gens[bid]
                gen["pg"] = 0.0
                gen["qg"] = 0.0
            end

            pg_remaining = -pf_data.p_inject_idx[i]
            _assign_pg!(data["gen"], bus_gens[bid], pg_remaining)

            qg_remaining = -pf_data.q_inject_idx[i]
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


function _compute_ac_pf(pf_data::PowerFlowData; finite_differencing=false, flat_start=false, kwargs...)
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

    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            J_idx = am.idx_to_J_idx[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[J_idx]
                va_idx[i] = x[J_idx+1]
            elseif bus_type_idx[i] == 2
                #q_inject_idx[i] = x[2*i - 1]
                va_idx[i] = x[J_idx]
            elseif bus_type_idx[i] == 3
                #p_inject_idx[i] = x[2*i - 1]
                #q_inject_idx[i] = x[2*i]
            else
                @assert false
            end
        end

        
        # TODO ensure this correclty updates p_inject_idx and q_inject_idx
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
            J_idx = am.idx_to_J_idx[i]
            if bus_type_idx[i] == 1
                F[J_idx] = balance_real
                F[J_idx+1] = balance_imag
            elseif bus_type_idx[i] == 2
                F[J_idx] = balance_real
                q_inject_idx[i] += - balance_imag
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] += - balance_real
                q_inject_idx[i] += - balance_imag
            end 
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
        println("Ran f!")
    end

    # ac power flow, sparse jacobian computation
    function jsp!(J::SparseArrays.SparseMatrixCSC{Float64,Int}, x::Vector{Float64})
        # Notes to self
        # Y_ij = |Y_ij| exp(j*θ_ij)

        for i in eachindex(am.idx_to_bus)   # NLsolve does NOT guarantee jsp! and f! execution order (different in Newton and main method)
            J_idx = am.idx_to_J_idx[i]
            if bus_type_idx[i] == 1
                vm_idx[i] = x[J_idx]
                va_idx[i] = x[J_idx+1]
            elseif bus_type_idx[i] == 2
                va_idx[i] = x[J_idx]
            elseif bus_type_idx[i] == 3
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            J_idx_i = am.idx_to_J_idx[i]

            f_i_r = J_idx_i         # PQ/PV bus: P
            f_i_i = J_idx_i + 1     # PQ bus:    Q

            bus_type_row = bus_type_idx[i]
            
            for j in neighbors[i]
                J_idx_j = am.idx_to_J_idx[j]
                x_j_fst = J_idx_j       # PQ bus: |V|, PV bus: δ
                x_j_snd = J_idx_j + 1   # PQ bus:  δ

                bus_type_col = bus_type_idx[j]
                if bus_type_row == 3 || bus_type_col == 3   # REF bus || Ref bus (no J entries)

                elseif bus_type_row == 2 && bus_type_col == 2  # PV bus && PV bus
                    if i == j # on diagonal
                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_fst] =              vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else # off diagonal
                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_fst] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end

                elseif bus_type_row == 2 && bus_type_col == 1  # PV bus && PQ bus
                    @assert i != j # has to be off diagonal
                    y_ij = am.matrix[i,j]
                    J[f_i_r, x_j_fst] =             vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j])) # good
                    J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j])) # good

                elseif bus_type_row == 1 && bus_type_col == 2  # PQ bus && PV bus
                    @assert i != j # has to be off diagonal
                    y_ij = am.matrix[i,j]
                    J[f_i_r, x_j_fst] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j])) # good
                    J[f_i_i, x_j_fst] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j])) # good
                
                elseif bus_type_row == 1 && bus_type_col == 1  # PQ bus && PQ bus
                    if i == j # on diagonal
                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_fst] =  2*real(y_ii)*vm_idx[i] +            sum(  real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i) # good
                        J[f_i_r, x_j_snd] =                          vm_idx[i] * sum(  real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i) # good

                        J[f_i_i, x_j_fst] = -2*imag(y_ii)*vm_idx[i] +            sum( -imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i) # good
                        J[f_i_i, x_j_snd] =                          vm_idx[i] * sum( -imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i) # good
                    else # off diagonal
                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_fst] =             vm_idx[i] * ( real(y_ij) * cos(va_idx[i] - va_idx[j]) + imag(y_ij) *  sin(va_idx[i] - va_idx[j])) # good
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * ( real(y_ij) * sin(va_idx[i] - va_idx[j]) + imag(y_ij) * -cos(va_idx[i] - va_idx[j])) # good

                        J[f_i_i, x_j_fst] =             vm_idx[i] * (-imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j])) # good
                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (-imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j])) # good
                    end
                else
                    @assert false
                end
            end
        end
        println("Ran jsp!")
    end

    # basic init point
    for i in eachindex(am.idx_to_bus)
        if bus_type_idx[i] == 1
            J_idx = am.idx_to_J_idx[i]
            x0[J_idx] = 1.0 #vm
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
            J_idx = am.idx_to_J_idx[i]
            if bus_type_idx[i] == 1
                if haskey(bus, "vm_start")
                    x0[J_idx] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[J_idx+1] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 2
                #x0[2*i - 1] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[J_idx] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3
                #x0[2*i - 1] = -p_inject[bid]
                #x0[2*i] = -q_inject[bid]
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

    return result
end


