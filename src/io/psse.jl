# Parse PSS(R)E data from PTI file into PowerModels data format


"""
    _init_bus!(bus, id)

Initializes a `bus` of id `id` with default values given in the PSS(R)E
specification.
"""
function _init_bus!(bus::Dict{String,Any}, id::Int)
    bus["bus_i"] = id
    bus["bus_type"] = 1
    bus["area"] = 1
    bus["vm"] = 1.0
    bus["va"] = 0.0
    bus["base_kv"] = 1.0
    bus["zone"] = 1
    bus["name"] = "            "
    bus["vmax"] = 1.1
    bus["vmin"] = 0.9
    bus["index"] = id
end


"""
    _get_bus_value(bus_i, field, pm_data)

Returns the value of `field` of `bus_i` from the PowerModels data. Requires
"bus" Dict to already be populated.
"""
function _get_bus_value(bus_i, field, pm_data)
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

    Memento.warn(_LOGGER, "Could not find bus $bus_i, returning 0 for field $field")
    return 0
end


"""
    _find_max_bus_id(pm_data)

Returns the maximum bus id in `pm_data`
"""
function _find_max_bus_id(pm_data::Dict)::Int
    max_id = 0
    for bus in pm_data["bus"]
        if bus["index"] > max_id && !endswith(bus["name"], "starbus")
            max_id = bus["index"]
        end
    end

    return max_id
end


"""
    create_starbus(pm_data, transformer)

Creates a starbus from a given three-winding `transformer`. "source_id" is given
by `["bus_i", "name", "I", "J", "K", "CKT"]` where "bus_i" and "name" are the
modified names for the starbus, and "I", "J", "K" and "CKT" come from the
originating transformer, in the PSS(R)E transformer specification.
"""
function _create_starbus_from_transformer(pm_data::Dict, transformer::Dict)::Dict
    starbus = Dict{String,Any}()

    # transformer starbus ids will be one order of magnitude larger than highest real bus id
    base = convert(Int, 10 ^ ceil(log10(abs(_find_max_bus_id(pm_data)))))
    starbus_id = transformer["I"] + base

    _init_bus!(starbus, starbus_id)

    starbus["name"] = "$(transformer["I"]) starbus"

    starbus["vm"] = transformer["VMSTAR"]
    starbus["va"] = transformer["ANSTAR"]
    starbus["bus_type"] = transformer["STAT"]
    starbus["area"] = _get_bus_value(transformer["I"], "area", pm_data)
    starbus["zone"] = _get_bus_value(transformer["I"], "zone", pm_data)
    starbus["source_id"] = push!(["transformer", starbus["bus_i"], starbus["name"]], transformer["I"], transformer["J"], transformer["K"], transformer["CKT"])

    return starbus
end


"Imports remaining keys from `data_in` into `data_out`, excluding keys in `exclude`"
function _import_remaining!(data_out::Dict, data_in::Dict, import_all::Bool; exclude=[])
    if import_all
        for (k, v) in data_in
            if !(k in exclude)
                if isa(v, Array)
                    for (n, item) in enumerate(v)
                        if isa(item, Dict)
                            _import_remaining!(item, item, import_all)
                            if !("index" in keys(item))
                                item["index"] = n
                            end
                        end
                    end
                elseif isa(v, Dict)
                    _import_remaining!(v, v, import_all)
                end
                data_out[lowercase(k)] = v
                delete!(data_in, k)
            end
        end
    end
end


