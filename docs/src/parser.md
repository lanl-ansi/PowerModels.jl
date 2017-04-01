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

The following two methods are the main exported methods for parsing matpower data files:

```@docs
parse_matpower
parse_matpower_data
```

We also provide the following (internal) helper methods:

```@docs
standardize_cost_order
update_branch_transformer_settings
merge_generator_cost_data
merge_bus_name_data
parse_cell
parse_matrix
parse_matlab_data
split_line
add_line_delimiter
extract_assignment
extract_mpc_assignment
type_value
type_array
build_typed_dict
extend_case_data
mp_data_to_pm_data
```
