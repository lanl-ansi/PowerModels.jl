# PowerModels Result Data Format

## The Result Data Dictionary

PowerModels utilizes a dictionary to organize the results of a run command. The dictionary uses strings as key values so it can be serialized to JSON for algorithmic data exchange.
The data dictionary organization is designed to be consistent with the PowerModels [The Network Data Dictionary](@ref).

At the top level the results data dictionary is structured as follows:

```json
{
"optimizer":<string>,    # name of the Julia class used to solve the model
"termination_status":<TerminationStatusCode enum>, # optimizer status at termination
"primal_status":<ResultStatusCode enum>, # the primal solution status at termination
"dual_status":<ResultStatusCode enum>, # the dual solution status at termination
"solve_time":<float>,    # reported solve time (seconds)
"objective":<float>,     # the final evaluation of the objective function
"objective_lb":<float>,  # the final lower bound of the objective function (if available)
"machine":{...},         # computer hardware information (details below)
"data":{...},            # test case information (details below)
"solution":{...}         # complete solution information (details below)
}
```

### Machine Data

This object provides basic information about the hardware that was
used when the run command was called.

```json
{
"cpu":<string>,    # CPU product name
"memory":<string>  # the amount of system memory (units given)
}
```

### Case Data

This object provides basic information about the network cases that was
used when the run command was called.

```json
{
"name":<string>,      # the name from the network data structure
"bus_count":<int>,    # the number of buses in the network data structure
"branch_count":<int>  # the number of branches in the network data structure
}
```

### Solution Data

The solution object provides detailed information about the solution
produced by the run command.  The solution is organized similarly to
[The Network Data Dictionary](@ref) with the same nested structure and
parameter names, when available.  A network solution most often only includes
a small subset of the data included in the network data.

For example the data for a bus, `data["bus"]["1"]` is structured as follows,

```
{
"bus_i": 1,
"bus_type": 3,
"vm":1.0,
"va":0.0,
...
}
```

A solution specifying a voltage magnitude and angle would for the same case, i.e. `result["solution"]["bus"]["1"]`, would result in,

```
{
"vm":1.12,
"va":-3.59,
}
```

A table-like text summary of the solution data can be generated using the standard data summary function as follows,

```
PowerModels.print_summary(result["solution"])
```

Because the data dictionary and the solution dictionary have the same structure
PowerModels provides an `update_data!` helper function which can be used to
update a data dictionary with the values from a solution as follows,

```
PowerModels.update_data!(data, result["solution"])
```