"""
    _psse2pm_branch!(pm_data, pti_data)

Parses PSS(R)E-style Branch data into a PowerModels-style Dict. "source_id" is
given by `["I", "J", "CKT"]` in PSS(R)E Branch specification.
"""
function _psse2pm_branch!(pm_data::Dict, pti_data::Dict, import_all::Bool)


    pm_data["branch"] = []
    if haskey(pti_data, "BRANCH")
        for (i, branch) in enumerate(pti_data["BRANCH"])
            sub_data = Dict{String,Any}()

            sub_data["f_bus"] = pop!(branch, "I")
            sub_data["t_bus"] = pop!(branch, "J")
            sub_data["br_r"] = pop!(branch, "R")
            sub_data["br_x"] = pop!(branch, "X")
            sub_data["g_fr"] = pop!(branch, "GI")
            sub_data["b_fr"] = branch["BI"] == 0. && branch["B"] != 0. ? branch["B"] / 2 : pop!(branch, "BI")
            sub_data["g_to"] = pop!(branch, "GJ")
            sub_data["b_to"] = branch["BJ"] == 0. && branch["B"] != 0. ? branch["B"] / 2 : pop!(branch, "BJ")
            sub_data["rate_a"] = pop!(branch, "RATEA")
            sub_data["rate_b"] = pop!(branch, "RATEB")
            sub_data["rate_c"] = pop!(branch, "RATEC")
            sub_data["tap"] = 1.0
            sub_data["shift"] = 0.0
            sub_data["br_status"] = pop!(branch, "ST")
            sub_data["angmin"] = 0.0
            sub_data["angmax"] = 0.0
            sub_data["transformer"] = false

            sub_data["source_id"] = ["branch", sub_data["f_bus"], sub_data["t_bus"], pop!(branch, "CKT")]
            sub_data["index"] = i

            _import_remaining!(sub_data, branch, import_all; exclude=["B", "BI", "BJ"])

            if sub_data["rate_a"] == 0.0
                delete!(sub_data, "rate_a")
            end
            if sub_data["rate_b"] == 0.0
                delete!(sub_data, "rate_b")
            end
            if sub_data["rate_c"] == 0.0
                delete!(sub_data, "rate_c")
            end

            push!(pm_data["branch"], sub_data)
        end
    end
end


"""
    _psse2pm_generator!(pm_data, pti_data)

Parses PSS(R)E-style Generator data in a PowerModels-style Dict. "source_id" is
given by `["I", "ID"]` in PSS(R)E Generator specification.
"""
function _psse2pm_generator!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["gen"] = []
    if haskey(pti_data, "GENERATOR")
        for gen in pti_data["GENERATOR"]
            sub_data = Dict{String,Any}()

            sub_data["gen_bus"] = pop!(gen, "I")
            sub_data["gen_status"] = pop!(gen, "STAT")
            sub_data["pg"] = pop!(gen, "PG")
            sub_data["qg"] = pop!(gen, "QG")
            sub_data["vg"] = pop!(gen, "VS")
            sub_data["mbase"] = pop!(gen, "MBASE")
            sub_data["pmin"] = pop!(gen, "PB")
            sub_data["pmax"] = pop!(gen, "PT")
            sub_data["qmin"] = pop!(gen, "QB")
            sub_data["qmax"] = pop!(gen, "QT")

            # Default Cost functions
            sub_data["model"] = 2
            sub_data["startup"] = 0.0
            sub_data["shutdown"] = 0.0
            sub_data["ncost"] = 2
            sub_data["cost"] = [1.0, 0.0]

            sub_data["source_id"] = ["generator", sub_data["gen_bus"], pop!(gen, "ID")]
            sub_data["index"] = length(pm_data["gen"]) + 1

            _import_remaining!(sub_data, gen, import_all)

            push!(pm_data["gen"], sub_data)
        end
    end
end


