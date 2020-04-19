# Constraints

```@meta
CurrentModule = PowerModels
```

## Constraint Templates
Constraint templates help simplify data wrangling across multiple Power Flow formulations by providing an abstraction layer between the network data and network constraint definitions. The constraint template's job is to extract the required parameters from a given network data structure and pass the data as named arguments to the Power Flow formulations.

These templates should be defined over `AbstractPowerModel` and should not refer to model variables. For more details, see the files: `core/constraint_template.jl` and `core/constraint.jl` (`core/constraint_template.jl` provides higher level APIs, and pulls out index information from the data dictionaries, before calling out to methods defined in `core/constraint.jl`).

## Voltage Constraints

```@docs
constraint_model_voltage
constraint_model_voltage_on_off
constraint_ne_model_voltage
```

## Generator Constraints

```@docs
constraint_gen_setpoint_active
constraint_gen_setpoint_reactive
```

## Bus Constraints

### Setpoint Constraints

```@docs
constraint_theta_ref
constraint_voltage_magnitude_setpoint
```

### Power Balance Constraints

```@docs
constraint_power_balance
constraint_power_balance_ls
constraint_ne_power_balance
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
constraint_ne_ohms_yt_from
constraint_ne_ohms_yt_to
```

### Current

```@docs
constraint_current_balance
constraint_power_magnitude_sqr
constraint_power_magnitude_sqr_on_off
constraint_power_magnitude_link
constraint_power_magnitude_link_on_off
```

### Thermal Limit Constraints

```@docs
constraint_thermal_limit_from
constraint_thermal_limit_to
constraint_thermal_limit_from_on_off
constraint_thermal_limit_to_on_off
constraint_ne_thermal_limit_from
constraint_ne_thermal_limit_to
```

### Current Limit Constraints

```@docs
constraint_current_limit
constraint_current_to
constraint_current_from
```

### Phase Angle Difference Constraints

```@docs
constraint_voltage_angle_difference
constraint_voltage_angle_difference_on_off
constraint_ne_voltage_angle_difference
```

### Loss Constraints

```@docs
constraint_power_losses
constraint_power_losses_lb
constraint_voltage_magnitude_difference
constraint_voltage_drop
```

### Storage Constraints

```@docs
constraint_storage_thermal_limit
constraint_storage_current_limit
constraint_storage_complementarity_nl
constraint_storage_complementarity_mi
constraint_storage_losses
constraint_storage_state_initial
constraint_storage_state
```

## DC Line Constraints

```@docs
constraint_dcline_power_losses
constraint_dcline_setpoint_active
```
