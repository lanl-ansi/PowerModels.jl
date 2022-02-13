# Power Flow Computations

The typical goal of PowerModels is to build a JuMP model that is used to solve
power network optimization problems.  The JuMP model abstraction enables
PowerModels to have state-of-the-art performance on a wide range of problem
formulations including those with discrete variables and complex non-linear
constraints, such as semi-definite cones.  That said, for the specific case of
power flow computations, in some specific applications performance gains can
be had by avoiding the JuMP model abstraction and solving the problem more
directly.  To that end, PowerModels includes Julia-native solvers
for AC power flow in polar voltage coordinates and the DC power flow approximation.
This section provides an overview of the different power flow options that are
available in PowerModels and under what circumstances they may be beneficial.


## Generic Power Flow

The general purpose power flow solver in PowerModels is,

```@docs
solve_pf
```

This function builds a JuMP model for a wide variety of the power flow formulations
supported by PowerModels.  For example it supports,
* `ACPPowerModel` - a non-convex nonlinear AC power flow using complex voltages in polar coordinates
* `ACRPowerModel` - a non-convex nonlinear AC power flow using complex voltages in rectangular coordinates
* `SOCWRPowerModel` - a convex quadratic relaxation of the power flow problem
* `DCPPowerModel` - a linear DC approximation of the power flow problem
The typical `ACPPowerModel` and `DCPPowerModel` formulations are available via
the shorthand form `solve_ac_pf` and `solve_dc_pf` respectively.

The `solve_pf` solution method is both formulation and solver agnostic and
can leverage the wide range of solvers that are available in the JuMP
ecosystem.  Many of these solvers are commercial-grade, which in turn makes
`solve_pf` the most reliable power flow solution method in PowerModels.

!!! note
    Use of `solve_pf` is highly recommended over the other solution methods for
    increased robustness.  Applications that benefit from the Julia native
    solution methods are an exception to this general rule.


### Warm Starting

In some applications an initial guess of the power flow solution may be
available.  In such a case, this information may be able to decrease a solver's
time to convergence, especial when solving systems of nonlinear equations.
The `_start` postfix can be used in the network data to initialize the solver's
variables and provide a suitable solution guess.  The most common values are
as follows,

For each generator,
* `pg_start` - active power injection starting point
* `qg_start` - reactive power injection starting point

For each bus,
* `vm_start` - voltage magnitude starting point for the `ACPPowerModel` model
* `va_start` - voltage angle starting point for the `ACPPowerModel` model
* `vr_start` - real voltage starting point for the `ACRPowerModel` model
* `vi_start` - imaginary voltage starting point for the `ACRPowerModel` model

The following helper function can be used to use the solution point in the
network data as the starting point for `solve_ac_pf`.
```@docs
set_ac_pf_start_values!
```

!!! warning
    Warm starting a solver is a very delicate task and can easily result in
    degraded performance.  Using PowerModels' default flat-start values is
    recommended before experimenting with warm starting a solver.


## Native AC Power Flow

The AC Power Flow problem is ubiquitous in power system analysis.
The problem requires solving a system of nonlinear equations, usually via a
Newton-Raphson type of algorithm.  In PowerModels, the package
[NLSolve](https://github.com/JuliaNLSolvers/NLsolve.jl) is used for solving
this system of nonlinear equations.  NLsolve provides a variety of established
solution methods.  The following function is used to solve AC Power Flow problem
with voltages in polar coordinates with NLsolve.
```@docs
compute_ac_pf
```
`compute_ac_pf` will typically provide an identical result to `solve_ac_pf`.
However, the existence of solution degeneracy around generator injection
assignments and multiple power flow solutions can yield different results.
The primary advantage of `compute_ac_pf` over `solve_ac_pf` is that it does not
require building a JuMP model.  If the initial point for the AC Power Flow
solution is near-feasible then `compute_ac_pf` can result in a significant
runtime saving by converging quickly and reducing data-wrangling and memory
allocation overheads.  This initial guess is provided using the standard
`_start` values.  The `set_ac_pf_start_values!` function provides a convenient
way of setting a suitable starting point.

!!! tip
    If `compute_ac_pf` fails to converge try `solve_ac_pf` instead.


## Native DC Power Flow

At its core the DC Power Flow problem simply requires solving a system of 
linear equations.  This can be done natively in Julia via the `\` operator.
The following function can be used to solve a DC Power Flow using Julia's
built-in linear systems solvers.
```@docs
compute_dc_pf
```
The `compute_dc_pf` method should provide identical results to `solve_dc_pf`.
The primary advantage of `compute_dc_pf` over `solve_dc_pf` is that it does not
require building a JuMP model.  This results in significant memory saving and
marginal performance saving due to reduced data-wrangling overhead.  The
primary use-case of this model is to compute the voltage angle values from
a collection of bus injections when working with a formulation that does not
explicitly model these values, such as a PTDF or LODF formulation.
The [`solve_opf_ptdf_branch_power_cuts`](@ref) utility function provides an example of how `compute_dc_pf` is typically used.

This solver does not support warm starting.


## Branch Flow Values

By default none of the Power Flow solvers produce branch flow values.
If needed, these can be computed with the network data functions,
```@docs
calc_branch_flow_ac
calc_branch_flow_dc
```
Both of these methods require a complete network data with a valid voltage solution
for computing the branch flows.  For example, one common work flow to recover
branch flow values is,
```julia
result = solve_ac_pf(network, ...)
# check that the solver converged
update_data!(network, result["solution"])
flows = calc_branch_flow_ac(network)
update_data!(network, flows)
```


## Network Admittance Matrix

Internally `compute_ac_pf` and `compute_dc_pf` utilize an admittance matrix
representation of the network data, which may be useful in other contexts.
The foundational type for both representations is `AdmittanceMatrix{T}`.
```@docs
AdmittanceMatrix
```
In the case of an full admittance matrix and simplified susceptance the type is 
`AdmittanceMatrix{Complex{Float64}}` and `AdmittanceMatrix{Float64}`, respectively.

The following functions can be used to compute the admittance matrix and
susceptance matrix from PowerModels network data.
```@docs
calc_admittance_matrix
calc_susceptance_matrix
```


