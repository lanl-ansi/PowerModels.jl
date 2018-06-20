# The PowerModels Mathematical Model

As PowerModels implements a variety of power network optimization problems, the implementation is the best reference for precise mathematical formulations.  This section provides a complex number based mathematical specification for a prototypical AC Optimal Power Flow problem, to provide an overview of the typical mathematical models in PowerModels.


## AC Optimal Power Flow

PowerModels implements a slightly generalized version of the AC Optimal Power Flow problem from [Matpower](http://www.pserc.cornell.edu/matpower/).  These generalizations make it possible for PowerModels to more accurately capture industrial transmission network datasets.  The core generalizations are,

- Support for multiple load and shunt components on each bus
- Line charging that supports a conductance and asymmetrical values

A complete mathematical model is as follows,

```math

\begin{align}
%
\mbox{sets:} & \nonumber \\ 
& N \mbox{ - buses}\nonumber \\
& R \mbox{ - refrences buses}\nonumber \\
& E, E^R \mbox{ - branches, forward and reverse orientation} \nonumber \\
& G, G_i \mbox{ - generators and generators at bus $i$} \nonumber \\
& L, L_i \mbox{ - loads and loads at bus $i$} \nonumber \\
& S, S_i \mbox{ - shunts and shunts at bus $i$} \nonumber \\
%
\mbox{data:} & \nonumber \\ 
& {S^{gl}}_k, {S^{gu}}_k \;\; \forall k \in G \nonumber \\
& c_{2k}, c_{1k}, c_{0k} \;\; \forall k \in G \nonumber \\
& {v^l}_i, {v^u}_i \;\; \forall i \in N \nonumber \\
& {S^d}_k \;\; \forall k \in L \nonumber \\
& {Y^s}_{k} \;\; \forall k \in S \nonumber \\
& Y_{ij}, {Y^c}_{ij}, {Y^c}_{ji}, {T}_{ij} \;\; \forall (i,j) \in E \nonumber \\
& {s^u}_{ij}, {\theta^{\Delta l}}_{ij}, {\theta^{\Delta u}}_{ij} \;\; \forall (i,j) \in E \nonumber \\
%
\mbox{variables: } & \nonumber \\
& S^g_k \;\; \forall k\in G \nonumber \\
& V_i \;\; \forall i\in N \nonumber \\
& S_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber \\
%
\mbox{minimize: } & \sum_{k \in G} c_{2k} (\Re(S^g_k))^2 + c_{1k}\Re(S^g_k) + c_{0k} \\
%
\mbox{subject to: } & \nonumber \\
& \angle V_{r} = 0  \;\; \forall r \in R \\
& {S^{gl}}_k \leq S^g_k \leq {S^{gu}}_k \;\; \forall k \in G  \\
& {v^l}_i \leq |V_i| \leq {v^u}_i \;\; \forall i \in N \\
& \sum_{\substack{k \in G_i}} S^g_k - \sum_{\substack{k \in L_i}} {{S^d}_k} - \sum_{\substack{k \in S_i}} {Y^s}_{k} |V_i|^2 = \sum_{\substack{(i,j)\in E_i \cup E_i^R}} S_{ij} \;\; \forall i\in N \\ 
& S_{ij} = \left( Y_{ij} + {Y^c}_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2} - Y^*_{ij} \frac{V_i V^*_j}{{T}_{ij}} \;\; \forall (i,j)\in E \\
& S_{ji} = \left( Y_{ij} + {Y^c}_{ji} \right)^* |V_j|^2 - Y^*_{ij} \frac{V^*_i V_j}{{T}^*_{ij}} \;\; \forall (i,j)\in E \\
& |S_{ij}| \leq {s^u}_{ij} \;\; \forall (i,j) \in E \cup E^R \\
& {\theta^{\Delta l}}_{ij} \leq \angle (V_i V^*_j) \leq {\theta^{\Delta u}}_{ij} \;\; \forall (i,j) \in E
%
\end{align}
```

Note that for clarity of this presentation some model variants that PowerModels supports have been omitted (e.g. piecewise linear cost functions and HVDC lines).  Details about these variants is available in the [Matpower](http://www.pserc.cornell.edu/matpower/) documentation.

