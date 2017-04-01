# Variables

We provide the following methods to provide a compositional approach for defining common variables used in power flow models. These methods should always be defined over "GenericPowerModel".

```@docs
variable_phase_angle(pm::GenericPowerModel; bounded = true)
variable_voltage_magnitude(pm::GenericPowerModel; bounded = true)
variable_voltage_magnitude_sqr(pm::GenericPowerModel; bounded = true)
variable_voltage_magnitude_sqr_from_on_off(pm::GenericPowerModel)
variable_voltage_magnitude_sqr_to_on_off(pm::GenericPowerModel)
variable_active_generation(pm::GenericPowerModel; bounded = true)
variable_reactive_generation(pm::GenericPowerModel; bounded = true)
variable_line_flow(pm::GenericPowerModel; kwargs...)
variable_active_line_flow(pm::GenericPowerModel; bounded = true)
variable_reactive_line_flow(pm::GenericPowerModel; bounded = true)
variable_line_flow_ne(pm::GenericPowerModel; kwargs...)
variable_active_line_flow_ne(pm::GenericPowerModel)
variable_reactive_line_flow_ne(pm::GenericPowerModel)
variable_line_indicator(pm::GenericPowerModel)
variable_line_ne(pm::GenericPowerModel)
```
