# Quick Start Guide

Once PowerModels is installed, Ipopt is installed, and a network data file (e.g. `"case3.m"` or `"case3.raw"`) has been acquired, an AC Optimal Power Flow can be executed with,

```julia
using PowerModels
using Ipopt

run_ac_opf("matpower/case3.m", with_optimizer(Ipopt.Optimizer))
```

Similarly, a DC Optimal Power Flow can be executed with

```julia
run_dc_opf("matpower/case3.m", with_optimizer(Ipopt.Optimizer))
```

PTI `.raw` files in the PSS(R)E v33 specification can be run similarly, e.g. in the case of an AC Optimal Power Flow

```julia
run_ac_opf("case3.raw", with_optimizer(Ipopt.Optimizer))
```

## Getting Results

The run commands in PowerModels return detailed results data in the form of a dictionary. Results dictionaries from either Matpower `.m` or PTI `.raw` files will be identical in format. This dictionary can be saved for further processing as follows,

```julia
result = run_ac_opf("matpower/case3.m", with_optimizer(Ipopt.Optimizer))
```

For example, the algorithm's runtime and final objective value can be accessed with,

```
result["solve_time"]
result["objective"]
```

The `"solution"` field contains detailed information about the solution produced by the run method.
For example, the following dictionary comprehension can be used to inspect the bus voltage angles in the solution,

```
Dict(name => data["va"] for (name, data) in result["solution"]["bus"])
```

For more information about PowerModels result data see the [PowerModels Result Data Format](@ref) section.


## Accessing Different Formulations

The function "run_ac_opf" and "run_dc_opf" are shorthands for a more general formulation-independent OPF execution, "run_opf".
For example, `run_ac_opf` is equivalent to,

```julia
run_opf("matpower/case3.m", ACPPowerModel, with_optimizer(Ipopt.Optimizer))
```

where "ACPPowerModel" indicates an AC formulation in polar coordinates.  This more generic `run_opf()` allows one to solve an OPF problem with any power network formulation implemented in PowerModels.  For example, an SOC Optimal Power Flow can be run with,

```julia
run_opf("matpower/case3.m", SOCWRPowerModel, with_optimizer(Ipopt.Optimizer))
```

## Modifying Network Data
The following example demonstrates one way to perform multiple PowerModels solves while modifing the network data in Julia,

```julia
network_data = PowerModels.parse_file("matpower/case3.m")

run_opf(network_data, ACPPowerModel, with_optimizer(Ipopt.Optimizer))

network_data["load"]["3"]["pd"] = 0.0
network_data["load"]["3"]["qd"] = 0.0

run_opf(network_data, ACPPowerModel, with_optimizer(Ipopt.Optimizer))
```

Network data parsed from PTI `.raw` files supports data extensions, i.e. data fields that are within the PSS(R)E specification, but not used by PowerModels for calculation. This can be achieved by

```julia
network_data = PowerModels.parse_file("pti/case3.raw"; import_all=true)
```

This network data can be modified in the same way as the previous Matpower `.m` file example. For additional details about the network data, see the [PowerModels Network Data Format](@ref) section.

## Inspecting AC and DC branch flow results
The flow AC and DC branch results are not written to the result by default. To inspect the flow results, pass a Dict in through the `setting` keyword:
```julia
result = run_opf("matpower/case3_dc.m", ACPPowerModel, with_optimizer(Ipopt.Optimizer), setting = Dict("output" => Dict("branch_flows" => true)))
result["solution"]["dcline"]["1"]
result["solution"]["branch"]["2"]
```

The losses of an AC or DC branch can be derived:
```julia
loss_ac =  Dict(name => data["pt"]+data["pf"] for (name, data) in result["solution"]["branch"])
loss_dc =  Dict(name => data["pt"]+data["pf"] for (name, data) in result["solution"]["dcline"])
```


## Building PowerModels from Network Data Dictionaries
The following example demonstrates how to break a `run_opf` call into separate model building and solving steps.  This allows inspection of the JuMP model created by PowerModels for the AC-OPF problem,

```julia
pm = build_model("matpower/case3.m", ACPPowerModel, PowerModels.post_opf)

print(pm.model)

result = optimize_model!(pm, IpoptSolver())
```

Alternatively, you can further break it up by parsing a file into a network data dictionary, before passing it on to `build_model()` like so

```julia
network_data = PowerModels.parse_file("matpower/case3.m")

pm = build_model(network_data, ACPPowerModel, PowerModels.post_opf)

print(pm.model)

result = optimize_model!(pm, with_optimizer(Ipopt.Optimizer))
```
