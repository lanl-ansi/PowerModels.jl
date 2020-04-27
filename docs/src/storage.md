# PowerModels' Storage Component

In addition to the standard transmission network components (e.g. bus, load, generator, branch, ...) PowerModels also includes a generic storage component, which can be configured to model a variety of storage devices.  This section provides a brief overview of the storage component's data and mathematical model.


## Storage Data Model

When parsing a matpower file with storage information, 
```julia
data = PowerModels.parse_file("matpower/case5_strg.m")
```
the storage information can be retrieved via the `"storage"` keyword in the `data` dictionary. They will be correspondingly rendered when `PowerModels.print_summary(data)` or `PowerModels.component_table(data, "storage", <columns>)` is called.

The list of columns for the generic storage model is roughly as follows,
```json
{
  "index":<int>,
  "storage_bus":<int>,
  "ps":<float, MW>,
  "qs":<float, MVAr>,
  "energy":<float, MWh>,
  "energy_rating":<float, MWh>,
  "charge_rating":<float, MW>,
  "discharge_rating":<float, MW>,
  "charge_efficiency":<float>,
  "discharge_efficiency":<float>,
  ("thermal_rating":<float, MVA>,)
  ("current_rating":<float, MA>,)
  "qmin":<float, MVar>,
  "qmax":<float, MVar>,
  "r":<float, p.u.>,
  "x":<float, p.u.>,
  "p_loss":<float, MW>,
  "q_loss":<float, MVar>,
  "status":<int>,
}
```
All of these quantities should be positive except for `qmin`,`p_loss` and `q_loss`, which can be negative.  The `efficiency` parameters are unit-less scalars in the range of 1.0 and 0.0.  By default, all of these quantities are used in per unit inside PowerModels.  The units indicated here are only used by PowerModels' mixed-unit representation and the extended Matpower network format.

Note that the optional `thermal_rating` and `current_rating` parameters are applied at the point of coupling to the network while the other ratings are internal to the storage device.

In addition to these component parameters, PowerModels also requires a global parameter `time_elapsed` (in hours) to specify how active power is converted into units of energy as the storage device is charged or discharged.

PowerModels' storage components can be added to Matpower data files as follows,
```matlab
% hours
mpc.time_elapsed = 1.0

%% storage data
%   storage_bus ps  qs  energy  energy_rating charge_rating  discharge_rating  charge_efficiency  discharge_efficiency  thermal_rating  qmin  qmax  r  x  p_loss  p_loss  status
mpc.storage = [
   3   0.0  0.0  20.0  100.0   50.0  70.0  0.8   0.9   100.0   -50.0   70.0  0.1   0.0   0.0   0.0   1;
   10  0.0  0.0  30.0  100.0   50.0  70.0  0.9   0.8   100.0   -50.0   70.0  0.1   0.0   0.0   0.0   1;
];
```
Note that this Matpower-based format includes the optional `thermal_rating` parameter.


## Storage Mathematical Model

Given the storage data model and two sequential time points $s$ and $t$, the storage component's mathematical model is given by,

```math
\begin{align}
%
\mbox{data: } & \nonumber \\
& e^u \mbox{ - energy rating} \nonumber \\
& sc^u \mbox{ - charge rating} \nonumber \\
& sd^u \mbox{ - discharge rating} \nonumber \\
& \eta^c \mbox{ - charge efficiency} \nonumber \\
& \eta^d \mbox{ - discharge efficiency} \nonumber \\
& te \mbox{ - time elapsed} \nonumber \\
& S^l \mbox{ - power losses} \nonumber \\
& Z \mbox{ - injection impedance} \nonumber \\
& q^l, q^u  \mbox{ - reactive power injection limits} \nonumber \\
& s^u \mbox{ - thermal injection limit} \nonumber \\
& i^u \mbox{ - current injection limit} \nonumber \\
%
\mbox{variables: } & \nonumber \\
& e_i \in (0, e^u) \mbox{ - storage energy at time $i$} \label{var_strg_energy} \\
& sc_i \in (0, sc^u) \mbox{ - charge amount at time $i$} \label{var_strg_charge} \\
& sd_i \in (0, sd^u) \mbox{ - discharge amount at time $i$} \label{var_strg_discharge} \\
& sqc_i \mbox{ - reactive power slack at time $i$} \label{var_strg_qslack} \\
& S_i \mbox{ - complex bus power injection at time $i$} \label{var_strg_power} \\
& I_i \mbox{ - complex bus current injection at time $i$} \label{var_strg_current} \\
%
\mbox{subject to: } & \nonumber \\
& e_t - e_s = te \left(\eta^c sc_t - \frac{sd_t}{\eta^d} \right) \label{eq_strg_energy} \\
& sc_t \cdot sd_t = 0 \label{eq_strg_compl} \\
& S_t + (sd_t - sc_t) = j \cdot sqc_t + S^l + Z |I_t| \label{eq_strg_loss} \\
& q^l \leq \Im(S_t) \leq q^u \label{eq_strg_q_limit} \\
& |S_t| \leq s^u \label{eq_strg_thermal_limit} \\
& |I_t| \leq i^u \label{eq_strg_current_limit}
\end{align}
```


### Mapping to PowerModels Functions
- Eq. $\eqref{var_strg_energy}$ - [`variable_storage_energy`](@ref)
- Eq. $\eqref{var_strg_charge}$ - [`variable_storage_charge`](@ref)
- Eq. $\eqref{var_strg_discharge}$ - [`variable_storage_discharge`](@ref)
- Eq. $\eqref{var_strg_qslack}$ - [`variable_storage_power_control_imaginary`](@ref)
- Eq. $\eqref{var_strg_power}$ - [`variable_storage_power`](@ref)
- Eq. $\eqref{var_strg_current}$ - implemented as a function of other variables
- Eq. $\eqref{eq_strg_energy}$ - [`constraint_storage_state`](@ref)
- Eq. $\eqref{eq_strg_compl}$ - [`constraint_storage_complementarity_nl`](@ref) or [`constraint_storage_complementarity_mi`](@ref)
- Eq. $\eqref{eq_strg_loss}$ - [`constraint_storage_losses`](@ref)
- Eq. $\eqref{eq_strg_q_limit}$ - bounds of [`variable_storage_power`](@ref)
- Eq. $\eqref{eq_strg_thermal_limit}$ - [`constraint_storage_thermal_limit`](@ref)
- Eq. $\eqref{eq_strg_current_limit}$ - [`constraint_storage_current_limit`](@ref)


