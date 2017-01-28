PowerModels.jl Change Log 
=================

### Staged
- Updated to JuMP v0.15 syntax
- Replaced PowerModels set data types with "ref" dictionary
- Refactored Matpower data processing to simplify editing network data after parsing
- Replaced JSON test files with Matpower test files
- Added documentation on internal JSON data format to DATA.md
- Updated TNEP models to work with Matpower parsing extensions
- Strengthened convex formulations with Lifted Nonlinear Cuts (LNCs)
- Added ability to easily inspect the JuMP model produced by PowerModels

### v0.2.3
- Multiple improvements to Matlab file parsing
  - Added support Matlab cell arrays
  - Added support for Matpower bus_names
  - Added ability for reading non-standard Matpower data elements
- Added JuMP version v0.14 upper bound 

### v0.2.2
- Added Transmission Network Expansion Planning (tnep) problem.

### v0.2.1
- Added support for julia v0.5.0 and OS X
- Added line flows option for solution output
- Added initial documentation and helper functions
- Replaced Gurobi with Pajarito for MISOCP tests

### v0.2.0
- Complete re-write to type-based implementation using dynamic dispatch
- Incorporated abstract problem specifications
- Added type-based formulation abstractions

### v0.1.0
- Initial function-based implementation