"""
    _psse2pm_bus!(pm_data, pti_data)

Parses PSS(R)E-style Bus data into a PowerModels-style Dict. "source_id" is given
by ["I", "NAME"] in PSS(R)E Bus specification.
"""
function _psse2pm_bus!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["bus"] = []
    if haskey(pti_data, "BUS")
        for bus in pti_data["BUS"]
            sub_data = Dict{String,Any}()

            sub_data["bus_i"] = bus["I"]
            sub_data["bus_type"] = pop!(bus, "IDE")
            sub_data["area"] = pop!(bus, "AREA")
            sub_data["vm"] = pop!(bus, "VM")
            sub_data["va"] = pop!(bus, "VA")
            sub_data["base_kv"] = pop!(bus, "BASKV")
            sub_data["zone"] = pop!(bus, "ZONE")
            sub_data["name"] = pop!(bus, "NAME")
            sub_data["vmax"] = pop!(bus, "NVHI")
            sub_data["vmin"] = pop!(bus, "NVLO")

            sub_data["source_id"] = ["bus", "$(bus["I"])"]
            sub_data["index"] = pop!(bus, "I")

            _import_remaining!(sub_data, bus, import_all)

            push!(pm_data["bus"], sub_data)
        end
    end
end


"""
    _psse2pm_load!(pm_data, pti_data)

Parses PSS(R)E-style Load data into a PowerModels-style Dict. "source_id" is given
by `["I", "ID"]` in the PSS(R)E Load specification.
"""
function _psse2pm_load!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["load"] = []
    if haskey(pti_data, "LOAD")
        for load in pti_data["LOAD"]
            sub_data = Dict{String,Any}()

            sub_data["load_bus"] = pop!(load, "I")
            sub_data["pd"] = pop!(load, "PL")
            sub_data["qd"] = pop!(load, "QL")
            sub_data["status"] = pop!(load, "STATUS")

            sub_data["source_id"] = ["load", sub_data["load_bus"], pop!(load, "ID")]
            sub_data["index"] = length(pm_data["load"]) + 1

            _import_remaining!(sub_data, load, import_all)

            push!(pm_data["load"], sub_data)
        end
    end
end


"""
    _psse2pm_shunt!(pm_data, pti_data)

Parses PSS(R)E-style Fixed and Switched Shunt data into a PowerModels-style
Dict. "source_id" is given by `["I", "ID"]` for Fixed Shunts, and `["I", "SWREM"]`
for Switched Shunts, as given by the PSS(R)E Fixed and Switched Shunts
specifications.
"""
function _psse2pm_shunt!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["shunt"] = []

    if haskey(pti_data, "FIXED SHUNT")
        for shunt in pti_data["FIXED SHUNT"]
            sub_data = Dict{String,Any}()

            sub_data["shunt_bus"] = pop!(shunt, "I")
            sub_data["gs"] = pop!(shunt, "GL")
            sub_data["bs"] = pop!(shunt, "BL")
            sub_data["status"] = pop!(shunt, "STATUS")

            sub_data["source_id"] = ["fixed shunt", sub_data["shunt_bus"], pop!(shunt, "ID")]
            sub_data["index"] = length(pm_data["shunt"]) + 1

            _import_remaining!(sub_data, shunt, import_all)

            push!(pm_data["shunt"], sub_data)
        end
    end

    if haskey(pti_data, "SWITCHED SHUNT")
        Memento.info(_LOGGER, "Switched shunt converted to fixed shunt, with default value gs=0.0")

        for shunt in pti_data["SWITCHED SHUNT"]
            sub_data = Dict{String,Any}()

            sub_data["shunt_bus"] = pop!(shunt, "I")
            sub_data["gs"] = 0.0
            sub_data["bs"] = pop!(shunt, "BINIT")
            sub_data["status"] = pop!(shunt, "STAT")

            sub_data["source_id"] = ["switched shunt", sub_data["shunt_bus"], pop!(shunt, "SWREM")]
            sub_data["index"] = length(pm_data["shunt"]) + 1

            _import_remaining!(sub_data, shunt, import_all)

            push!(pm_data["shunt"], sub_data)
        end
    end
end


