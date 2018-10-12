# Network Formulations

## Type Hierarchy
We begin with the top of the hierarchy, where we can distinguish between AC and DC power flow models.
```julia
AbstractACPForm <: AbstractPowerFormulation
AbstractDCPForm <: AbstractPowerFormulation
AbstractWRForm <: AbstractPowerFormulation
AbstractWForm <: AbstractPowerFormulation
```

From there, different forms for ACP and DCP are possible:
```julia
StandardACPForm <: AbstractACPForm
APIACPForm <: AbstractACPForm

DCPlosslessForm <: AbstractDCPForm

SOCWRForm <: AbstractWRForm
QCWRForm <: AbstractWRForm

SOCBFForm <: AbstractWForm
```

## Power Models
Each of these forms can be used as the type parameter for a PowerModel:
```julia
ACPPowerModel = GenericPowerModel{StandardACPForm}
APIACPPowerModel = GenericPowerModel{APIACPForm}

DCPPowerModel = GenericPowerModel{DCPlosslessForm}

SOCWRPowerModel = GenericPowerModel{SOCWRForm}
QCWRPowerModel = GenericPowerModel{QCWRForm}

SOCBFPowerModel = GenericPowerModel{SOCBFForm}
```

For details on `GenericPowerModel`, see the section on [Power Model](@ref).

## User-Defined Abstractions

Consider the class of conic formulations for power flow models. One way of modelling them in this package is through the following type hierarchy:
```julia
AbstractConicPowerFormulation <: AbstractPowerFormulation
AbstractWRMForm <: AbstractConicPowerFormulation

SDPWRMForm <: AbstractWRMForm
SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}
```

The user-defined abstractions do not have to begin from the root `AbstractPowerFormulation` abstract type, and can begin from an intermediate abstract type. For example, in the following snippet:
```julia
AbstractDCPLLForm <: AbstractDCPForm

StandardDCPLLForm <: AbstractDCPLLForm
DCPLLPowerModel = GenericPowerModel{StandardDCPLLForm}
```
