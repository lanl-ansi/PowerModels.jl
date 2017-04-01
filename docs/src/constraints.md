# Constraint Templates

Constraint templates help simplify data wrangling across multiple Power Flow formulations by providing an abstraction layer between the network data and network constraint definitions. The constraint template's job is to extract the required parameters from a given network data structure and pass the data as named arguments to the Power Flow formulations.

These templates should always be defined over "GenericPowerModel" and should never refer to model variables. In the following subsections, we document the current set of constraint templates implemented in this package.

For more details, see the following file: `core/constraint_template.jl` and `core/constraint.jl`.

## Generator Constraints

```@docs
constraint_active_gen_setpoint(pm::GenericPowerModel, gen)
constraint_reactive_gen_setpoint(pm::GenericPowerModel, gen)
```

## Bus Constraints

### Setpoint Constraints

```@docs
constraint_theta_ref(pm::GenericPowerModel)
constraint_voltage_magnitude_setpoint(pm::GenericPowerModel, bus; epsilon = 0.0)
```

### KCL Constraints

```@docs
constraint_kcl_shunt(pm::GenericPowerModel, bus)
constraint_kcl_shunt_ne(pm::GenericPowerModel, bus)
```

## Branch Constraints

### Ohm's Law Constraints

```@docs
constraint_ohms_yt_from(pm::GenericPowerModel, branch)
constraint_ohms_yt_to(pm::GenericPowerModel, branch)
constraint_ohms_y_from(pm::GenericPowerModel, branch)
constraint_ohms_y_to(pm::GenericPowerModel, branch)
```

### On/Off Ohm's Law Constraints

```@docs
constraint_ohms_yt_from_on_off(pm::GenericPowerModel, branch)
constraint_ohms_yt_to_on_off(pm::GenericPowerModel, branch)
constraint_ohms_yt_from_ne(pm::GenericPowerModel, branch)
constraint_ohms_yt_to_ne(pm::GenericPowerModel, branch)
```

### Current

```@docs
constraint_power_magnitude_sqr(pm::GenericPowerModel, branch)
constraint_power_magnitude_link(pm::GenericPowerModel, branch)
```

### Thermal Limit Constraints

```@docs
constraint_thermal_limit_from(pm::GenericPowerModel, branch; scale = 1.0)
constraint_thermal_limit_to(pm::GenericPowerModel, branch; scale = 1.0)
constraint_thermal_limit_from_on_off(pm::GenericPowerModel, branch)
constraint_thermal_limit_to_on_off(pm::GenericPowerModel, branch)
constraint_thermal_limit_from_ne(pm::GenericPowerModel, branch)
constraint_thermal_limit_to_ne(pm::GenericPowerModel, branch)
```

### Phase Angle Difference Constraints

```@docs
constraint_phase_angle_difference(pm::GenericPowerModel, branch)
constraint_phase_angle_difference_on_off(pm::GenericPowerModel, branch)
constraint_phase_angle_difference_ne(pm::GenericPowerModel, branch)
```

### Loss Constraints

```@docs
constraint_loss_lb(pm::GenericPowerModel, branch)
```

## Commonly Used Constraints
The following methods generally assume that the model contains `p` and `q` values for branches line flows and bus flow conservation.

### Generic thermal limit constraint

```@docs
constraint_thermal_limit_from(pm::GenericPowerModel, f_idx, rate_a)
constraint_thermal_limit_to(pm::GenericPowerModel, t_idx, rate_a)
constraint_thermal_limit_from(pm::GenericPowerModel{<: AbstractConicPowerFormulation}, f_idx, rate_a)
constraint_thermal_limit_to(pm::GenericPowerModel{<: AbstractConicPowerFormulation}, t_idx, rate_a)
```

# Generic on/off thermal limit constraint

```@docs
constraint_thermal_limit_from_on_off(pm::GenericPowerModel, i, f_idx, rate_a)
constraint_thermal_limit_to_on_off(pm::GenericPowerModel, i, t_idx, rate_a)
constraint_thermal_limit_from_ne(pm::GenericPowerModel, i, f_idx, rate_a)
constraint_thermal_limit_to_ne(pm::GenericPowerModel, i, t_idx, rate_a)
constraint_active_gen_setpoint(pm::GenericPowerModel, i, pg)
constraint_reactive_gen_setpoint(pm::GenericPowerModel, i, qg)
```
