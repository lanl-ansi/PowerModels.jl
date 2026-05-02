#
# Benchmark script: sensitivity_score donor selection vs nearest_gen / qv_inv,
# plus the Sherman-Morrison warm-start speedup question.
#
# Methodology (apples-to-apples with the paper's Table I):
#   - For each case, load the pre-generated perturbed-load xlsx dataset from
#     `bus_swap_data/test_cases/data/<case>/loads/<delta>.xlsx` (these are the
#     samples that the paper's `generate_dataset.jl::generate_loads` produces:
#     each load is perturbed up to ~85% of max generation and filtered for
#     DC-OPF + AC-OPF feasibility, with DC-OPF generator dispatch baked in).
#   - Mirrors `prepare_test_case` from generate_dataset.jl: bumps each
#     generator's bus vmax up to max(gen vg, bus vmax) and applies the
#     `pg_line_limits.txt` overrides if present.
#   - Runs every strategy on the SAME sample, so per-sample W/T/L comparisons
#     are paired and noise-free.
#
# Auto-detection:
#   - Looks for `bus_swap_data/` at the project root (the user's repo layout).
#   - Falls back to `config.jl` -> DATA_PATH if that's how the user has set
#     things up (matches generate_dataset.jl).
#   - If neither is available, falls back to in-repo case14.m + random load
#     scaling (informative for case14 only; case57/300 are skipped).
#
# What it reports per strategy:
#   - feas%      feasibility rate (samples with no V or Q violations)
#   - #V         avg # voltage-bound violations
#   - |V|        avg total V violation magnitude  (paper's primary quality metric)
#   - #Q         avg # reactive-power-bound violations
#   - swp        avg bus-type-switching outer iters
#   - jac        avg total Newton-Raphson iters across all swap iters
#                (this is the metric the paper uses for the speed claim --
#                 SMW is supposed to save ~1 NR iter per swap)
#   - time(s)    avg wall-clock solve time
#
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PowerModels
using XLSX
using DataFrames
using Printf
using Random
using Statistics

Random.seed!(2026)

# ----- locate datasets -------------------------------------------------------

const REPO_ROOT     = abspath(joinpath(@__DIR__, ".."))
const REPO_MATPOWER = joinpath(REPO_ROOT, "test", "data", "matpower")
const BSD_ROOT      = joinpath(REPO_ROOT, "bus_swap_data")

const HAS_BSD    = isdir(BSD_ROOT)
const HAS_CONFIG = isfile(joinpath(REPO_ROOT, "config.jl"))
if HAS_CONFIG
    include(joinpath(REPO_ROOT, "config.jl"))
end

# Resolve `case_name` -> .m file path. Prefer bus_swap_data, then config.jl,
# then in-repo test data (case14 only).
function _case_path(case_name::String)
    if HAS_BSD
        p = joinpath(BSD_ROOT, "test_cases", "network_info", case_name, "$(case_name).m")
        isfile(p) && return p
    end
    if HAS_CONFIG
        try
            p = joinpath(DATA_PATH, "test_cases", "network_info", case_name, "$(case_name).m")
            isfile(p) && return p
        catch
        end
    end
    p = joinpath(REPO_MATPOWER, "$(case_name).m")
    isfile(p) && return p
    return nothing
end

# Resolve `case_name` -> path of pg_line_limits.txt (if present).
function _line_limits_path(case_name::String)
    if HAS_BSD
        p = joinpath(BSD_ROOT, "test_cases", "network_info", case_name, "pg_line_limits.txt")
        isfile(p) && return p
    end
    if HAS_CONFIG
        try
            p = joinpath(DATA_PATH, "test_cases", "network_info", case_name, "pg_line_limits.txt")
            isfile(p) && return p
        catch
        end
    end
    return nothing
end

# Resolve `case_name` -> the (single) loads xlsx in its loads/ dir, or nothing.
function _loads_xlsx_path(case_name::String)
    candidates = String[]
    if HAS_BSD
        push!(candidates, joinpath(BSD_ROOT, "test_cases", "data", case_name, "loads"))
    end
    if HAS_CONFIG
        try
            push!(candidates, joinpath(TESTCASE_PATH, "data", case_name, "loads"))
        catch
        end
    end
    for dir in candidates
        isdir(dir) || continue
        files = filter(f -> endswith(f, ".xlsx"), readdir(dir))
        isempty(files) && continue
        return joinpath(dir, files[1])
    end
    return nothing
end

