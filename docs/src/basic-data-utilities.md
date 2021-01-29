# Basic Data Utilities

By default PowerModels uses a data model that captures the bulk of the features
of realistic transmission network datasets such as, inactive devices, breakers
and HVDC lines.  However, these features preclude popular matrix-based
analysis of power network datasets such as incidence, admittance, and power
transfer distribution factor (PTDF) matrices. To support these types of
analysis PowerModels introduces the concept of a _basic_ networks, which are
network datasets that have the properties required to interpret the system in
a matrix form.

The `make_basic_network` is provided to ensure that a given network dataset
satisfies the properties required for a matrix interpretation (the specific
requirements are outlined in the function documentation block).  If the given
dataset does not satisfy the properties, `make_basic_network` transforms the
dataset to enforce them.

```@docs
make_basic_network
```

!!! tip
    If `make_basic_network` results in significant changes to a dataset,
    `export_file` can be used to inspect and modify the new derivative dataset
    that conforms to the basic network requirements.


## Matrix-Based Data

Using a basic network dataset the following functions can be used to extract
key power system quantities in vectors and matrix forms. The prefix `_basic_`
distinguishes these functions from similar tools that operate on any type of
PowerModels data, but require addition bookkeeping.

```@docs
calc_basic_bus_voltage
calc_basic_bus_injection
calc_basic_incidence_matrix
calc_basic_admittance_matrix
calc_basic_ptdf_matrix
calc_basic_ptdf_column
calc_basic_jacobian_matrix
```

## Matrix-Based Computations

The following function is provides as an example of how basic network matrices
can be combined with linear algebra operations to solve a dc power flow.

```@docs
compute_basic_dc_pf
```