# Network Models

## Type Hierarchy
We begin with the top of the hierarchy, where we can distinguish between AC and DC power flow models.
```julia
AbstractACPModel <: AbstractPowerModel
AbstractDCPModel <: AbstractPowerModel
AbstractWRModel <: AbstractPowerModel
AbstractWModel <: AbstractPowerModel
```

## Power Models
Each of these forms can be used as the model parameter for a PowerModel:
```julia
ACPPowerModel <: AbstractACPForm

DCPPowerModel <: AbstractDCPForm

SOCWRPowerModel <: AbstractWRForm
QCRMPowerModel <: AbstractWRForm

SOCBFPowerModel <: AbstractSOCBFModel
```

For details on `AbstractPowerModel`, see the section on [Power Model](@ref).

## User-Defined Abstractions

Consider the class of conic Models for power flow models. One way of modelling them in this package is through the following type hierarchy:
```julia
AbstractConicPowerModel <: AbstractPowerModel
AbstractWRMModel <: AbstractConicPowerModel

AbstractSDPWRMModel <: AbstractWRMModel
mutable struct SDPWRMPowerModel <: AbstractSDPWRMModel @pm_fields end
```

The user-defined abstractions do not have to begin from the root `AbstractPowerModel` abstract type, and can begin from an intermediate abstract type. For example, in the following snippet:
```julia
AbstractDCPLLModel <: AbstractDCPModel

mutable struct DCPLLPowerModel <: AbstractDCPLLModel @pm_fields end
```
