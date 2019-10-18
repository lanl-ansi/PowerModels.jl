PowerModels.jl Change Log
=========================

### Staged
- Added DCMPPowerModel for replication of Matpower's DC model (#612)

### v0.13.0
- Added SOC formulation of the storage model
- Added support for optional line flow constraints (#576)
- Simplified PowerModel types (#192) (breaking)
- Improved multi-conductor support in the storage model (#572) (breaking)
- Renamed model_constructor to model_type (#192) (breaking)
- Made all component on/off variables conductorless (#390) (breaking)
- Require an explicit switch section in the data model (breaking)
- Fixed naming branch indicator variable (#551) (breaking)
- Made baseMVA not a global key in multinetwork models (breaking)
- Fixed bug in bus_storage_lookup (#598)

### v0.12.5
- Update to InfrastructureModels v0.3 and JuMP v0.20
- Fixed power balance duals in w-space formulations (#591)
- Dropped CI on Julia v1.0

### v0.12.4
- Fixed support for data without an explicit switch section
- Fixed support for single values in add_setpoint! and add_dual!

### v0.12.3
- Add switch component (#339)
- Added component status parameter lookup (#565)
- Relax JuMP Model type (#582)
- Fixed conductor semantics in storage devices (breaking)
- Fixed status-based filtering to support fractional values (#564)
- Fixed `va` default start point

### v0.12.2
- Added function for building pwl objective variables and constraints
- Added check_status to standard data reading checks (#547)
- Added storage on/off constraints (#552)
- Added an alternative storage complementary constraint that uses MIP instead of NLP (#552)
- Fixed a bug in branch status reporting (#553)
- Fixed a bug in `AbstractBFForm` version of `constraint_voltage_angle_difference` (#557)

### v0.12.1
- Fixed a bug in add_setpoint! in the multiconductor case

### v0.12.0
- Significant updates to function naming details in #538 (#268,#454,#499,#533) (breaking)
- Added component status based filtering to solution building (#523)
- Added constraint_model_current to bfm formulations (breaking)
- Updated Matpower "bus_name" to map to bus parameter "name" (breaking)
- Updated slope and intercept data structure (#521) (breaking)
- Updated time_elapsed to be a network-wise parameter (#541) (breaking)
- Updated current variable name from cm to ccm (#366) (breaking)

### v0.11.2
- Added support for pre-computed buspair data (#524)
- Added source_id to Matpower parser (#512)
- Added logger_config! to configure the PowerModels logger (#402)
- Minor improvements to Matpower export function (#388)
- Removed inequality constraint from theta_ref constraint in the ACR formulation
- Removed bounds on binary variable constructors (#535)

### v0.11.1
- Added calc_gen_cost to compute the generator cost from the setpoint in the data model
- Added calc_dcline_cost to compute the dcline cost from the setpoint in the data model
- Fixed a bug that resulted in an extra call to ref_core!

### v0.11.0
- Update to use JuMP/MOI status values (#276) (breaking)
- Made power setpoint values required in storage model (#487) (breaking)
- Added support for extensible ref building (#263) (breaking)
- Updates PSS(R)E `source_id` to include string indicating originating component type (#511) (breaking)
- Renamed data functions to indicate when modification can occur (#441) (breaking)
- Renamed objective functions to make dcline flow costs more explicit (#364) (breaking)

### v0.10.1
- Refactor connected_components to accept arbitrary edge-types with `edges` kwarg
- Fixes bug in warnings inside storage constraints
- Add Bool to allowed data types in json parse of MultiConductorVector/Matrix
- Add handling of Inf/NaN values in JSON parser in MultiConductorVector/Matrix

### v0.10.0
- Update to JuMP v0.19/MathOptInterface (breaking)

### v0.9.8
- Added a test network with dangling buses, case5_db.m
- Fixed voltage bound persistence bug in acr formulation (#497)

### v0.9.7
- Minor fix solve method scope

### v0.9.6
- Added calc_power_balance function for computing bus balance from the data model
- Added calc_branch_flow functions for computing flows from the data model
- Added JSON parser with support for multiconductor values
- Added Base.norm for multiconductorvectors
- Improved starting point support for branch flow variables
- Improved starting point of piecewise linear cost function variables
- Minor improvement to piecewise linear cost function pre-processing
- Minor fix to multiconductor broadcasting
- Updated using to import
- Dropped support for Julia v0.6 and v0.7

### v0.9.5
- Added generator on/off constraints
- Added opf model with unit commitment (#475)
- Fixed multiconductor support for ACR formulation
- Removed support for Julia versions < 1.0
- Update syntax to be compatible with JuMP v0.19 / MathOptInterface

### v0.9.4
- Added all error messages to memento log
- Added ability to parse default values in PTI files
- Updated dict types to Dict{String,<:Any} (#466)
- Dropped lower bounds on unbounded voltage variables
- Refactored PTI parsing function names with `_` to indicate internal use only
- Fixed minor typos in docs
- Fixed a minor bound tolerance bug in OBBT
- Fixed minor error in conic bfm models (#469)
- Fixed bug in parsing of PTI transformers (#459)
- Fixed bug in PTI parsing handling commas or comment characters inside of quotations
- Fixed bug in PTI parsing where quotation marks were not being properly stripped from String-type data

### v0.9.3
- Added support for heterogeneous cost functions
- Added automatic simplification of cost functions
- Improved support for polynomial cost functions
- Updated default cost function to linear when loading PSSE data
- Cleaned up generator data in Matpower files
- Cleaned up generator data in PSS(R)E PTI file parse
- Fixed source_id in PSS(R)E PTI parse of buses to be only bus id
- Fixed small PSS(R)E PTI parser errors (unicode handling, reserved characters in comments, error message handling)

### v0.9.2
- Added tracking of modifications in check_network_data
- Added validate option to parse_file
- Added silence() function to suppress info and warn messages
- Improved support for storage units in summary function

### v0.9.1
- Fixed print_summary in Julia v1.0

### v0.9.0
- Added LPAC cold-start approximation
- Improved support for linear cost functions (breaking)
- Reorganized power formulation types into core/types.jl
- Added an abstract type for all active power only models
- Minor revision of case5_clm, case5_npg and case5_strg test cases (breaking)
- Minor revision of top-level storage constraints (#413)
- Minor improvement to dictionary comprehensions
- Fixed the interpretation of ncost in Matpower data (thanks to @lthurner)
- Minor bug fix to line charging in check_branch_directions
- Minor improvement to error messaging during pti parsing
- Minor breaking changes #363, #391, #408, #429

### v0.8.8
- Added PowerModels specific replicate function
- Improved storage component data validation checks

### v0.8.7
- Add support for Julia v0.7 and v1.0 (thanks to @jd-lara)

### v0.8.6
- Add support for a generic storage component
- Added add_setpoint_fixed to improve solution reporting performance
- Added support for a user provided JuMP model
- Improved the Matpower data file export function

### v0.8.5
- Improved the optimal power balance problem specification
- Add SOCWRPowerModel support for the optimal power balance problem
- Added conductorsless option to add_setpoint
- Added support for conductor value in add_setpoint scaling
- Update tests for SCS v0.4

### v0.8.4
- Added SparseSDPWRMPowerModel model (thanks to @kersulis)
- Added Julia version upper bound
- Improved OBBT bound update logic

### v0.8.3
- Added support for current limits, issue #342
- Added a optimal power balance problem specification
- Added a network flow approximation formulation, NFAPowerModel
- Added conic variant of the SOCWRPowerModel model, SOCWRConicPowerModel (thanks to @kersulis)
- Added data simplification for piecewise linear cost functions
- Added sim_parallel_run_time to OBBT stats
- Made thermal limits optional in the data model
- Fixed a bug in quadratic conic objective functions
- Fixed a bug where dcline reactive variables entered active power only formulations
- Expanded documentation (mathematical model, formulations, references for formulations)

### v0.8.2
- Added optimality-based bound tightening (OBBT) functionality for the QC relaxations
- Added branch flow conic forms, e.g. AbstractBFConicForm, SOCBFConicPowerModel
- Update MINLP solvers used in testing
- Minor issues closed #328

### v0.8.1
- Strengthened the QCWRTri Power Flow formulation
- Added support for implicit single conductor to buspairs data
- Made add_setpoint more flexible when working with a mixture of data types
- Fixed a bug in TNEP voltage variable definitions

### v0.8.0
- Added support for asymmetric line charging in all formulations
- Added Matpower data file export function
- Added mathematical model to documentation
- Added parsing string data from IO objects
- Added support for network data with multiple conductors (breaking)
- Removed explicit series variables from branch flow model
- Improved helper functions ref, var, con to work with multiple networks and multiple conductors
- Minor robustness improvements to parsing PTI files
- Minor issues closed #316

### v0.7.2
- Removed Memento depreciation warnings

### v0.7.1
- Added warning when data is missing in a PTI file
- Minor tidying of matpower test cases
- Relaxed variable bounds in BFM to be consistent with BIM

### v0.7.0
- Added component_table function for building matrices from component data
- Added "source_id" to uniquely identify each component imported from a PTI file
- Added support for extending PowerModels data with all PTI data fields
- Extended support for PSS(R)E v33 data (three-winding transformers, two-terminal/vsc hvdc lines)
- Allow multinetwork as an optional parameter
- Removed multi-network filter option from objective functions (breaking)
- Removed option to run multi-network data in single-network models (breaking)
- Removed add_setpoint_bus_demand function (breaking)
- Changed parameters and improved performance of KCL constraints (breaking)
- Improved robustness of matpower data parsing and transformation
- Improved testing of convex relaxations
- Changed test MIP solver from GLPK to CBC
- Fixed bug where "info" messages were not printed by default
- Fixed bug in dcline cost function unit conversion
- Fixed bug where not all JuMP variables were anonymous
- Fixed minor bug in Power Flow models when the data does not specify a reference bus
- Minor issues closed #251

### v0.6.1
- Moved to Juniper for non-convex MINLP tests
- Fixed minor bug in non-convex MINLP formulations

### v0.6.0
- Dropped support for Julia v0.5 (breaking)
- Added basic support for PSS(R)E v33 data (buses, loads, shunts, generators, branches and two-winding transformers)
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
- Fixed bug in voltage angle differences in AbstractACPForms
- Fixed bugs in AbstractDCPLLForm and added OPF test

### v0.3.4
- Added support for Matpower data with dclines (thanks to @frederikgeth, @hakanergun)
- Added support for QC-OTS
- Added support for multiple reference buses
- Added rectangular voltage formulation of AC-OPF
- Added w-theta formulation of AC-OPF
- Added data units checks to update_data
- Made branch flow parameter names consistent with Matpower
- Fixed bug in constants for w-space voltage angle difference constraints
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
- Moved system wide voltage angle difference bounds to the "ref" dictionary
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
