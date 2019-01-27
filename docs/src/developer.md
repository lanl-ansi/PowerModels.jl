# Developer Documentation

## Variable and parameter naming scheme

### Suffixes

- `_fr`: from-side ('i'-node)
- `_to`: to-side ('j'-node)

### Power

Defining power $s = p + j \cdot q$ and $sm = |s|$
- `s`: complex power (VA)
- `sm`: apparent power (VA)
- `p`: active power (W)
- `q`: reactive power (var)

### Voltage

Defining voltage $v = vm \angle va = vr + j \cdot vi$:
- `vm`: magnitude of (complex) voltage (V)
- `va`: angle of complex voltage (rad)
- `vr`: real part of (complex) voltage (V)
- `vi`: imaginary part of complex voltage (V)

### Current

Defining current $c = cm \angle ca = cr + j \cdot ci$:
- `cm`: magnitude of (complex) current (A)
- `ca`: angle of complex current (rad)
- `cr`: real part of (complex) current (A)
- `ci`: imaginary part of complex current (A)

### Voltage products

Defining voltage product $w = v_i \cdot v_j$ then
$w = wm \angle wa = wr + j\cdot wi$:
- `wm` (short for vvm): magnitude of (complex) voltage products (V$^2$)
- `wa` (short for vva): angle of complex voltage products (rad)
- `wr` (short for vvr): real part of (complex) voltage products (V$^2$)
- `wi` (short for vvi): imaginary part of complex voltage products (V$^2$)

### Current products

Defining current product $cc = c_i \cdot c_j$ then
$cc = ccm \angle cca = ccr + j\cdot cci$:
- `ccm`: magnitude of (complex) current products (A$^2$)
- `cca`: angle of complex current products (rad)
- `ccr`: real part of (complex) current products (A$^2$)
- `cci`: imaginary part of complex current products (A$^2$)

### Transformer ratio

Defining complex transformer ratio
$t = tm \angle ta = tr + j\cdot ti$:
- `tm`: magnitude of (complex) transformer ratio (-)
- `ta`: angle of complex transformer ratio (rad)
- `tr`: real part of (complex) transformer ratio (-)
- `ti`: imaginary part of complex transformer ratio (-)

### Impedance

Defining impedance
$z = r + j\cdot x$:
- `r`: resistance ($\Omega$)
- `x`: reactance ($\Omega$)

### Admittance

Defining admittance
$y = g + j\cdot b$:
- `g`: conductance ($S$)
- `b`: susceptance ($S$)


### Standard Value Names

- network ids:`network`, `nw`, `n`
- conductors ids: `conductor`, `cnd`, `c`
- phase ids: `phase`, `ph`, `h`


## DistFlow derivation

### For an asymmetric pi section
Following notation of [^1], but recognizing it derives the SOC BFM without shunts. In a pi-section, part of the total current $I_{lij}$ at the from side flows through the series impedance, $I^{s}_{lij}$, part of it flows through the from side shunt admittance $I^{sh}_{lij}$. Vice versa for the to-side. Indicated by superscripts 's' (series) and 'sh' (shunt).
- Ohm's law: $U^{mag}_{j} \angle \theta_{j} = U^{mag}_{i}\angle \theta_{i}  - z^{s}_{lij} \cdot I^{s}_{lij}$ $\forall lij$
- KCL at shunts: $ I_{lij} = I^{s}_{lij} + I^{sh}_{lij}$, $ I_{lji} = I^{s}_{lji} + I^{sh}_{lji} $
- Observing: $I^{s}_{lij} = - I^{s}_{lji}$, $ \vert I^{s}_{lij} \vert = \vert I^{s}_{lji} \vert $
- Ohm's law times its own complex conjugate: $(U^{mag}_{j})^2 = (U^{mag}_{i}\angle \theta_{i}  - z^{s}_{lij} \cdot I^{s}_{lij})\cdot (U^{mag}_{i}\angle \theta_{i}  - z^{s}_{lij} \cdot I^{s}_{lij})^*$
- Defining $S^{s}_{lij} = P^{s}_{lij} + j\cdot Q^{s}_{lij} = (U^{mag}_{i}\angle \theta_{i}) \cdot (I^{s}_{lij})^*$
- Working it out $(U^{mag}_{j})^2 = (U^{mag}_{i})^2 - 2 \cdot(r^{s}_{lij} \cdot P^{s}_{lij} + x^{s}_{lij} \cdot Q^{s}_{lij}) $ + $((r^{s}_{lij})^2 + (x^{s}_{lij})^2)\vert I^{s}_{lij} \vert^2$

