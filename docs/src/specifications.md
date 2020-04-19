# Problem Specifications

This section provides links to the formulation agnostic problem specifications.

## Power Flow (PF)

For additional discussion please see, [Power Flow Computations](@ref).

**Bus Injection Models (BIM)**
```@docs
build_pf
compute_dc_pf
compute_ac_pf
```

**Branch Flow Models (BFM)**
```@docs
build_pf_bf
```

**Current Flow Models (CFM)**
```@docs
build_pf_iv
```


## Optimal Power Flow (OPF)

**Bus Injection Models (BIM)**
```@docs
build_opf
build_mn_opf
build_mn_opf_strg
build_opf_ptdf
```

**Branch Flow Models (BFM)**
```@docs
build_opf_bf
build_mn_opf_bf_strg
```

**Current Flow Models (CFM)**
```@docs
build_opf_iv
```


## Optimal Power Balance (OPB)

A copper-plate approximation of the OPF problem

```@docs
build_opb
```


## Optimal Transmission Switching (OTS)

```@docs
build_ots
```

!!! note
    if the branch status is `0` in the input, it is out of service and forced to `0` in OTS


## Transmission Network Expansion Planning (TNEP)

```@docs
build_tnep
```
