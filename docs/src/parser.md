# File IO

```@meta
CurrentModule = PowerModels
```

## General Data Formats

```@docs
parse_file
parse_json
```

## Matpower Data Files

The following method is the main exported methods for parsing Matpower data files:

```@docs
parse_matpower
```

We also provide the following (internal) helper methods:

```@autodocs
Modules = [PowerModels]
Pages   = ["io/matpower.jl"]
Order   = [:function]
Private  = true
```

## PTI Data Files (PSS/E)

**Note: This feature supports the parsing and conversion of PTI files into a
PowerModels format for the following power network components: buses, loads,
shunts (fixed and approximation of switched), branches, two-winding and
three-winding transformers (incl. magnetizing admittance), generators,
two-terminal dc lines, and voltage source converter HVDC lines.**

The following method is the main exported method for parsing PSS(R)E v33
specified PTI data files:

```@docs
parse_pti
parse_psse
```

The following internal helper methods are also provided:

```@autodocs
Modules = [PowerModels]
Pages   = ["io/psse.jl"]
Order   = [:function]
Private  = true
```

```@autodocs
Modules = [PowerModels]
Pages   = ["io/pti.jl"]
Order   = [:function]
Private  = true
```
