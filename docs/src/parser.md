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

```@docs
parse_matpower_file
parse_matpower_string
matpower_to_powermodels
row_to_typed_dict
row_to_dict
mp_cost_data
split_loads_shunts
standardize_cost_terms
merge_generator_cost_data
merge_bus_name_data
merge_generic_data
mp2pm_branch
mp2pm_dcline
add_dcline_costs
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
parse_psse
```

The following internal helper methods are also provided:

```@docs
parse_pti
parse_pti_data
get_line_elements
add_section_data!
parse_line_element!
get_pti_dtypes
get_pti_sections
psse2pm_dcline!
psse2pm_transformer!
psse2pm_shunt!
psse2pm_load!
psse2pm_bus!
psse2pm_generator!
psse2pm_branch!
import_remaining!
create_starbus_from_transformer
find_max_bus_id
init_bus!
calc_2term_reactive_power
```
