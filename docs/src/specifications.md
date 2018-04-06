# Problem Specifications

## Optimal Power Flow (OPF)

### Objective
```julia
objective_min_fuel_cost(pm)
```

### Variables
```julia
variable_voltage(pm)
variable_active_generation(pm)
variable_reactive_generation(pm)
variable_branch_flow(pm)
variable_dcline_flow(pm)
```

### Constraints
```julia
constraint_theta_ref(pm)
constraint_voltage(pm)
for (i,bus) in pm.ref[:bus]
    constraint_kcl_shunt(pm, bus)
end
for (i,branch) in pm.ref[:branch]
    constraint_ohms_yt_from(pm, branch)
    constraint_ohms_yt_to(pm, branch)

    constraint_voltage_angle_difference(pm, branch)

    constraint_thermal_limit_from(pm, branch)
    constraint_thermal_limit_to(pm, branch)
end
for (i,dcline) in pm.ref[:dcline]
    constraint_dcline(pm, dcline)
end
```

## Optimal Power Flow (OPF) using the Branch Flow Model

### Objective
```julia
objective_min_fuel_cost(pm)
```

### Variables
```julia
variable_voltage(pm)
variable_active_generation(pm)
variable_reactive_generation(pm)
variable_branch_flow(pm)
variable_branch_current(pm)
variable_dcline_flow(pm)
```

### Constraints
```julia
constraint_theta_ref(pm)
constraint_voltage(pm)
for (i,bus) in pm.ref[:bus]
    constraint_kcl_shunt(pm, bus)
end
for (i,branch) in pm.ref[:branch]
    constraint_flow_losses(pm, branch)
    constraint_voltage_magnitude_difference(pm, branch)
    constraint_branch_current(pm, branch)

    constraint_voltage_angle_difference(pm, branch)

    constraint_thermal_limit_from(pm, branch)
    constraint_thermal_limit_to(pm, branch)
end
for (i,dcline) in pm.ref[:dcline]
    constraint_dcline(pm, dcline)
end
```

## Optimal Transmission Switching (OTS)

### General Assumptions

- if the branch status is `0` in the input, it is out of service and forced to `0` in OTS
- the network will be maintained as one connected component (i.e. at least `n-1` edges)

### Variables

```julia
variable_branch_indicator(pm)
variable_voltage_on_off(pm)
variable_active_generation(pm)
variable_reactive_generation(pm)
variable_branch_flow(pm)
variable_dcline_flow(pm)
```

### Objective

```julia
objective_min_fuel_cost(pm)
```

### Constraints

```julia
constraint_theta_ref(pm)
constraint_voltage_on_off(pm)
for (i,bus) in pm.ref[:bus]
    constraint_kcl_shunt(pm, bus)
end
for (i,branch) in pm.ref[:branch]
    constraint_ohms_yt_from_on_off(pm, branch)
    constraint_ohms_yt_to_on_off(pm, branch)

    constraint_voltage_angle_difference_on_off(pm, branch)

    constraint_thermal_limit_from_on_off(pm, branch)
    constraint_thermal_limit_to_on_off(pm, branch)
end
for (i,dcline) in pm.ref[:dcline]
    constraint_dcline(pm, dcline)
end
```

## Power Flow (PF)

### Assumptions

### Variables
```julia
variable_voltage(pm, bounded = false)
variable_active_generation(pm, bounded = false)
variable_reactive_generation(pm, bounded = false)
variable_branch_flow(pm, bounded = false)
variable_dcline_flow(pm, bounded = false)
```

### Constraints
```julia
constraint_theta_ref(pm)
constraint_voltage_magnitude_setpoint(pm, pm.ref[:bus][pm.ref[:ref_bus]])
constraint_voltage(pm)


for (i,bus) in pm.ref[:bus]
    constraint_kcl_shunt(pm, bus)

    # PV Bus Constraints
    if length(pm.ref[:bus_gens][i]) > 0 && i != pm.ref[:ref_bus]
        # this assumes inactive generators are filtered out of bus_gens
        @assert bus["bus_type"] == 2

        constraint_voltage_magnitude_setpoint(pm, bus)
        for j in pm.ref[:bus_gens][i]
            constraint_active_gen_setpoint(pm, pm.ref[:gen][j])
        end
    end
end

for (i,branch) in pm.ref[:branch]
    constraint_ohms_yt_from(pm, branch)
    constraint_ohms_yt_to(pm, branch)
end
for (i,dcline) in pm.ref[:dcline]
    constraint_active_dcline_setpoint(pm, dcline)
end
```


## Power Flow (PF) using the Branch Flow Model

### Assumptions

### Variables
```julia
variable_voltage(pm, bounded = false)
variable_active_generation(pm, bounded = false)
variable_reactive_generation(pm, bounded = false)
variable_branch_flow(pm, bounded = false)
constraint_branch_current(pm, bounded = false)
variable_branch_current(pm, bounded = false)
```

### Constraints
```julia
constraint_theta_ref(pm)
constraint_voltage_magnitude_setpoint(pm, pm.ref[:bus][pm.ref[:ref_bus]])
constraint_voltage(pm)


for (i,bus) in pm.ref[:bus]
    constraint_kcl_shunt(pm, bus)

    # PV Bus Constraints
    if length(pm.ref[:bus_gens][i]) > 0 && i != pm.ref[:ref_bus]
        # this assumes inactive generators are filtered out of bus_gens
        @assert bus["bus_type"] == 2

        constraint_voltage_magnitude_setpoint(pm, bus)
        for j in pm.ref[:bus_gens][i]
            constraint_active_gen_setpoint(pm, pm.ref[:gen][j])
        end
    end
end

for (i,branch) in pm.ref[:branch]
    constraint_flow_losses(pm, branch)
    constraint_voltage_magnitude_difference(pm, branch)
    constraint_branch_current(pm, branch)
end
for (i,dcline) in pm.ref[:dcline]
    constraint_active_dcline_setpoint(pm, dcline)
end
```

## Transmission Network Expansion Planning (TNEP)

### Objective
```julia
objective_tnep_cost(pm)
```

### Variables
```julia
variable_branch_ne(pm)
variable_voltage(pm)
variable_voltage_ne(pm)
variable_active_generation(pm)
variable_reactive_generation(pm)
variable_branch_flow(pm)
variable_dcline_flow(pm)
variable_branch_flow_ne(pm)
```

### Constraints
```julia
constraint_theta_ref(pm)
constraint_voltage(pm)
constraint_voltage_ne(pm)

for (i,bus) in pm.ref[:bus]
    constraint_kcl_shunt_ne(pm, bus)
end

for (i,branch) in pm.ref[:branch]
    constraint_ohms_yt_from(pm, branch)
    constraint_ohms_yt_to(pm, branch)

    constraint_voltage_angle_difference(pm, branch)

    constraint_thermal_limit_from(pm, branch)
    constraint_thermal_limit_to(pm, branch)
end

for (i,branch) in pm.ref[:ne_branch]
    constraint_ohms_yt_from_ne(pm, branch)
    constraint_ohms_yt_to_ne(pm, branch)

    constraint_voltage_angle_difference_ne(pm, branch)

    constraint_thermal_limit_from_ne(pm, branch)
    constraint_thermal_limit_to_ne(pm, branch)
end
for (i,dcline) in pm.ref[:dcline]
    constraint_dcline(pm, dcline)
end
```
