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
  "standby_loss":<float, MW>,
  "status":<int>,
}
```
All of these quantities should be positive except for `qmin`, which can be negative.  The `efficiency` parameters are unit-less scalars in the range of 1.0 and 0.0.  By default, all of these quantities are used in per unit inside PowerModels.  The units indicated here are only used by PowerModels' mixed-unit representation and the extended Matpower network format.

Note that the optional `thermal_rating` and `current_rating` parameters are applied at the point of coupling to the network while the other ratings are internal to the storage device.

In addition to these component parameters, PowerModels also requires a global parameter `time_elapsed` (in hours) to specify how active power is converted into units of energy as the storage device is charged or discharged.

PowerModels' storage components can be added to Matpower data files as follows,
```matlab
% hours
mpc.time_elapsed = 1.0

%% storage data
%   storage_bus ps  qs  energy  energy_rating charge_rating  discharge_rating  charge_efficiency  discharge_efficiency  thermal_rating  qmin  qmax  r  x  standby_loss  status
mpc.storage = [
   3   0.0  0.0  20.0  100.0   50.0  70.0  0.8   0.9   100.0   -50.0   70.0  0.1   0.0   0.0   1;
   10  0.0  0.0  30.0  100.0   50.0  70.0  0.9   0.8   100.0   -50.0   70.0  0.1   0.0   0.0   1;
];
```
Note that this Matpower-based format includes the optional `thermal_rating` parameter.


## Storage Mathematical Model

Given the storage data model and two sequential time points $s$ and $t$, the storage component's mathematical model is given by,

```math
\begin{align}
%
\mbox{data: } & \nonumber \\
& e^u \mbox{ - energy rating} \\
& sc^u \mbox{ - charge rating} \\
& sd^u \mbox{ - discharge rating} \\
& \eta^c \mbox{ - charge efficiency} \\
& \eta^d \mbox{ - discharge efficiency} \\
& te \mbox{ - time elapsed} \\
& sl \mbox{ - standing losses} \\
& r \mbox{ - injection resistance} \\
& q^l, q^u  \mbox{ - reactive power injection limits} \\
& s^u \mbox{ - thermal injection limit} \\
& i^u \mbox{ - current injection limit} \\
%
\mbox{variables: } & \nonumber \\
& e_i \in (0, e^u) \mbox{ - storage energy at time $i$} \\
& sc_i \in (0, sc^u) \mbox{ - charge amount at time $i$} \\
& sd_i \in (0, sd^u) \mbox{ - discharge amount at time $i$} \\
& S_i \mbox{ - complex bus power injection at time $i$} \\
& I_i \mbox{ - complex bus current injection at time $i$} \\
%
\mbox{subject to: } & \nonumber \\
& e_t - e_s = te \left(\eta^c sc_t - \frac{sd_t}{\eta^d} \right) \label{eq_strg_energy} \\
& sc_t \cdot sd_t = 0 \label{eq_strg_compl} \\
& \Re(S_t) + (sd_t - sc_t) = sl + r |I_t| \label{eq_strg_loss} \\
& q^l \leq \Im(S_t) \leq q^u \label{eq_strg_q_limit} \\
& |S_t| \leq s^u \label{eq_strg_thermal_limit} \\
& |I_t| \leq i^u \label{eq_strg_current_limit}
\end{align}
```
