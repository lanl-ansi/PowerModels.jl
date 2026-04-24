
function update_bt2!(i, pf_data, pf_result, mapping_dict, bus_assn, gen_assn, is_feas, num_violations, violation_mag, q_violations)
    bid = pf_data.am.idx_to_bus[i]
    bus = bus_assn["$(bid)"]
    mapping = mapping_dict[i]
    # store the solved qg value 
    update_qg!(pf_data, pf_result, bid, gen_assn, mapping)
    # store the solved voltage angle 
    bus["va"] = pf_result.zero[mapping["va"]]
    # check if generators have exceeded reactive power bounds
    bus_feas = true 
    bus_feas = check_qg_bounds!(pf_data, bid, gen_assn, violation_mag, q_violations)
    
    if ~bus_feas 
        is_feas[] = bus_feas
        num_violations[] += 1
    end
end

function update_bt1!(i, pf_data, pf_result, mapping_dict, bus_assn, is_feas, num_violations, violation_mag; b_violations = [])
    bid = pf_data.am.idx_to_bus[i]
    bus = bus_assn["$(bid)"]
    mapping = mapping_dict[i]
    # store the solved voltage angle and voltage magnitude 
    bus["va"] = pf_result.zero[mapping["va"]]
    bus["vm"] = pf_result.zero[mapping["vm"]]

    # check if voltage exceeded bounds 
    bus_feas = check_vm_bounds!(pf_data, i, bus, violation_mag;  b_violations = b_violations)
    if ~bus_feas 
        is_feas[] = bus_feas
        num_violations[] += 1 
    end

end

function update_bt3!(i, pf_data, pf_result, mapping_dict, bus_assn, gen_assn)
    bid = pf_data.am.idx_to_bus[i]
    bus = bus_assn["$(bid)"]
    mapping = mapping_dict[i]
    # store the solved qg value 
    update_qg!(pf_data, pf_result, bid, gen_assn, mapping)
    # store the solved pg value 
    update_pg!(pf_data, pf_result, bid, gen_assn, mapping)
end

function update_bt5!(i, pf_data, pf_result, mapping_dict, bus_assn)
    bid = pf_data.am.idx_to_bus[i]
    bus = bus_assn["$(bid)"]
    mapping = mapping_dict[i]
    bus["va"] = pf_result.zero[mapping["va"]]
end

function update_bt6!(i, pf_data, pf_result, mapping_dict, bus_assn, gen_assn, is_feas, num_violations, violation_mag, vm_violations, q_violations)
    bid = pf_data.am.idx_to_bus[i]
    bus = bus_assn["$(bid)"]
    mapping = mapping_dict[i]
    # store the solved qg value 
    update_qg!(pf_data, pf_result, bid, gen_assn, mapping)
    # store the solved voltage angle and voltage magnitude 
    if verbose 
        @_debug( "updating vm on bus $i to $(pf_result.zero[mapping["vm"]])")
    end 

    bus["va"] = pf_result.zero[mapping["va"]]
    bus["vm"] = pf_result.zero[mapping["vm"]]
    # check if generators have exceeded reactive power bounds 
    bus_feas = check_qg_bounds!(pf_data, bid, gen_assn, violation_mag, q_violations)
    if ~bus_feas 
        is_feas[] = bus_feas
        num_violations[] += 1
    end
    # check if bus has exceeded voltage bounds (but only store vm bounds if haven't stored qg bounds)
    viols = bus_feas ? vm_violations : nothing
    bus_feas = check_vm_bounds!(pf_data, i, bus, violation_mag; b_violations = viols)
    if ~bus_feas 
        is_feas[] = bus_feas
        num_violations[] += 1
    end
end

function check_qg_bounds!(pf_data, bid, gen_assn, violation_mag, q_violations)
    b_ind = pf_data.am.bus_to_idx[bid]
    bus_feas = true
    for (i, gen) in enumerate(pf_data.bus_gens[bid])
        qg = gen_assn["$(gen["index"])"]["qg"]
        if qg < gen["qmin"] 
            violation_mag[] += gen["qmin"] - qg
            bus_feas = false
            push!(q_violations, [bid, i, qg, gen["qmin"] - qg, gen["qmin"]])
        elseif qg > gen["qmax"]
            violation_mag[] += qg - gen["qmax"]
            bus_feas = false
            push!(q_violations, [bid, i, qg, qg - gen["qmax"], gen["qmax"]])
        end
    end
    return bus_feas
