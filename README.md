# PowerModels with bus-type switching 
This repository is forked from LANL's PowerModels.jl repo. It maintains the same functionality but adds in the framework to use bus-type switching to improve the solution to AC power flow.

## Setup 
This project uses Julia's built-in package manager with Project.toml and Manifest.toml. Scripts can be run from a julia REPL with the line `include("path_to_script.jl")`. 

I've stored the datasets and results in a different directory to keep them off github, and to make it easier to set up on an HPC where the data and scripts shouldn't be stored in the same place. Instead, I store the absolute path to the dataset directories in config.jl and import them into my run scripts. The script `sample_config.jl` shows how these paths should be imported. 

## Project Structure 
Aside from very small changes to files in `src/core, src/form, src/io` (i.e. removing debugging statements), all the code for the bus type switching is contained in `prob/pf.jl` and `prob.update_bt.jl`. 
### PF.jl 
All the functions added to this file are below line 860. The majority of these functions are helper functions, but the following functions are important to understanding the code: 
 - `compute_ac_pf_mult_buses`: This is the function that wraps around the newton-raphson solver, then updates the variables, checks for bound violations, and performs bus-type switching. This is the main function that will be called. 
 - `map_types_to_variable_indices`: Since we are switching the number of variables on each bus, they cannot be traditionally indexed in the jacobian like they are in the original PowerModels.jl (for instance, variable 1 and 2 for bus $i$ aren't in columns $2i$ and $2i - 1$). This function creates a mapping dictionary that stores the variable indices for each bus, and the row indices for each power balance equation. 
 - `perform_bus_swaps!`: This function is called to perform bus type switching. Right now, it defaults to 1) resolving reactive power violations on generator buses, 2) resolving voltage violations on generator buses that have been selected to type-switch, and then 3) resolving voltage violations on load buses. There are two bus type switching techniques currently implemented. The default (`nearest_gen`) swaps a violated PQ bus with a nearby PV bus. The second (`qv_inv`) swaps PQ buses with PV buses based on maintaining invertibility of the QV sub-matrix. There is an empty function (`perform_bus_swaps_sensitivity_score`) for the next technique. 
 - `_compute_ac_pf`: This is almost identical to the original PowerModels.jl function, but it uses the mapping dictionary instead of manual indexing. It also supports the additional bus types (P and PQV). 
  - `_compute_ac_pf_grainger`: This implements the [Grainger](https://ritwikchowdhury.wordpress.com/wp-content/uploads/2017/12/power_system_analysis_john_grainger_1st.pdf) AC Power Flow steps. In this methodology, the  voltage magnitudes and angles are computed first and then used to determine the reactive power out of generators. Because this methodology solves for $\frac{\delta V}{V}$, the variable update in NLsolve needed to be adjusted to isolate the $\delta V$. So a few functions from NLsolve are patched over. Nothing in them has changed for the most part, but a new flag is passed into `trust_region_` that tells the function to update the voltage setpoints differently. 

### update_bt.jl
These functions are used to update the variables after a NR converges and to implement bus type switching, and should be fairly straightforward. 

### run_scripts

The `run_scripts` subdirectory contains the four scripts that I currently have to test the bus-type switching method.
 - `find_nearest_gens.jl` is one function that is used to calculate (before run-time) the nearest generators to each bus in the system. 
 - `generate_dataset.jl` is used to generate a dataset. Its two main functionalities are `generate_loads`, which creates samples for each test case (each sample has a bus load individually perturbed by up to 85%. Each sample must be DC-feasible and AC-feasible), and `generate_solutions`, which takes in a load dataset and runs each variant of AC power flow.  
 - `pf_validation.jl` is a quick script that checks that using the variable mapping gives the same solution as the manual indexing, and that using the grainger technique gives the same solution as the PowerModels technique (both with and without bus swapping). This is not super comprehensive, since it only validates on the default test case.
 - `practice_runs.jl` is another quick script that I use to test new updates to the power flow code.



## Documentation for original PowerModels package

The package [documentation](https://lanl-ansi.github.io/PowerModels.jl/stable/) includes a variety of useful information including a [quick-start guide](https://lanl-ansi.github.io/PowerModels.jl/stable/quickguide/), [network model specification](https://lanl-ansi.github.io/PowerModels.jl/stable/network-data/), and [baseline results](https://lanl-ansi.github.io/PowerModels.jl/stable/experiment-results/).

Additionally, these presentations provide a brief introduction to various aspects of PowerModels,
- [Network Model Update, v0.6](https://youtu.be/j7r4onyiNRQ)
- [PSCC 2018](https://youtu.be/AEEzt3IjLaM)
- [JuMP Developers Meetup 2017](https://youtu.be/W4LOKR7B4ts)

