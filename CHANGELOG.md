PowerModels.jl Change Log
=================

### Staged
- Removed multi-network filter option from objective functions (breaking)
- Removed option to run multi-network data in single-network models (breaking)
- Improved robustness of matpower data parsing and transformation

### v0.6.0
- Dropped support for Julia v0.5 (breaking)
- Added basic support for PSSE v33 raw data (incl. buses, loads, shunts, generators, branches and two-winding transformers)
- Added support for table-like data summary, #146
- Added support for network topology processing
- Added basic support for Branch Flow formulation variants
- Added support for parsing PTI files into a Dict
- Refactored implementation of WRM formulation
- Updated branch mathematical model and Matpower parser to support asymmetrical line charging
- Added explicit load and shunt components to the PowerModels network data structure
- Refactored Matlab and Matpower parsing functions
- Leveraging InfrastructureModels package for Matlab data parsing, #233, #247
- Migrated logging tools from Logging to Memento
- Updated struct and type parameter syntax to Julia v0.6
- Fixed a mathematical bug when swapping the orientation of a transformer
- Minor issues closed #51, #131, #220

### v0.5.1
- Added support for convex piecewise linear cost functions
- Added lambda-based convex hull relaxation scheme for trilinear products
- Added QCWRTri Power Flow formulation
- Added kcl and thermal limit dual values in linear power flow formulations
- Fixed bug in QC-OTS formulation

### v0.5.0
- Standardized around branch name for pi-model lines (breaking)
- Added checking for inconsistent orientation on parallel branches
- Added support for multiple networks in the JuMP model (breaking)
- Removed epsilon parameter from constraint_voltage_magnitude_setpoint (breaking)
- Moved misc models to PowerModelsAnnex (breaking)
- Removed unnecessary NL constraints from ACR and ACT formulations
- Removed redundant quadratic constraint from DCPLL formulation
- Added warning messages for inconsistent voltage set points
- Fixed branch flow units transformation bug

### v0.4.0
- Added JuMP v0.18 compatibility
- Added pm.var and made all JuMP variables anonymous (breaking)
- Added support for SDP, ACR, and ACT Power Flow formulations
- Added cost model zero filtering to matpower parser
- Eliminated usage of pm.model.ext, #149
- Made solution default units per-unit (breaking)
- Removed deprecated bus-less constraint_theta_ref function (breaking)
- Renamed polar voltage variables v,t to vm,va (breaking)
- Renamed functions with phase_angle to voltage_angle (breaking)
- Renamed v_from and w_from variables to v_fr w_fr (breaking)
- Removed variable and constraint function return values (breaking)
- Made index_name an optional parameter in add_setpoint (breaking)
- Moved check_cost_models into the objective building function
- Fixed out of range bug in calc_theta_delta_bounds
- Fixed bug in phase angle differences in AbstractACPForms
- Fixed bugs in AbstractDCPLLForm and added OPF test

### v0.3.4
- Added support for Matpower data with dclines (thanks to @frederikgeth, @hakanergun)
- Added support for QC-OTS
- Added support for multiple reference buses
- Added rectangular voltage formulation of AC-OPF
- Added w-theta formulation of AC-OPF
- Added data units checks to update_data
- Made branch flow parameter names consistent with Matpower
- Fixed bug in constants for w-space phase angle difference constraints
- Fixed bug when no reference bus was specified
- Fixed dcline parsing bug

### v0.3.3
- Added JuMP v0.17 compatibility
- Reorganized documentation into Manual, Library, Developer, and Experimental Results

### v0.3.2
- Updated type declarations to Julia v0.6 syntax
- Moved documentation to Documenter.jl (thanks to @yeesian)
- Added basic OPF results to Documentation
- Extended pm.ref include all fields from pm.data

### v0.3.1
- Added JuMP v0.16 and Julia v0.6 compatibility
- Added missing function for AC-TNEP models
- Added checks that tap ratios are non-zero
- Made all power model forms abstract types, to support future extensions
- Made matpower parser more robust to cases with line flow values
- Fixed a bug that prevented parsing of bus_names when buses have non-contiguous ids
- Fixed bounds correction units when angmin and angmax are 0.0

### v0.3.0
- Updated to JuMP v0.15 syntax
- Replaced PowerModels set data types with "ref" dictionary
- Refactored Matpower data processing to simplify editing network data after parsing
- Unified network data and solution formats and made them valid JSON documents
- Replaced JSON test files with Matpower test files
- Added documentation on internal JSON data format to DATA.md
- Updated TNEP models to work with Matpower parsing extensions
- Strengthened convex formulations with Lifted Nonlinear Cuts (LNCs)
- Added ability to easily inspect the JuMP model produced by PowerModels
- Added constraint templates to provide an abstraction layer between the network data and network constraint definitions
- Moved system wide phase angle difference bounds to the "ref" dictionary
- Refactored model definitions to be based on complex numbers

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
