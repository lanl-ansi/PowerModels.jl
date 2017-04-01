# Constraint Templates

Constraint templates help simplify data wrangling across multiple Power Flow formulations by providing an abstraction layer between the network data and network constraint definitions. The constraint template's job is to extract the required parameters from a given network data structure and pass the data as named arguments to the Power Flow formulations.

For more, see the following files:

- `core/constraint_template.jl` - templates should always be defined over "GenericPowerModel" and should never refer to model variables.

```@docs
constraint_active_gen_setpoint(pm::GenericPowerModel, gen)
constraint_reactive_gen_setpoint(pm::GenericPowerModel, gen)
```

- `core/constraint.jl`: defines commonly used constraints for power flow models. These constraints generally assume that the model contains `p` and `q` values for branches line flows and bus flow conservation.
