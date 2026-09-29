# Quick Start Guide

This page provides a brief overview of the features of PowerModels.jl.

## Setup

This page uses the following packages:
```@repl quick-guide
using PowerModels
using Ipopt
```

This page also uses various input files. In this build of the documentation, we
use the files in:
```@repl quick-guide
DATA_DIR = joinpath(pkgdir(PowerModels), "test", "data");
```
but there are many public instances that you can use, for example, by going to
[pglib-opf](https://github.com/power-grid-lib/pglib-opf).

## Solving the basic Optimal Power Flow

Once PowerModels is installed, Ipopt is installed, and a network data file
(e.g., `"case3.m"` or `"case3.raw"`) has been acquired, an AC Optimal Power Flow
can be executed with:
```@repl quick-guide
solve_ac_opf(joinpath(DATA_DIR, "matpower", "case3.m"), Ipopt.Optimizer)
```

Pass options to the solver using JuMP's `optimizer_with_attributes`:
```@repl quick-guide
solve_dc_opf(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

Similarly, a DC Optimal Power Flow can be executed with:
```@repl quick-guide
solve_dc_opf(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

PTI `.raw` files in the PSS(R)E v33 specification can be run similarly, for
example, in the case of an AC Optimal Power Flow:
```@repl quick-guide
solve_ac_opf(
    joinpath(DATA_DIR, "pti", "case3.raw"),
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

## Getting Results

The run commands in PowerModels return detailed results data in the form of a
dictionary. Results dictionaries from either Matpower `.m` or PTI `.raw` files
will be identical in format. This dictionary can be saved for further processing
as follows,

```@repl quick-guide
result = solve_ac_opf(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

For example, the algorithm's runtime and final objective value can be accessed
with:
```@repl quick-guide
result["solve_time"]
result["objective"]
```

The `"solution"` field contains detailed information about the solution produced
by the run method. For example, the following dictionary comprehension can be
used to inspect the bus voltage angles in the solution:
```@repl quick-guide
Dict(name => data["va"] for (name, data) in result["solution"]["bus"])
```

The `print_summary(result["solution"])` function can be used show an table-like
overview of the solution data.
```@repl quick-guide
print_summary(result["solution"])
```

For more information about PowerModels result data, see the
[PowerModels Result Data Format](@ref) section.

## Using a different optimizer

PowerModels supports any solver compatible with JuMP.  In the examples above,
we used [Ipopt.jl](https://github.com/jump-dev/Ipopt.jl). Another option, which
can be faster particularly on large-scale problems, is [ExaModels.jl](https://github.com/madsuite-org/ExaModels.jl).

```@repl quick-guide
import ExaModels
import NLPModelsIpopt
result = solve_ac_opf(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    () -> ExaModels.Optimizer(NLPModelsIpopt.ipopt),
)
```

A benefit of ExaModels is that it supports [MadNLP](https://github.com/madsuite-org/MadNLP.jl),
which can run on a GPU:
```julia
julia> import CUDA, CUDSS, MadNLP, MadNLPGPU

julia> result = solve_ac_opf(
           joinpath(DATA_DIR, "matpower", "case3.m"),
           () -> ExaModels.Optimizer(MadNLP.madnlp, CUDA.CUDABackend()),
       );
```

## Accessing Different Formulations

The functions `solve_ac_opf` and `solve_dc_opf` are shorthands for a more
general formulation-independent OPF execution, `solve_opf`. For example,
`solve_ac_opf` is equivalent to:
```@repl quick-guide
solve_opf(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    ACPPowerModel,
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

where `ACPPowerModel` indicates an AC formulation in polar coordinates. This
more generic `solve_opf()` allows one to solve an OPF problem with any power
network formulation implemented in PowerModels. For example, an SOC Optimal
Power Flow can be run with:
```@repl quick-guide
solve_opf(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    SOCWRPowerModel,
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

[Formulation Details](@ref) provides a list of available formulations.

## Modifying Network Data

The following example demonstrates one way to perform multiple PowerModels
solves while modifing the network data in Julia:

```@repl quick-guide
network_data = PowerModels.parse_file(joinpath(DATA_DIR, "matpower", "case3.m"))
solve_opf(
    network_data,
    ACPPowerModel,
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
network_data["load"]["3"]["pd"] = 0.0;
network_data["load"]["3"]["qd"] = 0.0;
solve_opf(
    network_data,
    ACPPowerModel,
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

Network data parsed from PTI `.raw` files supports data extensions, that is,
data fields that are within the PSS(R)E specification, but not used by
PowerModels for calculation. This can be achieved by:
```@repl quick-guide
filename = joinpath(DATA_DIR, "pti", "case3.raw")
network_data = PowerModels.parse_file(filename; import_all = true)
```

This network data can be modified in the same way as the previous Matpower `.m`
file example.

For additional details about the network data, see the
[PowerModels Network Data Format](@ref) section.

## Inspecting AC and DC branch flow results

The flow AC and DC branch results are written to the result by default. The
following can be used to inspect the flow results:
```@repl quick-guide
result = solve_opf(
    joinpath(DATA_DIR, "matpower", "case5_dc.m"),
    ACPPowerModel,
    optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
result["solution"]["dcline"]["1"]
result["solution"]["branch"]["2"]
```

The losses of an AC or DC branch can be derived:
```@repl quick-guide
loss_ac = Dict(
    name => data["pt"]+data["pf"]
    for (name, data) in result["solution"]["branch"]
)
loss_dc = Dict(
    name => data["pt"]+data["pf"]
    for (name, data) in result["solution"]["dcline"]
)
```

## Building PowerModels from Network Data Dictionaries

The following example demonstrates how to break a `solve_opf` call into separate
model building and solving steps.  This allows inspection of the JuMP model
created by PowerModels for the AC-OPF problem,

```@repl quick-guide
pm = instantiate_model(
    joinpath(DATA_DIR, "matpower", "case3.m"),
    ACPPowerModel,
    PowerModels.build_opf,
);
pm.model
print(pm.model)
result = optimize_model!(
    pm;
    optimizer = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```

Alternatively, you can further break it up by parsing a file into a network data
dictionary, before passing it on to `instantiate_model()` like so:
```@repl quick-guide
network_data = PowerModels.parse_file(
    joinpath(DATA_DIR, "matpower", "case3.m"),
);
pm = instantiate_model(network_data, ACPPowerModel, PowerModels.build_opf);
result = optimize_model!(
    pm;
    optimizer = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
)
```
