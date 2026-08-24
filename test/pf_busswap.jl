using Test
using PowerModels
import JSON

#
# Functional test suite for bus-type-swapping AC power flow.
#
# For each of the 6 "hard" load samples in test_scripts/testbed.json (2 per
# case, across case14/case57/case300 -- see test_scripts/test_cases.jl for how
# they were selected), this runs every combination of:
#   - default AC PF (no PV/PQ switching, no bus-type swapping)
#   - AC PF with q-limit-driven PV->PQ switching, with and without OBO
#   - bus-type swapping (nearest_gen, sensitivity_score techniques), each
#     crossed with grainger on/off and OBO on/off
# for a total of 11 configurations x 6 samples = 66 runs, each capped at
# max_acpf = 20 swap iterations.
#
# Pass condition: no run raises an exception.
# Warning condition: 5 consecutive runs fail to converge.
# Report: per-run convergence/feasibility status and vm/qg violation magnitude.
#

include(joinpath(@__DIR__, "..", "run_scripts", "find_nearest_gens.jl"))
import XLSX
import DataFrames: DataFrame
import Printf: @printf, @sprintf

const BUSSWAP_TESTBED_FILE = joinpath(@__DIR__, "..", "test_scripts", "testbed.json")
const BUSSWAP_MAX_ITERATIONS = 20
const BUSSWAP_CONSECUTIVE_WARN = 5
const BUSSWAP_PROGRESS = Ref(get(ENV, "PM_BUSSWAP_PROGRESS", "false") in ("1", "true", "on", "yes"))

function _busswap_progress(msg...)
    if BUSSWAP_PROGRESS[]
        println("[bf_busswap] ", msg...)
    end
    return nothing
end

"""
Run the bus-swap functional test on a subset of case names and/or datapoints,
or on the full testbed by default. Pass a list like `["case14", "case57"]` as
`case_filter` and/or a list like `[14]` as `datapoint_filter` to restrict
execution; either may be left as `nothing` to skip that filter.
"""
function _busswap_test_cases(case_filter = nothing, datapoint_filter = nothing)
    testbed = JSON.parsefile(BUSSWAP_TESTBED_FILE)
    filtered = testbed
    if case_filter !== nothing
        filtered = filter(entry -> entry["case_name"] in case_filter, filtered)
    end
    if datapoint_filter !== nothing
        filtered = filter(entry -> any(dp -> isapprox(entry["datapoint"], dp), datapoint_filter), filtered)
    end
    if isempty(filtered)
        throw(ArgumentError("No testbed entries matched case_filter=$(case_filter), datapoint_filter=$(datapoint_filter)"))
    end
    return filtered
end

"""
Restrict `BUSSWAP_CONFIGS` to a subset of config names, or return all configs
by default. Pass a list like `["nearest_gen+no_grainger+no_obo"]` to restrict.
"""
function _busswap_filter_configs(config_filter = nothing)
    if config_filter === nothing
        return BUSSWAP_CONFIGS
    end
    filtered = filter(cfg -> cfg[1] in config_filter, BUSSWAP_CONFIGS)
    if isempty(filtered)
        throw(ArgumentError("No configs matched config_filter=$(config_filter)"))
    end
    return filtered
end

"parse a comma-separated ENV var into a Vector{String}, or `nothing` if unset/empty"
function _busswap_env_list(name)
    raw = get(ENV, name, "")
    isempty(raw) && return nothing
    return String.(strip.(split(raw, ",")))
end

"parse a comma-separated ENV var into a Vector{Float64}, or `nothing` if unset/empty"
function _busswap_env_num_list(name)
    strs = _busswap_env_list(name)
    strs === nothing && return nothing
    return parse.(Float64, strs)
end

struct BusSwapRun
    case_name::String
    datapoint::Float64
    config_name::String
    errored::Bool
    error_msg::String
    converged::Bool
    feasible::Bool
    vm_violation_magnitude::Float64
    qg_violation_magnitude::Float64
end

