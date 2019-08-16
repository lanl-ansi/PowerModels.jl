# PowerModels.jl

<img src="https://lanl-ansi.github.io/PowerModels.jl/dev/assets/logo.svg" align="left" width="200" alt="PowerModels logo">

Release: [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://lanl-ansi.github.io/PowerModels.jl/stable/)

Dev:
[![Build Status](https://travis-ci.org/lanl-ansi/PowerModels.jl.svg?branch=master)](https://travis-ci.org/lanl-ansi/PowerModels.jl)
[![codecov](https://codecov.io/gh/lanl-ansi/PowerModels.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/lanl-ansi/PowerModels.jl)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://lanl-ansi.github.io/PowerModels.jl/latest/)
</p>

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
* AC (polar and rectangular coordinates)
* DC Approximation (polar coordinates)
* LPAC Approximation (polar coordinates)
* SDP Relaxation (W-space)
* SOC Relaxation (W-space)
* QC Relaxation (W+L-space)

**Network Data Formats**
* Matpower ".m" files
* PTI ".raw" files (PSS(R)E v33 specfication)


## Documentation

The package [documentation](https://lanl-ansi.github.io/PowerModels.jl/stable/) includes a variety of useful information including a [quick-start guide](https://lanl-ansi.github.io/PowerModels.jl/stable/quickguide/), [network model specification](https://lanl-ansi.github.io/PowerModels.jl/stable/network-data/), and [baseline results](https://lanl-ansi.github.io/PowerModels.jl/stable/experiment-results/).

Additionally, these presentations provide a brief introduction to various aspects of PowerModels,
- [Network Model Update, v0.6](https://youtu.be/j7r4onyiNRQ)
- [PSCC 2018](https://youtu.be/AEEzt3IjLaM)
- [JuMP Developers Meetup 2017](https://youtu.be/W4LOKR7B4ts)


## Development

Community-driven development and enhancement of PowerModels are welcome and encouraged. Please fork this repository and share your contributions to the master with pull requests.  See [CONTRIBUTING.md](https://github.com/lanl-ansi/PowerModels.jl/blob/master/CONTRIBUTING.md) for code contribution guidelines.


## Acknowledgments

This code has been developed as part of the Advanced Network Science Initiative at Los Alamos National Laboratory.
The primary developer is Carleton Coffrin(@ccoffrin) with support from the following contributors,
- Russell Bent (@rb004f) LANL, Matpower export, TNEP problem specification
- Jose Daniel Lara (@jd-lara) Berkeley, Julia v1.0 compatibility
- Hakan Ergun (@hakanergun) KU Leuven, HVDC lines
- David Fobes (@pseudocubic) LANL, PSS(R)E v33 data support
- Rory Finnegan (@rofinn) Invenia, Memento Logging
- Frederik Geth (@frederikgeth) CSIRO, storage modeling advise, Branch Flow formulation
- Jonas Kersulis (@kersulis) University of Michigan, Sparse SDP formulation
- Miles Lubin (@mlubin) MIT, Julia/JuMP advise
- Yeesian Ng (@yeesian) MIT, Documenter.jl setup
- Kaarthik Sundar (@kaarthiksundar) LANL, OBBT utility


## Citing PowerModels

If you find PowerModels useful in your work, we kindly request that you cite the following [publication](https://ieeexplore.ieee.org/document/8442948/):
```
@inproceedings{8442948, 
  author = {Carleton Coffrin and Russell Bent and Kaarthik Sundar and Yeesian Ng and Miles Lubin}, 
  title = {PowerModels.jl: An Open-Source Framework for Exploring Power Flow Formulations}, 
  booktitle = {2018 Power Systems Computation Conference (PSCC)}, 
  year = {2018},
  month = {June},
  pages = {1-8}, 
  doi = {10.23919/PSCC.2018.8442948}
}
```
Citation of the orginal works for problem denifitions (e.g. OPF) and [power flow formulations](https://lanl-ansi.github.io/PowerModels.jl/stable/formulation-details/) (e.g. SOC) is also encouraged when publishing works that use PowerModels.


## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
