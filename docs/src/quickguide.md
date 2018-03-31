# Quick Start Guide

Once PowerModels is installed, Ipopt is installed, and a network data file (e.g. `"nesta_case3_lmbd.m"`) has been acquired, an AC Optimal Power Flow can be executed with,

```julia
using PowerModels
using Ipopt

run_ac_opf("nesta_case3_lmbd.m", IpoptSolver())
```

Similarly, a DC Optimal Power Flow can be executed with

```julia
run_dc_opf("nesta_case3_lmbd.m", IpoptSolver())
```


## Getting Results

The run commands in PowerModels return detailed results data in the form of a dictionary.
This dictionary can be saved for further processing as follows,

```julia
result = run_ac_opf("nesta_case3_lmbd.m", IpoptSolver())
```

For example, the algorithm's runtime and final objective value can be accessed with,

```
result["solve_time"]
result["objective"]
```

The `"solution"` field contains detailed information about the solution produced by the run method.
For example, the following dictionary comprehension can be used to inspect the bus phase angles in the solution,

```
Dict(name => data["va"] for (name, data) in result["solution"]["bus"])
```

For more information about PowerModels result data see the [PowerModels Result Data Format](@ref) section.


## Accessing Different Formulations

The function "run_ac_opf" and "run_dc_opf" are shorthands for a more general formulation-independent OPF execution, "run_opf".
For example, `run_ac_opf` is equivalent to,

```julia
run_opf("nesta_case3_lmbd.m", ACPPowerModel, IpoptSolver())
```

where "ACPPowerModel" indicates an AC formulation in polar coordinates.  This more generic `run_opf()` allows one to solve an OPF problem with any power network formulation implemented in PowerModels.  For example, an SOC Optimal Power Flow can be run with,

```julia
run_opf("nesta_case3_lmbd.m", SOCWRPowerModel, IpoptSolver())
```

## Modifying Network Data
The following example demonstrates one way to perform multiple PowerModels solves while modifing the network data in Julia,

```julia
network_data = PowerModels.parse_file("nesta_case3_lmbd.m")

run_opf(network_data, ACPPowerModel, IpoptSolver())

network_data["load"]["3"]["pd"] = 0.0
network_data["load"]["3"]["qd"] = 0.0

run_opf(network_data, ACPPowerModel, IpoptSolver())
```

For additional details about the network data, see the [PowerModels Network Data Format](@ref) section.

## Inspecting AC and DC branch flow results
The flow AC and DC branch results are not written to the result by default. To inspect the flow results, pass a settings Dict
```julia
result = run_opf("case3_dc.m", ACPPowerModel, IpoptSolver(), setting = Dict("output" => Dict("line_flows" => true)))
result["solution"]["dcline"]["1"]
result["solution"]["branch"]["2"]
```

The losses of a AC or DC branch can be derived:
```julia
loss_ac =  Dict(name => data["p_to"]+data["p_from"] for (name, data) in result["solution"]["branch"])
loss_dc =  Dict(name => data["p_to"]+data["p_from"] for (name, data) in result["solution"]["dcline"])
```


## Inspecting the Formulation
The following example demonstrates how to break a `run_opf` call into seperate model building and solving steps.  This allows inspection of the JuMP model created by PowerModels for the AC-OPF problem,

```julia
pm = build_generic_model("nesta_case3_lmbd.m", ACPPowerModel, PowerModels.post_opf)

print(pm.model)

solve_generic_model(pm, IpoptSolver())
```
