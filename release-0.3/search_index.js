var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#PowerModels.jl-Documentation-1",
    "page": "Home",
    "title": "PowerModels.jl Documentation",
    "category": "section",
    "text": "CurrentModule = PowerModels"
},

{
    "location": "index.html#Overview-1",
    "page": "Home",
    "title": "Overview",
    "category": "section",
    "text": "PowerModels.jl is a Julia/JuMP package for Steady-State Power Network Optimization. It provides utilities for parsing and modifying network data (see PowerModels Network Data Format for details), and is designed to enable computational evaluation of emerging power network formulations and algorithms in a common platform.The code is engineered to decouple Problem Specifications (e.g. Power Flow, Optimal Power Flow, ...) from Network Formulations (e.g. AC, DC-approximation, SOC-relaxation, ...). This enables the definition of a wide variety of power network formulations and their comparison on common problem specifications."
},

{
    "location": "index.html#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "The latest stable release of PowerModels can be installed using the Julia package manager withPkg.add(\"PowerModels\")For the current development version, \"checkout\" this package withPkg.checkout(\"PowerModels\")At least one solver is required for running PowerModels.  The open-source solver Ipopt is recommended, as it is extremely fast, and can be used to solve a wide variety of the problems and network formulations provided in PowerModels.  The Ipopt solver can be installed via the package manager withPkg.add(\"Ipopt\")Test that the package works by runningPkg.test(\"PowerModels\")"
},

{
    "location": "quickguide.html#",
    "page": "Getting Started",
    "title": "Getting Started",
    "category": "page",
    "text": ""
},

{
    "location": "quickguide.html#Quick-Start-Guide-1",
    "page": "Getting Started",
    "title": "Quick Start Guide",
    "category": "section",
    "text": "Once PowerModels is installed, Ipopt is installed, and a network data file (e.g. \"nesta_case3_lmbd.m\") has been acquired, an AC Optimal Power Flow can be executed with,using PowerModels\nusing Ipopt\n\nrun_ac_opf(\"nesta_case3_lmbd.m\", IpoptSolver())Similarly, a DC Optimal Power Flow can be executed withrun_dc_opf(\"nesta_case3_lmbd.m\", IpoptSolver())"
},

{
    "location": "quickguide.html#Getting-Results-1",
    "page": "Getting Started",
    "title": "Getting Results",
    "category": "section",
    "text": "The run commands in PowerModels return detailed results data in the form of a dictionary. This dictionary can be saved for further processing as follows,result = run_ac_opf(\"nesta_case3_lmbd.m\", IpoptSolver())For example, the algorithm's runtime and final objective value can be accessed with,result[\"solve_time\"]\nresult[\"objective\"]The \"solution\" field contains detailed information about the solution produced by the run method. For example, the following dictionary comprehension can be used to inspect the bus phase angles in the solution,Dict(name => data[\"va\"] for (name, data) in result[\"solution\"][\"bus\"])For more information about PowerModels result data see the PowerModels Result Data Format section."
},

{
    "location": "quickguide.html#Accessing-Different-Formulations-1",
    "page": "Getting Started",
    "title": "Accessing Different Formulations",
    "category": "section",
    "text": "The function \"run_ac_opf\" and \"run_dc_opf\" are shorthands for a more general formulation-independent OPF execution, \"run_opf\". For example, run_ac_opf is equivalent to,run_opf(\"nesta_case3_lmbd.m\", ACPPowerModel, IpoptSolver())where \"ACPPowerModel\" indicates an AC formulation in polar coordinates.  This more generic run_opf() allows one to solve an OPF problem with any power network formulation implemented in PowerModels.  For example, an SOC Optimal Power Flow can be run with,run_opf(\"nesta_case3_lmbd.m\", SOCWRPowerModel, IpoptSolver())"
},

{
    "location": "quickguide.html#Modifying-Network-Data-1",
    "page": "Getting Started",
    "title": "Modifying Network Data",
    "category": "section",
    "text": "The following example demonstrates one way to perform multiple PowerModels solves while modify the network data in Julia,network_data = PowerModels.parse_file(\"nesta_case3_lmbd.m\")\n\nrun_opf(network_data, ACPPowerModel, IpoptSolver())\n\nnetwork_data[\"bus\"][\"3\"][\"pd\"] = 0.0\nnetwork_data[\"bus\"][\"3\"][\"qd\"] = 0.0\n\nrun_opf(network_data, ACPPowerModel, IpoptSolver())For additional details about the network data, see the PowerModels Network Data Format section."
},

{
    "location": "quickguide.html#Inspecting-the-Formulation-1",
    "page": "Getting Started",
    "title": "Inspecting the Formulation",
    "category": "section",
    "text": "The following example demonstrates how to break a run_opf call into seperate model building and solving steps.  This allows inspection of the JuMP model created by PowerModels for the AC-OPF problem,pm = build_generic_model(\"nesta_case3_lmbd.m\", ACPPowerModel, PowerModels.post_opf)\n\nprint(pm.model)\n\nsolve_generic_model(pm, IpoptSolver())"
},

{
    "location": "network-data.html#",
    "page": "Network Data Format",
    "title": "Network Data Format",
    "category": "page",
    "text": ""
},

{
    "location": "network-data.html#PowerModels-Network-Data-Format-1",
    "page": "Network Data Format",
    "title": "PowerModels Network Data Format",
    "category": "section",
    "text": ""
},

{
    "location": "network-data.html#The-Network-Data-Dictionary-1",
    "page": "Network Data Format",
    "title": "The Network Data Dictionary",
    "category": "section",
    "text": "Internally PowerModels utilizes a dictionary to store network data. The dictionary uses strings as key values so it can be serialized to JSON for algorithmic data exchange.The data dictionary organization and key names are designed to be consistent with the Matpower file format and should be familiar to power system researchers.The network data dictionary structure is roughly as follows:{\n\"name\":<string>,\n\"version\":\"2\",\n\"baseMVA\":<float>,\n\"bus\":{\n    \"1\":{\n        \"index\":<int>,\n        \"bus_type\":<int>,\n        \"pd\":<float>,\n        \"qd\":<float>,\n        ...\n    },\n    \"2\":{...},\n    ...\n},\n\"gen\":{\n    \"1\":{\n        \"index\":<int>,\n        \"gen_bus\":<int>,\n        \"pg\":<float>,\n        \"qg\":<float>,\n        ...\n    },\n    \"2\":{...},\n    ...\n},\n\"branch\":{\n    \"1\":{\n        \"index\":<int>,\n        \"f_bus\":<int>,\n        \"t_bus\":<int>,\n        \"br_r\":<int>,\n        ...\n    },\n    \"2\":{...},\n    ...\n}\n}The following commands can be used to explore the network data dictionary generated by a given Matpower data file,network_data = PowerModels.parse_file(\"nesta_case3_lmbd.m\")\ndisplay(network_data)For a detailed list of all possible parameters refer to the specification document provided with Matpower.  "
},

{
    "location": "network-data.html#Noteworthy-Differences-from-Matpower-Data-Files-1",
    "page": "Network Data Format",
    "title": "Noteworthy Differences from Matpower Data Files",
    "category": "section",
    "text": "The PowerModels network data dictionary differs from the Matpower format in the following ways,All PowerModels components have an index parameter, which can be used to uniquely identify that network element.\nAll network parameters are in per-unit and angles are in radians.\nAll non-transformer branches are given nominal transformer values (i.e. a tap of 1.0 and a shift of 0).\nAll branches have a transformer field indicating if they are a transformer or not.\nOnly quadratic active power generation cost functions are supported, at this time.\nWhen present, the gencost data is incorporated into the gen data, the column names remain the same.\nWhen present, the bus_names data is incorporated into the bus data under the property \"bus_name\".\nSpecial treatment is given to the optional ne_branch matrix to support the TNEP problem."
},

{
    "location": "network-data.html#Working-with-Matpower-Data-Files-1",
    "page": "Network Data Format",
    "title": "Working with Matpower Data Files",
    "category": "section",
    "text": "The data exchange via JSON files is ideal for building algorithms, however it is hard to for humans to read and process.  To that end PowerModels also has extensive support for parsing Matpower network files in the .m format.In addition to parsing the standard Matpower parameters, PowerModels also supports extending the standard Matpower format in a number of ways as illustrated by the following examples.  In these examples JSON document fragments are used to indicate the structure of the PowerModel dictionary."
},

{
    "location": "network-data.html#Single-Values-1",
    "page": "Network Data Format",
    "title": "Single Values",
    "category": "section",
    "text": "Single values are added to the root of the dictionary as follows,mpc.const_float = 4.56becomes{\n\"const_float\": 4.56\n}"
},

{
    "location": "network-data.html#Nonstandard-Matrices-1",
    "page": "Network Data Format",
    "title": "Nonstandard Matrices",
    "category": "section",
    "text": "Nonstandard matrices can be added as follows,mpc.areas = [\n    1   1;\n    2   3;\n];becomes{\n\"areas\":{\n    \"1\":{\n        \"index\":1,\n        \"col_1\":1,\n        \"col_2\":1\n    },\n    \"2\":{\n        \"index\":1,\n        \"col_1\":2,\n        \"col_2\":3\n    }\n}\n}"
},

{
    "location": "network-data.html#Column-Names-1",
    "page": "Network Data Format",
    "title": "Column Names",
    "category": "section",
    "text": "Column names can be given to nonstandard matrices using the following special comment,%column_names%  area    refbus\nmpc.areas_named = [\n    4   5;\n    5   6;\n];becomes{\n\"areas\":{\n    \"1\":{\n        \"index\":1,\n        \"area\":4,\n        \"refbus\":5\n    },\n    \"2\":{\n        \"index\":2,\n        \"area\":5,\n        \"refbus\":6\n    }\n}\n}"
},

{
    "location": "network-data.html#Standard-Matrix-Extensions-1",
    "page": "Network Data Format",
    "title": "Standard Matrix Extensions",
    "category": "section",
    "text": "Finally, if a nonstandard matrix's name extends a current Matpower matrix name with an underscore, then its values will be merged with the original Matpower component data.  Note that this feature requires that the nonstandard matrix has column names and has the same number of rows as the original matrix (similar to the gencost matrix in the Matpower format).  For example,%column_names%  rate_i  rate_p\nmpc.branch_limit = [\n    50.2    45;\n    36  60.1;\n    12  30;\n];becomes{\n\"branch\":{\n    \"1\":{\n        \"index\":1,\n        ...(all pre existing fields)...\n        \"rate_i\":50.2,\n        \"rate_p\":45\n    },\n    \"2\":{\n        \"index\":2,\n        ...(all pre existing fields)...\n        \"rate_i\":36,\n        \"rate_p\":60.1\n    },\n    \"3\":{\n        \"index\":3,\n        ...(all pre existing fields)...\n        \"rate_i\":12,\n        \"rate_p\":30\n    }\n}\n}"
},

{
    "location": "result-data.html#",
    "page": "Result Data Format",
    "title": "Result Data Format",
    "category": "page",
    "text": ""
},

{
    "location": "result-data.html#PowerModels-Result-Data-Format-1",
    "page": "Result Data Format",
    "title": "PowerModels Result Data Format",
    "category": "section",
    "text": ""
},

{
    "location": "result-data.html#The-Result-Data-Dictionary-1",
    "page": "Result Data Format",
    "title": "The Result Data Dictionary",
    "category": "section",
    "text": "PowerModels utilizes a dictionary to organize the results of a run command. The dictionary uses strings as key values so it can be serialized to JSON for algorithmic data exchange. The data dictionary organization is designed to be consistent with the PowerModels The Network Data Dictionary.At the top level the results data dictionary is structured as follows:{\n\"solver\":<string>,       # name of the Julia class used to solve the model\n\"status\":<julia symbol>, # solver status at termination\n\"solve_time\":<float>,    # reported solve time (seconds)\n\"objective\":<float>,     # the final evaluation of the objective function\n\"objective_lb\":<float>,  # the final lower bound of the objective function (if available)\n\"machine\":{...},         # computer hardware information (details below)\n\"data\":{...},            # test case information (details below)\n\"solution\":{...}         # complete solution information (details below)\n}"
},

{
    "location": "result-data.html#Machine-Data-1",
    "page": "Result Data Format",
    "title": "Machine Data",
    "category": "section",
    "text": "This object provides basic information about the hardware that was  used when the run command was called.{\n\"cpu\":<string>,    # CPU product name\n\"memory\":<string>  # the amount of system memory (units given)\n}"
},

{
    "location": "result-data.html#Case-Data-1",
    "page": "Result Data Format",
    "title": "Case Data",
    "category": "section",
    "text": "This object provides basic information about the network cases that was  used when the run command was called.{\n\"name\":<string>,      # the name from the network data structure\n\"bus_count\":<int>,    # the number of buses in the network data structure\n\"branch_count\":<int>  # the number of branches in the network data structure\n}"
},

{
    "location": "result-data.html#Solution-Data-1",
    "page": "Result Data Format",
    "title": "Solution Data",
    "category": "section",
    "text": "The solution object provides detailed information about the solution  produced by the run command.  The solution is organized similarly to  The Network Data Dictionary with the same nested structure and  parameter names, when available.  A network solution most often only includes a small subset of the data included in the network data.For example the data for a bus, data[\"bus\"][\"1\"] is structured as follows,{\n\"bus_i\": 1,\n\"bus_type\": 3,\n\"pd\":1.0,\n\"qd\":0.37,\n\"vm\":1.0,\n\"va\":0.0,\n...\n}A solution specifying a voltage magnitude and angle would for the same case, i.e. result[\"solution\"][\"bus\"][\"1\"], would result in,{\n\"vm\":1.12,\n\"va\":-3.59,\n}Because the data dictionary and the solution dictionary have the same structure  PowerModels provides an update_data helper function which can be used to  update a data diction with the values from a solution as follows,PowerModels.update_data(data, result[\"solution\"])"
},

{
    "location": "formulations.html#",
    "page": "Network Formulations",
    "title": "Network Formulations",
    "category": "page",
    "text": ""
},

{
    "location": "formulations.html#Network-Formulations-1",
    "page": "Network Formulations",
    "title": "Network Formulations",
    "category": "section",
    "text": ""
},

{
    "location": "formulations.html#Type-Hierarchy-1",
    "page": "Network Formulations",
    "title": "Type Hierarchy",
    "category": "section",
    "text": "We begin with the top of the hierarchy, where we can distinguish between AC and DC power flow models.AbstractACPForm <: AbstractPowerFormulation\nAbstractDCPForm <: AbstractPowerFormulation\nAbstractWRForm <: AbstractPowerFormulationFrom there, different forms for ACP and DCP are possible:StandardACPForm <: AbstractACPForm\nAPIACPForm <: AbstractACPForm\n\nStandardDCPForm <: AbstractDCPForm\n\nSOCWRForm <: AbstractWRForm\nQCWRForm <: AbstractWRForm"
},

{
    "location": "formulations.html#Power-Models-1",
    "page": "Network Formulations",
    "title": "Power Models",
    "category": "section",
    "text": "Each of these forms can be used as the type parameter for a PowerModel:ACPPowerModel = GenericPowerModel{StandardACPForm}\nAPIACPPowerModel = GenericPowerModel{APIACPForm}\n\nDCPPowerModel = GenericPowerModel{StandardDCPForm}\n\nSOCWRPowerModel = GenericPowerModel{SOCWRForm}\nQCWRPowerModel = GenericPowerModel{QCWRForm}For details on GenericPowerModel, see the section on Power Model."
},

{
    "location": "formulations.html#User-Defined-Abstractions-1",
    "page": "Network Formulations",
    "title": "User-Defined Abstractions",
    "category": "section",
    "text": "Consider the class of conic formulations for power flow models. One way of modelling them in this package is through the following type hierarchy:AbstractConicPowerFormulation <: AbstractPowerFormulation\nAbstractWRMForm <: AbstractConicPowerFormulation\n\nSDPWRMForm <: AbstractWRMForm\nSDPWRMPowerModel = GenericPowerModel{SDPWRMForm}The user-defined abstractions do not have to begin from the root AbstractPowerFormulation abstract type, and can begin from an intermediate abstract type. For example, in the following snippet:AbstractDCPLLForm <: AbstractDCPForm\n\nStandardDCPLLForm <: AbstractDCPLLForm\nDCPLLPowerModel = GenericPowerModel{StandardDCPLLForm}"
},

{
    "location": "specifications.html#",
    "page": "Problem Specifications",
    "title": "Problem Specifications",
    "category": "page",
    "text": ""
},

{
    "location": "specifications.html#Problem-Specifications-1",
    "page": "Problem Specifications",
    "title": "Problem Specifications",
    "category": "section",
    "text": ""
},

{
    "location": "specifications.html#Optimal-Power-Flow-(OPF)-1",
    "page": "Problem Specifications",
    "title": "Optimal Power Flow (OPF)",
    "category": "section",
    "text": ""
},

{
    "location": "specifications.html#Objective-1",
    "page": "Problem Specifications",
    "title": "Objective",
    "category": "section",
    "text": "objective_min_fuel_cost(pm)"
},

{
    "location": "specifications.html#Variables-1",
    "page": "Problem Specifications",
    "title": "Variables",
    "category": "section",
    "text": "variable_voltage(pm)\nvariable_active_generation(pm)\nvariable_reactive_generation(pm)\nvariable_line_flow(pm)"
},

{
    "location": "specifications.html#Constraints-1",
    "page": "Problem Specifications",
    "title": "Constraints",
    "category": "section",
    "text": "constraint_theta_ref(pm)\nconstraint_voltage(pm)\nfor (i,bus) in pm.ref[:bus]\n    constraint_kcl_shunt(pm, bus)\nend\nfor (i,branch) in pm.ref[:branch]\n    constraint_ohms_yt_from(pm, branch)\n    constraint_ohms_yt_to(pm, branch)\n\n    constraint_phase_angle_difference(pm, branch)\n\n    constraint_thermal_limit_from(pm, branch)\n    constraint_thermal_limit_to(pm, branch)\nend"
},

{
    "location": "specifications.html#Optimal-Transmission-Switching-(OTS)-1",
    "page": "Problem Specifications",
    "title": "Optimal Transmission Switching (OTS)",
    "category": "section",
    "text": ""
},

{
    "location": "specifications.html#General-Assumptions-1",
    "page": "Problem Specifications",
    "title": "General Assumptions",
    "category": "section",
    "text": "if the branch status is 0 in the input, it is out of service and forced to 0 in OTS\nthe network will be maintained as one connected component (i.e. at least n-1 edges)"
},

{
    "location": "specifications.html#Variables-2",
    "page": "Problem Specifications",
    "title": "Variables",
    "category": "section",
    "text": "variable_line_indicator(pm)\nvariable_voltage_on_off(pm)\nvariable_active_generation(pm)\nvariable_reactive_generation(pm)\nvariable_line_flow(pm)"
},

{
    "location": "specifications.html#Objective-2",
    "page": "Problem Specifications",
    "title": "Objective",
    "category": "section",
    "text": "objective_min_fuel_cost(pm)"
},

{
    "location": "specifications.html#Constraints-2",
    "page": "Problem Specifications",
    "title": "Constraints",
    "category": "section",
    "text": "constraint_theta_ref(pm)\nconstraint_voltage_on_off(pm)\nfor (i,bus) in pm.ref[:bus]\n    constraint_kcl_shunt(pm, bus)\nend\nfor (i,branch) in pm.ref[:branch]\n    constraint_ohms_yt_from_on_off(pm, branch)\n    constraint_ohms_yt_to_on_off(pm, branch)\n\n    constraint_phase_angle_difference_on_off(pm, branch)\n\n    constraint_thermal_limit_from_on_off(pm, branch)\n    constraint_thermal_limit_to_on_off(pm, branch)\nend"
},

{
    "location": "specifications.html#Power-Flow-(PF)-1",
    "page": "Problem Specifications",
    "title": "Power Flow (PF)",
    "category": "section",
    "text": ""
},

{
    "location": "specifications.html#Assumptions-1",
    "page": "Problem Specifications",
    "title": "Assumptions",
    "category": "section",
    "text": ""
},

{
    "location": "specifications.html#Variables-3",
    "page": "Problem Specifications",
    "title": "Variables",
    "category": "section",
    "text": "variable_voltage(pm, bounded = false)\nvariable_active_generation(pm, bounded = false)\nvariable_reactive_generation(pm, bounded = false)\nvariable_line_flow(pm, bounded = false)"
},

{
    "location": "specifications.html#Constraints-3",
    "page": "Problem Specifications",
    "title": "Constraints",
    "category": "section",
    "text": "constraint_theta_ref(pm)\nconstraint_voltage_magnitude_setpoint(pm, pm.ref[:bus][pm.ref[:ref_bus]])\nconstraint_voltage(pm)\n\nfor (i,bus) in pm.ref[:bus]\n    constraint_kcl_shunt(pm, bus)\n\n    # PV Bus Constraints\n    if length(pm.ref[:bus_gens][i]) > 0 && i != pm.ref[:ref_bus]\n        # this assumes inactive generators are filtered out of bus_gens\n        @assert bus[\"bus_type\"] == 2\n\n        # soft equality needed becouse v in file is not precice enough to ensure feasiblity\n        constraint_voltage_magnitude_setpoint(pm, bus; epsilon = 0.00001)\n        for j in pm.ref[:bus_gens][i]\n            constraint_active_gen_setpoint(pm, pm.ref[:gen][j])\n        end\n    end\nend\n\nfor (i,branch) in pm.ref[:branch]\n    constraint_ohms_yt_from(pm, branch)\n    constraint_ohms_yt_to(pm, branch)\nend"
},

{
    "location": "specifications.html#Transmission-Network-Expansion-Planning-(TNEP)-1",
    "page": "Problem Specifications",
    "title": "Transmission Network Expansion Planning (TNEP)",
    "category": "section",
    "text": ""
},

{
    "location": "specifications.html#Objective-3",
    "page": "Problem Specifications",
    "title": "Objective",
    "category": "section",
    "text": "objective_tnep_cost(pm)"
},

{
    "location": "specifications.html#Variables-4",
    "page": "Problem Specifications",
    "title": "Variables",
    "category": "section",
    "text": "variable_line_ne(pm) \nvariable_voltage(pm)\nvariable_voltage_ne(pm)\nvariable_active_generation(pm)\nvariable_reactive_generation(pm)\nvariable_line_flow(pm)\nvariable_line_flow_ne(pm)"
},

{
    "location": "specifications.html#Constraints-4",
    "page": "Problem Specifications",
    "title": "Constraints",
    "category": "section",
    "text": "constraint_theta_ref(pm)\nconstraint_voltage(pm)\nconstraint_voltage_ne(pm)\n\nfor (i,bus) in pm.ref[:bus]\n    constraint_kcl_shunt_ne(pm, bus)\nend\n\nfor (i,branch) in pm.ref[:branch]\n    constraint_ohms_yt_from(pm, branch)\n    constraint_ohms_yt_to(pm, branch)\n\n    constraint_phase_angle_difference(pm, branch)\n\n    constraint_thermal_limit_from(pm, branch)\n    constraint_thermal_limit_to(pm, branch)\nend \n\nfor (i,branch) in pm.ref[:ne_branch]\n    constraint_ohms_yt_from_ne(pm, branch)\n    constraint_ohms_yt_to_ne(pm, branch) \n\n    constraint_phase_angle_difference_ne(pm, branch)\n\n    constraint_thermal_limit_from_ne(pm, branch)\n    constraint_thermal_limit_to_ne(pm, branch)\nend"
},

{
    "location": "model.html#",
    "page": "PowerModel",
    "title": "PowerModel",
    "category": "page",
    "text": ""
},

{
    "location": "model.html#PowerModels.GenericPowerModel",
    "page": "PowerModel",
    "title": "PowerModels.GenericPowerModel",
    "category": "Type",
    "text": "type GenericPowerModel{T<:AbstractPowerFormulation}\n    model::JuMP.Model\n    data::Dict{String,Any} \n    setting::Dict{String,Any}\n    solution::Dict{String,Any}\n    ref::Dict{Symbol,Any} # reference data\nend\n\nwhere\n\ndata is the original data, usually from reading in a .json or .m (patpower) file,\nsetting usually looks something like Dict(\"output\" => Dict(\"line_flows\" => true)), and\nref is a place to store commonly used pre-computed data from of the data dictionary,   primarily for converting data-types, filtering out deactivated components, and storing   system-wide values that need to be computed globally. See build_ref(data) for further details.\n\nMethods on GenericPowerModel for defining variables and adding constraints should\n\nwork with the ref dict, rather than the original data dict,\nadd them to model::JuMP.Model, and\nfollow the conventions for variable and constraint names.\n\n\n\n"
},

{
    "location": "model.html#PowerModels.build_ref",
    "page": "PowerModel",
    "title": "PowerModels.build_ref",
    "category": "Function",
    "text": "Returns a dict that stores commonly used pre-computed data from of the data dictionary, primarily for converting data-types, filtering out deactivated components, and storing system-wide values that need to be computed globally.\n\nSome of the common keys include:\n\n:off_angmin and :off_angmax (see calc_theta_delta_bounds(data)),\n:bus – the set {(i, bus) in ref[:bus] : bus[\"bus_type\"] != 4},\n:gen – the set {(i, gen) in ref[:gen] : gen[\"gen_status\"] == 1 && gen[\"gen_bus\"] in keys(ref[:bus])},\n:branch – the set of branches that are active in the network (based on the component status values),\n:arcs_from – the set [(i,b[\"f_bus\"],b[\"t_bus\"]) for (i,b) in ref[:branch]],\n:arcs_to – the set [(i,b[\"t_bus\"],b[\"f_bus\"]) for (i,b) in ref[:branch]],\n:arcs – the set of arcs from both arcs_from and arcs_to,\n:bus_arcs – the mapping Dict(i => [(l,i,j) for (l,i,j) in ref[:arcs]]),\n:buspairs – (see buspair_parameters(ref[:arcs_from], ref[:branch], ref[:bus])), and\n:bus_gens – the mapping Dict(i => [gen[\"gen_bus\"] for (i,gen) in ref[:gen]]).\n\nIf :ne_branch exists, then the following keys are also available with similar semantics:\n\n:ne_branch, :ne_arcs_from, :ne_arcs_to, :ne_arcs, :ne_bus_arcs, :ne_buspairs.\n\n\n\n"
},

{
    "location": "model.html#PowerModels.buspair_parameters",
    "page": "PowerModel",
    "title": "PowerModels.buspair_parameters",
    "category": "Function",
    "text": "compute bus pair level structures\n\n\n\n"
},

{
    "location": "model.html#Power-Model-1",
    "page": "PowerModel",
    "title": "Power Model",
    "category": "section",
    "text": "CurrentModule = PowerModelsAll methods for constructing powermodels should be defined on the following type:GenericPowerModelwhich utilizes the following (internal) functions:build_ref\nbuspair_parameters"
},

{
    "location": "objective.html#",
    "page": "Objective",
    "title": "Objective",
    "category": "page",
    "text": ""
},

{
    "location": "objective.html#PowerModels.objective_min_fuel_cost-Tuple{PowerModels.GenericPowerModel{T<:PowerModels.AbstractConicPowerFormulation}}",
    "page": "Objective",
    "title": "PowerModels.objective_min_fuel_cost",
    "category": "Method",
    "text": "\n\n"
},

{
    "location": "objective.html#PowerModels.objective_min_fuel_cost-Tuple{PowerModels.GenericPowerModel}",
    "page": "Objective",
    "title": "PowerModels.objective_min_fuel_cost",
    "category": "Method",
    "text": "\n\n"
},

{
    "location": "objective.html#PowerModels.objective_tnep_cost-Tuple{PowerModels.GenericPowerModel}",
    "page": "Objective",
    "title": "PowerModels.objective_tnep_cost",
    "category": "Method",
    "text": "Cost of building lines\n\n\n\n"
},

{
    "location": "objective.html#Objective-1",
    "page": "Objective",
    "title": "Objective",
    "category": "section",
    "text": "Modules = [PowerModels]\nPages   = [\"core/objective.jl\"]\nOrder   = [:function]\nPrivate  = true"
},

{
    "location": "variables.html#",
    "page": "Variables",
    "title": "Variables",
    "category": "page",
    "text": ""
},

{
    "location": "variables.html#PowerModels.getstart",
    "page": "Variables",
    "title": "PowerModels.getstart",
    "category": "Function",
    "text": "extracts the start value\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_active_generation-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_active_generation",
    "category": "Method",
    "text": "variable: pg[j] for j in gen\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_active_line_flow-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_active_line_flow",
    "category": "Method",
    "text": "variable: p[l,i,j] for (l,i,j) in arcs\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_active_line_flow_ne-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_active_line_flow_ne",
    "category": "Method",
    "text": "variable: -ne_branch[l][\"rate_a\"] <= p_ne[l,i,j] <= ne_branch[l][\"rate_a\"] for (l,i,j) in ne_arcs\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_generation-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_generation",
    "category": "Method",
    "text": "generates variables for both active and reactive generation\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_line_flow-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_line_flow",
    "category": "Method",
    "text": "\n\n"
},

{
    "location": "variables.html#PowerModels.variable_line_flow_ne-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_line_flow_ne",
    "category": "Method",
    "text": "generates variables for both active and reactive line_flow_ne\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_line_indicator-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_line_indicator",
    "category": "Method",
    "text": "variable: 0 <= line_z[l] <= 1 for l in branches\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_line_ne-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_line_ne",
    "category": "Method",
    "text": "variable: 0 <= line_ne[l] <= 1 for l in branches\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_phase_angle-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_phase_angle",
    "category": "Method",
    "text": "variable: t[i] for i in buses\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_reactive_generation-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_reactive_generation",
    "category": "Method",
    "text": "variable: qq[j] for j in gen\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_reactive_line_flow-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_reactive_line_flow",
    "category": "Method",
    "text": "variable: q[l,i,j] for (l,i,j) in arcs\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_reactive_line_flow_ne-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_reactive_line_flow_ne",
    "category": "Method",
    "text": "variable: -ne_branch[l][\"rate_a\"] <= q_ne[l,i,j] <= ne_branch[l][\"rate_a\"] for (l,i,j) in ne_arcs\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_voltage_magnitude-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_voltage_magnitude",
    "category": "Method",
    "text": "variable: v[i] for i in buses\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_voltage_magnitude_sqr-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_voltage_magnitude_sqr",
    "category": "Method",
    "text": "variable: w[i] >= 0 for i in buses\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_voltage_magnitude_sqr_from_on_off-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_voltage_magnitude_sqr_from_on_off",
    "category": "Method",
    "text": "variable: 0 <= w_from[l] <= buses[branches[l][\"f_bus\"]][\"vmax\"]^2 for l in branches\n\n\n\n"
},

{
    "location": "variables.html#PowerModels.variable_voltage_magnitude_sqr_to_on_off-Tuple{PowerModels.GenericPowerModel}",
    "page": "Variables",
    "title": "PowerModels.variable_voltage_magnitude_sqr_to_on_off",
    "category": "Method",
    "text": "variable: 0 <= w_to[l] <= buses[branches[l][\"t_bus\"]][\"vmax\"]^2 for l in branches\n\n\n\n"
},

{
    "location": "variables.html#Variables-1",
    "page": "Variables",
    "title": "Variables",
    "category": "section",
    "text": "We provide the following methods to provide a compositional approach for defining common variables used in power flow models. These methods should always be defined over \"GenericPowerModel\".Modules = [PowerModels]\nPages   = [\"core/variable.jl\"]\nOrder   = [:type, :function]\nPrivate  = true"
},

{
    "location": "constraints.html#",
    "page": "Constraints",
    "title": "Constraints",
    "category": "page",
    "text": ""
},

{
    "location": "constraints.html#Constraints-1",
    "page": "Constraints",
    "title": "Constraints",
    "category": "section",
    "text": "CurrentModule = PowerModels"
},

{
    "location": "constraints.html#Constraint-Templates-1",
    "page": "Constraints",
    "title": "Constraint Templates",
    "category": "section",
    "text": "Constraint templates help simplify data wrangling across multiple Power Flow formulations by providing an abstraction layer between the network data and network constraint definitions. The constraint template's job is to extract the required parameters from a given network data structure and pass the data as named arguments to the Power Flow formulations.These templates should be defined over GenericPowerModel and should not refer to model variables. For more details, see the files: core/constraint_template.jl and core/constraint.jl."
},

{
    "location": "constraints.html#PowerModels.constraint_active_gen_setpoint",
    "page": "Constraints",
    "title": "PowerModels.constraint_active_gen_setpoint",
    "category": "Function",
    "text": "\n\npg[i] == pg\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_reactive_gen_setpoint",
    "page": "Constraints",
    "title": "PowerModels.constraint_reactive_gen_setpoint",
    "category": "Function",
    "text": "\n\nqq[i] == qq\n\n\n\ndo nothing, this model does not have reactive variables\n\n\n\n"
},

{
    "location": "constraints.html#Generator-Constraints-1",
    "page": "Constraints",
    "title": "Generator Constraints",
    "category": "section",
    "text": "constraint_active_gen_setpoint\nconstraint_reactive_gen_setpoint"
},

{
    "location": "constraints.html#Bus-Constraints-1",
    "page": "Constraints",
    "title": "Bus Constraints",
    "category": "section",
    "text": ""
},

{
    "location": "constraints.html#PowerModels.constraint_theta_ref",
    "page": "Constraints",
    "title": "PowerModels.constraint_theta_ref",
    "category": "Function",
    "text": "\n\nt[ref_bus] == 0\n\n\n\n\n\nDo nothing, no way to represent this in these variables\n\n\n\nt[ref_bus] == 0\n\n\n\nDo nothing, no way to represent this in these variables\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_voltage_magnitude_setpoint",
    "page": "Constraints",
    "title": "PowerModels.constraint_voltage_magnitude_setpoint",
    "category": "Function",
    "text": "\n\nvm - epsilon <= v[i] <= vm + epsilon\n\n\n\ndo nothing, this model does not have voltage variables\n\n\n\n"
},

{
    "location": "constraints.html#Setpoint-Constraints-1",
    "page": "Constraints",
    "title": "Setpoint Constraints",
    "category": "section",
    "text": "constraint_theta_ref\nconstraint_voltage_magnitude_setpoint"
},

{
    "location": "constraints.html#PowerModels.constraint_kcl_shunt",
    "page": "Constraints",
    "title": "PowerModels.constraint_kcl_shunt",
    "category": "Function",
    "text": "\n\nsum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*v^2\nsum(q[a] for a in bus_arcs) == sum(qg[g] for g in bus_gens) - qd + bs*v^2\n\n\n\n\n\nsum(p[a] for a in bus_arcs) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2\n\n\n\n\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_kcl_shunt_ne",
    "page": "Constraints",
    "title": "PowerModels.constraint_kcl_shunt_ne",
    "category": "Function",
    "text": "\n\nsum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*v^2\nsum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*v^2\n\n\n\n\n\nsum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*1.0^2\n\n\n\nsum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - pd - gs*w[i]\nsum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - qd + bs*w[i]\n\n\n\n"
},

{
    "location": "constraints.html#KCL-Constraints-1",
    "page": "Constraints",
    "title": "KCL Constraints",
    "category": "section",
    "text": "constraint_kcl_shunt\nconstraint_kcl_shunt_ne"
},

{
    "location": "constraints.html#Branch-Constraints-1",
    "page": "Constraints",
    "title": "Branch Constraints",
    "category": "section",
    "text": ""
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_yt_from",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_yt_from",
    "category": "Function",
    "text": "\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[f_idx] == g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))\nq[f_idx] == -(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]))\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[f_idx] == -b*(t[f_bus] - t[t_bus])\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[f_idx] == g/tm*w[f_bus] + (-g*tr+b*ti)/tm*(wr[f_bus,t_bus]) + (-b*tr-g*ti)/tm*(wi[f_bus,t_bus])\nq[f_idx] == -(b+c/2)/tm*w[f_bus] - (-b*tr-g*ti)/tm*(wr[f_bus,t_bus]) + (-g*tr+b*ti)/tm*(wi[f_bus,t_bus])\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_yt_to",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_yt_to",
    "category": "Function",
    "text": "\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[t_idx] == g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))\nq[t_idx] == -(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]))\n\n\n\nDo nothing, this model is symmetric\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[t_idx] == g*w[t_bus] + (-g*tr-b*ti)/tm*(wr[f_bus,t_bus]) + (-b*tr+g*ti)/tm*(-wi[f_bus,t_bus])\nq[t_idx] == -(b+c/2)*w[t_bus] - (-b*tr+g*ti)/tm*(wr[f_bus,t_bus]) + (-g*tr-b*ti)/tm*(-wi[f_bus,t_bus])\n\n\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_y_from",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_y_from",
    "category": "Function",
    "text": "\n\nCreates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)\n\np[f_idx] == g*(v[f_bus]/tr)^2 + -g*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -b*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)\nq[f_idx] == -(b+c/2)*(v[f_bus]/tr)^2 + b*v[f_bus]/tr*v[t_bus]*cos(t[f_bus]-t[t_bus]-as) + -g*v[f_bus]/tr*v[t_bus]*sin(t[f_bus]-t[t_bus]-as)\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_y_to",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_y_to",
    "category": "Function",
    "text": "\n\nCreates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)\n\np[t_idx] == g*v[t_bus]^2 + -g*v[t_bus]*v[f_bus]/tr*cos(t[t_bus]-t[f_bus]+as) + -b*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)\nq_to == -(b+c/2)*v[t_bus]^2 + b*v[t_bus]*v[f_bus]/tr*cos(t[f_bus]-t[t_bus]+as) + -g*v[t_bus]*v[f_bus]/tr*sin(t[t_bus]-t[f_bus]+as)\n\n\n\n"
},

{
    "location": "constraints.html#Ohm's-Law-Constraints-1",
    "page": "Constraints",
    "title": "Ohm's Law Constraints",
    "category": "section",
    "text": "constraint_ohms_yt_from\nconstraint_ohms_yt_to\nconstraint_ohms_y_from\nconstraint_ohms_y_to"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_yt_from_on_off",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_yt_from_on_off",
    "category": "Function",
    "text": "\n\np[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))\nq[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))\n\n\n\n-b*(t[f_bus] - t[t_bus] + t_min*(1-line_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + t_max*(1-line_z[i]))\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\n-b*(t[f_bus] - t[t_bus] + t_min*(1-line_z[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + t_max*(1-line_z[i]))\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[f_idx] ==        g/tm*w_from[i] + (-g*tr+b*ti)/tm*(wr[i]) + (-b*tr-g*ti)/tm*(wi[i])\nq[f_idx] == -(b+c/2)/tm*w_from[i] - (-b*tr-g*ti)/tm*(wr[i]) + (-g*tr+b*ti)/tm*(wi[i])\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_yt_to_on_off",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_yt_to_on_off",
    "category": "Function",
    "text": "\n\np[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))\nq[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))\n\n\n\nDo nothing, this model is symmetric\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[f_idx] + p[t_idx] >= r*( (-b*(t[f_bus] - t[t_bus]))^2 - (-b*(t_m))^2*(1-line_z[i]) )\n\nwhere r = g/(g^2 + b^2) and t_m = max(|t_min|, |t_max|)\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[t_idx] ==        g*w_to[i] + (-g*tr-b*ti)/tm*(wr[i]) + (-b*tr+g*ti)/tm*(-wi[i])\nq[t_idx] == -(b+c/2)*w_to[i] - (-b*tr+g*ti)/tm*(wr[i]) + (-g*tr-b*ti)/tm*(-wi[i])\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_yt_from_ne",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_yt_from_ne",
    "category": "Function",
    "text": "\n\np_ne[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))\nq_ne[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr+b*ti)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus])))\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\n-b*(t[f_bus] - t[t_bus] + t_min*(1-line_ne[i])) <= p_ne[f_idx] <= -b*(t[f_bus] - t[t_bus] + t_max*(1-line_ne[i]))\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[f_idx] == g/tm*w_from_ne[i] + (-g*tr+b*ti)/tm*(wr_ne[i]) + (-b*tr-g*ti)/tm*(wi_ne[i])\nq[f_idx] == -(b+c/2)/tm*w_from_ne[i] - (-b*tr-g*ti)/tm*(wr_ne[i]) + (-g*tr+b*ti)/tm*(wi_ne[i])\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_ohms_yt_to_ne",
    "page": "Constraints",
    "title": "PowerModels.constraint_ohms_yt_to_ne",
    "category": "Function",
    "text": "\n\np_ne[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus])) + (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))\nq_ne[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus])) + (-g*tr-b*ti)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus])))\n\n\n\nDo nothing, this model is symmetric\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np_ne[f_idx] + p_ne[t_idx] >= r*( (-b*(t[f_bus] - t[t_bus]))^2 - (-b*(t_m))^2*(1-line_ne[i]) )\n\nwhere r = g/(g^2 + b^2) and t_m = max(|t_min|, |t_max|)\n\n\n\nCreates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)\n\np[t_idx] == g*w_to_ne[i] + (-g*tr-b*ti)/tm*(wr_ne[i]) + (-b*tr+g*ti)/tm*(-wi_ne[i])\nq[t_idx] == -(b+c/2)*w_to_ne[i] - (-b*tr+g*ti)/tm*(wr_ne[i]) + (-g*tr-b*ti)/tm*(-wi_ne[i])\n\n\n\n"
},

{
    "location": "constraints.html#On/Off-Ohm's-Law-Constraints-1",
    "page": "Constraints",
    "title": "On/Off Ohm's Law Constraints",
    "category": "section",
    "text": "constraint_ohms_yt_from_on_off\nconstraint_ohms_yt_to_on_off\nconstraint_ohms_yt_from_ne\nconstraint_ohms_yt_to_ne"
},

{
    "location": "constraints.html#PowerModels.constraint_power_magnitude_sqr",
    "page": "Constraints",
    "title": "PowerModels.constraint_power_magnitude_sqr",
    "category": "Function",
    "text": "\n\np[f_idx]^2 + q[f_idx]^2 <= w[f_bus]/tm*cm[f_bus,t_bus]\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_power_magnitude_link",
    "page": "Constraints",
    "title": "PowerModels.constraint_power_magnitude_link",
    "category": "Function",
    "text": "\n\ncm[f_bus,t_bus] == (g^2 + b^2)*(w[f_bus]/tm + w[t_bus] - 2*(tr*wr[f_bus,t_bus] + ti*wi[f_bus,t_bus])/tm) - c*q[f_idx] - ((c/2)/tm)^2*w[f_bus]\n\n\n\n"
},

{
    "location": "constraints.html#Current-1",
    "page": "Constraints",
    "title": "Current",
    "category": "section",
    "text": "constraint_power_magnitude_sqr\nconstraint_power_magnitude_link"
},

{
    "location": "constraints.html#PowerModels.constraint_thermal_limit_from",
    "page": "Constraints",
    "title": "PowerModels.constraint_thermal_limit_from",
    "category": "Function",
    "text": "\n\np[f_idx]^2 + q[f_idx]^2 <= rate_a^2\n\n\n\nnorm([p[f_idx]; q[f_idx]]) <= rate_a\n\n\n\n-rate_a <= p[f_idx] <= rate_a\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_thermal_limit_to",
    "page": "Constraints",
    "title": "PowerModels.constraint_thermal_limit_to",
    "category": "Function",
    "text": "\n\np[t_idx]^2 + q[t_idx]^2 <= rate_a^2\n\n\n\nnorm([p[t_idx]; q[t_idx]]) <= rate_a\n\n\n\nDo nothing, this model is symmetric\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_thermal_limit_from_on_off",
    "page": "Constraints",
    "title": "PowerModels.constraint_thermal_limit_from_on_off",
    "category": "Function",
    "text": "\n\np[f_idx]^2 + q[f_idx]^2 <= (rate_a * line_z[i])^2\n\n\n\nGeneric on/off thermal limit constraint\n\n-rate_a*line_z[i] <= p[f_idx] <=  rate_a*line_z[i]\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_thermal_limit_to_on_off",
    "page": "Constraints",
    "title": "PowerModels.constraint_thermal_limit_to_on_off",
    "category": "Function",
    "text": "\n\np[t_idx]^2 + q[t_idx]^2 <= (rate_a * line_z[i])^2\n\n\n\nnothing to do, from handles both sides\n\n\n\n-rate_a*line_z[i] <= p[t_idx] <= rate_a*line_z[i]\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_thermal_limit_from_ne",
    "page": "Constraints",
    "title": "PowerModels.constraint_thermal_limit_from_ne",
    "category": "Function",
    "text": "\n\np_ne[f_idx]^2 + q_ne[f_idx]^2 <= (rate_a * line_ne[i])^2\n\n\n\nGeneric on/off thermal limit constraint\n\n-rate_a*line_ne[i] <= p_ne[f_idx] <=  rate_a*line_ne[i]\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_thermal_limit_to_ne",
    "page": "Constraints",
    "title": "PowerModels.constraint_thermal_limit_to_ne",
    "category": "Function",
    "text": "\n\np_ne[t_idx]^2 + q_ne[t_idx]^2 <= (rate_a * line_ne[i])^2\n\n\n\nnothing to do, from handles both sides\n\n\n\n-rate_a*line_ne[i] <= p_ne[t_idx] <=  rate_a*line_ne[i]\n\n\n\n"
},

{
    "location": "constraints.html#Thermal-Limit-Constraints-1",
    "page": "Constraints",
    "title": "Thermal Limit Constraints",
    "category": "section",
    "text": "constraint_thermal_limit_from\nconstraint_thermal_limit_to\nconstraint_thermal_limit_from_on_off\nconstraint_thermal_limit_to_on_off\nconstraint_thermal_limit_from_ne\nconstraint_thermal_limit_to_ne"
},

{
    "location": "constraints.html#PowerModels.constraint_phase_angle_difference",
    "page": "Constraints",
    "title": "PowerModels.constraint_phase_angle_difference",
    "category": "Function",
    "text": "\n\nt[f_bus] - t[t_bus] <= angmax\nt[f_bus] - t[t_bus] >= angmin\n\n\n\nangmin <= t[f_bus] - t[t_bus] <= angmax\n\n\n\n\n\n\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_phase_angle_difference_on_off",
    "page": "Constraints",
    "title": "PowerModels.constraint_phase_angle_difference_on_off",
    "category": "Function",
    "text": "\n\nangmin <= line_z[i]*(t[f_bus] - t[t_bus]) <= angmax\n\n\n\nangmin*line_z[i] + t_min*(1-line_z[i]) <= t[f_bus] - t[t_bus] <= angmax*line_z[i] + t_max*(1-line_z[i])\n\n\n\nangmin*wr[i] <= wi[i] <= angmax*wr[i]\n\n\n\n"
},

{
    "location": "constraints.html#PowerModels.constraint_phase_angle_difference_ne",
    "page": "Constraints",
    "title": "PowerModels.constraint_phase_angle_difference_ne",
    "category": "Function",
    "text": "\n\nangmin <= line_ne[i]*(t[f_bus] - t[t_bus]) <= angmax\n\n\n\nangmin*line_ne[i] + t_min*(1-line_ne[i]) <= t[f_bus] - t[t_bus] <= angmax*line_ne[i] + t_max*(1-line_ne[i])\n\n\n\nangmin*wr_ne[i] <= wi_ne[i] <= angmax*wr_ne[i]\n\n\n\n"
},

{
    "location": "constraints.html#Phase-Angle-Difference-Constraints-1",
    "page": "Constraints",
    "title": "Phase Angle Difference Constraints",
    "category": "section",
    "text": "constraint_phase_angle_difference\nconstraint_phase_angle_difference_on_off\nconstraint_phase_angle_difference_ne"
},

{
    "location": "constraints.html#PowerModels.constraint_loss_lb",
    "page": "Constraints",
    "title": "PowerModels.constraint_loss_lb",
    "category": "Function",
    "text": "\n\np[f_idx] + p[t_idx] >= 0\nq[f_idx] + q[t_idx] >= -c/2*(v[f_bus]^2/tr^2 + v[t_bus]^2)\n\n\n\n"
},

{
    "location": "constraints.html#Loss-Constraints-1",
    "page": "Constraints",
    "title": "Loss Constraints",
    "category": "section",
    "text": "constraint_loss_lb"
},

{
    "location": "constraints.html#Commonly-Used-Constraints-1",
    "page": "Constraints",
    "title": "Commonly Used Constraints",
    "category": "section",
    "text": "The following methods generally assume that the model contains p and q values for branches line flows and bus flow conservation."
},

{
    "location": "constraints.html#Generic-thermal-limit-constraint-1",
    "page": "Constraints",
    "title": "Generic thermal limit constraint",
    "category": "section",
    "text": "constraint_thermal_limit_from(pm::GenericPowerModel, f_idx, rate_a)\nconstraint_thermal_limit_to(pm::GenericPowerModel, t_idx, rate_a)"
},

{
    "location": "constraints.html#Generic-on/off-thermal-limit-constraint-1",
    "page": "Constraints",
    "title": "Generic on/off thermal limit constraint",
    "category": "section",
    "text": "constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i, f_idx, rate_a)\nconstraint_thermal_limit_to_on_off(pm::GenericPowerModel, i, t_idx, rate_a)\nconstraint_thermal_limit_from_ne(pm::GenericPowerModel, i, f_idx, rate_a)\nconstraint_thermal_limit_to_ne(pm::GenericPowerModel, i, t_idx, rate_a)\nconstraint_active_gen_setpoint(pm::GenericPowerModel, i, pg)\nconstraint_reactive_gen_setpoint(pm::GenericPowerModel, i, qg)"
},

{
    "location": "relaxations.html#",
    "page": "Relaxation Schemes",
    "title": "Relaxation Schemes",
    "category": "page",
    "text": ""
},

{
    "location": "relaxations.html#PowerModels.cut_complex_product_and_angle_difference-Tuple{Any,Any,Any,Any,Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.cut_complex_product_and_angle_difference",
    "category": "Method",
    "text": "In the literature this constraints are called the Lifted Nonlinear Cuts (LNCs)\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_complex_product-Tuple{Any,Any,Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_complex_product",
    "category": "Method",
    "text": "constraint: c^2 + d^2 <= a*b\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_complex_product_on_off-Tuple{Any,Any,Any,Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_complex_product_on_off",
    "category": "Method",
    "text": "c^2 + d^2 <= a*b*getupperbound(z)\nc^2 + d^2 <= getupperbound(a)*b*getupperbound(z)\nc^2 + d^2 <= a*getupperbound(b)*z\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_cos-Tuple{Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_cos",
    "category": "Method",
    "text": "general relaxation of a cosine term\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_equality_on_off-Tuple{Any,Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_equality_on_off",
    "category": "Method",
    "text": "x - getupperbound(x)*(1-z) <= y <= x - getlowerbound(x)*(1-z)\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_product-Tuple{Any,Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_product",
    "category": "Method",
    "text": "general relaxation of binlinear term (McCormick)\n\nz >= getlowerbound(x)*y + getlowerbound(y)*x - getlowerbound(x)*getlowerbound(y)\nz >= getupperbound(x)*y + getupperbound(y)*x - getupperbound(x)*getupperbound(y)\nz <= getlowerbound(x)*y + getupperbound(y)*x - getlowerbound(x)*getupperbound(y)\nz <= getupperbound(x)*y + getlowerbound(y)*x - getupperbound(x)*getlowerbound(y)\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_sin-Tuple{Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_sin",
    "category": "Method",
    "text": "general relaxation of a sin term\n\n\n\n"
},

{
    "location": "relaxations.html#PowerModels.relaxation_sqr-Tuple{Any,Any,Any}",
    "page": "Relaxation Schemes",
    "title": "PowerModels.relaxation_sqr",
    "category": "Method",
    "text": "general relaxation of a square term\n\nx^2 <= y <= (getupperbound(x)+getlowerbound(x))*x - getupperbound(x)*getlowerbound(x)\n\n\n\n"
},

{
    "location": "relaxations.html#Relaxation-Schemes-1",
    "page": "Relaxation Schemes",
    "title": "Relaxation Schemes",
    "category": "section",
    "text": "Modules = [PowerModels]\nPages   = [\"core/relaxation_scheme.jl\"]\nOrder   = [:function]\nPrivate  = true"
},

{
    "location": "parser.html#",
    "page": "File IO",
    "title": "File IO",
    "category": "page",
    "text": ""
},

{
    "location": "parser.html#File-IO-1",
    "page": "File IO",
    "title": "File IO",
    "category": "section",
    "text": "CurrentModule = PowerModels"
},

{
    "location": "parser.html#PowerModels.parse_file",
    "page": "File IO",
    "title": "PowerModels.parse_file",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.parse_json",
    "page": "File IO",
    "title": "PowerModels.parse_json",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#General-Data-Formats-1",
    "page": "File IO",
    "title": "General Data Formats",
    "category": "section",
    "text": "parse_file\nparse_json"
},

{
    "location": "parser.html#PowerModels.parse_matpower",
    "page": "File IO",
    "title": "PowerModels.parse_matpower",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.parse_matpower_data",
    "page": "File IO",
    "title": "PowerModels.parse_matpower_data",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.standardize_cost_order",
    "page": "File IO",
    "title": "PowerModels.standardize_cost_order",
    "category": "Function",
    "text": "ensures all costs functions are quadratic and reverses their order\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.update_branch_transformer_settings",
    "page": "File IO",
    "title": "PowerModels.update_branch_transformer_settings",
    "category": "Function",
    "text": "sets all line transformer taps to 1.0, to simplify line models\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.merge_generator_cost_data",
    "page": "File IO",
    "title": "PowerModels.merge_generator_cost_data",
    "category": "Function",
    "text": "merges generator cost functions into generator data, if costs exist\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.merge_bus_name_data",
    "page": "File IO",
    "title": "PowerModels.merge_bus_name_data",
    "category": "Function",
    "text": "merges bus name data into buses, if names exist\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.parse_cell",
    "page": "File IO",
    "title": "PowerModels.parse_cell",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.parse_matrix",
    "page": "File IO",
    "title": "PowerModels.parse_matrix",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.parse_matlab_data",
    "page": "File IO",
    "title": "PowerModels.parse_matlab_data",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.split_line",
    "page": "File IO",
    "title": "PowerModels.split_line",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.add_line_delimiter",
    "page": "File IO",
    "title": "PowerModels.add_line_delimiter",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.extract_assignment",
    "page": "File IO",
    "title": "PowerModels.extract_assignment",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.extract_mpc_assignment",
    "page": "File IO",
    "title": "PowerModels.extract_mpc_assignment",
    "category": "Function",
    "text": "\n\n"
},

{
    "location": "parser.html#PowerModels.type_value",
    "page": "File IO",
    "title": "PowerModels.type_value",
    "category": "Function",
    "text": "Attempts to determine the type of a string extracted from a matlab file\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.type_array",
    "page": "File IO",
    "title": "PowerModels.type_array",
    "category": "Function",
    "text": "Attempts to determine the type of an array of strings extracted from a matlab file\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.build_typed_dict",
    "page": "File IO",
    "title": "PowerModels.build_typed_dict",
    "category": "Function",
    "text": "takes a list of list of strings and turns it into a list of typed dictionaries\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.extend_case_data",
    "page": "File IO",
    "title": "PowerModels.extend_case_data",
    "category": "Function",
    "text": "extends a give case data with typed dictionary data\n\n\n\n"
},

{
    "location": "parser.html#PowerModels.mp_data_to_pm_data",
    "page": "File IO",
    "title": "PowerModels.mp_data_to_pm_data",
    "category": "Function",
    "text": "converts arrays of objects into a dicts with lookup by \"index\"\n\n\n\n"
},

{
    "location": "parser.html#Matpower-Data-Files-1",
    "page": "File IO",
    "title": "Matpower Data Files",
    "category": "section",
    "text": "The following two methods are the main exported methods for parsing matpower data files:parse_matpower\nparse_matpower_dataWe also provide the following (internal) helper methods:standardize_cost_order\nupdate_branch_transformer_settings\nmerge_generator_cost_data\nmerge_bus_name_data\nparse_cell\nparse_matrix\nparse_matlab_data\nsplit_line\nadd_line_delimiter\nextract_assignment\nextract_mpc_assignment\ntype_value\ntype_array\nbuild_typed_dict\nextend_case_data\nmp_data_to_pm_data"
},

{
    "location": "developer.html#",
    "page": "Developer",
    "title": "Developer",
    "category": "page",
    "text": ""
},

{
    "location": "developer.html#Developer-Documentation-1",
    "page": "Developer",
    "title": "Developer Documentation",
    "category": "section",
    "text": "Nothing yet."
},

{
    "location": "experiment-results.html#",
    "page": "Experiment Results",
    "title": "Experiment Results",
    "category": "page",
    "text": ""
},

{
    "location": "experiment-results.html#PowerModels-Experiment-Results-1",
    "page": "Experiment Results",
    "title": "PowerModels Experiment Results",
    "category": "section",
    "text": "This section presents results of running PowerModel.jl on  collections of established power network test cases from  NESTA. This provides validation of the  PowerModel.jl as well as a results baseline for these test cases. All models were solved using IPOPT."
},

{
    "location": "experiment-results.html#Experiment-Design-1",
    "page": "Experiment Results",
    "title": "Experiment Design",
    "category": "section",
    "text": "This experiment consists of running the following PowerModels commands,result_ac  = run_opf(case, ACPPowerModel, IpoptSolver(tol=1e-6))\nresult_soc = run_opf(case, SOCWRPowerModel, IpoptSolver(tol=1e-6))\nresult_qc  = run_opf(case, QCWRPowerModel, IpoptSolver(tol=1e-6))for each case in the NESTA archive. If the value of result[\"status\"] is :LocalOptimal then the values of result[\"objective\"] and result[\"solve_time\"] are reported, otherwise an err. or -- is displayed.  A value of n.d. indicates that no data was available.   The optimality gap is defined as,soc_gap = 100*(result_ac[\"objective\"] - result_soc[\"objective\"])/result_ac[\"objective\"]It is important to note that the result[\"solve_time\"] value in this experiment includes Julia's JIT time. Excluding the JIT time will reduce the runtime by 2-5 seconds."
},

{
    "location": "experiment-results.html#Software-Versions-1",
    "page": "Experiment Results",
    "title": "Software Versions",
    "category": "section",
    "text": "PowerModels.jl: v0.3.1, 4488d66ae45c2ad523c1514a384ae4cb15242e2bIpopt.jl: v0.2.6, 959b9c67e396a6e2307fc022d26b0d95692ee6a4NESTA: v0.7.0, ce1ecc76f5f6d3afec9fc5e9d23c82862d96667eHardware: Dual Intel 2.10GHz CPUs, 128GB RAM"
},

{
    "location": "experiment-results.html#Typical-Operating-Conditions-(TYP)-1",
    "page": "Experiment Results",
    "title": "Typical Operating Conditions (TYP)",
    "category": "section",
    "text": "Case Name Nodes Edges AC ($/h) QC Gap (%) SOC Gap (%) AC Time (sec.) QC Time (sec.) SOC Time (sec.)\nnesta_case3_lmbd 3 3 5.8126e+03 1.22 1.32 5 2 2\nnesta_case4_gs 4 4 1.5643e+02 0.01 0.01 5 2 2\nnesta_case5_pjm 5 6 1.7552e+04 14.55 14.55 5 2 2\nnesta_case6_c 6 7 2.3206e+01 0.30 0.30 5 2 2\nnesta_case6_ww 6 11 3.1440e+03 0.62 0.63 5 3 2\nnesta_case9_wscc 9 9 5.2967e+03 0.01 0.01 5 2 2\nnesta_case14_ieee 14 20 2.4405e+02 0.11 0.11 5 2 2\nnesta_case24_ieee_rts 24 38 6.3352e+04 0.02 0.02 5 3 3\nnesta_case29_edin 29 99 2.9895e+04 0.10 0.12 5 3 3\nnesta_case30_as 30 41 8.0313e+02 0.06 0.06 5 3 3\nnesta_case30_fsr 30 41 5.7577e+02 0.39 0.39 5 3 3\nnesta_case30_ieee 30 41 2.0497e+02 15.65 15.89 5 2 2\nnesta_case39_epri 39 46 9.6506e+04 0.05 0.05 5 3 3\nnesta_case57_ieee 57 80 1.1433e+03 0.07 0.07 5 3 2\nnesta_case73_ieee_rts 73 120 1.8976e+05 0.04 0.04 5 3 3\nnesta_case89_pegase 89 210 5.8198e+03 0.17 0.17 5 4 3\nnesta_case118_ieee 118 186 3.7186e+03 1.57 1.83 5 3 3\nnesta_case162_ieee_dtc 162 284 4.2302e+03 3.96 4.03 6 4 3\nnesta_case189_edin 189 206 8.4929e+02 0.22 0.22 5 4 3\nnesta_case240_wecc 240 448 7.5136e+04 5.27 5.74 9 12 5\nnesta_case300_ieee 300 411 1.6891e+04 1.18 1.18 6 5 3\nnesta_case1354_pegase 1354 1991 7.4069e+04 0.08 0.08 10 24 23\nnesta_case1397sp_eir 1418 1919 3.8890e+03 0.69 0.94 10 20 8\nnesta_case1394sop_eir 1418 1920 1.3668e+03 0.58 0.83 9 28 9\nnesta_case1460wp_eir 1481 1988 4.6402e+03 0.65 0.89 9 20 10\nnesta_case1888_rte 1888 2531 5.9805e+04 0.38 0.38 41 22 175\nnesta_case1951_rte 1951 2596 8.1738e+04 0.07 0.08 25 26 26\nnesta_case2224_edin 2224 3207 3.8128e+04 6.03 6.09 18 46 15\nnesta_case2383wp_mp 2383 2896 1.8685e+06 0.99 1.05 18 33 18\nnesta_case2736sp_mp 2736 3504 1.3079e+06 0.29 0.30 15 35 15\nnesta_case2737sop_mp 2737 3506 7.7763e+05 0.25 0.26 13 31 12\nnesta_case2746wop_mp 2746 3514 1.2083e+06 0.36 0.37 14 33 13\nnesta_case2746wp_mp 2746 3514 1.6318e+06 0.32 0.33 16 33 15\nnesta_case2848_rte 2848 3776 5.3022e+04 0.08 0.08 86 33 255\nnesta_case2868_rte 2868 3808 7.9795e+04 0.07 0.07 46 44 24\nnesta_case2869_pegase 2869 4582 1.3400e+05 0.09 0.09 17 53 48\nnesta_case3012wp_mp 3012 3572 2.6008e+06 0.98 1.03 21 46 25\nnesta_case3120sp_mp 3120 3693 2.1457e+06 0.54 0.55 20 45 18\nnesta_case3375wp_mp 3375 4161 7.4357e+06 0.50 0.52 26 344 71\nnesta_case6468_rte 6468 9000 8.6829e+04 0.23 0.23 121 202 590\nnesta_case6470_rte 6470 9005 9.8348e+04 0.17 0.18 109 184 99\nnesta_case6495_rte 6495 9019 1.0632e+05 0.49 0.49 74 173 90\nnesta_case6515_rte 6515 9037 1.0987e+05 0.43 0.43 71 143 1240\nnesta_case9241_pegase 9241 16049 3.1591e+05 n.d. 1.64 169 n.d. 586\nnesta_case13659_pegase 13659 20467 3.8612e+05 n.d. 1.43 599 n.d. 5234"
},

{
    "location": "experiment-results.html#Congested-Operating-Conditions-(API)-1",
    "page": "Experiment Results",
    "title": "Congested Operating Conditions (API)",
    "category": "section",
    "text": "Case Name Nodes Edges AC ($/h) QC Gap (%) SOC Gap (%) AC Time (sec.) QC Time (sec.) SOC Time (sec.)\nnesta_case3_lmbd__api 3 3 3.6744e+02 – 2.33 5 2 2\nnesta_case4_gs__api 4 4 7.6667e+02 0.64 0.64 5 2 2\nnesta_case5_pjm__api 5 6 2.9963e+03 0.27 0.27 5 2 2\nnesta_case6_c__api 6 7 8.1387e+02 0.34 0.34 5 2 2\nnesta_case9_wscc__api 9 9 6.5623e+02 0.01 0.01 5 2 2\nnesta_case14_ieee__api 14 20 3.2513e+02 1.27 1.27 5 2 2\nnesta_case24_ieee_rts__api 24 38 6.4267e+03 11.88 20.70 5 3 2\nnesta_case29_edin__api 29 99 2.9529e+05 0.41 0.41 5 4 3\nnesta_case30_as__api 30 41 5.7008e+02 4.64 4.64 5 2 2\nnesta_case30_fsr__api 30 41 3.6656e+02 45.20 45.20 5 3 2\nnesta_case30_ieee__api 30 41 4.1499e+02 0.93 0.93 5 2 2\nnesta_case39_epri__api 39 46 7.4604e+03 2.98 3.00 5 3 2\nnesta_case57_ieee__api 57 80 1.4307e+03 0.21 0.21 5 3 3\nnesta_case73_ieee_rts__api 73 120 1.9995e+04 10.98 14.20 5 3 3\nnesta_case89_pegase__api 89 210 4.2554e+03 19.83 19.88 6 4 3\nnesta_case118_ieee__api 118 186 1.0270e+04 43.50 43.70 6 3 3\nnesta_case162_ieee_dtc__api 162 284 6.1069e+03 1.25 1.34 6 4 3\nnesta_case189_edin__api 189 206 1.9141e+03 1.70 1.70 6 4 3\nnesta_case240_wecc__api 240 448 1.4267e+05 0.58 0.70 10 15 6\nnesta_case300_ieee__api 300 411 1.9868e+04 0.64 0.71 6 5 3\nnesta_case1354_pegase__api 1354 1991 5.2449e+04 0.36 0.36 12 25 10\nnesta_case1397sp_eir__api 1418 1919 6.6658e+03 1.07 1.29 10 21 10\nnesta_case1394sop_eir__api 1418 1920 3.3776e+03 0.37 0.39 12 32 9\nnesta_case1460wp_eir__api 1481 1988 6.4449e+03 1.54 1.69 10 21 10\nnesta_case1888_rte__api 1888 2531 5.8546e+04 0.71 0.71 16 43 16\nnesta_case1951_rte__api 1951 2596 7.5639e+04 0.13 0.14 18 32 118\nnesta_case2224_edin__api 2224 3207 4.4435e+04 2.41 2.42 19 45 15\nnesta_case2383wp_mp__api 2383 2896 2.3489e+04 0.74 0.75 14 49 12\nnesta_case2736sp_mp__api 2736 3504 2.5884e+04 2.18 2.19 15 33 14\nnesta_case2737sop_mp__api 2737 3506 2.1675e+04 0.39 0.40 14 34 15\nnesta_case2746wop_mp__api 2746 3514 2.2803e+04 0.49 0.49 14 34 14\nnesta_case2746wp_mp__api 2746 3514 2.5964e+04 0.58 0.59 14 32 14\nnesta_case2848_rte__api 2848 3776 4.4032e+04 0.23 0.23 37 55 20\nnesta_case2868_rte__api 2868 3808 7.5506e+04 0.20 0.21 47 56 21\nnesta_case2869_pegase__api 2869 4582 9.8415e+04 0.59 0.60 24 60 23\nnesta_case3012wp_mp__api 3012 3572 2.8334e+04 1.04 1.07 16 38 17\nnesta_case3120sp_mp__api 3120 3693 2.3715e+04 2.73 2.75 21 40 17\nnesta_case3375wp_mp__api 3375 4161 4.8939e+04 0.68 0.69 22 341 102\nnesta_case6468_rte__api 6468 9000 6.8149e+04 0.89 0.91 164 195 494\nnesta_case6470_rte__api 6470 9005 9.0583e+04 0.80 0.82 80 168 58\nnesta_case6495_rte__api 6495 9019 8.8944e+04 1.24 1.26 85 166 58\nnesta_case6515_rte__api 6515 9037 9.7217e+04 1.07 1.10 93 166 63\nnesta_case9241_pegase__api 9241 16049 2.3890e+05 n.d. 2.45 191 n.d. 138\nnesta_case13659_pegase__api 13659 20467 3.0284e+05 n.d. 1.73 237 n.d. 257"
},

{
    "location": "experiment-results.html#Small-Angle-Difference-Conditions-(SAD)-1",
    "page": "Experiment Results",
    "title": "Small Angle Difference Conditions (SAD)",
    "category": "section",
    "text": "Case Name Nodes Edges AC ($/h) QC Gap (%) SOC Gap (%) AC Time (sec.) QC Time (sec.) SOC Time (sec.)\nnesta_case3_lmbd__sad 3 3 5.9593e+03 1.00 3.75 5 2 2\nnesta_case4_gs__sad 4 4 3.1584e+02 1.50 4.50 5 2 2\nnesta_case5_pjm__sad 5 6 2.6115e+04 0.99 3.61 5 2 2\nnesta_case6_c__sad 6 7 2.4376e+01 0.43 1.32 5 2 2\nnesta_case6_ww__sad 6 11 3.1463e+03 0.18 0.70 5 3 2\nnesta_case9_wscc__sad 9 9 5.5283e+03 0.51 1.55 5 2 2\nnesta_case14_ieee__sad 14 20 2.4405e+02 0.05 0.07 5 2 2\nnesta_case24_ieee_rts__sad 24 38 7.6943e+04 2.66 9.35 5 3 3\nnesta_case29_edin__sad 29 99 4.1258e+04 16.46 25.90 5 3 3\nnesta_case30_as__sad 30 41 8.9749e+02 2.29 7.87 5 3 2\nnesta_case30_fsr__sad 30 41 5.7679e+02 0.41 0.47 5 3 3\nnesta_case30_ieee__sad 30 41 2.0497e+02 4.17 6.57 5 3 2\nnesta_case39_epri__sad 39 46 9.6745e+04 0.01 0.03 5 3 3\nnesta_case57_ieee__sad 57 80 1.1433e+03 0.05 0.07 5 3 3\nnesta_case73_ieee_rts__sad 73 120 2.2775e+05 2.28 6.53 5 3 3\nnesta_case89_pegase__sad 89 210 5.8198e+03 0.13 0.14 5 3 3\nnesta_case118_ieee__sad 118 186 4.1067e+03 4.46 8.23 5 3 3\nnesta_case162_ieee_dtc__sad 162 284 4.2535e+03 4.31 4.56 6 4 3\nnesta_case189_edin__sad 189 206 8.6482e+02 0.80 0.80 5 4 3\nnesta_case240_wecc__sad 240 448 7.6495e+04 5.17 7.41 10 11 5\nnesta_case300_ieee__sad 300 411 1.6894e+04 1.10 1.17 6 5 3\nnesta_case1354_pegase__sad 1354 1991 7.4070e+04 0.07 0.08 10 19 16\nnesta_case1397sp_eir__sad 1418 1919 4.2378e+03 7.23 7.37 11 35 9\nnesta_case1394sop_eir__sad 1418 1920 1.4493e+03 3.30 4.32 10 26 9\nnesta_case1460wp_eir__sad 1481 1988 5.3370e+03 0.72 0.92 10 19 9\nnesta_case1888_rte__sad 1888 2531 5.9806e+04 0.37 0.38 46 26 178\nnesta_case1951_rte__sad 1951 2596 8.1786e+04 0.11 0.13 28 27 215\nnesta_case2224_edin__sad 2224 3207 3.8265e+04 5.45 6.04 20 45 14\nnesta_case2383wp_mp__sad 2383 2896 1.9165e+06 2.13 3.12 19 33 18\nnesta_case2736sp_mp__sad 2736 3504 1.3294e+06 1.52 1.80 19 35 16\nnesta_case2737sop_mp__sad 2737 3506 7.9266e+05 1.92 2.10 17 34 13\nnesta_case2746wop_mp__sad 2746 3514 1.2344e+06 1.99 2.37 16 28 14\nnesta_case2746wp_mp__sad 2746 3514 1.6674e+06 1.66 2.21 17 32 17\nnesta_case2848_rte__sad 2848 3776 5.3031e+04 0.08 0.09 92 41 26\nnesta_case2868_rte__sad 2868 3808 7.9818e+04 0.08 0.10 92 45 26\nnesta_case2869_pegase__sad 2869 4582 1.3402e+05 0.09 0.10 19 67 123\nnesta_case3012wp_mp__sad 3012 3572 2.6213e+06 1.40 1.61 23 50 20\nnesta_case3120sp_mp__sad 3120 3693 2.1755e+06 1.40 1.59 24 51 20\nnesta_case3375wp_mp__sad 3375 4161 7.4357e+06 0.47 0.52 24 129 260\nnesta_case6468_rte__sad 6468 9000 8.6829e+04 0.21 0.21 155 209 518\nnesta_case6470_rte__sad 6470 9005 9.8357e+04 0.16 0.17 109 139 594\nnesta_case6495_rte__sad 6495 9019 1.0632e+05 0.48 0.49 71 187 92\nnesta_case6515_rte__sad 6515 9037 1.0995e+05 0.49 0.51 79 149 115\nnesta_case9241_pegase__sad 9241 16049 3.1592e+05 n.d. 0.82 153 n.d. 840\nnesta_case13659_pegase__sad 13659 20467 3.8614e+05 n.d. 0.71 505 n.d. 1749"
},

{
    "location": "experiment-results.html#Radial-Topologies-(RAD)-1",
    "page": "Experiment Results",
    "title": "Radial Topologies (RAD)",
    "category": "section",
    "text": "Case Name Nodes Edges AC ($/h) QC Gap (%) SOC Gap (%) AC Time (sec.) QC Time (sec.) SOC Time (sec.)\nnesta_case9_kds__rad 9 8 inf. – – 5 2 2\nnesta_case9_l_kds__rad 9 8 inf. – – 5 2 2\nnesta_case30_fsr_kds__rad 30 29 6.1904e+02 1.74 1.74 5 3 2\nnesta_case30_fsr_l_kds__rad 30 29 4.4584e+02 2.25 2.25 5 3 2\nnesta_case30_kds__rad 30 29 4.7943e+03 11.47 11.47 5 3 2\nnesta_case30_l_kds__rad 30 29 4.5623e+03 33.47 33.47 5 2 2\nnesta_case57_kds__rad 57 56 1.2101e+04 13.58 13.58 5 3 3\nnesta_case57_l_kds__rad 57 56 1.0173e+04 17.43 17.43 5 3 2"
},

{
    "location": "experiment-results.html#Non-Convex-Optimization-Cases-(NCO)-1",
    "page": "Experiment Results",
    "title": "Non-Convex Optimization Cases (NCO)",
    "category": "section",
    "text": "Case Name Nodes Edges AC ($/h) QC Gap (%) SOC Gap (%) AC Time (sec.) QC Time (sec.) SOC Time (sec.)\nnesta_case5_bgm__nco 5 6 1.0823e+03 9.59 10.06 5 2 2\nnesta_case9_bgm__nco 9 9 3.0878e+03 10.85 10.85 5 2 2\nnesta_case9_na_cao__nco 9 9 -2.1243e+02 -15.05 -18.12 5 2 2\nnesta_case9_nb_cao__nco 9 9 -2.4742e+02 -15.62 -19.31 5 2 2\nnesta_case14_s_cao__nco 14 20 9.6704e+03 3.83 3.83 5 2 3\nnesta_case39_1_bgm__nco 39 46 1.1221e+04 3.73 3.74 5 3 3"
},

{
    "location": "experiment-results.html#Utility-Cases-(UTL)-1",
    "page": "Experiment Results",
    "title": "Utility Cases (UTL)",
    "category": "section",
    "text": "Case Name Nodes Edges AC ($/h) QC Gap (%) SOC Gap (%) AC Time (sec.) QC Time (sec.) SOC Time (sec.)\nnesta_case3_cc__utl 3 3 2.0756e+02 1.55 1.62 5 2 2\nnesta_case3_cgs__utl 3 3 1.0171e+02 1.69 1.69 5 2 2\nnesta_case3_ch__utl 3 5 9.8740e+01 100.01 100.01 5 2 2\nnesta_case5_lmbd__utl 5 7 2.3989e+03 0.01 0.01 5 2 2\nnesta_case7_lmbd__utl 7 9 1.0344e+02 0.16 0.16 5 2 2\nnesta_case22_bgm__utl 22 22 4.5388e+03 0.00 0.01 5 2 2\nnesta_case30_test__utl 30 44 6.1510e+02 7.05 7.05 5 3 2"
},

]}