"prep a parsed case the same way run_scripts/generate_dataset.jl::prepare_test_case does: bump gen-bus vmax to vg, apply pg_line_limits.txt, and compute pv_pairs for the nearest_gen swap technique"
function _busswap_prepare_case(case_name)
    file_pth = joinpath(DATA_PATH, "test_cases", "network_info", case_name, "$(case_name).m")
    test_case = PowerModels.parse_file(file_pth)

    for gen in values(test_case["gen"])
        bus = test_case["bus"][string(gen["gen_bus"])]
        bus["vmax"] = max(gen["vg"], bus["vmax"])
    end

    line_lim_pth = joinpath(DATA_PATH, "test_cases", "network_info", case_name, "pg_line_limits.txt")
    if isfile(line_lim_pth)
        line_limits = split(read(line_lim_pth, String), ' ')[1:end-1]
        for (i, lim) in enumerate(line_limits)
            test_case["branch"][string(i)]["rate_a"] = parse(Int, lim)
        end
    end

    test_case["pv_pairs"] = find_nearest_generators_khop(file_pth)
    return test_case
end

"apply one testbed datapoint's perturbed load/gen row onto a (deep-copied) base case"
function _busswap_apply_load!(test_case, case_name, row_index)
    loads_dir = joinpath(TESTCASE_PATH, "data", case_name, "loads")
    files = filter(f -> endswith(f, ".xlsx"), readdir(loads_dir))
    @assert length(files) == 1 "expected exactly one loads xlsx in $loads_dir, found $(length(files))"
    load_data = DataFrame(XLSX.readtable(joinpath(loads_dir, files[1]), "loads"))
    row = load_data[row_index, :]
    for (load_ind, load) in pairs(test_case["load"])
        load["pd"] = row["pd_$load_ind"]
        load["qd"] = row["qd_$load_ind"]
    end
    for (gen_ind, gen) in pairs(test_case["gen"])
        gen["pg"] = row["pg_$gen_ind"]
    end
    return test_case
end

"summed magnitude of vm and qg bound violations in a solved `solution` dict"
function _busswap_violation_magnitudes(test_case, soln)
    vm_mag = 0.0
    for (bus_ind, bus_soln) in soln["bus"]
        bus_data = test_case["bus"][bus_ind]
        if bus_soln["vm"] < bus_data["vmin"] - 1e-6
            vm_mag += bus_data["vmin"] - bus_soln["vm"]
        elseif bus_soln["vm"] > bus_data["vmax"] + 1e-6
            vm_mag += bus_soln["vm"] - bus_data["vmax"]
        end
    end
    qg_mag = 0.0
    for (gen_ind, gen_soln) in soln["gen"]
        gen_data = test_case["gen"][gen_ind]
        if gen_soln["qg"] < gen_data["qmin"] - 1e-6
            qg_mag += gen_data["qmin"] - gen_soln["qg"]
        elseif gen_soln["qg"] > gen_data["qmax"] + 1e-6
            qg_mag += gen_soln["qg"] - gen_data["qmax"]
        end
    end
    return vm_mag, qg_mag
end

# (config name, entry-point kind, kwargs). :single -> compute_ac_pf (no bus-type
# swapping, just the built-in PV<->PQ q-limit switching). :swap ->
# compute_ac_pf_mult_buses (full bus-type-swapping loop).
const BUSSWAP_CONFIGS = [
    ("default",                              :single, (enforce_q_lims = false,)),
    ("qlim+obo",                             :single, (enforce_q_lims = true, obo = true)),
    ("qlim+no_obo",                          :single, (enforce_q_lims = true, obo = false)),
    ("nearest_gen+grainger+obo",             :swap,   (swap_technique = "nearest_gen", grainger = true, obo = true)),
    ("nearest_gen+grainger+no_obo",          :swap,   (swap_technique = "nearest_gen", grainger = true, obo = false)),
    ("nearest_gen+no_grainger+obo",          :swap,   (swap_technique = "nearest_gen", grainger = false, obo = true)),
    ("nearest_gen+no_grainger+no_obo",       :swap,   (swap_technique = "nearest_gen", grainger = false, obo = false)),
    ("sensitivity_score+grainger+obo",       :swap,   (swap_technique = "sensitivity_score", grainger = true, obo = true)),
    ("sensitivity_score+grainger+no_obo",    :swap,   (swap_technique = "sensitivity_score", grainger = true, obo = false)),
    ("sensitivity_score+no_grainger+obo",    :swap,   (swap_technique = "sensitivity_score", grainger = false, obo = true)),
    ("sensitivity_score+no_grainger+no_obo", :swap,   (swap_technique = "sensitivity_score", grainger = false, obo = false)),
]

