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
split_loads_shunts
```

## PTI Data Files (PSS/E)

**Note: This feature is currently in development, and only partial parsing of
and conversion of PTI files into a PowerModels format is supported. The
following power network components are currently supported: buses, loads,
shunts (fixed and approximation of switched), branches, two-winding and
three-winding transformers (incl. magnetizing admittance), and generators.
There is early support for two-terminal dc lines, but this feature should not
be relied upon.**

The following method is the main exported method for parsing PTI data files:

```@docs
parse_pti
parse_psse
```

The following internal helper methods are also provided:

```@docs
get_pti_sections
get_pti_dtypes
parse_line_element!
add_section_data!
get_line_elements
parse_pti_data
convert_vsc_to_dcline
wye_delta_transform
psse2pm_branch!
psse2pm_generator!
psse2pm_bus!
psse2pm_load!
psse2pm_shunt!
psse2pm_transformer!
psse2pm_dclines
calc_2term_reactive_power
get_bus_values
find_max_bus_id
create_starbus_from_transformer
import_remaining!
```