debug = false
""
function solve_ac_opf(file, optimizer; kwargs...)
    return solve_opf(file, ACPPowerModel, optimizer; kwargs...)
end

function solve_dc_opf(file, optimizer; kwargs...)
    return solve_opf(file, DCPPowerModel, optimizer; kwargs...)
end

function solve_opf(file, model_type::Type, optimizer; kwargs...)
    return solve_model(file, model_type, optimizer, build_opf; kwargs...)
end

function solve_relaxed_opf(file, optimizer; kwargs...)
    return solve_model(file, ACPPowerModel, optimizer, build_relaxed_opf; kwargs...)
end

function solve_dc_ac_pf(file, optimizer; kwargs...)
    return solve_model(file, ACPPowerModel, optimizer, build_dc_ac_pf; kwargs...)
end

"""
    build_opf(pm::AbstractPowerModel)
"""
function build_opf(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline_power_losses(pm, i)
    end
end

"""
    build opf for distance maximization, all else equal 
"""
function build_ac_setpoint_max(pm::AbstractPowerModel)

end

"""
    build_dc_ac_pf for setpoint minimization
"""
function build_dc_ac_pf(pm::AbstractPowerModel)
    vm, va = variable_bus_voltage(pm)
    pgs, pg_sps, qgs = variable_gen_power(pm)
    variable_branch_power(pm)
    #variable_dcline_power(pm)

    vm_sps = []
    vm_gens = []
    va_sps = []
    
    for i in ids(pm, :gen)
        push!(vm_sps, pm.data["gen"][string(i)]["vg"])
        push!(vm_gens, var(pm, nw_id_default, :vm, pm.data["gen"][string(i)]["gen_bus"]))
    end
    @infiltrate debug
    constraint_model_voltage(pm)
    constraint_generator_setpoint(pm, pgs, pg_sps)
    constraint_vm_setpoint(pm, vm_gens, vm_sps)
    # objective_min_vm_qg_va(pm, vm_gens, vm_sps, va, va_sps, qgs, qg_sps)
    # objective_min_setpoint_dist(pm, pgs, pg_sps)
    


    # constraint_vm_setpoint(pm, vm_gens, vm_sps)
    # for (pg, sp) in zip(pgs, pg_sps)
    #     constraint_generator_setpoint(pm, pg, sp)
    # end    

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        #constraint_voltage_angle_difference(pm, i)

        # constraint_thermal_limit_from(pm, i)
        # constraint_thermal_limit_to(pm, i)
    end

    # for i in ids(pm, :dcline)
    #     constraint_dcline_power_losses(pm, i)
    # end
    objective_min_vm_dist(pm, vm_gens, vm_sps)
end

"""
    build_ac_opf with relaxed constraints
"""
function build_relaxed_opf(pm::AbstractPowerModel)
    variable_bus_voltage(pm)
    pgs, pg_sps, qgs = variable_gen_power(pm)
    variable_branch_power(pm)
    variable_dcline_power(pm)

    constraint_dict = Dict()
    vm_dict = constraint_model_voltage(pm)
    constraint_dict =  isnothing(vm_dict) ? constraint_dict : merge(constraint_dict, vm_dict)
    for i in ids(pm, :ref_buses)
        tref = constraint_theta_ref(pm, i)
        constraint_dict[JuMP.index(tref)] = "tref_$i"
    end

    for i in ids(pm, :bus)
        constr_p, constr_q = constraint_power_balance(pm, i)
        constraint_dict[JuMP.index(constr_p)] = "pbal_$i"
        constraint_dict[JuMP.index(constr_q)] = "qbal_$i"
    end

    for i in ids(pm, :branch)
        ytfp, ytfq = constraint_ohms_yt_from(pm, i)
        constraint_dict[JuMP.index(ytfp)] = "ytfp_$i"
        constraint_dict[JuMP.index(ytfq)] = "ytfq_$i"
        yttp, yttq = constraint_ohms_yt_to(pm, i)
        constraint_dict[JuMP.index(yttp)] = "yttp_$i"
        constraint_dict[JuMP.index(yttq)] = "yttq_$i"

        vadiff = constraint_voltage_angle_difference(pm, i)
        constraint_dict[JuMP.index(vadiff)] = "vadiff_$i"

        tlf = constraint_thermal_limit_from(pm, i)
        tlt = constraint_thermal_limit_to(pm, i)
        constraint_dict[JuMP.index(tlf)] = "tlf_$i"
        constraint_dict[JuMP.index(tlt)] = "tlt_$i"
    end

    for i in ids(pm, :dcline)
        dcline = constraint_dcline_power_losses(pm, i)
        constraint_dict[JuMP.index(dcline)] = "dcline_$i"
    end

    constraints = JuMP.all_constraints(pm.model; include_variable_in_set_constraints=true)
    relaxation_penalty = JuMP.MOI.Utilities.PenaltyRelaxation(Dict(JuMP.index(c) => 5.0 for c in constraints))
    backend = JuMP.backend(pm.model)
    penalty_dict = JuMP.MOI.modify(backend, relaxation_penalty)

    for (pg, sp) in zip(pgs, pg_sps)
        constraint_pbal_sp(pm, pg, sp)
    end
    pm.data["penalty_dict"] = penalty_dict
    pm.data["constraint_dict"] = constraint_dict
end

"a toy example of how to model with multi-networks"
function solve_mn_opf(file, model_type::Type, optimizer; kwargs...)
    return solve_model(file, model_type, optimizer, build_mn_opf; multinetwork=true, kwargs...)
end

"""
    build_mn_opf(pm::AbstractPowerModel)
"""
function build_mn_opf(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_bus_voltage(pm, nw=n)
        variable_gen_power(pm, nw=n)
        variable_branch_power(pm, nw=n)
        variable_dcline_power(pm, nw=n)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_power_balance(pm, i, nw=n)
        end

        for i in ids(pm, :branch, nw=n)
            constraint_ohms_yt_from(pm, i, nw=n)
            constraint_ohms_yt_to(pm, i, nw=n)

            constraint_voltage_angle_difference(pm, i, nw=n)

            constraint_thermal_limit_from(pm, i, nw=n)
            constraint_thermal_limit_to(pm, i, nw=n)
        end

        for i in ids(pm, :dcline, nw=n)
            constraint_dcline_power_losses(pm, i, nw=n)
        end
    end

    objective_min_fuel_and_flow_cost(pm)
end


"a toy example of how to model with multi-networks and storage"
function solve_mn_opf_strg(file, model_type::Type, optimizer; kwargs...)
    return solve_model(file, model_type, optimizer, build_mn_opf_strg; multinetwork=true, kwargs...)
end

"""
    build_mn_opf_strg(pm::AbstractPowerModel)
"""
function build_mn_opf_strg(pm::AbstractPowerModel)
    for (n, network) in nws(pm)
        variable_bus_voltage(pm, nw=n)
        variable_gen_power(pm, nw=n)
        variable_storage_power_mi(pm, nw=n)
        variable_branch_power(pm, nw=n)
        variable_dcline_power(pm, nw=n)

        constraint_model_voltage(pm, nw=n)

        for i in ids(pm, :ref_buses, nw=n)
            constraint_theta_ref(pm, i, nw=n)
        end

        for i in ids(pm, :bus, nw=n)
            constraint_power_balance(pm, i, nw=n)
        end

        for i in ids(pm, :storage, nw=n)
            constraint_storage_complementarity_mi(pm, i, nw=n)
            constraint_storage_losses(pm, i, nw=n)
            constraint_storage_thermal_limit(pm, i, nw=n)
        end

        for i in ids(pm, :branch, nw=n)
            constraint_ohms_yt_from(pm, i, nw=n)
            constraint_ohms_yt_to(pm, i, nw=n)

            constraint_voltage_angle_difference(pm, i, nw=n)

            constraint_thermal_limit_from(pm, i, nw=n)
            constraint_thermal_limit_to(pm, i, nw=n)
        end

        for i in ids(pm, :dcline, nw=n)
            constraint_dcline_power_losses(pm, i, nw=n)
        end
    end

    network_ids = sort(collect(nw_ids(pm)))

    n_1 = network_ids[1]
    for i in ids(pm, :storage, nw=n_1)
        constraint_storage_state(pm, i, nw=n_1)
    end

    for n_2 in network_ids[2:end]
        for i in ids(pm, :storage, nw=n_2)
            constraint_storage_state(pm, i, n_1, n_2)
        end
        n_1 = n_2
    end

    objective_min_fuel_and_flow_cost(pm)
end




"""
Solves an opf using ptdfs with no explicit voltage or line flow variables.

This formulation is most often used when a small subset of the line flow
constraints are active in the data model.
"""
function solve_opf_ptdf(file, model_type::Type, optimizer; full_inverse=false, kwargs...)
    if !full_inverse
        return solve_model(file, model_type, optimizer, build_opf_ptdf; ref_extensions=[ref_add_connected_components!,ref_add_sm!], kwargs...)
    else
        return solve_model(file, model_type, optimizer, build_opf_ptdf; ref_extensions=[ref_add_connected_components!,ref_add_sm_inv!], kwargs...)
    end
end

function build_opf_ptdf(pm::AbstractPowerModel)
    Memento.error(_LOGGER, "build_opf_ptdf is only valid for DCPPowerModels")
end

"""
    build_opf_ptdf(pm::DCPPowerModel)
"""
function build_opf_ptdf(pm::DCPPowerModel)
    variable_gen_power(pm)

    for i in ids(pm, :bus)
        expression_bus_power_injection(pm, i)
    end

    objective_min_fuel_cost(pm)

    constraint_model_voltage(pm)

    # this constraint is implicit in this model
    #for i in ids(pm, :ref_buses)
    #    constraint_theta_ref(pm, i)
    #end

    for i in ids(pm, :components)
        constraint_network_power_balance(pm, i)
    end

    for (i, branch) in ref(pm, :branch)
        # requires optional vad parameters
        #constraint_voltage_angle_difference(pm, i)

        # only create these expressions if a line flow is specified
        if haskey(branch, "rate_a")
            expression_branch_power_ohms_yt_from_ptdf(pm, i)
            expression_branch_power_ohms_yt_to_ptdf(pm, i)
        end

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end
end


function ref_add_sm!(ref::Dict{Symbol, <:Any}, data::Dict{String, <:Any})
    apply_pm!(_ref_add_sm!, ref, data)
end


function _ref_add_sm!(ref::Dict{Symbol, <:Any}, data::Dict{String, <:Any})
    reference_bus(data) # throws an error if an incorrect number of reference buses are defined
    ref[:sm] = calc_susceptance_matrix(data)
end


function ref_add_sm_inv!(ref::Dict{Symbol, <:Any}, data::Dict{String, <:Any})
    apply_pm!(_ref_add_sm_inv!, ref, data)
end


function _ref_add_sm_inv!(ref::Dict{Symbol, <:Any}, data::Dict{String, <:Any})
    ref[:sm] = calc_susceptance_matrix_inv(data)
end
