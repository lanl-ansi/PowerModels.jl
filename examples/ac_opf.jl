using PowerModels
using Ipopt

const _PMA = PowerModelsAnalytics

import JSON
import JuMP

"""
    read_matpower_case(url :: String)

Reads a MATPOWER case file from the given URL and returns a PowerModel.
MATPOWER case files can be found at the following locations:

- [MATPOWER](https://github.com/MATPOWER/matpower)
- [PGLib - OPF](https://github.com/power-grid-lib/pglib-opf)
"""
function read_matpower_case(url :: String)
    return parse_matpower(download(url))
end

case = "https://raw.githubusercontent.com/MATPOWER/matpower/master/data/case9.m" |> read_matpower_case

pm = instantiate_model(case, ACPPowerModel, build_opf)

"""
    variable_pv_generation(pm::AbstractPowerModel)

    Adds variables modelling PV generation (real power only). at each bus
"""
function variable_pv_generation_real(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    pg_pv = var(pm, nw)[:pg_pv] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :bus)], base_name="$(nw)_pg_pv",
        start = comp_start_value(ref(pm, nw, :bus, i), "pg_pv_start"),
        lower_bound = 0,
        upper_bound = 100
    )

    report && sol_component_value(pm, nw, :bus, :pg_pv, ids(pm, nw, :bus), pg_pv)
end

variable_pv_generation_real(pm)


"""
    objective_maximise_generation(pm::AbstractPowerModel)

Sets the objective to maximize generation.
"""
function objective_maximise_generation(pm::AbstractPowerModel)
    
    return JuMP.@objective(pm.model, Max,
        sum(
            sum( var(pm, n, :pg, i)^2 + var(pm, n, :qg, i)^2
                for (i,gen) in nw_ref[:gen])
        for (n, nw_ref) in nws(pm))
    )
end

objective_maximise_generation(pm)

result = solve_ac_opf(case, Ipopt.Optimizer)

