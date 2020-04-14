# Problem Specifications

## Optimal Power Flow (OPF)

### Objective
```julia
objective_min_fuel_cost(pm)
```

### Variables
```julia
variable_bus_voltage(pm)
variable_gen_power_real(pm)
variable_gen_power_imag(pm)
variable_branch_power(pm)
variable_dcline_power(pm)
```

### Constraints
```julia
constraint_model_voltage(pm)
for i in ids(pm, :ref_buses)
    constraint_theta_ref(pm, i)
end
for i in ids(pm, :bus)
    constraint_power_balance_shunt(pm, i)
end
for i in ids(pm, :branch)
    constraint_ohms_yt_from(pm, i)
    constraint_ohms_yt_to(pm, i)

    constraint_voltage_angle_difference(pm, i)

    constraint_thermal_limit_from(pm, i)
    constraint_thermal_limit_to(pm, i)
end
for i in ids(pm, :dcline)
    constraint_dcline_power_losses(pm, i)
end
```

## Optimal Power Flow (OPF) using the Branch Flow Model

### Objective
```julia
objective_min_fuel_cost(pm)
```

### Variables
```julia
variable_bus_voltage(pm)
variable_gen_power_real(pm)
variable_gen_power_imag(pm)
variable_branch_power(pm)
variable_branch_current(pm)
variable_dcline_power(pm)
```

### Constraints
```julia
constraint_model_voltage(pm)
for i in ids(pm, :ref_buses)
    constraint_theta_ref(pm, i)
end
for i in ids(pm, :bus)
    constraint_power_balance_shunt(pm, i)
end
for i in ids(pm, :branch)
    constraint_power_losses(pm, i)
    constraint_voltage_magnitude_difference(pm, i)

    constraint_voltage_angle_difference(pm, i)

    constraint_thermal_limit_from(pm, i)
    constraint_thermal_limit_to(pm, i)
end
for i in ids(pm, :dcline)
    constraint_dcline_power_losses(pm, i)
end
```

## Optimal Transmission Switching (OTS)

### General Assumptions

- if the branch status is `0` in the input, it is out of service and forced to `0` in OTS

### Variables

```julia
variable_branch_indicator(pm)
variable_bus_voltage_on_off(pm)
variable_gen_power(pm)
variable_branch_power(pm)
variable_dcline_power(pm)
```

### Objective

```julia
objective_min_fuel_cost(pm)
```

### Constraints

```julia
constraint_model_voltage_on_off(pm)
for i in ids(pm, :ref_buses)
    constraint_theta_ref(pm, i)
end
for i in ids(pm, :bus)
    constraint_power_balance_shunt(pm, i)
end
for i in ids(pm, :branch)
    constraint_ohms_yt_from_on_off(pm, i)
    constraint_ohms_yt_to_on_off(pm, i)

    constraint_voltage_angle_difference_on_off(pm, i)

    constraint_thermal_limit_from_on_off(pm, i)
    constraint_thermal_limit_to_on_off(pm, i)
end
for i in ids(pm, :dcline)
    constraint_dcline_power_losses(pm, i)
end
```

## Power Flow (PF)

### Assumptions

### Variables
```julia
variable_bus_voltage(pm, bounded = false)
variable_gen_power_real(pm, bounded = false)
variable_gen_power_imag(pm, bounded = false)
variable_branch_power(pm, bounded = false)
variable_dcline_power(pm, bounded = false)
```

