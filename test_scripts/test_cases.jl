# Run this as a standalone Julia script from the repo root:
#   julia --project=. --startup-file=no test_scripts/test_cases.jl
#
# Restrict to specific cases/datapoints/configs with positional CLI args
# (each a comma-separated list; omit an arg, or pass "", to leave it
# unfiltered). Default with no args is the full 66-run sweep:
#   julia --project=. --startup-file=no test_scripts/test_cases.jl <cases> <datapoints> <configs>
#
# Examples:
#   # everything (default)
#   julia --project=. --startup-file=no test_scripts/test_cases.jl
#
#   # just the 300-bus case, both its datapoints, all 11 configs
#   julia --project=. --startup-file=no test_scripts/test_cases.jl case300
#
#   # one specific (case, datapoint, config) combination
#   julia --project=. --startup-file=no test_scripts/test_cases.jl case300 14 nearest_gen+no_grainger+no_obo
#
#   # re-run only the run that errored with InterruptException during the
#   # full sweep on 2026-08-24 (case300 dp=14 nearest_gen+no_grainger+no_obo)
#   julia --project=. --startup-file=no test_scripts/test_cases.jl rerun-failed
#
# Or from a Julia REPL started in the repo root:
#   using Pkg
#   Pkg.activate(".")
#   ENV["PM_BUSSWAP_PROGRESS"] = "1"
#   ENV["PM_BUSSWAP_CASES"] = "case300"                            # optional, comma-separated
#   ENV["PM_BUSSWAP_DATAPOINTS"] = "14"                            # optional, comma-separated
#   ENV["PM_BUSSWAP_CONFIGS"] = "nearest_gen+no_grainger+no_obo"   # optional, comma-separated
#   using Test, PowerModels, JSON
#   include("test/pf_busswap.jl")
#
# This file is intentionally kept as Julia code so it can be used as a
# lightweight launcher for the bus-swap functional test without depending on the
# full test/runtests.jl harness.

using Pkg

# Known failing runs from past sweeps, keyed by a short label you can pass as
# the sole CLI arg to re-run just that one (case, datapoint, config) combo.
const BUSSWAP_KNOWN_FAILURES = Dict(
    # errored with InterruptException during the full 66-run sweep on 2026-08-24
    "rerun-failed" => (case = "case300", datapoint = "14", config = "nearest_gen+no_grainger+no_obo"),
)

# When this file is executed directly as a script, activate the local project
# environment and run the standalone bus-swap test with progress reporting on.
# Positional CLI args (all optional, comma-separated, default = unfiltered = all):
#   ARGS[1] -> PM_BUSSWAP_CASES
#   ARGS[2] -> PM_BUSSWAP_DATAPOINTS
#   ARGS[3] -> PM_BUSSWAP_CONFIGS
# A single arg matching a key in BUSSWAP_KNOWN_FAILURES overrides all three
# with that run's exact case/datapoint/config.
if abspath(PROGRAM_FILE) == @__FILE__
    repo_root = normpath(joinpath(@__DIR__, ".."))
    Pkg.activate(repo_root)
    ENV["PM_BUSSWAP_PROGRESS"] = "1"

    if length(ARGS) == 1 && haskey(BUSSWAP_KNOWN_FAILURES, ARGS[1])
        known = BUSSWAP_KNOWN_FAILURES[ARGS[1]]
        ENV["PM_BUSSWAP_CASES"] = known.case
        ENV["PM_BUSSWAP_DATAPOINTS"] = known.datapoint
        ENV["PM_BUSSWAP_CONFIGS"] = known.config
    else
        length(ARGS) >= 1 && !isempty(ARGS[1]) && (ENV["PM_BUSSWAP_CASES"] = ARGS[1])
        length(ARGS) >= 2 && !isempty(ARGS[2]) && (ENV["PM_BUSSWAP_DATAPOINTS"] = ARGS[2])
        length(ARGS) >= 3 && !isempty(ARGS[3]) && (ENV["PM_BUSSWAP_CONFIGS"] = ARGS[3])
    end

    using Test
    using PowerModels
    using JSON
    include(joinpath(repo_root, "test", "pf_busswap.jl"))
end