Power flow balance w.r.t. branch *total* losses
- Active power flow:   $P_{lij}$ + $ P_{lji} $ = $  g^{sh}_{lij} \cdot (U^{mag}_{i})^2 + r^{s}_{l} \cdot \vert I^{s}_{lij} \vert^2 +  g^{sh}_{lji} \cdot  (U^{mag}_{j})^2 $
- Reactive power flow: $Q_{lij}$ + $ Q_{lji} $ = $ -b^{sh}_{lij} \cdot (U^{mag}_{i})^2 + x^{s}_{l} \cdot \vert I^{s}_{lij} \vert^2  - b^{sh}_{lji} \cdot  (U^{mag}_{j})^2 $
- Current definition: $ \vert S^{s}_{lij} \vert^2  $ $=(U^{mag}_{i})^2 \cdot \vert I^{s}_{lij} \vert^2 $

Substitution:
- Voltage from: $(U^{mag}_{i})^2 \rightarrow w_{i}$
- Voltage to: $(U^{mag}_{j})^2 \rightarrow w_{j}$
- Series current : $\vert I^{s}_{lij} \vert^2 \rightarrow l^{s}_{l}$
Note that $l^{s}_{l}$ represents squared magnitude of the *series* current, i.e. the current flow through the series impedance in the pi-model.

Power flow balance w.r.t. branch *total* losses
- Active power flow:   $P_{lij}$ + $ P_{lji} $ = $  g^{sh}_{lij} \cdot w_{i} + r^{s}_{l} \cdot l^{s}_{l} +  g^{sh}_{lji} \cdot  w_{j} $
- Reactive power flow: $Q_{lij}$ + $ Q_{lji} $ = $ -b^{sh}_{lij} \cdot w_{i} + x^{s}_{l} \cdot l^{s}_{l}  - b^{sh}_{lji} \cdot  w_{j} $

Power flow balance w.r.t. branch *series* losses:
- Series active power flow : $P^{s}_{lij} + P^{s}_{lji}$ $ = r^{s}_{l} \cdot l^{s}_{l} $
- Series reactive power flow: $Q^{s}_{lij} + Q^{s}_{lji}$ $ = x^{s}_{l} \cdot l^{s}_{l} $

Valid equality to link $w_{i}, l_{lij}, P^{s}_{lij}, Q^{s}_{lij}$:
- Nonconvex current definition: $(P^{s}_{lij})^2$ + $(Q^{s}_{lij})^2$  $=w_{i} \cdot l_{lij} $
- SOC current definition: $(P^{s}_{lij})^2$ + $(Q^{s}_{lij})^2$  $\leq$ $ w_{i} \cdot l_{lij} $


### Adding an ideal transformer
Adding an ideal transformer at the from side implicitly creates an internal branch voltage, between the transformer and the pi-section.
- new voltage: $w^{'}_{l}$
- ideal voltage magnitude transformer: $w^{'}_{l} = \frac{w_{i}}{(t^{mag})^2}$

W.r.t to the pi-section only formulation, we effectively perform the following substitution in all the equations above:
- $ w_{i} \rightarrow \frac{w_{i}}{(t^{mag})^2}$

The branch's power balance isn't otherwise impacted by adding the ideal transformer, as such transformer is lossless.

### Adding total current limits
- Total current from: $ \vert I_{lij} \vert \leq I^{rated}_{l}$
- Total current to: $ \vert I_{lji} \vert \leq I^{rated}_{l}$

In squared voltage magnitude variables:
- Total current from: $ (P_{lij})^2$ + $(Q_{lij})^2  \leq (I^{rated}_{l})^2 \cdot  w_{i}$
- Total current to: $ (P_{lji})^2$ + $(Q_{lji})^2  \leq (I^{rated}_{l})^2 \cdot w_{j}$




[^1] Gan, L., Li, N., Topcu, U., & Low, S. (2012). Branch flow model for radial networks: convex relaxation. 51st IEEE Conference on Decision and Control, 1–8. Retrieved from http://smart.caltech.edu/papers/ExactRelaxation.pdf