### Constraints
```julia
constraint_model_voltage(pm)
for (i,bus) in ref(pm, :ref_buses)
    @assert bus["bus_type"] == 3
    constraint_theta_ref(pm, i)
    constraint_voltage_magnitude_setpoint(pm, i)
end
for (i,bus) in ref(pm, :bus)
    constraint_power_balance_shunt(pm, i)
    # PV Bus Constraints
    if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
        # this assumes inactive generators are filtered out of bus_gens
        @assert bus["bus_type"] == 2
        constraint_voltage_magnitude_setpoint(pm, i)
        for j in ref(pm, :bus_gens, i)
            constraint_gen_setpoint_active(pm, j)
        end
    end
end
for i in ids(pm, :branch)
    constraint_ohms_yt_from(pm, i)
    constraint_ohms_yt_to(pm, i)
end
for (i,dcline) in ref(pm, :dcline)
    constraint_dcline_setpoint_active(pm, i)

    f_bus = ref(pm, :bus)[dcline["f_bus"]]
    if f_bus["bus_type"] == 1
        constraint_voltage_magnitude_setpoint(pm, f_bus["index"])
    end

    t_bus = ref(pm, :bus)[dcline["t_bus"]]
    if t_bus["bus_type"] == 1
        constraint_voltage_magnitude_setpoint(pm, t_bus["index"])
    end
end
```

## Power Flow (PF) using the Branch Flow Model

### Assumptions

### Variables
```julia
variable_bus_voltage(pm, bounded = false)
variable_gen_power_real(pm, bounded = false)
variable_gen_power_imag(pm, bounded = false)
variable_branch_power(pm, bounded = false)
variable_branch_current(pm, bounded = false)
variable_dcline_power(pm, bounded = false)
```

### Constraints
```julia
constraint_model_voltage(pm)
for (i,bus) in ref(pm, :ref_buses)
    @assert bus["bus_type"] == 3
    constraint_theta_ref(pm, i)
    constraint_voltage_magnitude_setpoint(pm, i)
end
for (i,bus) in ref(pm, :bus)
    constraint_power_balance_shunt(pm, i)
    if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
        # this assumes inactive generators are filtered out of bus_gens
        @assert bus["bus_type"] == 2
        constraint_voltage_magnitude_setpoint(pm, i)
        for j in ref(pm, :bus_gens, i)
            constraint_gen_setpoint_active(pm, j)
        end
    end
end
for i in ids(pm, :branch)
    constraint_power_losses(pm, i)
    constraint_voltage_magnitude_difference(pm, i)
end
for (i,dcline) in ref(pm, :dcline)
    constraint_dcline_setpoint_active(pm, i)

    f_bus = ref(pm, :bus)[dcline["f_bus"]]
    if f_bus["bus_type"] == 1
        constraint_voltage_magnitude_setpoint(pm, f_bus["index"])
    end

    t_bus = ref(pm, :bus)[dcline["t_bus"]]
    if t_bus["bus_type"] == 1
        constraint_voltage_magnitude_setpoint(pm, t_bus["index"])
    end
end
```

## Transmission Network Expansion Planning (TNEP)

### Objective
```julia
objective_tnep_cost(pm)
```

### Variables
```julia
variable_ne_branch_indicator(pm)
variable_bus_voltage(pm)
variable_ne_branch_voltage(pm)
variable_gen_power_real(pm)
variable_gen_power_imag(pm)
variable_branch_power(pm)
variable_dcline_power(pm)
variable_ne_branch_power(pm)
```

### Constraints
```julia
constraint_model_voltage(pm)
constraint_ne_model_voltage(pm)
for i in ids(pm, :ref_buses)
    constraint_theta_ref(pm, i)
end
for i in ids(pm, :bus)
    constraint_power_balance_shunt_ne(pm, i)
end
for i in ids(pm, :branch)
    constraint_ohms_yt_from(pm, i)
    constraint_ohms_yt_to(pm, i)

    constraint_voltage_angle_difference(pm, i)

    constraint_thermal_limit_from(pm, i)
    constraint_thermal_limit_to(pm, i)
end
for i in ids(pm, :ne_branch)
    constraint_ne_ohms_yt_from(pm, i)
    constraint_ne_ohms_yt_to(pm, i)

    constraint_ne_voltage_angle_difference(pm, i)

    constraint_ne_thermal_limit_from(pm, i)
    constraint_ne_thermal_limit_to(pm, i)
end
for i in ids(pm, :dcline)
    constraint_dcline_power_losses(pm, i)
end
```
