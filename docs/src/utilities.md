# PowerModels Utility Functions

This section provides an overview of the some of the utility functions that are implemented as a part of the PowerModels julia package.

## Optimization-Based Bound-Tightening for the AC Optimal Power Flow Problem

To improve the quality of the convex relaxations available in PowerModels and also to obtain tightened bounds on the voltage-magnitude and phase-angle difference variables, an optimization-based bound-tightening algorithm is made available as a function in PowerModels.

```@docs
solve_obbt_opf!
```


## Lazy Line Flow Limits

The following functions are meta-algorithms for solving OPF problems where line flow limit constraints are added iteratively to exploit the property that the majority of line flows constraints will be inactive in the optimal solution.

```@docs
solve_opf_branch_power_cuts
solve_opf_ptdf_branch_power_cuts
```