end

function check_vm_bounds!(pf_data, i, bus, violation_mag;  b_violations = nothing)
    bus_feas = true
    if bus["vm"] < bus["vmin"]
        violation_mag[] += bus["vmin"] - bus["vm"]
        bus_feas = false
        if ~isnothing(b_violations)
            push!(b_violations, (i, bus["vmin"] - bus["vm"], bus["vmin"]))
        end
    elseif bus["vm"] > bus["vmax"]
        violation_mag[] += bus["vm"] - bus["vmax"]
        bus_feas = false
        if ~isnothing(b_violations)
            push!(b_violations, (i, bus["vmax"] - bus["vm"], bus["vmax"]))
        end
    end
    return bus_feas
end

function update_bus_type!(pf_data, i, new_type)
    # update index
    old_type = pf_data.bus_type_idx[i]
    pf_data.bus_type_idx[i] = new_type
    # if old type was PV, remove from stored list of PV buses 
    if old_type == 2
        filter!(e -> e != i, pf_data.data["pv_bus_inds"])
    end
    # if new type is PV, add to stored list of PV buses 
    if new_type == 2 
        push!(pf_data.data["pv_bus_inds"], i)
    end
    if verbose 
         @_debug( "new bus type! bus $i was $old_type now $new_type")
    end
end

function find_pv_bus(pf_data, pqv_bus)
    # see if pv bus is available nearby
    nearby_pvs = pf_data.data["pv_pairs"][pf_data.am.idx_to_bus[pqv_bus]]
    pv_bus = findfirst(x -> pf_data.am.bus_to_idx[x] in pf_data.data["pv_bus_inds"], nearby_pvs)
    # if a pv bus is found, remove from this bus's list (so it never swaps again)
    if isnothing(pv_bus)
        return pv_bus
    end 
    pv_bus = nearby_pvs[pv_bus]
    filter!(x -> x != pv_bus, pf_data.data["pv_pairs"][pf_data.am.idx_to_bus[pqv_bus]])
    return pf_data.am.bus_to_idx[pv_bus]
end

function swap_pqv_buses_grainger!(pf_data, b_violations, violated_gens, p_pqv_pairs, bus_assignment, swap)
    for (b_viol, gen) in zip(b_violations, violated_gens)
        bus, viol, adjust = b_viol
        # swap bus types 
        update_bus_type!(pf_data, bus, 5)
        update_bus_type!(pf_data, gen, 6)
        append!(pf_data.data["prev_swaps"][bus], gen)
        swap[] = true 
        # update vm on pq bus 
        pf_data.vm_idx[bus] = adjust
        bus_assignment[string(pf_data.am.idx_to_bus[bus])]["vm"] = adjust
        # store pair 
        p_pqv_pairs[gen] = bus
    end
    return swap 
end 

function swap_pqv_buses!(pf_data, obo, b_violations, p_pqv_pairs, bus_assignment, swap)
    # find bus to swap with 
    for (pq_bus, viol, adjust) in b_violations
        pv_bus = find_pv_bus(pf_data, pq_bus)
        if isnothing(pv_bus) 
            continue 
        end 
        # swap the bus types 
        update_bus_type!(pf_data, pq_bus, 5)
        update_bus_type!(pf_data, pv_bus, 6)
        # update vm on pq bus 
        pf_data.vm_idx[pq_bus] = adjust
        bus_assignment[string(pf_data.am.idx_to_bus[pq_bus])]["vm"] = adjust
        swap[] = true
        # update list of available pvs and store pair 
        filter!(e -> e != pv_bus, pf_data.data["pv_bus_inds"])
        p_pqv_pairs[pv_bus] = pq_bus
        if obo 
            break 
        end
    end
    return swap
end

