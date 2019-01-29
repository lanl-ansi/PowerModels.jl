# Formulation Details

This section provides references to understand the formulations as provided by PowerModels. The list is not meant as a literature discussion, but to give the main starting points to understand the implementation of the formulations.

- Molzahn, D., & Hiskens, I. (forthcoming). A Survey of Relaxations and Approximations of the Power Flow Equations. Foundations and Trends in Electric Energy Systems
- Coffrin, C., & Roald, L. (2018). Convex relaxations in power system optimization: a brief introduction. [Math.OC], 1–5. Retrieved from <http://arxiv.org/abs/1807.07227>
- Coffrin, C., Hijazi, H., & Van Hentenryck, P. (2016). The QC relaxation: a theoretical and computational study on optimal power flow. IEEE Trans. Power Syst., 31(4), 3008–3018. <https://doi.org/10.1109/TPWRS.2015.2463111>


## Notes on the mathematical model for all formulations
PowerModels implements a slightly generalized version of the AC Optimal Power Flow problem from [Matpower](http://www.pserc.cornell.edu/matpower/), as discussed in [The PowerModels Mathematical Model](@ref) and presented [here](https://www.youtube.com/watch?v=j7r4onyiNRQ).

In the next subsections the differences between PowerModels' bus and branch models and those commonly used in the literature are discussed.
Consideration is given to these differences when implementing formulations from articles.

### Standardized branch model
The branch model is standardized as follows:
- An idealized (lossless) transformer at the from side of the branch (immediately on node $i$) with a fixed, complex-value voltage transformation (i.e. tap and shift)
- Followed by a pi-section with complex-valued line shunt admittance, where the from and to side shunt can have different values
- A branch is uniquely defined by a tuple $(l,i,j)$ where $l$ is the line index, $i$ is the from node, and $j$ is the to node.
- Thermal limits are defined in apparent power, and are defined at both ends of a line
- Each branch has a phase angle difference constraint

Nevertheless, in the literature, the following can be observed:
- The to and from side line shunts are equal
- The line shunt admittance is a pure susceptance (equivalent to shunt conductance set to 0)
- A branch in a grid without parallel lines is uniquely defined by a tuple $(i,j)$ where $i$ is the from node, and $j$ is the to node.
- Thermal limits are defined in current (total or series), complex power limits are approximated as a regular polygon, ...
- Thermal limits are defined only at the from (or to) side
- Phase angle difference constraints are not included

Furthermore, "lifted nonlinear cuts" are used to improve the accuracy of PAD constraints for all formulations in the lifted S-W variable space:
- Coffrin, C., Hijazi, H., & Van Hentenryck, P. (2017). Strengthening the SDP relaxation of ac power flows with convex envelopes, bound tightening, and valid inequalities. IEEE Trans. Power Syst., 32(5), 3549–3558. <https://doi.org/10.1109/TPWRS.2016.2634586>


### Standardized bus model
The bus model is standardized as follows:
- A bus defines a complex power balance for all the sets lines, generators, loads, bus shunts connected to it, i.e. one can define multiple load  and shunt  components on each bus $i$

Nevertheless, in the literature, a simplified bus model is often used:
- Only a single (aggregated) load per bus is supported
- Only a single (aggregated) bus shunt per bus is supported


## Exact Non-Convex Models

```@docs
ACPPowerModel
ACRPowerModel
ACTPowerModel
```

## Linear Approximations

```@docs
DCPPowerModel
NFAPowerModel
```

## Quadratic Approximation

```@docs
DCPLLPowerModel
LPACCPowerModel
```

## Quadratic Relaxations

```@docs
SOCWRPowerModel
SOCWRConicPowerModel
QCWRPowerModel
QCWRTriPowerModel
SOCBFPowerModel
SOCBFConicPowerModel
```

## SDP Relaxation

```@docs
SDPWRMPowerModel
SparseSDPWRMPowerModel
```
