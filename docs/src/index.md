# PowerModels.jl Documentation

## Overview

PowerModels.jl is a Julia/JuMP package for Steady-State Power Network Optimization. It is designed to enable computational evaluation of emerging power network formulations and algorithms in a common platform.

The code is engineered to decouple problem specifications (e.g. Power Flow, Optimal Power Flow, ...) from the power network formulations (e.g. AC, DC-approximation, SOC-relaxation, ...). This enables the definition of a wide variety of power network formulations and their comparison on common problem specifications.

## Installation

The latest stable release of PowerModels can be installed using the Julia package manager with

```@repl
Pkg.add("PowerModels")
````

For the current development version, "checkout" this package with,

```@repl
Pkg.checkout("PowerModels")
```

At least one solver is required for running PowerModels.  The open-source solver Ipopt is recommended, as it is extremely fast, and can be used to solve a wide variety of the problems and network formulations provided in PowerModels.  The Ipopt solver can be installed via the package manager with,

```@repl
Pkg.add("Ipopt")
```

Test that the package works by running

```@repl
Pkg.test("PowerModels")
```

## Highlights

Mention some nice things here.

