# PowerModels Data Format

## Network Data Dictionary

Internally PowerModels utilizes a dictionary to store network data.
The dictionary uses strings as key values so this data structure can be serialized to JSON for algorithmic data exchange.
The data dictionary organization and key names are designed to be consistent with the [Matpower](http://www.pserc.cornell.edu/matpower/) file format and should be familiar to power system researchers.

The network data dictionary structure is roughly as follows,
```
{
"name":<string>,
"version":"2",
"baseMVA":<float>,
"bus":[
    {
        "index":<int>,
        "bus_type":<int>,
        "pd":<float>,
        "qd":<float>,
        ...
    },
    ...
],
"gen":[
    {
        "index":<int>,
        "gen_bus":<int>,
        "pg":<float>,
        "qg":<float>,
        ...
    },
    ...
],
"branch":[
    {
        "index":<int>,
        "f_bus":<int>,
        "t_bus":<int>,
        "br_r":<int>,
        ...
    }
    ...
],
"gencost":[
    {
        "index":<int>,
        "model":<int>,
        "startup":<float>,
        "shutdown":<float>,
        ...
    },
    ...
]
```

For a detailed list of all possible parameters please refer to the specification document provided with [Matpower](http://www.pserc.cornell.edu/matpower/).  In addition to the traditional Matpower parameters every network component in the PowerModels dictionary has an `index` parameter, which can be used to uniquely identify that network element.

It is also important to note that although the Matpower format contains values in mixed units during the data setup phase of PowerModels.jl all of data values are converted to per unit and radian values.


## Matpower Data Files

The data exchange via JSON files is ideal for building algorithms, however it is hard to for humans to read and process.
To that end PowerModels also has extensive support for parsing Matpower network files in the `.m` format.


### User Extensions

In addition to parsing the standard Matpower parameters, PowerModels also supports extending the standard Matpower format in a number of ways as illustrated by the following examples.  In these examples a JSON document fragments are used to indicate the structure of the PowerModel dictionary.

Adding single values,
```
mpc.const_float = 4.56
```
becomes,
```
{
"const_float": 4.56
}
```

Adding new matrices,
```
mpc.areas = [
    1   1;
    2   3;
];
```
becomes,
```
{
"areas":[
    {
        "index":1,
        "col_1":1,
        "col_2":1
    },
    {
        "index":1,
        "col_1":2,
        "col_2":3
    }
]
```

Column names can be given to matrices using the following special comment,
```
%column_names%  area    refbus
mpc.areas_named = [
    4   5;
    5   6;
];
```
becomes,
```
{
"areas":[
    {
        "index":1,
        "area":4,
        "refbus":5
    },
    {
        "index":1,
        "area":5,
        "refbus":6
    }
]
```

Finally, if a new matrix's name extends a current Matpower matrix name with an underscore, then its values will be merged with the original Matpower data matrix.  Note that this feature requires that the new matrix column names and is the same length as the original matrix.  For example,
```
% add two new columns to "branch" matrix
%column_names%  rate_i  rate_p
mpc.branch_limit = [
    50.2    45;
    36  60.1;
    12  30;
];

```
becomes,
```
{
"branch":[
    {
        "index":1,
        ...(all pre existing fields)...
        "rate_i":50.2,
        "rate_p":45
    },
    {
        "index":2,
        ...(all pre existing fields)...
        "rate_i":36,
        "rate_p":60.1
    },
    {
        "index":3,
        ...(all pre existing fields)...
        "rate_i":12,
        "rate_p":30
    }
]
```


