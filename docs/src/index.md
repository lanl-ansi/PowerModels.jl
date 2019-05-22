# PowerModels.jl Documentation

```@meta
CurrentModule = PowerModels
```

## Overview

PowerModels.jl is a Julia/JuMP package for Steady-State Power Network Optimization. It provides utilities for parsing and modifying network data (see [PowerModels Network Data Format](@ref) for details), and is designed to enable computational evaluation of emerging power network formulations and algorithms in a common platform.

The code is engineered to decouple [Problem Specifications](@ref) (e.g. Power Flow, Optimal Power Flow, ...) from [Network Formulations](@ref) (e.g. AC, DC-approximation, SOC-relaxation, ...). This enables the definition of a wide variety of power network formulations and their comparison on common problem specifications.

## Installation

The latest stable release of PowerModels can be installed using the Julia package manager with

```julia
] add PowerModels
```

For the current development version, "checkout" this package with

```julia
] add PowerModels#master
```

At least one solver is required for running PowerModels.  The open-source solver Ipopt is recommended, as it is fast, scaleable and can be used to solve a wide variety of the problems and network formulations provided in PowerModels.  The Ipopt solver can be installed via the package manager with

```julia
] add Ipopt
```

Test that the package works by running

```julia
] test PowerModels
```

PowerModels' tests are comprehensive and can take as long as 10 minutes to complete.
