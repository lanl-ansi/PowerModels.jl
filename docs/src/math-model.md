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
& S^{gl}_k, S^{gu}_k \;\; \forall k \in G \nonumber \\
& c_{2k}, c_{1k}, c_{0k} \;\; \forall k \in G \nonumber \\
& v^l_i, v^u_i \;\; \forall i \in N \nonumber \\
& {S^d}_k \;\; \forall k \in L \nonumber \\
& Y^s_{k} \;\; \forall k \in S \nonumber \\
& Y_{ij}, Y^c_{ij}, Y^c_{ji}, {T}_{ij} \;\; \forall (i,j) \in E \nonumber \\
& {s^u}_{ij}, \theta^{\Delta l}_{ij}, \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \nonumber \\
%
\mbox{variables: } & \nonumber \\
& S^g_k \;\; \forall k\in G \nonumber \\
& V_i \;\; \forall i\in N \nonumber \\
& S_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber \\
%
\mbox{minimize: } & \sum_{k \in G} c_{2k} (\Re(S^g_k))^2 + c_{1k}\Re(S^g_k) + c_{0k} \label{eq_objective}\\
%
\mbox{subject to: } & \nonumber \\
& \angle V_{r} = 0  \;\; \forall r \in R \label{eq_ref_bus}\\
& S^{gl}_k \leq S^g_k \leq S^{gu}_k \;\; \forall k \in G  \label{eq_gen_bounds}\\
& v^l_i \leq |V_i| \leq v^u_i \;\; \forall i \in N \label{eq_voltage_bounds}\\
& \sum_{\substack{k \in G_i}} S^g_k - \sum_{\substack{k \in L_i}} S^d_k - \sum_{\substack{k \in S_i}} Y^s_k |V_i|^2 = \sum_{\substack{(i,j)\in E_i \cup E_i^R}} S_{ij} \;\; \forall i\in N \label{eq_kcl_shunt} \\
& S_{ij} = \left( Y_{ij} + Y^c_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2} - Y^*_{ij} \frac{V_i V^*_j}{{T}_{ij}} \;\; \forall (i,j)\in E \label{eq_power_from}\\
& S_{ji} = \left( Y_{ij} + Y^c_{ji} \right)^* |V_j|^2 - Y^*_{ij} \frac{V^*_i V_j}{{T}^*_{ij}} \;\; \forall (i,j)\in E \label{eq_power_to}\\
& |S_{ij}| \leq s^u_{ij} \;\; \forall (i,j) \in E \cup E^R \label{eq_thermal_limit}\\
& \theta^{\Delta l}_{ij} \leq \angle (V_i V^*_j) \leq \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \label{eq_angle_difference}
%
\end{align}
```

Note that for clarity of this presentation some model variants that PowerModels supports have been omitted (e.g. piecewise linear cost functions and HVDC lines).  Details about these variants is available in the [Matpower](http://www.pserc.cornell.edu/matpower/) documentation.


### Mapping to `constraint_template.jl`
- Eq. $\eqref{eq_objective}$ - `objective_min_fuel_cost`
- Eq. $\eqref{eq_ref_bus}$ - `constraint_theta_ref`
- Eq. $\eqref{eq_gen_bounds}$ - bounds of `variable_generation`
- Eq. $\eqref{eq_voltage_bounds}$ - bounds of `variable_voltage`
- Eq. $\eqref{eq_kcl_shunt}$ - `constraint_kcl_shunt`
- Eq. $\eqref{eq_power_from}$ - `constraint_ohms_yt_from`
- Eq. $\eqref{eq_power_to}$ - `constraint_ohms_yt_to`
- Eq. $\eqref{eq_thermal_limit}$ - `constraint_thermal_limit_from` and `constraint_thermal_limit_to`
- Eq. $\eqref{eq_angle_difference}$ - `constraint_voltage_angle_difference`




## AC Optimal Power Flow for the Branch Flow Model
The same assumptions apply as before. The series impedance is $Z_{ij}=(Y_{ij})^{-1}$.
In comparison  with the BIM, a new variable $I^{s}_{ij}$, representing the current in the direction $i$ to $j$, through the series part of the pi-section, is introduced.
A complete mathematical formulation for a Branch Flow Model is conceived as:

```math
\begin{align}
%
\mbox{variables: } & \nonumber \\
& S^g_k \;\; \forall k\in G \nonumber \\
& V_i \;\; \forall i\in N \nonumber \\
& S_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber \\
& I^{s}_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber \\
%
\mbox{minimize: } & \sum_{k \in G} c_{2k} (\Re(S^g_k))^2 + c_{1k}\Re(S^g_k) + c_{0k} \nonumber\\
%
\mbox{subject to: } & \nonumber \\
& \angle V_{r} = 0  \;\; \forall r \in R \nonumber \\
& S^{gl}_k \leq S^g_k \leq S^{gu}_k \;\; \forall k \in G \nonumber \\
& v^l_i \leq |V_i| \leq v^u_i \;\; \forall i \in N \nonumber\\
& \sum_{\substack{k \in G_i}} S^g_k - \sum_{\substack{k \in L_i}} S^d_k - \sum_{\substack{k \in S_i}} Y^s_k |V_i|^2 = \sum_{\substack{(i,j)\in E_i \cup E_i^R}} S_{ij} \;\; \forall i\in N \nonumber\\
& S_{ij} +  S_{ji} = \left(Y^c_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2} + Z_{ij} |I^{s}_{ij}|^2 +  \left(Y^c_{ji}\right)^* {|V_j|^2}  \;\; \forall (i,j)\in E \label{eq_line_losses} \\
& S_{ij} = S^{s}_{ij} + \left(Y^c_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2}  \;\; \forall (i,j)\in E \label{eq_series_power_flow} \\
& S^{s}_{ij} = \frac{V_i}{{T}_{ij}} (I^{s}_{ij})^*  \;\; \forall (i,j)\in E \label{eq_complex_power_definition} \\
& \frac{V_i}{{T}_{ij}} = V_j + z_{ij} I^{s}_{ij}  \;\; \forall (i,j)\in E \label{eq_ohms_bfm} \\
& |S_{ij}| \leq s^u_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber\\
& \theta^{\Delta l}_{ij} \leq \angle (V_i V^*_j) \leq \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \nonumber
%
\end{align}
```

Note that constraints $\eqref{eq_line_losses} - \eqref{eq_ohms_bfm}$ replace $\eqref{eq_power_from} - \eqref{eq_power_to}$ but the remainder of the problem formulation is identical. Furthermore, the problems have the same feasible set.  

### Mapping to `constraint_template.jl`
- Eq. $\eqref{eq_line_losses}$ - `constraint_flow_losses`
- Eq. $\eqref{eq_series_power_flow}$ - implicit, substituted out
- Eq. $\eqref{eq_complex_power_definition}$ - `constraint_branch_current`
- Eq. $\eqref{eq_ohms_bfm}$ - `constraint_voltage_magnitude_difference`
