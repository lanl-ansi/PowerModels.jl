### Solvers where line flow limit cuts are added iteratively ###

"""
Solves the OPF problem by iteratively adding line flow constraints based on 
constraint violations

# Keyword Arguments
* `model_type`: the power flow formulaiton.
* `max_iter`: maximum number of flow iterations to perform.
* `time_limit`: maximum amount of time (sec) for the algorithm.
"""
function run_opf_flow_cuts(file::String, model_type::Type, optimizer; kwargs...)
    data = PowerModels.parse_file(file)
    return run_opf_flow_cuts!(data, model_type, optimizer; kwargs...)
end

function run_opf_flow_cuts!(data::Dict{String,<:Any}, model_type::Type, optimizer; solution_processors=[], max_iter::Int=100, time_limit::Float64=3600.0)
    Memento.info(_LOGGER, "maximum cut iterations set to value of $max_iter")

    for (i,branch) in data["branch"]
        if haskey(branch, "rate_a")
            branch["rate_a_inactive"] = branch["rate_a"]
            delete!(branch, "rate_a")
        end
    end

    start_time = time()

    #result = run_opf(data, model_type, optimizer)
    pm = instantiate_model(data, model_type, build_opf)
    result = optimize_model!(pm, optimizer=optimizer, solution_processors=solution_processors)

    #print_summary(result["solution"])

    iteration = 1
    violated = true
    while violated && iteration < max_iter && (time() - start_time) < time_limit
        violated = false
        for (i,branch) in data["branch"]
            if haskey(branch, "rate_a_inactive")
                rate_a = branch["rate_a_inactive"]
                branch_sol = result["solution"]["branch"][i]

                mva_fr = abs(branch_sol["pf"])
                mva_to = abs(branch_sol["pt"])

                if !isnan(branch_sol["qf"]) && !isnan(branch_sol["qt"])
                    mva_fr = sqrt(branch_sol["pf"]^2 + branch_sol["qf"]^2)
                    mva_to = sqrt(branch_sol["pt"]^2 + branch_sol["qt"]^2)
                end

                #println(branch["index"], rate_a, mva_fr, mva_to)

                if mva_fr > rate_a || mva_to > rate_a
                    Memento.info(_LOGGER, "activate rate_a on branch $(branch["index"])")

                    branch["rate_a"] = branch["rate_a_inactive"]
                    delete!(branch, "rate_a_inactive")

                    idx = branch["index"]
                    constraint_thermal_limit_from(pm, idx)
                    constraint_thermal_limit_to(pm, idx)

                    violated = true
                end
            end
        end

        if violated
            iteration += 1
            #result = run_opf(data, model_type, optimizer)
            result = optimize_model!(pm, solution_processors=solution_processors)

            #print_summary(result["solution"])
        else
            Memento.info(_LOGGER, "flow cuts converged in $iteration iterations")
        end
    end

    result["solve_time"] = time() - start_time
    result["iterations"] = iteration

    return result
end


"""
Solves the PTDF variant of the OPF problem by iteratively adding line flow
constraints based on constraint violations.

Currently the DCPPowerModel is used in this solver as that is the only model
supporting the PTDF problem specification at this time.

# Keyword Arguments
* `max_iter`: maximum number of flow iterations to perform.
* `time_limit`: maximum amount of time (sec) for the algorithm.
* `full_inverse`: compute the complete admittance matrix inverse, instead of a
branch by branch computation.
"""
function run_opf_ptdf_flow_cuts(file::String, optimizer; kwargs...)
    data = PowerModels.parse_file(file)
    return run_opf_ptdf_flow_cuts!(data, optimizer; kwargs...)
end

function run_opf_ptdf_flow_cuts!(data::Dict{String,<:Any}, optimizer; max_iter::Int=100, time_limit::Float64=3600.0, full_inverse=false)
    Memento.info(_LOGGER, "maximum cut iterations set to value of $max_iter")

    for (i,branch) in data["branch"]
        if haskey(branch, "rate_a")
            branch["rate_a_inactive"] = branch["rate_a"]
            delete!(branch, "rate_a")
        end
    end

    ref_extensions = Any[ref_add_connected_components!]

    if full_inverse
        push!(ref_extensions, ref_add_sm_inv!)
    else
        push!(ref_extensions, ref_add_sm!)
    end

    start_time = time()


    #result = run_ptdf_opf(data, DCPPowerModel, optimizer, full_inverse=full_inverse)
    pm = instantiate_model(data, DCPPowerModel, build_opf_ptdf; ref_extensions=ref_extensions)
    result = optimize_model!(pm, optimizer=optimizer)
    update_data!(data, result["solution"])

    solution = compute_dc_pf(data)
    update_data!(data, solution)

    flow = calc_branch_flow_dc(data)
    update_data!(data, flow)

    iteration = 1
    violated = true
    while violated && iteration < max_iter && (time() - start_time) < time_limit
        violated = false
        for (i,branch) in data["branch"]
            if haskey(branch, "rate_a_inactive")
                rate_a = branch["rate_a_inactive"]

                mva_fr = abs(branch["pf"])
                mva_to = abs(branch["pt"])

                if !isnan(branch["qf"]) && !isnan(branch["qt"])
                    mva_fr = sqrt(branch["pf"]^2 + branch["qf"]^2)
                    mva_to = sqrt(branch["pt"]^2 + branch["qt"]^2)
                end

                if mva_fr > rate_a || mva_to > rate_a
                    Memento.info(_LOGGER, "activate rate_a on branch $(branch["index"])")

                    # update data model
                    branch["rate_a"] = branch["rate_a_inactive"]
                    delete!(branch, "rate_a_inactive")

                    idx = branch["index"]
                    expression_branch_flow_yt_from_ptdf(pm, idx)
                    expression_branch_flow_yt_to_ptdf(pm, idx)
                    constraint_thermal_limit_from(pm, idx)
                    constraint_thermal_limit_to(pm, idx)

                    violated = true
                end
            end
        end

        if violated
            iteration += 1

            #result = run_ptdf_opf(data, DCPPowerModel, optimizer, full_inverse=full_inverse)
            result = optimize_model!(pm)

            update_data!(data, result["solution"])

            solution = compute_dc_pf(data)
            update_data!(data, solution)

            flow = calc_branch_flow_dc(data)
            update_data!(data, flow)

            #print_summary(result["solution"])
        else
            Memento.info(_LOGGER, "flow cuts converged in $iteration iterations")
        end
    end

    result["solve_time"] = time() - start_time
    result["iterations"] = iteration

    return result
end

