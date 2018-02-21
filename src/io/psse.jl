# Parse PSS(R)E data from PTI file into PowerModels data format

"""
    calc_2term_reactive_power(power_demand, min_firing_angle, max_firing_angle)

Calculates the lower and upper limits on the reactive power for a two-terminal
DC line. See Kimbark (ISBN 0-471-47580-7), Ch 3, Eq (46). Overlap is assumed to
be <60deg, i.e. the dc line is operating normally. See discussion in cited
book above.
"""
function calc_2term_reactive_power(power_demand, min_firing_angle, max_firing_angle)
    qmin = abs(power_demand * tand(min_firing_angle))
    qmax = abs(power_demand * tand((acosd(cosd(max_firing_angle) + 1 / 2) / 2)))

    return qmin, qmax
end


"""
    get_bus_value(bus_i, field, pm_data)

Returns the value of `field` of `bus_i` from the PowerModels data. Requires
"bus" Dict to already be populated.
"""
function get_bus_value(bus_i, field, pm_data)
    if isa(pm_data["bus"], Array)
        for bus in pm_data["bus"]
            if bus["index"] == bus_i
                return bus[field]
            end
        end
    elseif isa(pm_data["bus"], Dict)
        for (k, bus) in pm_data["bus"]
            if bus["index"] == bus_i
                return bus[field]
            end
        end
    end

    warn(LOGGER, "Could not find bus $bus_i, returning 0 for field $field")
    return 0
end


"""
    psse2pm_branch!(pm_data, pti_data)

Parses PSS(R)E-style Branch data into a PowerModels-style Dict.
"""
function psse2pm_branch!(pm_data::Dict, pti_data::Dict)
    pm_data["branch"] = []
    if haskey(pti_data, "BRANCH")
        for (i, branch) in enumerate(pti_data["BRANCH"])
            sub_data = Dict{String,Any}()

            sub_data["f_bus"] = branch["I"]
            sub_data["t_bus"] = branch["J"]
            sub_data["br_r"] = branch["R"]
            sub_data["br_x"] = branch["X"]
            sub_data["g_fr"] = branch["GI"]
            sub_data["b_fr"] = branch["BI"] == 0. && branch["B"] != 0. ? branch["B"] / 2 : branch["BI"]
            sub_data["g_to"] = branch["GJ"]
            sub_data["b_to"] = branch["BJ"] == 0. && branch["B"] != 0. ? branch["B"] / 2 : branch["BJ"]
            sub_data["rate_a"] = branch["RATEA"]
            sub_data["rate_b"] = branch["RATEB"]
            sub_data["rate_c"] = branch["RATEC"]
            sub_data["tap"] = 1.0
            sub_data["shift"] = 0.0
            sub_data["br_status"] = branch["ST"]
            sub_data["angmin"] = 0.0
            sub_data["angmax"] = 0.0
            sub_data["transformer"] = false
            sub_data["index"] = i

            append!(pm_data["branch"], [deepcopy(sub_data)])
        end
    end
end


"""
    psse2pm_generator!(pm_data, pti_data)

Parses PSS(R)E-style Generator data in a PowerModels-style Dict.
"""
function psse2pm_generator!(pm_data::Dict, pti_data::Dict)
    pm_data["gen"] = []
    if haskey(pti_data, "GENERATOR")
        for (i, gen) in enumerate(pti_data["GENERATOR"])
            sub_data = Dict{String,Any}()

            sub_data["model"] = 2
            sub_data["startup"] = 0.0
            sub_data["shutdown"] = 0.0
            sub_data["ncost"] = 3
            sub_data["cost"] = [0.0, 1.0, 0.0]
            sub_data["gen_bus"] = gen["I"]
            sub_data["gen_status"] = gen["STAT"]
            sub_data["pg"] = gen["PG"]
            sub_data["qg"] = gen["QG"]
            sub_data["vg"] = gen["VS"]
            sub_data["mbase"] = gen["MBASE"]
            sub_data["ramp_agc"] = 0.0
            sub_data["ramp_q"] = 0.0
            sub_data["ramp_10"] = 0.0
            sub_data["ramp_30"] = 0.0
            sub_data["pmin"] = gen["PB"]
            sub_data["pmax"] = gen["PT"]
            sub_data["apf"] = 0.0
            sub_data["qmin"] = gen["QB"]
            sub_data["qmax"] = gen["QT"]
            sub_data["pc1"] = 0.0
            sub_data["pc2"] = 0.0
            sub_data["qc1min"] = 0.0
            sub_data["qc1max"] = 0.0
            sub_data["qc2min"] = 0.0
            sub_data["qc2max"] = 0.0
            sub_data["index"] = i

            append!(pm_data["gen"], [deepcopy(sub_data)])
        end
    end
end


