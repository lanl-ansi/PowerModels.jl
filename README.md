# PowerModels.jl 

Release: [![PowerModels](http://pkg.julialang.org/badges/PowerModels_0.4.svg)](http://pkg.julialang.org/?pkg=PowerModels), [![PowerModels](http://pkg.julialang.org/badges/PowerModels_0.5.svg)](http://pkg.julialang.org/?pkg=PowerModels), [![PowerModels](http://pkg.julialang.org/badges/PowerModels_0.6.svg)](http://pkg.julialang.org/?pkg=PowerModels)

Dev:
[![Build Status](https://travis-ci.org/lanl-ansi/PowerModels.jl.svg?branch=master)](https://travis-ci.org/lanl-ansi/PowerModels.jl)
[![codecov](https://codecov.io/gh/lanl-ansi/PowerModels.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/lanl-ansi/PowerModels.jl)

PowerModels.jl is a Julia/JuMP package for Steady-State Power Network Optimization.
It is designed to enable computational evaluation of emerging power network formulations and algorithms in a common platform.
The code is engineered to decouple problem specifications (e.g. Power Flow, Optimal Power Flow, ...) from the power network formulations (e.g. AC, DC-approximation, SOC-relaxation, ...).
This enables the definition of a wide variety of power network formulations and their comparison on common problem specifications.

**Core Problem Specifications**
* Power Flow (pf)
* Optimal Power Flow (opf)
* Optimal Transmission Switching (ots)
* Transmission Network Expansion Planning (tnep)

**Core Network Formulations**
* AC (polar coordinates)
* DC Approximation (polar coordinates)
* SOC Relaxation (W-space)
* QC Relaxation (W+L-space)

**Network Data Formats**
* Matpower ".m" files (see DATA.md for details)


## Installation

The latest stable release of PowerModels can be installed using the Julia package manager with,

`Pkg.add("PowerModels")`

For the current development version, "checkout" this package with,

`Pkg.checkout("PowerModels")`

At least one solver is required for running PowerModels.  The open-source solver Ipopt is recommended, as it is extremely fast, and can be used to solve a wide variety of the problems and network formulations provided in PowerModels.  The Ipopt solver can be installed via tha package manager with,

`Pkg.add("Ipopt")`


## Basic Usage

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

In fact, "run_ac_opf" and "run_dc_opf" are shorthands for a more general formulation-independent OPF execution, "run_opf".  For example, "run_ac_opf" is,
```
run_opf("nesta_case3_lmbd.m", ACPPowerModel, IpoptSolver())
```

Where "ACPPowerModel" indicates an AC formulation in polar coordinates.  This more generic "run_opf" allows one to solve an OPF problem with any power network formulation implemented in PowerModels.  For example, an SOC Optimal Power Flow can be run with,

```
run_opf("nesta_case3_lmbd.m", SOCWRPowerModel, IpoptSolver())
```

Extending PowerModels with new problems and formulations will be covered in a another tutorial, that is not yet available.


### Modifying Network Data

The follow example demonstrates how to modify the network data in Julia.

```
network_data = PowerModels.parse_file("nesta_case3_lmbd.m")
run_opf(network_data, ACPPowerModel, IpoptSolver())

network_data["bus"][3]["pd"] = 0.0
network_data["bus"][3]["qd"] = 0.0

run_opf(network_data, ACPPowerModel, IpoptSolver())
```

For additional details about the PowerModels network data structure see the DATA.md file.


## Comparison to Other Tools

Forthcoming.


## Development

Community-driven development and enhancement of PowerModels are welcome and encouraged. Please fork this repository and share your contributions to the master with pull requests.


## Acknowledgments

This code has been developed as part of the Advanced Network Science Initiative at Los Alamos National Laboratory.
The primary developer is Carleton Coffrin, with significant contributions from Russell Bent.

Special thanks to Miles Lubin for his assistance in integrating with Julia/JuMP.


## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