"""
    _psse2pm_transformer!(pm_data, pti_data)

Parses PSS(R)E-style Transformer data into a PowerModels-style Dict. "source_id"
is given by `["I", "J", "K", "CKT", "winding"]`, where "winding" is 0 if
transformer is two-winding, and 1, 2, or 3 for three-winding, and the remaining
keys are defined in the PSS(R)E Transformer specification.
"""
function _psse2pm_transformer!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    if !haskey(pm_data, "branch")
        pm_data["branch"] = []
    end

    if haskey(pti_data, "TRANSFORMER")
        for transformer in pti_data["TRANSFORMER"]
            if transformer["K"] == 0  # Two-winding Transformers
                sub_data = Dict{String,Any}()

                sub_data["f_bus"] = transformer["I"]
                sub_data["t_bus"] = transformer["J"]

                # Unit Transformations
                if transformer["CZ"] == 1  # "for resistance and reactance in pu on system MVA base and winding voltage base"
                    br_r, br_x = transformer["R1-2"], transformer["X1-2"]
                else  # NOT "for resistance and reactance in pu on system MVA base and winding voltage base"
                    if transformer["CZ"] == 3  # "for transformer load loss in watts and impedance magnitude in pu on a specified MVA base and winding voltage base."
                        br_r = 1e-6 * transformer["R1-2"] / transformer["SBASE1-2"]
                        br_x = sqrt(transformer["X1-2"]^2 - br_r^2)
                    else
                        br_r, br_x = transformer["R1-2"], transformer["X1-2"]
                    end
                    br_r *= (transformer["NOMV1"]^2 / _get_bus_value(transformer["I"], "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE1-2"])
                    br_x *= (transformer["NOMV1"]^2 / _get_bus_value(transformer["I"], "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE1-2"])
                end

                sub_data["br_r"] = br_r
                sub_data["br_x"] = br_x

                sub_data["g_fr"] = pop!(transformer, "MAG1")
                sub_data["b_fr"] = pop!(transformer, "MAG2")
                sub_data["g_to"] = 0.0
                sub_data["b_to"] = 0.0

                sub_data["rate_a"] = pop!(transformer, "RATA1")
                sub_data["rate_b"] = pop!(transformer, "RATB1")
                sub_data["rate_c"] = pop!(transformer, "RATC1")

                if sub_data["rate_a"] == 0.0
                    delete!(sub_data, "rate_a")
                end
                if sub_data["rate_b"] == 0.0
                    delete!(sub_data, "rate_b")
                end
                if sub_data["rate_c"] == 0.0
                    delete!(sub_data, "rate_c")
                end

                sub_data["tap"] = pop!(transformer, "WINDV1") / pop!(transformer, "WINDV2")
                sub_data["shift"] = pop!(transformer, "ANG1")

                # Unit Transformations
                if transformer["CW"] != 1  # NOT "for off-nominal turns ratio in pu of winding bus base voltage"
                    sub_data["tap"] *= _get_bus_value(transformer["J"], "base_kv", pm_data) / _get_bus_value(transformer["I"], "base_kv", pm_data)
                    if transformer["CW"] == 3  # "for off-nominal turns ratio in pu of nominal winding voltage, NOMV1, NOMV2 and NOMV3."
                        sub_data["tap"] *= transformer["NOMV1"] / transformer["NOMV2"]
                    end
                end

                sub_data["br_status"] = transformer["STAT"]

                sub_data["angmin"] = 0.0
                sub_data["angmax"] = 0.0

                sub_data["source_id"] = ["transformer", pop!(transformer, "I"), pop!(transformer, "J"), pop!(transformer, "K"), pop!(transformer, "CKT"), 0]
                sub_data["transformer"] = true
                sub_data["index"] = length(pm_data["branch"]) + 1

                _import_remaining!(sub_data, transformer, import_all; exclude=["I", "J", "K", "CZ", "CW", "R1-2", "R2-3", "R3-1",
                                                                              "X1-2", "X2-3", "X3-1", "SBASE1-2", "SBASE2-3",
                                                                              "SBASE3-1", "MAG1", "MAG2", "STAT", "NOMV1", "NOMV2"])

                push!(pm_data["branch"], sub_data)
            else  # Three-winding Transformers
                bus_id1, bus_id2, bus_id3 = transformer["I"], transformer["J"], transformer["K"]

                # Creates a starbus (or "dummy" bus) to which each winding of the transformer will connect
                starbus = _create_starbus_from_transformer(pm_data, transformer)
                push!(pm_data["bus"], starbus)

                # Create 3 branches from a three winding transformer (one for each winding, which will each connect to the starbus)
                br_r12, br_r23, br_r31 = transformer["R1-2"], transformer["R2-3"], transformer["R3-1"]
                br_x12, br_x23, br_x31 = transformer["X1-2"], transformer["X2-3"], transformer["X3-1"]

                # Unit Transformations
                if transformer["CZ"] == 3  # "for transformer load loss in watts and impedance magnitude in pu on a specified MVA base and winding voltage base."
                    br_r12 *= 1e-6 / transformer["SBASE1-2"]
                    br_r23 *= 1e-6 / transformer["SBASE2-3"]
                    br_r31 *= 1e-6 / transformer["SBASE3-1"]

                    br_x12 = sqrt(br_x12^2 - br_r12^2)
                    br_x23 = sqrt(br_x23^2 - br_r23^2)
                    br_x31 = sqrt(br_x31^2 - br_r31^2)
                end

                # Unit Transformations
                if transformer["CZ"] != 1  # NOT "for resistance and reactance in pu on system MVA base and winding voltage base"
                    br_r12 *= (transformer["NOMV1"]^2 / _get_bus_value(bus_id1, "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE1-2"])
                    br_r23 *= (transformer["NOMV2"]^2 / _get_bus_value(bus_id2, "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE2-3"])
                    br_r31 *= (transformer["NOMV3"]^2 / _get_bus_value(bus_id3, "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE3-1"])

                    br_x12 *= (transformer["NOMV1"]^2 / _get_bus_value(bus_id1, "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE1-2"])
                    br_x23 *= (transformer["NOMV2"]^2 / _get_bus_value(bus_id2, "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE2-3"])
                    br_x31 *= (transformer["NOMV3"]^2 / _get_bus_value(bus_id3, "base_kv", pm_data)^2) * (pm_data["baseMVA"] / transformer["SBASE3-1"])
                end

                # See "Power System Stability and Control", ISBN: 0-07-035958-X, Eq. 6.72
                Zr_p = 1/2 * (br_r12 - br_r23 + br_r31)
                Zr_s = 1/2 * (br_r23 - br_r31 + br_r12)
                Zr_t = 1/2 * (br_r31 - br_r12 + br_r23)
                Zx_p = 1/2 * (br_x12 - br_x23 + br_x31)
                Zx_s = 1/2 * (br_x23 - br_x31 + br_x12)
                Zx_t = 1/2 * (br_x31 - br_x12 + br_x23)

                # Build each of the three transformer branches
                for (m, (bus_id, br_r, br_x)) in enumerate(zip([bus_id1, bus_id2, bus_id3], [Zr_p, Zr_s, Zr_t], [Zx_p, Zx_s, Zx_t]))
                    sub_data = Dict{String,Any}()

                    sub_data["f_bus"] = bus_id
                    sub_data["t_bus"] = starbus["bus_i"]

                    sub_data["br_r"] = br_r
                    sub_data["br_x"] = br_x

                    sub_data["g_fr"] = m == 1 ? pop!(transformer, "MAG1") : 0.0
                    sub_data["b_fr"] = m == 1 ? pop!(transformer, "MAG2") : 0.0
                    sub_data["g_to"] = 0.0
                    sub_data["b_to"] = 0.0

                    sub_data["rate_a"] = pop!(transformer, "RATA$m")
                    sub_data["rate_b"] = pop!(transformer, "RATB$m")
                    sub_data["rate_c"] = pop!(transformer, "RATC$m")

                    if sub_data["rate_a"] == 0.0
                        delete!(sub_data, "rate_a")
                    end
                    if sub_data["rate_b"] == 0.0
                        delete!(sub_data, "rate_b")
                    end
                    if sub_data["rate_c"] == 0.0
                        delete!(sub_data, "rate_c")
                    end

                    sub_data["tap"] = pop!(transformer, "WINDV$m")
                    sub_data["shift"] = pop!(transformer, "ANG$m")

                    # Unit Transformations
                    if transformer["CW"] != 1  # NOT "for off-nominal turns ratio in pu of winding bus base voltage"
                        sub_data["tap"] /= _get_bus_value(bus_id, "base_kv", pm_data)
                        if transformer["CW"] == 3  # "for off-nominal turns ratio in pu of nominal winding voltage, NOMV1, NOMV2 and NOMV3."
                            sub_data["tap"] *= transformer["NOMV$m"]
                        end
                    end

                    sub_data["br_status"] = transformer["STAT"]

                    sub_data["angmin"] = 0.0
                    sub_data["angmax"] = 0.0

                    sub_data["source_id"] = ["transformer", transformer["I"], transformer["J"], transformer["K"], transformer["CKT"], m]
                    sub_data["transformer"] = true
                    sub_data["index"] = length(pm_data["branch"]) + 1

                    _import_remaining!(sub_data, transformer, import_all; exclude=["I", "J", "K", "CZ", "CW", "R1-2", "R2-3", "R3-1",
                                                                                  "X1-2", "X2-3", "X3-1", "SBASE1-2", "SBASE2-3", "CKT",
                                                                                  "SBASE3-1", "MAG1", "MAG2", "STAT","NOMV1", "NOMV2",
                                                                                  "NOMV3", "WINDV1", "WINDV2", "WINDV3", "RATA1",
                                                                                  "RATA2", "RATA3", "RATB1", "RATB2", "RATB3", "RATC1",
                                                                                  "RATC2", "RATC3", "ANG1", "ANG2", "ANG3"])

                    push!(pm_data["branch"], sub_data)
                end
            end
        end
    end
