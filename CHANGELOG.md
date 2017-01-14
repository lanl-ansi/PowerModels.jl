PowerModels.jl Change Log 
=================

### staged
- Updated to JuMP v0.15 syntax

### v0.2.3
- Multiple improvements to Matlab file parsing
  - Added support matlab cell arrays
  - Added support for matpower bus_names
  - Added ability for reading non-standard matpower data elements
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