"""
    psse2pm_bus!(pm_data, pti_data)

Parses PSS(R)E-style Bus data into a PowerModels-style Dict.
"""
function psse2pm_bus!(pm_data::Dict, pti_data::Dict)
    pm_data["bus"] = []
    if haskey(pti_data, "BUS")
        for (i, bus) in enumerate(pti_data["BUS"])
            sub_data = Dict{String,Any}()

            sub_data["bus_i"] = bus["I"]
            sub_data["bus_type"] = bus["IDE"]
            sub_data["area"] = bus["AREA"]
            sub_data["vm"] = bus["VM"]
            sub_data["va"] = bus["VA"]
            sub_data["base_kv"] = bus["BASKV"]
            sub_data["zone"] = bus["ZONE"]
            sub_data["name"] = bus["NAME"]

            if haskey(bus, "NVHI") && haskey(bus, "NVLO")
                sub_data["vmax"] = bus["NVHI"]
                sub_data["vmin"] = bus["NVLO"]
            else
                warn(LOGGER, "PTI v$(pti_data["CASE IDENTIFICATION"][1]["REV"]) does not contain vmin and vmax values, defaults of 0.9 and 1.1, respectively, assumed.")
                sub_data["vmax"] = 1.1
                sub_data["vmin"] = 0.9
            end

            sub_data["index"] = bus["I"]

            append!(pm_data["bus"], [deepcopy(sub_data)])
        end
    end
end


"""
    psse2pm_load!(pm_data, pti_data)

Parses PSS(R)E-style Load data into a PowerModels-style Dict.
"""
function psse2pm_load!(pm_data::Dict, pti_data::Dict)
    pm_data["load"] = []
    if haskey(pti_data, "LOAD")
        for (i, load) in enumerate(pti_data["LOAD"])
            sub_data = Dict{String,Any}()

            sub_data["load_bus"] = load["I"]
            sub_data["pd"] = load["PL"]
            sub_data["qd"] = load["QL"]
            sub_data["status"] = load["STATUS"]
            sub_data["index"] = i

            append!(pm_data["load"], [deepcopy(sub_data)])
        end
    end
end


"""
    psse2pm_shunt!(pm_data, pti_data)

Parses PSS(R)E-style Fixed and Switched Shunt data into a PowerModels-style
Dict.
"""
function psse2pm_shunt!(pm_data::Dict, pti_data::Dict)
    pm_data["shunt"] = []
    if haskey(pti_data, "FIXED SHUNT")
        for (i, shunt) in enumerate(pti_data["FIXED SHUNT"])
            sub_data = Dict{String,Any}()

            sub_data["shunt_bus"] = shunt["I"]
            sub_data["gs"] = shunt["GL"]
            sub_data["bs"] = shunt["BL"]
            sub_data["status"] = shunt["STATUS"]
            sub_data["index"] = i

            append!(pm_data["shunt"], [deepcopy(sub_data)])
        end
    else
        i = 0
    end

    if haskey(pti_data, "SWITCHED SHUNT")
        warn(LOGGER, "Switched shunt converted to fixed shunt, with default value gs=0.0")

        for (n, shunt) in enumerate(pti_data["SWITCHED SHUNT"])
            sub_data = Dict{String,Any}()

            sub_data["shunt_bus"] = shunt["I"]
            sub_data["gs"] = 0.0
            sub_data["bs"] = shunt["BINIT"]
            sub_data["status"] = shunt["STAT"]
            sub_data["index"] = i + n

            append!(pm_data["shunt"], [deepcopy(sub_data)])
        end
    end
end


"""
    psse2pm_transformer!(pm_data, pti_data)

Parses PSS(R)E-style Transformer data into a PowerModels-style Dict.
"""
function psse2pm_transformer!(pm_data::Dict, pti_data::Dict)
    if !haskey(pm_data, "branch")
        pm_data["branch"] = []
        n = 0
    else
        n = length(pm_data["branch"])
    end

    if haskey(pti_data, "TRANSFORMER")
        for (i, transformer) in enumerate(pti_data["TRANSFORMER"])
            if transformer["K"] == 0  # Two-winding Transformers
                sub_data = Dict{String,Any}()

                sub_data["f_bus"] = transformer["I"]
                sub_data["t_bus"] = transformer["J"]
                sub_data["br_r"] = transformer["R1-2"]
                sub_data["br_x"] = transformer["X1-2"]

                # TODO: Correct implimentation of magnetizing admittance
                if transformer["MAG1"] != 0.0 || transformer["MAG2"] != 0.0
                    warn(LOGGER, "Magnetizing admittance is not yet supported")
                end

                sub_data["g_fr"] = 0.0
                sub_data["b_fr"] = transformer["MAG1"]
                sub_data["g_to"] = 0.0
                sub_data["b_to"] = 0.0

                sub_data["rate_a"] = transformer["RATA1"]
                sub_data["rate_b"] = transformer["RATB1"]
                sub_data["rate_c"] = transformer["RATC1"]
                sub_data["tap"] = transformer["WINDV1"] / transformer["WINDV2"]
                sub_data["shift"] = transformer["ANG1"]
                sub_data["br_status"] = transformer["STAT"]
                sub_data["angmin"] = 0.0
                sub_data["angmax"] = 0.0
                sub_data["transformer"] = true
                sub_data["index"] = i + n

                append!(pm_data["branch"], [deepcopy(sub_data)])
            else  # Three-winding Transformers
                # TODO: write converter for three-winding transformers
                warn(LOGGER, "Three-winding transformers are not yet supported, skipping transformer entry #$i")
            end
        end
    end