const CASES = ["case14", "case57", "case300", "case118", "case240", "case1354_pegase"]

# ----- strategies under comparison ------------------------------------------

# (label, kind, kwargs). `kind` selects entry point:
#   :baseline -> compute_ac_pf with enforce_q_lims=false
#   :qlim     -> compute_ac_pf with enforce_q_lims=true
#   :switch   -> compute_ac_pf_mult_buses with `swap_technique` etc.
const STRATEGIES = [
    ("baseline",                   :baseline, NamedTuple()),
    ("qlim",                       :qlim,     NamedTuple()),
    ("nearest_gen",                :switch,   (swap_technique = "nearest_gen",)),
    ("qv_inv",                     :switch,   (swap_technique = "qv_inv",)),
    ("sensitivity_score",          :switch,   (swap_technique = "sensitivity_score",)),
    ("sensitivity_score+SMW",      :switch,   (swap_technique = "sensitivity_score", use_smw_warmstart = true)),
    ("sensitivity_score+collat",   :switch,   (swap_technique = "sensitivity_score", score_collateral_aware = true)),
]

# ----- test-case prep (mirrors generate_dataset.jl::prepare_test_case) ------

function _prepare_test_case!(test_case, case_name)
    # Bump each generator's bus vmax up to max(gen vg, bus vmax) so that the
    # voltage at gen buses isn't immediately at the upper bound.
    for gen in values(test_case["gen"])
        gen_bus = gen["gen_bus"]
        bus = test_case["bus"][string(gen_bus)]
        bus["vmax"] = max(get(gen, "vg", bus["vmax"]), bus["vmax"])
    end
    # Apply line-limits override file if present.
    line_lim_pth = _line_limits_path(case_name)
    if line_lim_pth !== nothing
        line_limits = split(read(line_lim_pth, String), ' ')
        for (i, lim) in enumerate(line_limits)
            isempty(strip(lim)) && continue
            haskey(test_case["branch"], string(i)) || continue
            test_case["branch"][string(i)]["rate_a"] = parse(Int, lim)
        end
    end
end

# ----- helpers --------------------------------------------------------------

function _all_pairs_pv_pairs(data)
    gen_bus_ids = unique([gen["gen_bus"] for gen in values(data["gen"])])
    load_bus_ids = [bus["bus_i"] for bus in values(data["bus"])]
    return Dict{Int, Vector{Int}}(b => copy(gen_bus_ids) for b in load_bus_ids)
end

# Apply one row of the perturbed-load dataset to `data` in place. Mirrors
# generate_dataset.jl::run_pf!: pd_<load>, qd_<load>, pg_<gen>.
function _apply_xlsx_row!(data, row)
    for (load_ind, load) in pairs(data["load"])
        col = "pd_$load_ind"; load["pd"] = row[col]
        col = "qd_$load_ind"; load["qd"] = row[col]
    end
    for (gen_ind, gen) in pairs(data["gen"])
        col = "pg_$gen_ind"; gen["pg"] = row[col]
    end
end

# Random-scaling sample (used only when no xlsx dataset is available).
function _scale_loads!(data, base_pd, base_qd, scale)
    for (k, l) in data["load"]
        l["pd"] = scale * base_pd[k]
        l["qd"] = scale * base_qd[k]
    end
end

# Count V/Q violations and total magnitudes in result["solution"]. Works for
# both compute_ac_pf and compute_ac_pf_mult_buses.
function _violations(data, result)
    nv_v = 0; nv_q = 0
    mag_v = 0.0; mag_q = 0.0
    soln = get(result, "solution", nothing)
    (isnothing(soln) || !haskey(soln, "bus")) && return (nv_v, nv_q, mag_v, mag_q, false)
    converged = !any(b -> b["vm"] == -1.0, values(soln["bus"]))
    !converged && return (nv_v, nv_q, mag_v, mag_q, false)
    for (s, b) in soln["bus"]
        bd = data["bus"][s]
        if b["vm"] < bd["vmin"] - 1e-6; nv_v += 1; mag_v += bd["vmin"] - b["vm"]; end
        if b["vm"] > bd["vmax"] + 1e-6; nv_v += 1; mag_v += b["vm"] - bd["vmax"]; end
    end
    for (s, g) in soln["gen"]
        gd = data["gen"][s]
        if g["qg"] < gd["qmin"] - 1e-6; nv_q += 1; mag_q += gd["qmin"] - g["qg"]; end
        if g["qg"] > gd["qmax"] + 1e-6; nv_q += 1; mag_q += g["qg"] - gd["qmax"]; end
    end
    return (nv_v, nv_q, mag_v, mag_q, true)
