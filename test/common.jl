
function build_mn_data(base_data; replicates::Int=2)
    mp_data = PowerModels.parse_file(base_data)
    return PowerModels.replicate(mp_data, replicates)
end

"checks that no bounds are in Inf"
function check_variable_bounds(model)
    for v in JuMP.all_variables(model)
        #println(v)
        if JuMP.has_lower_bound(v)
            if isinf(JuMP.lower_bound(v))
                println(v, JuMP.lower_bound(v))
                return false
            end
        end
        if JuMP.has_upper_bound(v)
            if isinf(JuMP.upper_bound(v))
                println(v, JuMP.upper_bound(v))
                return false
            end
        end
    end
    return true
end


function bus_gen_values(data, solution, value_key)
    bus_pg = Dict(i => 0.0 for (i,bus) in data["bus"])
    for (i,gen) in data["gen"]
        bus_pg["$(gen["gen_bus"])"] += solution["gen"][i][value_key]
    end
    return bus_pg
end


function all_loads_on(result; atol=1e-5)
    # tolerance of 1e-5 is needed for SCS tests to pass
    return !haskey(result["solution"], "load") || all(isapprox(load["status"], 1.0, atol=atol) for (i,load) in result["solution"]["load"])
end

function all_shunts_on(result; atol=1e-5)
    # tolerance of 1e-5 is needed for SCS tests to pass
    return !haskey(result["solution"], "shunt") ||all(isapprox(shunt["status"], 1.0, atol=atol) for (i,shunt) in result["solution"]["shunt"])
end

""
function load_status(result, nw_id, load_id)
    return result["solution"]["nw"][nw_id]["load"][load_id]["status"]
end

""
function load_status(result, load_id)
    return result["solution"]["load"][load_id]["status"]
end

""
function shunt_status(result, nw_id, shunt_id)
    return result["solution"]["nw"][nw_id]["shunt"][shunt_id]["status"]
end

""
function shunt_status(result, shunt_id)
    return result["solution"]["shunt"][shunt_id]["status"]
end

""
function active_power_served(result)
    return sum([load["pd"] for (i,load) in result["solution"]["load"]])
end

"""
An AC Power Flow Solver from scratch. 
"""
function compute_basic_ac_pf!(data::Dict{String, Any}; decoupled=false)
    if !get(data, "basic_network", false)
        Memento.warn(_LOGGER, "compute_basic_ac_pf requires basic network data and given data may be incompatible. make_basic_network can be used to transform data into the appropriate form.")
    end
    bus_num = length(data["bus"])
    gen_num = length(data["gen"])

    # Count the number of generators per bus
    gen_per_bus = Dict()
    for (i, gen) in data["gen"]
        bus_i = gen["gen_bus"]
        gen_per_bus[bus_i] = get(gen_per_bus, bus_i, 0) + 1
        # Update set point in PV buses
        if data["bus"]["$bus_i"]["bus_type"] == 2
            data["bus"]["$bus_i"]["vm"] = gen["vg"]
        end
    end

    Y = calc_basic_admittance_matrix(data)
    tol = 1e-4
    itr_max = 20
    itr = 0

    while itr < itr_max
        # STEP 1: Compute mismatch and check convergence
        V = calc_basic_bus_voltage(data)
        S = calc_basic_bus_injection(data)
        Si = V .* conj(Y * V)
        delta_P, delta_Q = real(S - Si), imag(S - Si)
        if LinearAlgebra.normInf([delta_P; delta_Q]) < tol
            break
        end
        # STEP 2 and 3: Compute the jacobian and update step
        if !decoupled
            J = calc_basic_jacobian_matrix(data)
            x = J \ [delta_P; delta_Q]
        else
            H, L = calc_basic_decoupled_jacobian_matrices(data)
            va = H \ delta_P
            vm = L \ delta_Q
            x = [va; vm]
        end
        # STEP 4
        # update voltage variables
        for i in 1:bus_num
            bus_type = data["bus"]["$(i)"]["bus_type"]
            if bus_type == 1
                data["bus"]["$(i)"]["va"] = data["bus"]["$(i)"]["va"] + x[i]
                data["bus"]["$(i)"]["vm"] = data["bus"]["$(i)"]["vm"] + x[i+bus_num] * data["bus"]["$(i)"]["vm"] 
            end
            if bus_type == 2
                data["bus"]["$(i)"]["va"] = data["bus"]["$(i)"]["va"] + x[i]
            end
        end
        # update power variables
        for i in 1:gen_num
            bus_i = data["gen"]["$i"]["gen_bus"]
            bus_type = data["bus"]["$bus_i"]["bus_type"]
            num_gens = gen_per_bus[bus_i]
            if bus_type == 2
                data["gen"]["$i"]["qg"] = data["gen"]["$i"]["qg"] - delta_Q[bus_i] / num_gens # TODO it is ok for multiples gens in same bus?
            else bus_type == 3
                data["gen"]["$i"]["qg"] = data["gen"]["$i"]["qg"] - delta_Q[bus_i] / num_gens
                data["gen"]["$i"]["pg"] = data["gen"]["$i"]["pg"] - delta_P[bus_i] / num_gens
            end
        end
        # update iteration counter
        itr += 1
    end
    if itr == itr_max
        Memento.warn(_LOGGER, "Max iteration limit")
        @assert false
    end
end
