# The PowerModels Mathematical Model

As PowerModels implements a variety of power network optimization problems, the implementation is the best reference for precise mathematical formulations.  This section provides a complex number based mathematical specification for a prototypical AC Optimal Power Flow problem, to provide an overview of the typical mathematical models in PowerModels.
## Sets and Parameters

PowerModels implements a slightly generalized version of the AC Optimal Power Flow problem from [Matpower](http://www.pserc.cornell.edu/matpower/).  These generalizations make it possible for PowerModels to more accurately capture industrial transmission network datasets.  The core generalizations are,

- Support for multiple load ($S^d_k$) and shunt ($Y^s_{k}$) components on each bus $i$
- Line charging that supports a conductance and asymmetrical values ($Y^c_{ij}, Y^c_{ji}$)


```math
\begin{align}
%
\mbox{sets:} & \nonumber \\
& N \mbox{ - buses}\nonumber \\
& R \mbox{ - reference buses}\nonumber \\
& E, E^R \mbox{ - branches, forward and reverse orientation} \nonumber \\
& G, G_i \mbox{ - generators and generators at bus $i$} \nonumber \\
& L, L_i \mbox{ - loads and loads at bus $i$} \nonumber \\
& S, S_i \mbox{ - shunts and shunts at bus $i$} \nonumber \\
%
\mbox{data:} & \nonumber \\
& S^{gl}_k, S^{gu}_k \;\; \forall k \in G \nonumber \mbox{ - generator complex power bounds}\\
& c_{2k}, c_{1k}, c_{0k} \;\; \forall k \in G \nonumber  \mbox{ - generator cost components}\\
& v^l_i, v^u_i \;\; \forall i \in N \nonumber \mbox{ - voltage bounds}\\
& S^d_k \;\; \forall k \in L \nonumber \mbox{ - load complex power consumption}\\
& Y^s_{k} \;\; \forall k \in S \nonumber \mbox{ - bus shunt admittance}\\
& Y_{ij}, Y^c_{ij}, Y^c_{ji} \;\; \forall (i,j) \in E \nonumber \mbox{ - branch pi-section parameters}\\
& {T}_{ij} \;\; \forall (i,j) \in E \nonumber \mbox{ - branch complex transformation ratio}\\
& s^u_{ij}  \;\; \forall (i,j) \in E \nonumber \mbox{ - branch apparent power limit}\\
& i^u_{ij}  \;\; \forall (i,j) \in E \nonumber \mbox{ - branch current limit}\\
& \theta^{\Delta l}_{ij}, \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \nonumber \mbox{ - branch voltage angle difference bounds}\\
%
\end{align}
```

## AC Optimal Power Flow

A complete mathematical model is as follows,

```math
\begin{align}
%
\mbox{variables: } & \nonumber \\
& S^g_k \;\; \forall k\in G \mbox{ - generator complex power dispatch} \label{var_generation}\\
& V_i \;\; \forall i\in N \label{var_voltage} \mbox{ - bus complex voltage}\\
& S_{ij} \;\; \forall (i,j) \in E \cup E^R  \label{var_complex_power} \mbox{ - branch complex power flow}\\
%
\mbox{minimize: } & \sum_{k \in G} c_{2k} (\Re(S^g_k))^2 + c_{1k}\Re(S^g_k) + c_{0k} \label{eq_objective}\\
%
\mbox{subject to: } & \nonumber \\
& \angle V_{r} = 0  \;\; \forall r \in R \label{eq_ref_bus}\\
& S^{gl}_k \leq S^g_k \leq S^{gu}_k \;\; \forall k \in G  \label{eq_gen_bounds}\\
& v^l_i \leq |V_i| \leq v^u_i \;\; \forall i \in N \label{eq_voltage_bounds}\\
& \sum_{\substack{k \in G_i}} S^g_k - \sum_{\substack{k \in L_i}} S^d_k - \sum_{\substack{k \in S_i}} (Y^s_k)^* |V_i|^2 = \sum_{\substack{(i,j)\in E_i \cup E_i^R}} S_{ij} \;\; \forall i\in N \label{eq_kcl_shunt} \\
& S_{ij} = \left( Y_{ij} + Y^c_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2} - Y^*_{ij} \frac{V_i V^*_j}{{T}_{ij}} \;\; \forall (i,j)\in E \label{eq_power_from}\\
& S_{ji} = \left( Y_{ij} + Y^c_{ji} \right)^* |V_j|^2 - Y^*_{ij} \frac{V^*_i V_j}{{T}^*_{ij}} \;\; \forall (i,j)\in E \label{eq_power_to}\\
& |S_{ij}| \leq s^u_{ij} \;\; \forall (i,j) \in E \cup E^R \label{eq_thermal_limit}\\
& |S_{ij}| \leq |V_i| i^u_{ij} \;\; \forall (i,j) \in E \cup E^R \label{eq_current_limit}\\
& \theta^{\Delta l}_{ij} \leq \angle (V_i V^*_j) \leq \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \label{eq_angle_difference}
%
\end{align}
```

Note that for clarity of this presentation some model variants that PowerModels supports have been omitted (e.g. piecewise linear cost functions and HVDC lines).  Details about these variants is available in the [Matpower](http://www.pserc.cornell.edu/matpower/) documentation.


### Mapping to PowerModels Functions
- Eq. $\eqref{var_generation}$ - [`variable_gen_power`](@ref)
- Eq. $\eqref{var_voltage}$ - [`variable_bus_voltage`](@ref)
- Eq. $\eqref{var_complex_power}$ - [`variable_branch_power`](@ref)
- Eq. $\eqref{eq_objective}$ - [`objective_min_fuel_cost`](@ref)
- Eq. $\eqref{eq_ref_bus}$ - [`constraint_theta_ref`](@ref)
- Eq. $\eqref{eq_gen_bounds}$ - bounds of [`variable_gen_power`](@ref)
- Eq. $\eqref{eq_voltage_bounds}$ - bounds of [`variable_bus_voltage`](@ref)
- Eq. $\eqref{eq_kcl_shunt}$ - [`constraint_power_balance`](@ref)
- Eq. $\eqref{eq_power_from}$ - [`constraint_ohms_yt_from`](@ref)
- Eq. $\eqref{eq_power_to}$ - [`constraint_ohms_yt_to`](@ref)
- Eq. $\eqref{eq_thermal_limit}$ - [`constraint_thermal_limit_from`](@ref) and [`constraint_thermal_limit_to`](@ref)
- Eq. $\eqref{eq_current_limit}$ - [`constraint_current_limit`](@ref)
- Eq. $\eqref{eq_angle_difference}$ - [`constraint_voltage_angle_difference`](@ref)




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
& I^{s}_{ij} \;\; \forall (i,j) \in E \cup E^R \label{var_branch_current}  \mbox{ - branch complex (series) current}\\
%
\mbox{minimize: } & \sum_{k \in G} c_{2k} (\Re(S^g_k))^2 + c_{1k}\Re(S^g_k) + c_{0k} \nonumber\\
%
\mbox{subject to: } & \nonumber \\
& \angle V_{r} = 0  \;\; \forall r \in R \nonumber \\
& S^{gl}_k \leq S^g_k \leq S^{gu}_k \;\; \forall k \in G \nonumber \\
& v^l_i \leq |V_i| \leq v^u_i \;\; \forall i \in N \nonumber\\
& \sum_{\substack{k \in G_i}} S^g_k - \sum_{\substack{k \in L_i}} S^d_k - \sum_{\substack{k \in S_i}} (Y^s_k)^* |V_i|^2 = \sum_{\substack{(i,j)\in E_i \cup E_i^R}} S_{ij} \;\; \forall i\in N \nonumber\\
& S_{ij} +  S_{ji} = \left(Y^c_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2} + Z_{ij} |I^{s}_{ij}|^2 +  \left(Y^c_{ji}\right)^* {|V_j|^2}  \;\; \forall (i,j)\in E \label{eq_line_losses} \\
& S_{ij} = S^{s}_{ij} + \left(Y^c_{ij}\right)^* \frac{|V_i|^2}{|{T}_{ij}|^2}  \;\; \forall (i,j)\in E \label{eq_series_power_flow} \\
& S^{s}_{ij} = \frac{V_i}{{T}_{ij}} (I^{s}_{ij})^*  \;\; \forall (i,j)\in E \label{eq_complex_power_definition} \\
& \frac{V_i}{{T}_{ij}} = V_j + z_{ij} I^{s}_{ij}  \;\; \forall (i,j)\in E \label{eq_ohms_bfm} \\
& |S_{ij}| \leq s^u_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber\\
& |I_{ij}| \leq i^u_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber\\
& \theta^{\Delta l}_{ij} \leq \angle (V_i V^*_j) \leq \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \nonumber
%
\end{align}
```

Note that constraints $\eqref{eq_line_losses} - \eqref{eq_ohms_bfm}$ replace $\eqref{eq_power_from} - \eqref{eq_power_to}$ but the remainder of the problem formulation is identical. Furthermore, the problems have the same feasible set.  

### Mapping to PowerModels Functions
- Eq. $\eqref{var_branch_current}$ - [`variable_branch_current`](@ref)
- Eq. $\eqref{eq_line_losses}$ - [`constraint_power_losses`](@ref)
- Eq. $\eqref{eq_series_power_flow}$ - implicit, substituted out before implementation
- Eq. $\eqref{eq_complex_power_definition}$ - [`constraint_model_voltage`](@ref)
- Eq. $\eqref{eq_ohms_bfm}$ - [`constraint_voltage_magnitude_difference`](@ref)


## AC Optimal Power Flow in Current-Voltage Variables
A variable $I^{s}_{ij}$, representing the current in the direction $i$ to $j$, through the series part of the pi-section, is used.
The mathematical structure for a current-voltage formulation is conceived as:

```math
\begin{align}
%
\mbox{variables: } & \nonumber \\
& I^g_k \;\; \forall k\in G \nonumber \\
& V_i \;\; \forall i\in N \nonumber \\
& I^{s}_{ij} \;\; \forall (i,j) \in E \cup E^R  \mbox{ - branch complex (series) current}\\
& I_{ij} \;\; \forall (i,j) \in E \cup E^R  \mbox{ - branch complex (total) current} \label{var_total_current}\\
%
\mbox{minimize: } & \sum_{k \in G} c_{2k} (\Re(S^g_k))^2 + c_{1k}\Re(S^g_k) + c_{0k} \nonumber\\
%
\mbox{subject to: } & \nonumber \\
& \angle V_{r} = 0  \;\; \forall r \in R \nonumber \\
& S^{gl}_k \leq V_i (I^g_k)^* \leq S^{gu}_k \;\; \forall k \in G   \label{eq_complex_power_definition_gen}\\
& v^l_i \leq |V_i| \leq v^u_i \;\; \forall i \in N \nonumber\\
& \sum_{\substack{k \in G_i}} I^g_k - \sum_{\substack{k \in L_i}} \left(\frac{S^d_k}{V_i}\right)^{*} - \sum_{\substack{k \in S_i}} Y^s_k V_i = \sum_{\substack{(i,j)\in E_i \cup E_i^R}} I_{ij} \;\; \forall i\in N  \label{eq_kcl_current} \\
& I_{ij} =  \frac{I^{s}_{ij}}{T_{ij}^*} + Y^c_{ij} \frac{V_i}{|T_{ij}|^2}  \;\; \forall (i,j)\in E \label{eq_current_from} \\
& I_{ji} = -I^{s}_{ij} + Y^c_{ji} V_j  \;\; \forall (i,j)\in E \label{eq_current_to} \\
& \frac{V_i}{{T}_{ij}} = V_j + z_{ij} I^{s}_{ij}  \;\; \forall (i,j) \in E \label{eq_ohms_iv} \\
& |V_{i}| |I_{ij}| \leq s^u_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber\\
& |I_{ij}| \leq i^u_{ij} \;\; \forall (i,j) \in E \cup E^R \nonumber\\
& \theta^{\Delta l}_{ij} \leq \angle (V_i V^*_j) \leq \theta^{\Delta u}_{ij} \;\; \forall (i,j) \in E \nonumber
%
\end{align}
```

### Mapping to PowerModels Functions
- Eq. $\eqref{var_total_current}$ - total current flow into a branch on either end [`variable_branch_current`](@ref)
- Eq. $\eqref{eq_complex_power_definition_gen}$  - models active and reactive power range of a generator [`variable_gen_current`](@ref)
- Eq. $\eqref{eq_kcl_current}$  - Kirchhoff's current law in current variables  [`constraint_current_balance`](@ref)
- Eq. $\eqref{eq_current_from}$  - branch from-side current constraint in [`constraint_current_from`](@ref)
- Eq. $\eqref{eq_current_to}$  - branch to-side current constraint in [`constraint_current_to`](@ref)
- Eq. $\eqref{eq_ohms_iv}$  - Ohm's law [`constraint_voltage_drop`](@ref)
