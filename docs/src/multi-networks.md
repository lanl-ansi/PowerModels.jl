# Working with Multi-Network Data

```@setup powermodels
import Pkg
using PowerModels

case3file = Pkg.dir(dirname(@__DIR__), "test", "data", "matpower", "case3.m")
```

There are occasions when it will be desirable to support multiple replicates of the same network, where there might be additional dimensions to represent variable network parameters. These dimensions might correspond to time for dynamic networks, or scenarios for stochastic networks.

To distinguish between network data (see [The Network Data Dictionary](@ref)) that correspond to a single network or to multiple networks, PowerModels.jl provides
```@docs
PowerModels.ismultinetwork
```
For example, we can do the following:
```@example powermodels
network_data = PowerModels.parse_file(case3file)
pm = build_generic_model(network_data, ACPPowerModel, PowerModels.post_opf)

PowerModels.ismultinetwork(pm)
```
PowerModels.jl would generally not read in network data as multi-networks. To generate multiple networks from the same network data, we use the following method
```@docs
PowerModels.replicate
```
For example, we can make three replicates by calling
```@example powermodels
network_data3 = PowerModels.replicate(network_data, 3)
```
Observe that the structure of `network_data3` is different from that of `network_data`, since it is a multi-network. The user can then modify each replicate of the network to vary in the corresponding parameter of interest. See [`test/common.jl`](https://github.com/lanl-ansi/PowerModels.jl/blob/master/test/common.jl) for examples on setting up valid Multi-Network data.

To build a PowerModel from a multinetwork data dictionary (see [Building PowerModels from Network Data Dictionaries](@ref)), we supply `multinetwork=true` during the call to `build_generic_model` and replace `post_opf` with `post_mn_opf`,
```@example powermodels
pm3 = PowerModels.build_generic_model(network_data3, ACPPowerModel, PowerModels.post_mn_opf, multinetwork=true)

PowerModels.ismultinetwork(pm3)
```

!!! note

    The `replicate()` method only works on single networks. So
    ```julia
    data33 = PowerModels.replicate(data3, 3)
    ```
    will result in an error. Moreover, `build_generic_model()` (see )

Because this is a common pattern of usage, we provide corresponding calls to `run_mn_opf` (which behaves analogously to `run_opf`, but for multinetworks), `run_mn_opb`, `run_mn_pf`, `run_mn_mc_opf`, `run_mn_strg_opf` and `run_mn_mc_strg_opf`.

!!! note

    Working with Multi-Networks is for advanced users, and those who are interested should refer to [`src/prob/test.jl`](https://github.com/lanl-ansi/PowerModels.jl/blob/master/src/prob/test.jl) for toy problem formulations of multi-network and multi-conductor models.