end

# Total NR iterations across all swap iters: count non-empty entries in
# jacobian_history (it interleaves sparse Jacobians with `[]` separators).
function _jac_iters(result)
    haskey(result, "jacobian_history") || return 0
    return count(j -> !(j isa AbstractVector && isempty(j)), result["jacobian_history"])
end

function _run_strategy(kind, kwargs, data)
    sample = deepcopy(data)
    t0 = time()
    result = if kind == :baseline
        PowerModels.compute_ac_pf(sample; mapping = true, enforce_q_lims = false)
    elseif kind == :qlim
        PowerModels.compute_ac_pf(sample; mapping = true, enforce_q_lims = true)
    else
        PowerModels.compute_ac_pf_mult_buses(sample; obo = true, kwargs...)
    end
    t = time() - t0
    nv_v, nv_q, mag_v, mag_q, converged = _violations(sample, result)
    swap_iters = if kind == :switch && haskey(result, "solution_history")
        length(result["solution_history"])
    else
        1
    end
    return (
        time = t,
        swap_iters = swap_iters,
        jac_iters = _jac_iters(result),
        nv_v = nv_v,
        nv_q = nv_q,
        mag_v = mag_v,
        mag_q = mag_q,
        converged = converged,
        feasible = converged && nv_v == 0 && nv_q == 0,
    )
end

# Run every strategy once on the baseline data to pre-compile JIT. Without
# this, timings on tiny cases are dominated by first-call compile overhead.
function _warmup_jit(base_data, pv_pairs)
    sample = deepcopy(base_data)
    sample["pv_pairs"] = deepcopy(pv_pairs)
    for (_, kind, kwargs) in STRATEGIES
        try
            _run_strategy(kind, kwargs, sample)
        catch
        end
    end
end

# ----- per-case driver ------------------------------------------------------

