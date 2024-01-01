# Objective

PowerModels includes support for cost functions provided as either univariate polynomials or piecewise linear functions.
These functions are encoded in the generator and dcline components following the conventions of the [Matpower](http://www.pserc.cornell.edu/matpower/) data format.
The implementation of the piecewise linear cost functions uses an auxiliary variable implementation often referred to as the $\lambda$ formulation.
Additional information about this formulation and why it is used can be found in this [technical report](https://arxiv.org/abs/2005.14087).

The objective functions that include the term `fuel_and_flow` capture cost functions on both generator and dcline components, while the names only including the term `fuel` work exclusively on generator components and ignore any cost data relating to dcline components.


```@autodocs
Modules = [PowerModels]
Pages   = ["core/objective.jl"]
Order   = [:function]
Private  = true
```
