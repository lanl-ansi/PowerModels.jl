# PowerModels Network Data Format

## The Network Data Dictionary

Internally PowerModels utilizes a dictionary to store network data. The dictionary uses strings as key values so it can be serialized to JSON for algorithmic data exchange.

The data dictionary organization and key names are designed to be mostly consistent with the [Matpower](http://www.pserc.cornell.edu/matpower/) file format and should be familiar to power system researchers, with the notable exceptions that loads and shunts are now split into separate components (see example below), and in the case of `"multinetwork"` data, most often used for time series.

Following the conventions of the InfrastructureModels ecosystem, all PowerModels components have the following standard parameters unless noted otherwise:
- `"index":<int>` the component's unique integer id, which is also its lookup id
- `"status":<int>` a {1,0} flag that determines if the component is active or not, respectively.
- (`"name":<string>`) a human readable name for the component
- (`"source_id":<vector{string}>`) a list of string data forming a unique id from a source data format

The PowerModels network data dictionary structure is roughly as follows:
```json
{
"per_unit":<boolean>,            # A boolean value indicating if the component parameters are in mixed-units or per unit (p.u.)
"baseMVA":<float, MVA>,          # The system wide MVA value for converting between mixed-units and p.u. unit values
("time_elapsed":<float, hours>,) # An amount of time that has passed, used to computing time integrals in storage models
("multinetwork":<boolean>,)      # A boolean value indicating if the data represents a single network or multiple networks (assumed `false` when not present)
("name":<string>,)               # A human readable name for the network data
("description":<string>,)        # A textual description of the network data and any other related notes
("source_type":<string>,)        # The type of source data that generated this data
("source_version":<string>,)     # The version of source data, if applicable
"bus":{
    "1":{
        "va":<float, radians>,  # Voltage angle
        "vm":<float, V p.u.>,   # Voltage magnitude
        "vmin":<float, V p.u.>, # A minimum voltage magnitude
        "vmax":<float, V p.u.>, # A maximum voltage magnitude
        "bus_type":<int>,       # Bus status field inactive if 4, active otherwise; also used in power flow studies
        ...
    },
    "2":{...},
    ...
},
"load":{
    "1":{
        "load_bus":<int>,   # Index of the bus to which the load is attached
        "pd":<float, MW>,   # Active power withdrawn
        "qd":<float, MVar>, # Reactive power withdrawn
        ...
    },
    "2":{...},
    ...
},
"shunt":{
    "1":{
        "shunt_bus":<int>, # Index of the bus to which the shunt is attached
        "gs":<float>,      # Active power withdrawn per voltage p.u.
        "bs":<float>,      # Reactive power withdrawn per voltage p.u.
        ...
    },
    "2":{...},
    ...
},
"gen":{
    "1":{
        "gen_bus":<int>,       # Index of the bus to which the generator is attached
        "pg":<float, MW>,      # Active power injected
        "qg":<float, MVAr>,    # Reactive power injected
        "pmin":<float, MW>,    # Active power lower bound
        "pmax":<float, MW>,    # Active power upper bound
        "qmin":<float, MVAr>,  # Reactive power lower bound
        "qmax":<float, MVAr>,  # Reactive power upper bound
        "gen_status":<int>,    # Status flag for generators
        ("model":<int>,)       # Cost model 1=piecewise linear, 2=polynomial
        ("ncost":<int>,)       # Length of cost model data
        ("cost"<vector{float}, $MWh>:) # Cost model data
        ...
    },
    "2":{...},
    ...
},
"storage":{
    "1":{
        "storage_bus":<int>,             # Index of the bus to which the storage is attached
        "ps":<float, MW>,                # Active power withdrawn
        "qs":<float, MVAr>,              # Reactive power withdrawn
        "energy":<float, MWh>,           # Amount of stored energy
        "energy_rating":<float, MWh>,    # Maximum amount of stored energy
        "charge_rating":<float, MW>,     # Maximum amount of charge per unit time
        "discharge_rating":<float, MW>,  # Maximum amount of discharge per unit time
        "charge_efficiency":<float>,     # Relative efficiency when charging (between 0.0 and 1.0)
        "discharge_efficiency":<float>,  # Relative efficiency when discharging (between 0.0 and 1.0)
        "qmin":<float, MVar>,            # Reactive power lower bound
        "qmax":<float, MVar>,            # Reactive power upper bound
        "r":<float, p.u.>,               # Power inverter resistance
        "x":<float, p.u.>,               # Power inverter reactance
        "p_loss":<float, MW>,            # Active power standby losses
        "q_loss":<float, MVar>,          # Reactive power standby losses
        ("thermal_rating":<float, MVA>,) # Apparent power withdrawn limit
        ("current_rating":<float, MA>,)  # Current magnitude withdrawn limit
        ...
    },
    "2":{...},
    ...
},
"branch":{
    "1":{
        "f_bus":<int>,               # Index of the from bus to which the branch is attached
        "t_bus":<int>,               # Index of the to bus to which the branch is attached
        "br_r":<float, p.u.>,        # Branch series resistance
        "br_x":<float, p.u.>,        # Branch series reactance
        "tap": <float, p.u.>,        # Branch off nominal turns ratio
        "shift": <float, radians>,   # Branch phase shift angle
        "g_fr":<float, p.u.>,        # Line charging conductance at from bus
        "b_fr":<float, p.u.>,        # Line charging susceptance at from bus
        "g_to":<float, p.u.>,        # Line charging conductance at to bus
        "b_to":<float, p.u.>,        # Line charging susceptance at to bus
        "transformer":<boolean>,     # Status flag indicating if the branch is a transformer
        "br_status":<int>,           # Status flag for branches
        ("rate_a":<float, MVA>,)     # Long term thermal line rating
        ("rate_b":<float, MVA>,)     # Short term thermal line rating
        ("rate_c":<float, MVA>,)     # Emergency thermal line rating
        ("angmin": <float, radians>, # Minimum angle difference between the from and to buses
        ("angmax": <float, radians>, # Maximum angle difference between the from and to buses
        ("c_rating_a":<float, MA>,)  # Long term current line rating
        ("c_rating_b":<float, MA>,)  # Short term current line rating
        ("c_rating_c":<float, MA>,)  # Emergency current line rating
        ("pf":<float, MW>,)          # Active power withdrawn at the from bus
        ("qf":<float, MVAr>,)        # Reactive power withdrawn at the from bus
        ("pt":<float, MW>,)          # Active power withdrawn at the to bus
        ("qt":<float, MVAr>,)        # Reactive power withdrawn at the to bus
        ...
    },
    "2":{...},
    ...
},
"dcline":{
    "1":{
        "f_bus":<int>,          # Index of the from bus to which the dcline is attached
        "t_bus":<int>,          # Index of the to bus to which the dcline is attached
        "pminf":<float, MW>,    # Active power lower bound at the from bus
        "pmaxf":<float, MW>,    # Active power upper bound at the from bus
        "qminf":<float, MVAr>,  # Reactive power lower bound at the from bus
        "qmaxf":<float, MVAr>,  # Reactive power upper bound at the from bus
        "pmint":<float, MW>,    # Active power lower bound at the to bus
        "pmaxt":<float, MW>,    # Active power upper bound at the to bus
        "qmint":<float, MVAr>,  # Reactive power lower bound at the to bus
        "qmaxt":<float, MVAr>,  # Reactive power upper bound at the to bus
        "loss0":<float>,        # Constant active power loss term linking the from and to buses
        "loss1":<float>,        # Linear active power loss term linking the from and to buses
        "br_status":<int>,      # Status flag for dclines
        ("pf":<float, MW>,)     # Active power withdrawn at the from bus
        ("qf":<float, MVAr>,)   # Reactive power withdrawn at the from bus
        ("pt":<float, MW>,)     # Active power withdrawn at the to bus
        ("qt":<float, MVAr>,)   # Reactive power withdrawn at the to bus
        ("vf":<float, V p.u.>,) # Voltage set-point at the from bus
        ("vt":<float, V p.u.>,) # Voltage set-point at the to bus
        ("model":<int>,)        # Cost model 1=piecewise linear, 2=polynomial
        ("ncost":<int>,)        # Length of cost model data
        ("cost"<vector{float}, $MWh>:) # Cost model data
        ...
    },
    "2":{...},
    ...
},
"switch":{
    "1":{
        "f_bus":<int>,                   # Index of the from bus to which the switch is attached
        "t_bus":<int>,                   # Index of the to bus to which the switch is attached
        "state":<int>,                   # A {0,1} flag that determines if the switch is open or closed, respectively.
        ("thermal_rating":<float, MVA>,) # Apparent power flow limit
        ("current_rating":<float, MA>,)  # Current magnitude flow limit
        ("psw":<float, MW>,)             # Active power withdrawn at the from bus
        ("qsw":<float, MVar>,)           # Reactive power withdrawn at the from bus
        ...
    },
    "2":{...},
    ...
},
...
}
```

The following commands can be used to explore the network data dictionary generated by a given PTI or Matpower (this example) data file,

```julia
network_data = PowerModels.parse_file("matpower/case3.m")
display(network_data) # raw dictionary
PowerModels.print_summary(network_data) # quick table-like summary
PowerModels.component_table(network_data, "bus", ["vmin", "vmax"]) # component data in matrix form
```

The `print_summary` function generates a table-like text summary of the network data, which is helpful in quickly assessing the values in a data or solution dictionary.  The `component_table` builds a matrix of data for a given component type where there is one row for each component and one column for each requested data field.  The first column of a component table is the component's identifier (i.e. the index).

For a detailed list of all possible parameters refer to the specification document provided with [Matpower](http://www.pserc.cornell.edu/matpower/). The exception to this is that `"load"` and `"shunt"`, containing `"pd"`, `"qd"` and `"gs"`, `"bs"`, respectively, have been added as additional fields. These values are contained in `"bus"` in the original specification.

### Noteworthy Differences from Matpower Data Files

The PowerModels network data dictionary differs from the Matpower format in the following ways,

- All PowerModels components have an `index` parameter, which can be used to uniquely identify that network element.
- All network parameters are in per-unit and angles are in radians.
- All non-transformer branches are given nominal transformer values (i.e. a tap of 1.0 and a shift of 0.0).
- All branches have a `transformer` field indicating if they are a transformer or not.
- Thermal limit (`rate`) and current (`c_rating`) ratings on branches are optional.
- When present, the `gencost` data is incorporated into the `gen` data, the column names remain the same.
- When present, the `dclinecost` data is incorporated into the `dcline` data, the column names remain the same.
- When present, the `bus_names` data is incorporated into the `bus` data under the property `"bus_name"`.
- Special treatment is given to the optional `ne_branch` matrix to support the TNEP problem.
- Load data are split off from `bus` data into `load` data under the same property names.
- Shunt data are split off from `bus` data into `shunt` data under the same property names.

## Working with the Network Data Dictionary

Data exchange via JSON files is ideal for building algorithms, however it is hard to for humans to read and process.  To that end PowerModels provides various helper functions for manipulating the network data dictionary.

The first of these helper functions are `make_per_unit` and `make_mixed_units!`, which convert the units of the data inside a network data dictionary.  The *mixed units* format follows the unit conventions from Matpower and other common power network formats where some of the values are in per unit and others are the true values.  These functions can be used as follows,
```
network_data = PowerModels.parse_file("matpower/case3.m")
PowerModels.print_summary(network_data) # default per-unit form
PowerModels.make_mixed_units!(network_data)
PowerModels.print_summary(network_data) # mixed units form
```

Another useful helper function is `update_data`, which takes two network data dictionaries and updates the values in the first dictionary with the values from the second dictionary.  This is particularly helpful when applying sparse updates to network data.  A good example is using the solution of one computation to update the data in preparation for a second computation, like so,
```
data = PowerModels.parse_file("matpower/case3.m")
opf_result = solve_ac_opf(data, Ipopt.Optimizer)
PowerModels.print_summary(opf_result["solution"])

PowerModels.update_data!(data, opf_result["solution"])
pf_result = solve_ac_pf(data, Ipopt.Optimizer)
PowerModels.print_summary(pf_result["solution"])
```

A variety of helper functions are available for processing the topology of the network.  For example, `connected_components` will compute the collections of buses that are connected by branches (i.e. the network's islands).  By default PowerModels will attempt to solve all of the network components simultaneously.  The `select_largest_component` function can be used to only consider the largest component in the network.  Finally the `propagate_topology_status!` can be used to explicitly deactivate components that are implicitly inactive due to the status of other components (e.g. deactivating branches based on the status of their connecting buses), like so,
```
data = PowerModels.parse_file("matpower/case3.m")
PowerModels.propagate_topology_status!(data)
opf_result = solve_ac_opf(data, Ipopt.Optimizer)
```
The `test/data/matpower/case7_tplgy.m` case provides an example of the kind of component status deductions that can be made.  The `simplify_network!`, `propagate_topology_status!` and `deactivate_isolated_components!` functions can be helpful in diagnosing network models that do not converge or have an infeasible solution.

For details on all of the network data helper functions see, `src/core/data.jl`.


## Working with Matpower Data Files

PowerModels has extensive support for parsing Matpower network files in the `.m` format.

In addition to parsing the standard Matpower parameters, PowerModels also supports extending the standard Matpower format in a number of ways as illustrated by the following examples.  In these examples JSON document fragments are used to indicate the structure of the PowerModel dictionary.

Note that for DC lines, the flow results are returned using the same convention as for the AC lines, i.e. positive values for `p_from`/`q_from `and `p_to`/`q_to` indicating power flow from the 'to' node or 'from' node into the line. This means that w.r.t matpower the sign is identical for `p_from`, but opposite for `q_from`/`p_to`/`q_to`.


### Single Values
Single values are added to the root of the dictionary as follows,

```
mpc.const_float = 4.56
```

becomes

```json
{
"const_float": 4.56
}
```

### Nonstandard Matrices

Nonstandard matrices can be added as follows,

```
mpc.areas = [
    1   1;
    2   3;
];
```

becomes

```json
{
"areas":{
    "1":{
        "index":1,
        "col_1":1,
        "col_2":1
    },
    "2":{
        "index":1,
        "col_1":2,
        "col_2":3
    }
}
}
```

### Column Names

Column names can be given to nonstandard matrices using the following special comment,

```
%column_names%  area    refbus
mpc.areas_named = [
    4   5;
    5   6;
];
```

becomes

```json
{
"areas":{
    "1":{
        "index":1,
        "area":4,
        "refbus":5
    },
    "2":{
        "index":2,
        "area":5,
        "refbus":6
    }
}
}
```

### Standard Matrix Extensions

Finally, if a nonstandard matrix's name extends a current Matpower matrix name with an underscore, then its values will be merged with the original Matpower component data.  Note that this feature requires that the nonstandard matrix has column names and has the same number of rows as the original matrix (similar to the `gencost` matrix in the Matpower format).  For example,

```
%column_names%  rate_i  rate_p
mpc.branch_limit = [
    50.2    45;
    36  60.1;
    12  30;
];
```

becomes

```json
{
"branch":{
    "1":{
        "index":1,
        ...(all pre existing fields)...
        "rate_i":50.2,
        "rate_p":45
    },
    "2":{
        "index":2,
        ...(all pre existing fields)...
        "rate_i":36,
        "rate_p":60.1
    },
    "3":{
        "index":3,
        ...(all pre existing fields)...
        "rate_i":12,
        "rate_p":30
    }
}
}
```

## Working with PTI Data files

PowerModels also has support for parsing PTI network files in the `.raw` format that follow the PSS(R)E v33 specification.  Currently PowerModels supports the following PTI components,

- Buses
- Loads (constant power)
- Fixed Shunts
- Switch Shunts (default configuration)
- Generators
- Branches
- Transformers (two and three winding)
- Two-Terminal HVDC Lines (approximate)
- Voltage Source Converter HVDC Lines (approximate)

In addition to parsing the standard parameters required by PowerModels for calculations, PowerModels also supports parsing additional data fields that are defined by the PSS(R)E specification, but not used by PowerModels directly. This can be achieved via the `import_all` optional keyword argument in `parse_file` when loading a `.raw` file, e.g.

```julia
PowerModels.parse_file("pti/case3.raw"; import_all=true)
```