function run_case(case_name::String; max_samples::Int = 50)
    path = _case_path(case_name)
    if path === nothing
        println("[skip] $case_name: no .m found in bus_swap_data, config.jl, or test/data")
        return
    end
    base_data = PowerModels.parse_file(path)
    _prepare_test_case!(base_data, case_name)
    base_pd = Dict{String, Float64}(k => l["pd"] for (k, l) in base_data["load"])
    base_qd = Dict{String, Float64}(k => l["qd"] for (k, l) in base_data["load"])
    pv_pairs = _all_pairs_pv_pairs(base_data)

    # Try to load the pre-generated xlsx dataset (apples-to-apples); fall back
    # to random scaling if no xlsx is available.
    xlsx_path = _loads_xlsx_path(case_name)
    samples = NamedTuple[]
    src_label = ""
    if xlsx_path !== nothing
        df = DataFrame(XLSX.readtable(xlsx_path, "loads"))
        n = min(nrow(df), max_samples)
        for i in 1:n
            push!(samples, (kind = :xlsx, row = df[i, :]))
        end
        src_label = "$(basename(xlsx_path)) ($(n)/$(nrow(df)) samples)"
    else
        # case14 falls back to random scaling around the baseline load.
        rng = Random.MersenneTwister(hash(case_name))
        lo, hi = 0.95, 1.20
        for _ in 1:max_samples
            push!(samples, (kind = :scale, scale = lo + rand(rng) * (hi - lo)))
        end
        src_label = "random scaling [$lo, $hi] ($(max_samples) samples)"
    end

    println("=== $case_name  --  $(src_label) ===")
    print("  warmup..."); _warmup_jit(base_data, pv_pairs); println(" done")

    results = Dict{String, Vector{NamedTuple}}(label => [] for (label, _, _) in STRATEGIES)

    for s in samples
        sample_data = deepcopy(base_data)
        if s.kind == :xlsx
            _apply_xlsx_row!(sample_data, s.row)
        else
            _scale_loads!(sample_data, base_pd, base_qd, s.scale)
        end
        sample_data["pv_pairs"] = deepcopy(pv_pairs)
        for (label, kind, kwargs) in STRATEGIES
            r = _run_strategy(kind, kwargs, sample_data)
            push!(results[label], r)
        end
    end

    # ---- Aggregate stats ----
    @printf "  %-25s %8s %8s %8s %8s %8s %8s %10s\n" "strategy" "feas%" "#V" "|V|" "#Q" "swp" "jac" "time(s)"
    println("  " * "-"^(25 + 8*6 + 11))
    for (label, _, _) in STRATEGIES
        rs = results[label]
        feas = 100 * mean(r.feasible for r in rs)
        nvv  = mean(r.nv_v for r in rs)
        magv = mean(r.mag_v for r in rs)
        nvq  = mean(r.nv_q for r in rs)
        siters = mean(r.swap_iters for r in rs)
        jiters = mean(r.jac_iters for r in rs)
        tavg = mean(r.time for r in rs)
        @printf "  %-25s %8.1f %8.2f %8.4f %8.2f %8.2f %8.2f %10.5f\n" label feas nvv magv nvq siters jiters tavg
    end
    println()

    # ---- Targeted comparisons ----
    rs_no  = results["sensitivity_score"]
    rs_yes = results["sensitivity_score+SMW"]
    rs_ng  = results["nearest_gen"]
    rs_qv  = results["qv_inv"]

    # SMW speed signal: jac_iters first (theory-grounded), then wall clock.
    pairs_swap = [(rn, ry) for (rn, ry) in zip(rs_no, rs_yes)
                   if rn.converged && ry.converged && rn.swap_iters > 1]
    if !isempty(pairs_swap)
        jac_no  = mean(p[1].jac_iters for p in pairs_swap)
        jac_yes = mean(p[2].jac_iters for p in pairs_swap)
        jac_wins = count(p -> p[2].jac_iters < p[1].jac_iters, pairs_swap)
        @printf "  SMW vs sens.-only on %d swap-triggering samples:\n" length(pairs_swap)
        @printf "     avg jac_iters: %.2f  ->  %.2f  (delta = %+0.2f)\n" jac_no jac_yes (jac_yes - jac_no)
        @printf "     SMW used strictly fewer jac iters on %d / %d samples\n" jac_wins length(pairs_swap)
        time_ratios = [p[2].time / p[1].time for p in pairs_swap if p[1].time > 0]
        if !isempty(time_ratios)
            @printf "     mean(time_with_SMW / time_without) = %.3f\n" mean(time_ratios)
        end
    else
        println("  SMW vs sens.-only: no samples triggered swaps (nothing to compare)")
    end

    # Quality vs nearest_gen.
    let
        wins = 0; ties = 0; losses = 0
        for (rss, rg) in zip(rs_no, rs_ng)
            if     rss.mag_v < rg.mag_v - 1e-9; wins += 1
            elseif rss.mag_v > rg.mag_v + 1e-9; losses += 1
            else;                                ties += 1
            end
        end
        @printf "  Quality |V| vs nearest_gen: sens W/T/L = %d/%d/%d  (mean |V| %.4f vs %.4f)\n" wins ties losses mean(r.mag_v for r in rs_no) mean(r.mag_v for r in rs_ng)
    end
    let
        wins = 0; ties = 0; losses = 0
        for (rss, rq) in zip(rs_no, rs_qv)
            if     rss.mag_v < rq.mag_v - 1e-9; wins += 1
            elseif rss.mag_v > rq.mag_v + 1e-9; losses += 1
            else;                                ties += 1
            end
        end
        @printf "  Quality |V| vs qv_inv:      sens W/T/L = %d/%d/%d  (mean |V| %.4f vs %.4f)\n" wins ties losses mean(r.mag_v for r in rs_no) mean(r.mag_v for r in rs_qv)
    end
    println()
end

# ----- entry point ----------------------------------------------------------

function main()
    PowerModels.logger_config!("warn")
    PowerModels.silence()
    if HAS_BSD
        @info "using bus_swap_data datasets at $BSD_ROOT"
    elseif HAS_CONFIG
        @info "using DATA_PATH from config.jl"
    else
        @info "no bus_swap_data or config.jl found; case14 only with random scaling"
    end
    # Heavier cases get fewer samples to keep total runtime reasonable.
    sample_caps = Dict(
        "case14" => 100,
        "case57" => 50,
        "case300" => 15,
        "case118" => 30,
        "case240" => 20,
        "case1354_pegase" => 5,
    )
    for case_name in CASES
        run_case(case_name; max_samples = get(sample_caps, case_name, 30))
    end
    println("Notes:")
    println("  - For the canonical Table I numbers across the FULL paper grid")
    println("    (1000 samples, all obo/grainger combos), run")
    println("      run_scripts/generate_dataset.jl")
    println("    which now includes sensitivity_score + use_smw_warmstart in")
    println("    its run_dict and writes xlsx outputs to RESULTS_PATH.")
end

main()
