# Basic Data Utilities

By default PowerModels uses a data model that captures the bulk of the features
of realistic transmission network datasets such as, inactive devices, breakers
and HVDC lines. However, these features preclude popular matrix-based
analysis of power network datasets such as incidence, admittance, and power
transfer distribution factor (PTDF) matrices. To support these types of
analysis PowerModels introduces the concept of a _basic networks_, which are
network datasets that satisfy the properties required to interpret the system
in a matrix form.

The `make_basic_network` is provided to ensure that a given network dataset
satisfies the properties required for a matrix interpretation (the specific
requirements are outlined in the function documentation block). If the given
dataset does not satisfy the properties, `make_basic_network` transforms the
dataset to enforce them.

```@docs
make_basic_network
```

The standard procedure for loading basic network data is as follows,
```julia
data = make_basic_network(parse_file("<path to network data file>"))
```
modifications to the original network data file are indicated by logging
messages in the terminal.

!!! tip
    If `make_basic_network` results in significant changes to a dataset,
    `export_file` can be used to inspect and modify the new derivative dataset
    that conforms to the basic network requirements.


## Matrix-Based Data

Using a basic network dataset the following functions can be used to extract
key power system quantities in vectors and matrix forms. The prefix `_basic_`
distinguishes these functions from similar tools that operate on any type of
PowerModels data, including those that are not amenable to a vector/matrix
format.

```@docs
calc_basic_bus_voltage
calc_basic_bus_injection
calc_basic_branch_series_impedance
calc_basic_incidence_matrix
calc_basic_admittance_matrix
calc_basic_susceptance_matrix
calc_basic_branch_susceptance_matrix
calc_basic_ptdf_matrix
calc_basic_ptdf_row
```

!!! warning
    Several variants of the real-valued susceptance matrix are possible.
    PowerModels uses the version based on inverse of branch series impedance,
    that is `imag(inv(r + x im))`. One may observe slightly different results
    when compared to tools that use other variants such as `1/x`.


## Matrix-Based Computations

Matrix-based network data can be combined to compute a number of useful
quantities. For example, by combining the incidence matrix and the series
impedance one can drive the susceptance and branch susceptance matrices as follows,

```julia
import LinearAlgebra: Diagonal

bz = calc_basic_branch_series_impedance(data)
A  = calc_basic_incidence_matrix(data)

Y  = imag(Diagonal(inv.(bz)))
B  = A'*Y*A    # equivalent to calc_basic_susceptance_matrix
BB = (A'*Y)'   # equivalent to calc_basic_branch_susceptance_matrix
```

The bus voltage angles can be combined with the susceptance and branch susceptance
matrices to observe how power flows through the network as follows,

```julia
va = angle.(calc_basic_bus_voltage(data))
B  = calc_basic_susceptance_matrix(data)
BB = calc_basic_branch_susceptance_matrix(data)

bus_injection =  -B * va
branch_power  = -BB * va
```

In the inverse operation, bus injection values can be combined with a PTDF matrix to compute branch flow values as follows,

```julia
bi   = real(calc_basic_bus_injection(data))
PTDF = calc_basic_ptdf_matrix(data)

branch_power = PTDF * bi
```

Finally, the following function provides a tool to solve a DC power flow on
basic network data using Julia's native linear equation solver,

```@docs
compute_basic_dc_pf
```

!!! tip
    By default PowerModels uses Julia's SparseArrays to ensure the best
    performance of matrix operations on large power network datasets.
    The function `Matrix(sparse_array)` can be used to covert a sparse matrix
    into a full matrix when that is preferred.