function update_qg!(pf_data, pf_result, bid, gen_assn, mapping)
    for gen in pf_data.bus_gens[bid]
        sol_gen = gen_assn["$(gen["index"])"]
        sol_gen["qg"] = 0.0
    end
    qg_remaining = -pf_result.zero[mapping["q"]]
    _assign_qg!(gen_assn, pf_data.bus_gens[bid], qg_remaining)
end

function update_pg!(pf_data, pf_result, bid, gen_assn, mapping)
    for gen in pf_data.bus_gens[bid]
        sol_gen = gen_assn["$(gen["index"])"]
        sol_gen["pg"] = 0.0
    end
    pg_remaining = -pf_result.zero[mapping["p"]]
    _assign_pg!(gen_assn, pf_data.bus_gens[bid], pg_remaining)
end

function update_pilot_buses!(pf_data, b_violations, bus_assignment, swap)
    bus_viol = Float64[0.0 for i in 1:length(pf_data.data["bus"])]
    for viol in b_violations
        bus_viol[viol[1]] = viol[2]
    end
    clusters = pf_data.data["clusters"]
    am = pf_data.am
    pilot_bus_violations = []
    for (pilot_bus, buses) in pairs(clusters)
        buses = Int.(buses)
        pilot_bus = parse(Int64, pilot_bus)
        if pilot_bus == -1 
            continue 
        end
        pb_ind = am.bus_to_idx[pilot_bus]

        # get average violation from violated buses in this zone
        nonzero_viol = [bus_viol[am.bus_to_idx[i]] for i in buses if bus_viol[am.bus_to_idx[i]] != 0]
        denom = length(nonzero_viol) > 0 ? length(nonzero_viol) : 1
        zone_viol = sum(nonzero_viol)/denom
        if abs(zone_viol) <= 1e-4
            continue 
        end
        # find adjusted pilot bus voltage 
        pb_assn = bus_assignment[string(pilot_bus)]
        vm, vmin, vmax = pb_assn["vm"], pb_assn["vmin"], pb_assn["vmax"]
        update_vm = min(max(vmin, vm + zone_viol), vmax)
        # either adjust here (if type 5) or store for bus swap 
        if pf_data.bus_type_idx[pb_ind] == 5
            pf_data.vm_idx[pb_ind] = update_vm
            bus_assignment[string(pilot_bus)]["vm"] = update_vm
            if abs(update_vm - vm) > 0 
                if verbose 
                    @_debug( "update vm on pilot bus $pilot_bus: was $vm, now = $update_vm")
                end
                swap = true
            end
        else 
            push!(pilot_bus_violations, (pb_ind, vm - update_vm, update_vm))
        end
    end
    return pilot_bus_violations
end

function update_vm_violations!(pf_data, vm_violations, p_pqv_pairs, obo, swap)
    for viol in vm_violations 
        i, mag_viol, new_setpoint = viol
        # update the voltage 
        pf_data.vm_idx[i] = new_setpoint
        # find pqv bus 
        pqv = -1
        try
            pqv = pop!(p_pqv_pairs, i)
        catch e 
            @infiltrate debug 
            rethrow(e)
        end
        # swap bus type 
        update_bus_type!(pf_data, pqv, 1)
        update_bus_type!(pf_data, i, 2)
        swap[] = true
        if obo 
            break 
        end
    end
end

function update_q_violations!(pf_data, q_violations, p_pqv_pairs, obo, swap)
    for viol in q_violations 
        bid, gen_ind, qg, mag_viol, new_setpoint = viol
        b_ind = pf_data.am.bus_to_idx[bid]
        # update setpoint
        gen = values(pf_data.bus_gens[bid])[Int(gen_ind)]
        gen["qg"] = new_setpoint
        pf_data.q_inject_idx[b_ind] += qg
        pf_data.q_inject_idx[b_ind] -= new_setpoint
        # update bus type 
        if pf_data.bus_type_idx[b_ind] == 6 
            pqv = pop!(p_pqv_pairs, b_ind)
            update_bus_type!(pf_data, pqv, 1)
        end 
        update_bus_type!(pf_data, b_ind, 1)
        swap[] = true
        if obo 
            break 
        end
    end
end