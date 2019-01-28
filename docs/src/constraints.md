# Constraints

```@meta
CurrentModule = PowerModels
```

## Constraint Templates
Constraint templates help simplify data wrangling across multiple Power Flow formulations by providing an abstraction layer between the network data and network constraint definitions. The constraint template's job is to extract the required parameters from a given network data structure and pass the data as named arguments to the Power Flow formulations.

These templates should be defined over `GenericPowerModel` and should not refer to model variables. For more details, see the files: `core/constraint_template.jl` and `core/constraint.jl`.

## Generator Constraints

```@docs
constraint_active_gen_setpoint
constraint_reactive_gen_setpoint
```

## Bus Constraints

### Setpoint Constraints

```@docs
constraint_theta_ref
constraint_voltage_magnitude_setpoint
```

### KCL Constraints

```@docs
constraint_kcl_shunt
constraint_kcl_shunt_ne
```

## Branch Constraints

### Ohm's Law Constraints

```@docs
constraint_ohms_yt_from
constraint_ohms_yt_to
constraint_ohms_y_from
constraint_ohms_y_to
```

### On/Off Ohm's Law Constraints

```@docs
constraint_ohms_yt_from_on_off
constraint_ohms_yt_to_on_off
constraint_ohms_yt_from_ne
constraint_ohms_yt_to_ne
```

### Current

```@docs
constraint_power_magnitude_sqr
constraint_power_magnitude_link
```

### Thermal Limit Constraints

```@docs
constraint_thermal_limit_from
constraint_thermal_limit_to
constraint_thermal_limit_from_on_off
constraint_thermal_limit_to_on_off
constraint_thermal_limit_from_ne
constraint_thermal_limit_to_ne
```

### Phase Angle Difference Constraints

```@docs
constraint_voltage_angle_difference
constraint_voltage_angle_difference_on_off
constraint_voltage_angle_difference_ne
```

### Loss Constraints

```@docs
constraint_loss_lb
```

## DC Line Constraints
### Network Flow Constraints

```@docs
constraint_dcline
```