"run one (case, config) combination; never throws -- errors are captured into the returned BusSwapRun"
function _busswap_run_one(base_case, case_name, datapoint, config_name, kind, config_kwargs)
    try
        tc = deepcopy(base_case)
        result = if kind == :single
            PowerModels.compute_ac_pf(tc; mapping = true, max_acpf = BUSSWAP_MAX_ITERATIONS, config_kwargs...)
        else
            PowerModels.compute_ac_pf_mult_buses(tc; mapping = true, max_acpf = BUSSWAP_MAX_ITERATIONS, config_kwargs...)
        end

        converged = result["termination_status"] == true
        if !converged
            return BusSwapRun(case_name, datapoint, config_name, false, "", false, false, NaN, NaN)
        end

        vm_mag, qg_mag = _busswap_violation_magnitudes(tc, result["solution"])
        feasible = vm_mag < 1e-4 && qg_mag < 1e-4
        return BusSwapRun(case_name, datapoint, config_name, false, "", true, feasible, vm_mag, qg_mag)
    catch e
        return BusSwapRun(case_name, datapoint, config_name, true, sprint(showerror, e), false, false, NaN, NaN)
    end
end

function _busswap_print_report(runs)
    errored = filter(r -> r.errored, runs)
    diverged = filter(r -> !r.errored && !r.converged, runs)
    infeasible = filter(r -> !r.errored && r.converged && !r.feasible, runs)
    feasible = filter(r -> !r.errored && r.converged && r.feasible, runs)

    println()
    println("="^108)
    println("BUS-SWAP AC-PF FUNCTIONAL TEST REPORT  ($(length(runs)) runs, max_acpf=$BUSSWAP_MAX_ITERATIONS)")
    println("="^108)

    println()
    println("SUMMARY")
    println("-"^108)
    println("  errored (crashed):         $(length(errored))")
    println("  failed to converge:        $(length(diverged))")
    println("  converged but infeasible:  $(length(infeasible))")
    println("  converged and feasible:    $(length(feasible))")

    if !isempty(errored)
        println()
        println("ERRORS")
        println("-"^108)
        for r in errored
            println("  $(r.case_name) dp=$(r.datapoint) | $(r.config_name)")
            println("    $(r.error_msg)")
        end
    end

    println()
    println("PER-RUN DETAIL")
    println("-"^108)
    @printf("%-10s %-8s %-40s %-10s %-11s %-14s %-14s\n",
            "case", "dp", "config", "converged", "feasible", "vm viol mag", "qg viol mag")
    println("-"^108)
    for r in runs
        status = r.errored ? "ERROR" : (r.converged ? "yes" : "no")
        feas = r.errored ? "-" : (r.converged ? (r.feasible ? "yes" : "no") : "-")
        vm_str = (r.errored || !r.converged) ? "-" : @sprintf("%.6f", r.vm_violation_magnitude)
        qg_str = (r.errored || !r.converged) ? "-" : @sprintf("%.6f", r.qg_violation_magnitude)
        @printf("%-10s %-8.0f %-40s %-10s %-11s %-14s %-14s\n",
                r.case_name, r.datapoint, r.config_name, status, feas, vm_str, qg_str)
    end
    println("="^108)
    println()
end