end




"""
    _psse2pm_dcline!(pm_data, pti_data)

Parses PSS(R)E-style Two-Terminal and VSC DC Lines data into a PowerModels
compatible Dict structure by first converting them to a simple DC Line Model.
For Two-Terminal DC lines, "source_id" is given by `["IPR", "IPI", "NAME"]` in the
PSS(R)E Two-Terminal DC specification. For Voltage Source Converters, "source_id"
is given by `["IBUS1", "IBUS2", "NAME"]`, where "IBUS1" is "IBUS" of the first
converter bus, and "IBUS2" is the "IBUS" of the second converter bus, in the
PSS(R)E Voltage Source Converter specification.
"""
function _psse2pm_dcline!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["dcline"] = []

    if haskey(pti_data, "TWO-TERMINAL DC")
        for dcline in pti_data["TWO-TERMINAL DC"]
            Memento.info(_LOGGER, "Two-Terminal DC lines are supported via a simple *lossless* dc line model approximated by two generators.")
            sub_data = Dict{String,Any}()

            # Unit conversions?
            power_demand = dcline["MDC"] == 1 ? abs(dcline["SETVL"]) : dcline["MDC"] == 2 ? abs(dcline["SETVL"] / pop!(dcline, "VSCHD") / 1000) : 0

            sub_data["f_bus"] = dcline["IPR"]
            sub_data["t_bus"] = dcline["IPI"]
            sub_data["br_status"] = pop!(dcline, "MDC") == 0 ? 0 : 1
            sub_data["pf"] = power_demand
            sub_data["pt"] = power_demand
            sub_data["qf"] = 0.0
            sub_data["qt"] = 0.0
            sub_data["vf"] = _get_bus_value(pop!(dcline, "IPR"), "vm", pm_data)
            sub_data["vt"] = _get_bus_value(pop!(dcline, "IPI"), "vm", pm_data)

            sub_data["pminf"] = 0.0
            sub_data["pmaxf"] = dcline["SETVL"] > 0 ? power_demand : -power_demand
            sub_data["pmint"] = pop!(dcline, "SETVL") > 0 ? -power_demand : power_demand
            sub_data["pmaxt"] = 0.0

            anmn = []
            for key in ["ANMNR", "ANMNI"]
                if abs(dcline[key]) <= 90.
                    push!(anmn, pop!(dcline, key))
                else
                    push!(anmn, 0)
                    Memento.warn(_LOGGER, "$key outside reasonable limits, setting to 0 degress")
                end
            end

            sub_data["qmaxf"] = 0.0
            sub_data["qmaxt"] = 0.0
            sub_data["qminf"] = -max(abs(sub_data["pminf"]), abs(sub_data["pmaxf"])) * cosd(anmn[1])
            sub_data["qmint"] = -max(abs(sub_data["pmint"]), abs(sub_data["pmaxt"])) * cosd(anmn[2])

            # Can we use "number of bridges in series (NBR/NBI)" to compute a loss?
            sub_data["loss0"] = 0.0
            sub_data["loss1"] = 0.0

            # Costs (set to default values)
            sub_data["startup"] = 0.0
            sub_data["shutdown"] = 0.0
            sub_data["ncost"] = 3
            sub_data["cost"] = [0.0, 0.0, 0.0]
            sub_data["model"] = 2

            sub_data["source_id"] = ["two-terminal dc", sub_data["f_bus"], sub_data["t_bus"], pop!(dcline, "NAME")]
            sub_data["index"] = length(pm_data["dcline"]) + 1

            _import_remaining!(sub_data, dcline, import_all)

            push!(pm_data["dcline"], sub_data)
        end
    end

    if haskey(pti_data, "VOLTAGE SOURCE CONVERTER")
        Memento.info(_LOGGER, "VSC-HVDC lines are supported via a dc line model approximated by two generators and an associated loss.")
        for dcline in pti_data["VOLTAGE SOURCE CONVERTER"]
            # Converter buses : is the distinction between ac and dc side meaningful?
            dcside, acside = dcline["CONVERTER BUSES"]

            # PowerWorld conversion from PTI to matpower seems to create two
            # artificial generators from a VSC, but it is not clear to me how
            # the value of "pg" is determined and adds shunt to the DC-side bus.
            sub_data = Dict{String,Any}()

            # VSC intended to be one or bi-directional?
            sub_data["f_bus"] = pop!(dcside, "IBUS")
            sub_data["t_bus"] = pop!(acside, "IBUS")
            sub_data["br_status"] = pop!(dcline, "MDC") == 0 || pop!(dcside, "TYPE") == 0 || pop!(acside, "TYPE") == 0 ? 0 : 1

            sub_data["pf"] = 0.0
            sub_data["pt"] = 0.0

            sub_data["qf"] = 0.0
            sub_data["qt"] = 0.0

            sub_data["vf"] = pop!(dcside, "MODE") == 1 ? pop!(dcside, "ACSET") : 1.0
            sub_data["vt"] = pop!(acside, "MODE") == 1 ? pop!(acside, "ACSET") : 1.0

            sub_data["pmaxf"] = dcside["SMAX"] == 0.0 && dcside["IMAX"] == 0.0 ? max(abs(dcside["MAXQ"]), abs(dcside["MINQ"])) : min(pop!(dcside, "IMAX"), pop!(dcside, "SMAX"))
            sub_data["pmaxt"] = acside["SMAX"] == 0.0 && acside["IMAX"] == 0.0 ? max(abs(acside["MAXQ"]), abs(acside["MINQ"])) : min(pop!(acside, "IMAX"), pop!(acside, "SMAX"))
            sub_data["pminf"] = -sub_data["pmaxf"]
            sub_data["pmint"] = -sub_data["pmaxt"]

            sub_data["qminf"] = pop!(dcside, "MINQ")
            sub_data["qmaxf"] = pop!(dcside, "MAXQ")
            sub_data["qmint"] = pop!(acside, "MINQ")
            sub_data["qmaxt"] = pop!(acside, "MAXQ")

            sub_data["loss0"] = (pop!(dcside, "ALOSS") + pop!(acside, "ALOSS") + pop!(dcside, "MINLOSS") + pop!(acside, "MINLOSS")) * 1e-3
            sub_data["loss1"] = (pop!(dcside, "BLOSS") + pop!(acside, "BLOSS")) * 1e-3 # how to include resistance?

            # Costs (set to default values)
            sub_data["startup"] = 0.0
            sub_data["shutdown"] = 0.0
            sub_data["ncost"] = 3
            sub_data["cost"] = [0.0, 0.0, 0.0]
            sub_data["model"] = 2

            sub_data["source_id"] = ["vsc dc", sub_data["f_bus"], sub_data["t_bus"], pop!(dcline, "NAME")]
            sub_data["index"] = length(pm_data["dcline"]) + 1

            _import_remaining!(sub_data, dcline, import_all)

            push!(pm_data["dcline"], sub_data)
        end
    end
