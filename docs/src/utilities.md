# PowerModels Utility Functions

This section provides an overview of the some of the utility functions that are implemented as a part of the PowerModels julia package. 

## Optimization-Based Bound-Tightening for the AC Optimal Power Flow Problem

To improve the quality of the convex relaxations available in PowerModels and also to obtain tightened bounds on the voltage-magnitude and phase-angle difference variables, an optimization-based bound-tightening algorithm is made available as a function in PowerModels. The implementation of this function can be found in `src/util/obbt.jl`. The algorithm iteratively tightens the bounds on the voltage magnitude and phase-angle difference variables. The function can be invoked on any convex relaxation which explicitly has these variables. By default, the function uses the QC relaxation for performing bound-tightening. Interested readers are refered to the paper "Strengthening Convex Relaxations with Bound Tightening for Power Network Optimization" for an overview of the algorithm. The function can be invoked as follows:

```julia
data, stats = run_obbt_opf("case3.m", IpoptSolver());
# stats is a dictionary that contains some useful information output by algorithm
# data is a dictionary that contains the parsed network data with tightened bounds
Dict{String,Any} with 19 entries:
  "initial_relaxation_objective" => 5817.91
  "vm_range_init"                => 0.6
  "final_relaxation_objective"   => 5901.96
  "max_td_iteration_time"        => 0.03
  "avg_vm_range_init"            => 0.2
  "final_rel_gap_from_ub"        => NaN
  "run_time"                     => 0.832232
  "model_constructor"            => PowerModels.GenericPowerModel{PowerModels.Q…
  "max_vm_iteration_time"        => 0.06
  "avg_td_range_final"           => 0.436166
  "initial_rel_gap_from_ub"      => Inf
  "upper_bound"                  => Inf
  "vm_range_final"               => 0.6
  "vad_sign_determined"          => 2
  "avg_td_range_init"            => 1.0472
  "avg_vm_range_final"           => 0.2
  "iteration_count"              => 5
  "td_range_init"                => 3.14159
  "td_range_final"               => 1.3085
```

The optional keyword arguments are self-explantory and can also be found in the function's implementation. The keyword arguments with their defaults are as follows:

```
model_constructor = QCWRTriPowerModel,
max_iter = 100, 
time_limit = 3600.0,
upper_bound = Inf,
upper_bound_constraint = false, 
rel_gap_tol = Inf,
min_bound_width = 1e-2,
improvement_tol = 1e-3, 
precision = 4,
termination = :avg,
```

1. The keyword `model_constructor` specifies the relaxation to use for performing bound-tightening. Currently, it supports any relaxation that has explicit voltage magnitude and phase-angle difference variables. 
2. `max_iter` is the keyword that limits the number of bound-tightening iterations to perform. 
3. `time_limit` is the limit on the computation time of the bound-tightening algorithm in seconds.
4. `upper_bound` is a keyword that can be used to specify a local feasible solution objective for the AC Optimal Power Flow problem. 
5. `upper_bound_constraint` is a boolean option that can be used to add an additional constraint to reduce the search space of each of the bound-tightening solves. This option cannot be set to true without specifying an upper bound. 
6. `rel_gap_tol` is a tolerance that is used to terminate the algorithm when the objective value of the relaxation is close to the upper bound specified using the `upper_bound` keyword. 
7. `min_bound_width`, as the name suggests is the variable domain, beyond which point, bound-tightening is not performed for that variable.
8. The bound-tightening algorithm terminates if the improvement in the average or maximum bound improvement, specified using either the `termination = :avg` or the `termination =:max` option, is less than `improvement_tol`. 
9. Finally, `precision` is used to round the tightened bounds to that many decimal digits. 