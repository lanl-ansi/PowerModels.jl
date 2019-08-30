# PowerModels Utility Functions

This section provides an overview of the some of the utility functions that are implemented as a part of the PowerModels julia package.

## Optimization-Based Bound-Tightening for the AC Optimal Power Flow Problem

To improve the quality of the convex relaxations available in PowerModels and also to obtain tightened bounds on the voltage-magnitude and phase-angle difference variables, an optimization-based bound-tightening algorithm is made available as a function in PowerModels.

```@docs
run_obbt_opf!
```