end


function _psse2pm_storage!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["storage"] = []
end

function _psse2pm_switch!(pm_data::Dict, pti_data::Dict, import_all::Bool)
    pm_data["switch"] = []
end


"""
    _pti_to_powermodels!(pti_data)

Converts PSS(R)E-style data parsed from a PTI raw file, passed by `pti_data`
into a format suitable for use internally in PowerModels. Imports all remaining
data from the PTI file if `import_all` is true (Default: false).
"""
function _pti_to_powermodels!(pti_data::Dict; import_all=false, validate=true)::Dict
    pm_data = Dict{String,Any}()

    rev = pop!(pti_data["CASE IDENTIFICATION"][1], "REV")

    pm_data["per_unit"] = false
    pm_data["source_type"] = "pti"
    pm_data["source_version"] = "$rev"
    pm_data["baseMVA"] = pop!(pti_data["CASE IDENTIFICATION"][1], "SBASE")
    pm_data["name"] = pop!(pti_data["CASE IDENTIFICATION"][1], "NAME")

    _import_remaining!(pm_data, pti_data["CASE IDENTIFICATION"][1], import_all)

    _psse2pm_bus!(pm_data, pti_data, import_all)
    _psse2pm_load!(pm_data, pti_data, import_all)
    _psse2pm_shunt!(pm_data, pti_data, import_all)
    _psse2pm_generator!(pm_data, pti_data, import_all)
    _psse2pm_branch!(pm_data, pti_data, import_all)
    _psse2pm_transformer!(pm_data, pti_data, import_all)
    _psse2pm_dcline!(pm_data, pti_data, import_all)
    _psse2pm_storage!(pm_data, pti_data, import_all)
    _psse2pm_switch!(pm_data, pti_data, import_all)

    _import_remaining!(pm_data, pti_data, import_all; exclude=[
        "CASE IDENTIFICATION", "BUS", "LOAD", "FIXED SHUNT",
        "SWITCHED SHUNT", "GENERATOR","BRANCH", "TRANSFORMER",
        "TWO-TERMINAL DC", "VOLTAGE SOURCE CONVERTER"
    ])

    # update lookup structure
    for (k, v) in pm_data
        if isa(v, Array)
            #println("updating $(k)")
            dict = Dict{String,Any}()
            for item in v
                @assert("index" in keys(item))
                dict[string(item["index"])] = item
            end
            pm_data[k] = dict
        end
    end

    if validate
        correct_network_data!(pm_data)
    end

    return pm_data
end


"Parses directly from file"
function parse_psse(filename::String; kwargs...)::Dict
    pm_data = open(filename) do f
        parse_psse(f; kwargs...)
    end

    return pm_data
end


"Parses directly from iostream"
function parse_psse(io::IO; kwargs...)::Dict
    pti_data = parse_pti(io)
    pm = _pti_to_powermodels!(pti_data; kwargs...)
    return pm
end
