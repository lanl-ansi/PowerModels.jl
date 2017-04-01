# Quick Guide

Once PowerModels is installed, Ipopt is installed, and a network data file (e.g. "nesta\_case3\_lmbd.m") has been acquired, an AC Optimal Power Flow can be executed with,
```
using PowerModels
using Ipopt

run_ac_opf("nesta_case3_lmbd.m", IpoptSolver())
```

Similarly, a DC Optimal Power Flow can be executed with,
```
run_dc_opf("nesta_case3_lmbd.m", IpoptSolver())
```

## Providing a Different Formulation
In fact, "run_ac_opf" and "run_dc_opf" are shorthands for a more general formulation-independent OPF execution, "run_opf".  For example, "run_ac_opf" is,
```
run_opf("nesta_case3_lmbd.m", ACPPowerModel, IpoptSolver())
```

Where "ACPPowerModel" indicates an AC formulation in polar coordinates.  This more generic "run_opf" allows one to solve an OPF problem with any power network formulation implemented in PowerModels.  For example, an SOC Optimal Power Flow can be run with,

```
run_opf("nesta_case3_lmbd.m", SOCWRPowerModel, IpoptSolver())
```

## Performing Multiple Solves
The following example demonstrates one way to perform multiple PowerModels solves while modify the network data in Julia,

```julia
network_data = PowerModels.parse_file("nesta_case3_lmbd.m")

run_opf(network_data, ACPPowerModel, IpoptSolver())

network_data["bus"]["3"]["pd"] = 0.0
network_data["bus"]["3"]["qd"] = 0.0

run_opf(network_data, ACPPowerModel, IpoptSolver())
```

## Inspecting the Formulation
The following example demonstrates how to break a `run_opf` call into seperate model building and solving steps.  This allows inspection of the JuMP model created by PowerModels for the AC-OPF problem,

```julia
pm = build_generic_model("nesta_case3_lmbd.m", ACPPowerModel, PowerModels.post_opf)

print(pm.model)

solve_generic_model(pm, IpoptSolver())
```