@testset "pf_busswap: bus-type-swapping AC power flow" begin
    PowerModels.logger_config!("warn")

    # Optional filters, set as comma-separated ENV vars (all default to
    # unfiltered, i.e. the full 66-run sweep):
    #   PM_BUSSWAP_CASES="case300"
    #   PM_BUSSWAP_DATAPOINTS="14"
    #   PM_BUSSWAP_CONFIGS="nearest_gen+no_grainger+no_obo"
    case_filter = _busswap_env_list("PM_BUSSWAP_CASES")
    datapoint_filter = _busswap_env_num_list("PM_BUSSWAP_DATAPOINTS")
    config_filter = _busswap_env_list("PM_BUSSWAP_CONFIGS")

    testbed = _busswap_test_cases(case_filter, datapoint_filter)
    configs = _busswap_filter_configs(config_filter)
    total_runs = length(testbed) * length(configs)
    completed_runs = 0
    case_cache = Dict{String, Any}()
    runs = BusSwapRun[]
    consecutive_nonconvergence = 0

    _busswap_progress("starting bus-swap test: $(length(testbed)) cases x $(length(configs)) configs = $(total_runs) total runs")

    for entry in testbed
        case_name = entry["case_name"]
        datapoint = entry["datapoint"]
        row_index = entry["row_index"]

        base_case = get!(() -> _busswap_prepare_case(case_name), case_cache, case_name)
        base_case = deepcopy(base_case)
        _busswap_apply_load!(base_case, case_name, row_index)

        _busswap_progress("case $(case_name) datapoint $(datapoint): preparing case and starting configs")

        for (config_name, kind, config_kwargs) in configs
            completed_runs += 1
            _busswap_progress("run $(completed_runs)/$(total_runs): $(case_name) dp=$(datapoint) | $(config_name)")

            run = _busswap_run_one(base_case, case_name, datapoint, config_name, kind, config_kwargs)
            push!(runs, run)

            if run.errored
                consecutive_nonconvergence = 0
            elseif !run.converged
                consecutive_nonconvergence += 1
                if consecutive_nonconvergence == BUSSWAP_CONSECUTIVE_WARN
                    @warn "$BUSSWAP_CONSECUTIVE_WARN consecutive runs failed to converge (most recent: $(run.case_name) dp=$(run.datapoint) | $(run.config_name))"
                end
            else
                consecutive_nonconvergence = 0
            end
        end
    end

    _busswap_progress("completed $(completed_runs)/$(total_runs) bus-swap runs")
    _busswap_print_report(runs)

    errored_count = count(r -> r.errored, runs)
    @test errored_count == 0
end

# Convenience wrapper for targeted runs: pass e.g. ["case14", "case57"] as
# case_filter, [14] as datapoint_filter, and/or ["nearest_gen+no_grainger+no_obo"]
# as config_filter to restrict execution. Any argument left as `nothing`
# (the default) is unfiltered, so calling with no arguments runs everything.
function run_pf_busswap(case_filter = nothing, config_filter = nothing; datapoint_filter = nothing)
    global BUSSWAP_PROGRESS
    testbed = _busswap_test_cases(case_filter, datapoint_filter)
    configs = _busswap_filter_configs(config_filter)

    total_runs = length(testbed) * length(configs)
    completed_runs = 0
    case_cache = Dict{String, Any}()
    runs = BusSwapRun[]
    consecutive_nonconvergence = 0

    _busswap_progress("starting bus-swap test: $(length(testbed)) cases x $(length(configs)) configs = $(total_runs) total runs")

    for entry in testbed
        case_name = entry["case_name"]
        datapoint = entry["datapoint"]
        row_index = entry["row_index"]

        base_case = get!(() -> _busswap_prepare_case(case_name), case_cache, case_name)
        base_case = deepcopy(base_case)
        _busswap_apply_load!(base_case, case_name, row_index)

        _busswap_progress("case $(case_name) datapoint $(datapoint): preparing case and starting configs")

        for (config_name, kind, config_kwargs) in configs
            completed_runs += 1
            _busswap_progress("run $(completed_runs)/$(total_runs): $(case_name) dp=$(datapoint) | $(config_name)")

            run = _busswap_run_one(base_case, case_name, datapoint, config_name, kind, config_kwargs)
            push!(runs, run)

            if run.errored
                consecutive_nonconvergence = 0
            elseif !run.converged
                consecutive_nonconvergence += 1
                if consecutive_nonconvergence == BUSSWAP_CONSECUTIVE_WARN
                    @warn "$BUSSWAP_CONSECUTIVE_WARN consecutive runs failed to converge (most recent: $(run.case_name) dp=$(run.datapoint) | $(run.config_name))"
                end
            else
                consecutive_nonconvergence = 0
            end
        end
    end

    _busswap_progress("completed $(completed_runs)/$(total_runs) bus-swap runs")
    _busswap_print_report(runs)

    errored_count = count(r -> r.errored, runs)
    @test errored_count == 0
    return runs
end