end


"""
    psse2pm_dclines!(pm_data, pti_data)

Parses PSS(R)E-style Two-Terminal and VSC DC Lines data into a PowerModels
compatible Dict structure by first converting them to a simple DC Line Model.
"""
function psse2pm_dclines!(pm_data::Dict, pti_data::Dict)
    pm_data["dcline"] = []

    if haskey(pti_data, "TWO-TERMINAL DC")
        warn(LOGGER, "Two-Terminal DC Lines are not yet supported")
        for (i, dcline) in enumerate(pti_data["TWO-TERMINAL DC"])
            sub_data = Dict{String,Any}()

            power_demand = dcline["MDC"] == 1 ? abs(dcline["SETVL"]) : dcline["MDC"] == 2 ? abs(dcline["SETVL"] / dcline["VSCHD"] / 1000) : 0

            sub_data["qminf"], sub_data["qmaxf"] = calc_2term_reactive_power(power_demand, dcline["ANMNR"], dcline["ANMXR"])
            sub_data["qmint"], sub_data["qmaxt"] = calc_2term_reactive_power(power_demand, dcline["ANMNI"], dcline["ANMXI"])

            sub_data["f_bus"] = dcline["IPR"]
            sub_data["t_bus"] = dcline["IPI"]
            sub_data["br_status"] = dcline["MDC"] == 0 ? 0 : 1
            sub_data["pf"] = power_demand
            sub_data["pt"] = power_demand
            sub_data["qf"] = 0
            sub_data["qt"] = 0
            sub_data["vf"] = get_bus_value(dcline["IPR"], "vm", pm_data)
            sub_data["vt"] = get_bus_value(dcline["IPI"], "vm", pm_data)

            sub_data["pminf"] = dcline["MDC"] > 0.0 ? 0.9 * power_demand : 0.0
            sub_data["pmaxf"] = dcline["MDC"] > 0.0 ? 1.1 * power_demand : 0.0
            sub_data["pmint"] = dcline["MDC"] < 0.0 ? 0.9 * power_demand : 0.0
            sub_data["pmaxt"] = dcline["MDC"] < 0.0 ? 1.1 * power_demand : 0.0

            sub_data["loss0"] = 0
            sub_data["loss1"] = 0
            sub_data["startup"] = 0.0
            sub_data["shutdown"] = 0.0
            sub_data["ncost"] = 3
            sub_data["cost"] = [0.0, 1.0, 0.0]
            sub_data["model"] = 2
            sub_data["index"] = i

            append!(pm_data["dcline"], [deepcopy(sub_data)])
        end
    else
        i = 0
    end

    if haskey(pti_data, "VOLTAGE SOURCE CONVERTER")
        warn(LOGGER, "Voltage Source Converter DC lines are not yet supported")
        for (n, dcline) in enumerate(pti_data["VOLTAGE SOURCE CONVERTER"])
            # TODO: Write converter for VSC dc lines
            # See thesis by Xiaoya Tan entitled "HVDC-VSC Model for MATPOWER"
        end
    end
end


"""
    parse_psse(pti_data)

Converts PSS(R)E-style data parsed from a PTI raw file, passed by `pti_data`
into a format suitable for use internally in PowerModels.
"""
function parse_psse(pti_data::Dict)::Dict
    pm_data = Dict{String,Any}()

    pm_data["multinetwork"] = false
    pm_data["per_unit"] = false
    pm_data["source_type"] = "pti"
    pm_data["source_version"] = VersionNumber("$(pti_data["CASE IDENTIFICATION"][1]["REV"])")
    pm_data["baseMVA"] = pti_data["CASE IDENTIFICATION"][1]["SBASE"]
    pm_data["name"] = pti_data["CASE IDENTIFICATION"][1]["NAME"]

    psse2pm_branch!(pm_data, pti_data)
    psse2pm_bus!(pm_data, pti_data)
    psse2pm_generator!(pm_data, pti_data)
    psse2pm_load!(pm_data, pti_data)
    psse2pm_load!(pm_data, pti_data)
    psse2pm_shunt!(pm_data, pti_data)
    psse2pm_transformer!(pm_data, pti_data)
    psse2pm_dclines!(pm_data, pti_data)

    # update lookup structure
    for (k, v) in pm_data
        if isa(v, Array)
            #println("updating $(k)")
            dict = Dict{String,Any}()
            for item in v
                assert("index" in keys(item))
                dict[string(item["index"])] = item
            end
            pm_data[k] = dict
        end
    end

    return pm_data
end


"Parses directly from file"
function parse_psse(file::String)::Dict
    pti_data = parse_pti(file)

    return parse_psse(pti_data)
end