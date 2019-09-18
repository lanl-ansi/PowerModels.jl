# PowerModels' Switch Component

In addition to the standard transmission network components (e.g. bus, load, generator, branch, ...) PowerModels also includes a generic switch component, which can be used to model a variety of topology control devices (e.g. breakers, reclosers, fuses, ect...).  This section provides a brief overview of the switch component's data and mathematical model.


## Switch Data Model

When parsing a matpower file with switch information, 
```julia
data = PowerModels.parse_file("matpower/case5_sw.m")
```
the switch information can be retrieved via the `"switch"` keyword in the `data` dictionary. They will be correspondingly rendered when `PowerModels.print_summary(data)` or `PowerModels.component_table(data, "switch", <columns>)` is called.

The list of columns for the generic switch model is roughly as follows,
```json
{
  "index":<int>,
  "f_bus":<int>,
  "r_bus":<int>,
  "psw":<float, MW>,
  "qsw":<float, MVAr>,
  "state":<int>,
  ("thermal_rating":<float, MVA>,)
  ("current_rating":<float, MA>,)
  "status":<int>,
}
```
By default, all of these quantities are used in per unit inside PowerModels.  The units indicated here are only used by PowerModels' mixed-unit representation and the extended Matpower network format.

PowerModels' switch components can be added to Matpower data files as follows,
```matlab
%% switch data
% f_bus t_bus psw qsw state thermal_rating  status
mpc.switch = [
  1  2   300.0   98.61   1   1000.0  1;
  3  2     0.0    0.00   0   1000.0  1;
  3  4     0.0    0.00   1   1000.0  0;
];
```
Note that this Matpower-based format includes the optional `thermal_rating` parameter.


## Switch Mathematical Model

Switch component have two discrete states open (i.e. 0) and closed (i.e. 1).  When a switch is in the open state no power can flow between the connected buses through the switch.  When the switch is in the closed state power can flow freely between the connected buses (up to the provide flow limits) and the voltage at the two connecting buses should be the same.  The switch component's mathematical model is given by,

```math
\begin{align}
%
\mbox{data: } & \nonumber \\
& s^u \mbox{ - thermal injection limit} \\
& i^u \mbox{ - current injection limit} \\
%
\mbox{variables: } & \nonumber \\
& z \in {0, 1} \mbox{ - the state of the switch (open/closed)} \\
& V_i \mbox{ - complex voltage on bus $i$} \\
& V_j \mbox{ - complex voltage on bus $j$} \\
& S \mbox{ - complex power flowing along the switch} \\
%
\mbox{subject to: } & \nonumber \\
& z \cdot V_i = z \cdot V_j \label{eq_sw_voltage} \\
& |S| \leq z \cdot s^u \label{eq_sw_thermal_limit} \\
& |I| \leq z \cdot i^u \label{eq_sw_current_limit}
\end{align}
```
