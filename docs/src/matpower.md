# Parsing Matpower Data

The following two methods are the main exported methods for parsing matpower data files:

```@docs
parse_matpower(file_string)
parse_matpower_data(data_string)
```

We also provide the following (internal) helper methods:

```@docs
standardize_cost_order(data::Dict{String,Any})
update_branch_transformer_settings(data::Dict{String,Any})
merge_generator_cost_data(data::Dict{String,Any})
merge_bus_name_data(data::Dict{String,Any})
parse_cell(lines, index)
parse_matrix(lines, index)
parse_matlab_data(lines, index, start_char, end_char)
split_line(mp_line)
add_line_delimiter(mp_line, start_char, end_char)
extract_assignment(string)
extract_mpc_assignment(string)
type_value(value_string)
type_array(string_array)
build_typed_dict(data, column_names)
extend_case_data(case, name, typed_dict_data, has_column_names)
mp_data_to_pm_data(mp_data)
```
