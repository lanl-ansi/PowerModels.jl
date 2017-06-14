# PowerModels.jl 

Release: [![PowerModels](http://pkg.julialang.org/badges/PowerModels_0.4.svg)](http://pkg.julialang.org/?pkg=PowerModels), [![PowerModels](http://pkg.julialang.org/badges/PowerModels_0.5.svg)](http://pkg.julialang.org/?pkg=PowerModels), [![PowerModels](http://pkg.julialang.org/badges/PowerModels_0.6.svg)](http://pkg.julialang.org/?pkg=PowerModels), 
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://lanl-ansi.github.io/PowerModels.jl/stable)

Dev:
[![Build Status](https://travis-ci.org/lanl-ansi/PowerModels.jl.svg?branch=master)](https://travis-ci.org/lanl-ansi/PowerModels.jl)
[![codecov](https://codecov.io/gh/lanl-ansi/PowerModels.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/lanl-ansi/PowerModels.jl)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://lanl-ansi.github.io/PowerModels.jl/latest)

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
* Matpower ".m" files

For further information, consult the package [documentation](https://lanl-ansi.github.io/PowerModels.jl/stable/).

## Development

Community-driven development and enhancement of PowerModels are welcome and encouraged. Please fork this repository and share your contributions to the master with pull requests.


## Acknowledgments

This code has been developed as part of the Advanced Network Science Initiative at Los Alamos National Laboratory.
The primary developer is Carleton Coffrin, with significant contributions from Russell Bent.

Special thanks to Miles Lubin for his assistance in integrating with Julia/JuMP.


## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
