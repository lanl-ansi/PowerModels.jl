#####################################################################
#                                                                   #
# This file provides functions for interfacing with pti .raw files  #
#                                                                   #
#####################################################################
using DataStructures


"""
    get_pti_sections()

Returns `Array` of the names of the sections, in the order that they
appear in a PTI file, v33+
"""
function get_pti_sections()::Array
    return ["CASE IDENTIFICATION", "BUS", "LOAD", "FIXED SHUNT", "GENERATOR", "BRANCH", "TRANSFORMER",
            "AREA INTERCHANGE", "TWO-TERMINAL DC", "VOLTAGE SOURCE CONVERTER", "IMPEDANCE CORRECTION",
            "MULTI-TERMINAL DC", "MULTI-SECTION LINE", "ZONE", "INTER-AREA TRANSFER", "OWNER",
            "FACTS CONTROL DEVICE", "SWITCHED SHUNT", "GNE DEVICE", "INDUCTION MACHINE"]
end


"""
    get_pti_dtypes(field_name)

Returns `OrderedDict` of data types for PTI file section given by `field_name`,
as enumerated by PSS/E Program Operation Manual
"""
function get_pti_dtypes(field_name::AbstractString)::OrderedDict
    transaction_dtypes = OrderedDict{String,Type}("IC" => Int64, "SBASE" => Float64, "REV" => Int64,
                                                  "XFRRAT" => Float64, "NXFRAT" => Float64, "BASFRQ" => Float64)

    bus_dtypes = OrderedDict{String,Type}("I" => Int64, "NAME" => String, "BASKV" => Float64,
                                    "IDE" => Int64, "AREA" => Int64, "ZONE" => Int64, "OWNER" => Int64,
                                    "VM" => Float64, "VA" => Float64,
                                    "NVHI" => Float64, "NVLO" => Float64,
                                    "EVHI" => Float64, "EVLO" => Float64)

    load_dtypes = OrderedDict{String,Type}("I" => Int64, "ID" => String, "STATUS" => Int64, "AREA" => Int64,
                                    "ZONE" => Int64, "PL" => Float64, "QL" => Float64, "IP" => Float64,
                                    "IQ" => Float64, "YP" => Float64, "YQ" => Float64, "OWNER" => Int64,
                                    "SCALE" => Int64, "INTRPT" => Int64)

    fixded_shunt_dtypes = OrderedDict{String,Type}("I" => Int64, "ID" => String, "STATUS" => Int64,
                                            "GL" => Float64, "BL" => Float64)

    generator_dtypes = OrderedDict{String,Type}("I" => Int64, "ID" => String, "PG" => Float64, "QG" => Float64,
                                         "QT" => Float64, "QB" => Float64, "VS" => Float64, "IREG" => Int64,
                                         "MBASE" => Float64, "ZR" => Float64, "ZX" => Float64, "RT" => Float64,
                                         "XT" => Float64, "GTAP" => Float64, "STAT" => Int64, "RMPCT" => Float64,
                                         "PT" => Float64, "PB" => Float64, "O1" => Int64, "F1" => Float64,
                                         "O2" => Int64, "F2" => Float64, "O3" => Int64, "F3" => Float64,
                                         "O4" => Int64, "F4" => Float64, "WMOD" => Int64, "WPF" => Float64)

    branch_dtypes = OrderedDict{String,Type}("I" => Int64, "J" => Int64, "CKT" => String, "R" => Float64, "X" => Float64,
                                      "B" => Float64, "RATEA" => Float64, "RATEB" => Float64, "RATEC" => Float64,
                                      "GI" => Float64, "BI" => Float64, "GJ" => Float64, "BJ" => Float64,
                                      "ST" => Int64, "MET" => Int64, "LEN" => Float64, "O1" => Int64, "F1" => Float64,
                                      "O2" => Int64, "F2" => Float64, "O3" => Int64, "F3" => Float64,
                                      "O4" => Int64, "F4" => Float64)

    transformer_3_dtypes = OrderedDict{String,Type}("I" => Int64, "J" => Int64, "K" => Int64, "CKT" => String,
                                           "CW" => Int64, "CZ" => Int64, "CM" => Int64, "MAG1" => Float64,
                                           "MAG2" => Float64, "NMETR" => Int64, "NAME" => String,
                                           "STAT" => Int64,
                                           "O1" => Int64, "F1" => Float64,
                                           "O2" => Int64, "F2" => Float64,
                                           "O3" => Int64, "F3" => Float64,
                                           "O4" => Int64,  "F4" => Float64,
                                           "VECGRP" => String,

                                           "R1-2" => Float64, "X1-2" => Float64, "SBASE1-2" => Float64,
                                           "R2-3" => Float64, "X2-3" => Float64, "SBASE2-3" => Float64,
                                           "R3-1" => Float64, "X3-1" => Float64, "SBASE3-1" => Float64,
                                           "VMSTAR" => Float64, "ANSTAR" => Float64,

                                           "WINDV1" => Float64, "NOMV1" => Float64, "ANG1" => Float64,
                                           "RATA1" => Float64, "RATB1" => Float64, "RATC1" => Float64,
                                           "COD1" => Int64, "CONT1" => Int64, "RMA1" => Float64, "RMI1" => Float64,
                                           "VMA1" => Float64, "VMI1" => Float64, "NTP1" => Float64, "TAB1" => Int64,
                                           "CR1" => Float64, "CX1" => Float64, "CNXA1" => Float64,

                                           "WINDV2" => Float64, "NOMV2" => Float64, "ANG2" => Float64,
                                           "RATA2" => Float64, "RATB2" => Float64, "RATC2" => Float64,
                                           "COD2" => Int64, "CONT2" => Int64, "RMA2" => Float64, "RMI2" => Float64,
                                           "VMA2" => Float64, "VMI2" => Float64, "NTP2" => Float64, "TAB2" => Int64,
                                           "CR2" => Float64, "CX2" => Float64, "CNXA2" => Float64,

                                           "WINDV3" => Float64, "NOMV3" => Float64, "ANG3" => Float64,
                                           "RATA3" => Float64, "RATB3" => Float64, "RATC3" => Float64,
                                           "COD3" => Int64, "CONT3" => Int64, "RMA3" => Float64, "RMI3" => Float64,
                                           "VMA3" => Float64, "VMI3" => Float64, "NTP3" => Float64, "TAB3" => Int64,
                                           "CR3" => Float64, "CX3" => Float64, "CNXA3" => Float64)

    transformer_2_dtypes = OrderedDict{String,Type}("I" => Int64, "J" => Int64, "K" => Int64, "CKT" => String,
                                           "CW" => Int64, "CZ" => Int64, "CM" => Int64, "MAG1" => Float64,
                                           "MAG2" => Float64, "NMETR" => Int64, "NAME" => String,
                                           "STAT" => Int64,
                                           "O1" => Int64, "F1" => Float64,
                                           "O2" => Int64, "F2" => Float64,
                                           "O3" => Int64, "F3" => Float64,
                                           "O4" => Int64,  "F4" => Float64,
                                           "VECGRP" => String,

                                           "R1-2" => Float64, "X1-2" => Float64, "SBASE1-2" => Float64,

                                           "WINDV1" => Float64, "NOMV1" => Float64, "ANG1" => Float64,
                                           "RATA1" => Float64, "RATB1" => Float64, "RATC1" => Float64,
                                           "COD1" => Int64, "CONT1" => Int64, "RMA1" => Float64, "RMI1" => Float64,
                                           "VMA1" => Float64, "VMI1" => Float64, "NTP1" => Float64, "TAB1" => Int64,
                                           "CR1" => Float64, "CX1" => Float64, "CNXA1" => Float64,

                                           "WINDV2" => Float64, "NOMV2" => Float64)

    area_interchange_dtypes = OrderedDict{String,Type}("I" => Int64, "ISW" => Int64,
                                                       "PDES" => Float64, "PTOL" => Float64,
                                                       "ARNAME" => String)

    two_terminal_line_dtypes = OrderedDict{String,Type}("NAME" => String, "MDC" => Int64, "RDC" => Float64,
                                                 "SETVL" => Float64, "VSCHD" => Float64, "VCMOD" => Float64,
                                                 "RCOMP" => Float64, "DELTI" => Float64, "METER" => String,
                                                 "DCVMIN" => Float64, "CCCITMX" => Int64, "CCCACC" => Float64,
                                                 "IPR" => Int64, "NBR" => Int64, "ANMXR" => Float64,
                                                 "ANMNR" => Float64, "RCR" => Float64, "XCR" => Float64,
                                                 "EBASR" => Float64, "TRR" => Float64, "TAPR" => Float64,
                                                 "TMXR" => Float64, "TMNR" => Float64, "STPR" => Float64,
                                                 "ICR" => Int64, "IFR" => Int64, "ITR" => Int64, "IDR" => String,
                                                 "XCAPR" => Float64, "IPI" => Int64, "NBI" => Int64,
                                                 "ANMXI" => Float64, "ANMNI" => Float64, "RCI" => Float64,
                                                 "XCI" => Float64, "EBASI" => Float64, "TRI" => Float64,
                                                 "TAPI" => Float64, "TMXI" => Float64, "TMNI" => Float64,
                                                 "STPI" => Float64, "ICI" => Int64, "IFI" => Int64,
                                                 "ITI" => Int64, "IDI" => String, "XCAPI" => Float64)

    vsc_line_dtypes = OrderedDict{String,Type}("NAME" => String, "MDC" => Int64, "RDC" => Float64,
                                               "O1" => Int64, "F1" => Float64,
                                               "O2" => Int64, "F2" => Float64,
                                               "O3" => Int64, "F3" => Float64,
                                               "O4" => Int64, "F4" => Float64)

    vsc_subline_dtypes = OrderedDict{String,Type}("IBUS" => Int64, "TYPE" => Int64, "MODE" => Int64,
                                                  "DCSET" => Float64, "ACSET" => Float64,
                                                  "ALOSS" => Float64, "BLOSS" => Float64, "MINLOSS" => Float64,
                                                  "SMAX" => Float64, "IMAX" => Float64, "PWF" => Float64,
                                                  "MAXQ" => Float64, "MINQ" => Float64,
                                                  "REMOT" => Int64, "RMPCT" => Float64)

    impedance_correction_dtypes = OrderedDict{String,Type}("I" => Int64, "T1" => Float64, "F1" => Float64,
                                                    "T2" => Float64, "F2" => Float64, "T3" => Float64, "F3" => Float64,
                                                    "T4" => Float64, "F4" => Float64, "T5" => Float64, "F5" => Float64,
                                                    "T6" => Float64, "F6" => Float64, "T7" => Float64, "F7" => Float64,
                                                    "T8" => Float64, "F8" => Float64, "T9" => Float64, "F9" => Float64,
                                                    "T10" => Float64, "F10" => Float64, "T11" => Float64, "F11" => Float64)

    multi_term_main_dtypes = OrderedDict{String,Type}("NAME" => String, "NCONV" => Int64, "NDCBS" => Int64, "NDCLN" => Int64,
                                              "MDC" => Int64, "VCONV" => Int64, "VCMOD" => Float64, "VCONVN" => Float64)

    multi_term_nconv_dtypes = OrderedDict{String,Type}("IB" => Int64, "N" => Int64, "ANGMX" => Float64, "ANGMN" => Float64,
                                              "RC" => Float64, "XC" => Float64, "EBAS" => Float64, "TR" => Float64,
                                              "TAP" => Float64, "TPMX" => Float64, "TPMN" => Float64, "TSTP" => Float64,
                                              "SETVL" => Float64, "DCPF" => Float64, "MARG" => Float64, "CNVCOD" => Int64)

    multi_term_ndcbs_dtypes = OrderedDict{String,Type}("IDC" => Int64, "IB" => Int64, "AREA" => Int64, "ZONE" => Int64,
                                              "DCNAME" => String, "IDC2" => Int64, "RGRND" => Float64, "OWNER" => Int64)

    multi_term_ndcln_dtypes = OrderedDict{String,Type}("IDC" => Int64, "JDC" => Int64, "DCCKT" => String, "MET" => Int64,
                                              "RDC" => Float64, "LDC" => Float64)

    multi_section_dtypes = OrderedDict{String,Type}("I" => Int64, "J" => Int64, "ID" => String, "MET" => Int64, "DUM1" => Int64,
                                             "DUM2" => Int64, "DUM3" => Int64, "DUM4" => Int64, "DUM5" => Int64,
                                             "DUM6" => Int64, "DUM7" => Int64, "DUM8" => Int64, "DUM9" => Int64)

    zone_dtypes = OrderedDict{String,Type}("I" => Int64, "ZONAME" => String)

    interarea_dtypes = OrderedDict{String,Type}("ARFROM" => Int64, "ARTO" => Int64, "TRID" => String, "PTRAN" => Float64)

    owner_dtypes = OrderedDict{String,Type}("I" => Int64, "OWNAME" => String)

    FACTS_dtypes = OrderedDict{String,Type}("NAME" => String, "I" => Int64, "J" => Int64, "MODE" => Int64, "PDES" => Float64,
                                     "QDES" => Float64, "VSET" => Float64, "SHMX" => Float64, "TRMX" => Float64,
                                     "VTMN" => Float64, "VTMX" => Float64, "VSMX" => Float64, "IMX" => Float64,
                                     "LINX" => Float64, "RMPCT" => Float64, "OWNER" => Int64, "SET1" => Float64,
                                     "SET2" => Float64, "VSREF" => Int64, "REMOT" => Int64, "MNAME" => String)

    switched_shunt_dtypes = OrderedDict{String,Type}("I" => Int64, "MODSW" => Int64, "ADJM" => Int64, "STAT" => Int64,
                                                     "VSWHI" => Float64, "VSWLO" => Float64, "SWREM" => Int64,
                                                     "RMPCT" => Float64, "RMIDNT" => String, "BINIT" => Float64,
                                                     "N1" => Int64, "B1" => Float64, "N2" => Int64, "B2" => Float64,
                                                     "N3" => Int64, "B3" => Float64, "N4" => Int64, "B4" => Float64,
                                                     "N5" => Int64, "B5" => Float64, "N6" => Int64, "B6" => Float64,
                                                     "N7" => Int64, "B7" => Float64, "N8" => Int64, "B8" => Float64)

    # TODO: Account for multiple lines in GNE Device entries
    gne_device_dtypes = OrderedDict{String,Type}("NAME" => String, "MODEL" => String, "NTERM" => Int64, "BUSi" => Int64,
                                                 "NREAL" => Int64, "NINTG" => Int64, "NCHAR" => Int64,

                                                 "STATUS" => Int64, "OWNER" => Int64, "NMETR" => Int64,

                                                 "REALi" => Float64,
                                                 "INTGi" => Int64,
                                                 "CHARi" => String)

    induction_machine_dtypes = OrderedDict{String,Type}("I" => Int64, "ID" => String, "STAT" => Int64, "SCODE" => Int64,
                                                        "DCODE" => Int64, "AREA" => Int64, "ZONE" => Int64, "OWNER" => Int64,
                                                        "TCODE" => Int64, "BCODE" => Int64, "MBASE" => Float64,
                                                        "RATEKV" => Float64, "PCODE" => Int64, "PSET" => Float64,
                                                        "H" => Float64, "A" => Float64, "B" => Float64, "D" => Float64,
                                                        "E" => Float64, "RA" => Float64, "XA" => Float64, "XM" => Float64,
                                                        "R1" => Float64, "X1" => Float64, "R2" => Float64, "X2" => Float64,
                                                        "X3" => Float64, "E1" => Float64, "SE1" => Float64, "E2" => Float64,
                                                        "SE2" => Float64, "IA1" => Float64, "IA2" => Float64, "XAMULT" => Float64)

    dtypes = Dict{String,OrderedDict}("BUS" => bus_dtypes,
                                      "LOAD" => load_dtypes,
                                      "FIXED SHUNT" => fixded_shunt_dtypes,
                                      "GENERATOR" => generator_dtypes,
                                      "BRANCH" => branch_dtypes,
                                      "TRANSFORMER TWO WINDING" => transformer_2_dtypes,
                                      "TRANSFORMER THREE WINDING" => transformer_3_dtypes,
                                      "AREA INTERCHANGE" => area_interchange_dtypes,
                                      "TWO-TERMINAL DC" => two_terminal_line_dtypes,
                                      "VOLTAGE SOURCE CONVERTER" => vsc_line_dtypes,
                                      "VOLTAGE SOURCE CONVERTER SUBLINES" => vsc_subline_dtypes,
                                      "IMPEDANCE CORRECTION" => impedance_correction_dtypes,
                                      "MULTI-TERMINAL DC" => multi_term_main_dtypes,
                                      "MULTI-TERMINAL DC NCONV" => multi_term_nconv_dtypes,
                                      "MULTI-TERMINAL DC NDCBS" => multi_term_ndcbs_dtypes,
                                      "MULTI-TERMINAL DC NDCLN" => multi_term_ndcln_dtypes,
                                      "MULTI-SECTION LINE" => multi_section_dtypes,
                                      "ZONE" => zone_dtypes,
                                      "INTER-AREA TRANSFER" => interarea_dtypes,
                                      "OWNER" => owner_dtypes,
                                      "FACTS CONTROL DEVICE" => FACTS_dtypes,
                                      "SWITCHED SHUNT" => switched_shunt_dtypes,
                                      "CASE IDENTIFICATION" => transaction_dtypes,
                                      "GNE DEVICE" => gne_device_dtypes,
                                      "INDUCTION MACHINE" => induction_machine_dtypes)

    return dtypes[field_name]
end


"""
    parse_line_element!(data, elements, section)

Parses a single "line" of data elements from a PTI file, as given by `elements`
which is an array of the line, typically split at `,`. Elements are parsed into
data types given by `section` and saved into `data::Dict`

"""
function parse_line_element!(data::Dict, elements::Array, section::AbstractString)
    for (field, dtype) in get_pti_dtypes(section)
        try
            element = shift!(elements)
        catch message
            if isa(message, ArgumentError)
                debug(LOGGER, "Have run out of elements in $section at $field")
                break
            end
        end

        if endswith(element, '\r')
            element = element[1:end-1]
        end

        if startswith(element, "'") && endswith(element, "'")
            dtype = String
            element = element[2:end - 1]
        end

        try
            if dtype != String
                data[field] = parse(dtype, element)
            else
                data[field] = element
            end

        catch message
            if isa(message, ParseError)
                data[field] = element
            else
                debug(LOGGER, "$section $field $dtype $element")
                error(LOGGER, message)
            end
        end
    end
end


"""
    add_section_data!(pti_data, section_data, section)

Adds `section_data::Dict`, which contains all parsed elements of a PTI file
section given by `section`, into the parent `pti_data::Dict`
"""
function add_section_data!(pti_data::Dict, section_data::Dict, section::AbstractString)
    try
        pti_data[section] = append!(pti_data[section], [deepcopy(section_data)])
    catch message
        if isa(message, KeyError)
            pti_data[section] = [deepcopy(section_data)]
        else
            error(LOGGER, message)
        end
    end
end


"""
    get_line_elements(line)

Uses regular expressions to extract all separate data elements from a line of
a PTI file and populate them into an `Array{String}`. Comments, typically
indicated at the end of a line with a `'/'` character, are also extracted
separately, and `Array{Array{String}, String}` is returned.
"""
function get_line_elements(line::AbstractString)::Array
    match_string = r"(-*\d*\.*\d+[eE]*[+-]*\d*)|(\'[^\']*?\')|(\"[^\"]*?\")|(\w+)|\,(\s+)?\,|(\/.*)"
    matches = matchall(match_string, line)

    debug(LOGGER, "$line")
    debug(LOGGER, "$matches")

    elements = []
    comment = ""
    for item in matches
        if startswith(item, ',') && endswith(item, ',') && length(item) == 2
            elements = append!(elements, [""])
        elseif startswith(item, '/')
            comment = item
        else
            elements = append!(elements, [item])
        end
    end

    return [elements, comment]
end


"""
    parse_pti_data(data_string, sections)

Parse a PTI raw file into a `Dict`, given the `data_string` of the file and a
list of the `sections` in the PTI file (typically given by default by
`get_pti_sections()`.
"""
function parse_pti_data(data_string::String, sections::Array)
    data_lines = split(data_string, '\n')
    skip_lines = 0
    skip_sublines = 0
    subsection = ""

    pti_data = Dict{String,Array{Dict}}()

    section = shift!(sections)
    section_data = Dict{String,Any}()

    for (line_number, line) in enumerate(data_lines)
        debug(LOGGER, "$line_number: $line")

        (elements, comment) = get_line_elements(line)

        if length(elements) != 0 && elements[1] == "Q"
            break

        elseif length(elements) != 0 && elements[1] == "0" && line_number != 1
            if line_number == 4
                section = shift!(sections)
            end

            match_string = r"\s*END OF ([\w\s-]+) DATA(?:, BEGIN ([\w\s-]+) DATA)?"
            debug(LOGGER, "$comment")
            matches = match(match_string, comment)

            if !isa(matches, Void)
                guess_section = matches.captures[1]
            else
                guess_section = ""
            end

            if guess_section == section
                section = shift!(sections)
                continue
            else
                info(LOGGER, "At line $line_number, unexpected section: expected: $section, comment specified: $(guess_section)")
                if !isempty(sections)
                    section = shift!(sections)
                end

                continue
            end
        else
            if line_number == 4
                section = shift!(sections)
                section_data = Dict{String,Any}()
            end

            if skip_lines > 0
                skip_lines -= 1
                continue
            end

            debug(LOGGER, join(["Section:", section], " "))
            if section ∉ ["CASE IDENTIFICATION","TRANSFORMER","VOLTAGE SOURCE CONVERTER","MULTI-TERMINAL DC","TWO-TERMINAL DC","GNE DEVICE"]
                section_data = Dict{String,Any}()
                parse_line_element!(section_data, elements, section)

            elseif section == "CASE IDENTIFICATION"
                if line_number == 1
                    parse_line_element!(section_data, elements, section)
                    try
                        if section_data["REV"] < 33
                            warn(LOGGER, "Version $(section_data["REV"]) of PTI format is unsupported, parser may not function correctly.")
                        end
                    catch message
                        if isa(message, KeyError)
                            error(LOGGER, "This file is unrecognized and cannot be parsed")
                        end
                    end
                else
                    section_data["Comment_Line_$(line_number - 1)"] = line
                end

                if line_number < 3
                    continue
                end

            elseif section == "TRANSFORMER"
                section_data = Dict{String,Any}()
                if length(split(data_lines[line_number + 1], ',')) == 3  && parse(Int64, split(line, ',')[3]) == 0 # two winding transformer
                    temp_section = "TRANSFORMER TWO WINDING"
                    elements = split(join(data_lines[line_number:line_number + 3], ','), ',')
                    skip_lines = 3
                elseif length(split(data_lines[line_number + 1], ',')) == 11 && parse(Int64, split(line, ',')[3]) != 0 # three winding transformer
                    temp_section = "TRANSFORMER THREE WINDING"
                    elements = split(join(data_lines[line_number:line_number + 4], ','), ',')
                    skip_lines = 4
                else
                    error(LOGGER, "Cannot detect type of Transformer")
                end

                parse_line_element!(section_data, elements, temp_section)

            elseif section == "VOLTAGE SOURCE CONVERTER"
                if length(split(line, ',')) == 11
                    section_data = Dict{String,Any}()
                    parse_line_element!(section_data, elements, section)
                    skip_sublines = 2
                    continue

                elseif skip_sublines > 0
                    skip_sublines -= 1

                    (elements, comment) = get_line_elements(line)
                    subsection_data = Dict{String,Any}()

                    for (field, dtype) in get_pti_dtypes("$section SUBLINES")
                        element = shift!(elements)
                        subsection_data[field] = parse(dtype, element)
                    end

                    try
                        section_data["CONVERTER BUSES"] = append!(section_data["CONVERTER BUSES"], [deepcopy(subsection_data)])
                    catch message
                        if isa(message, KeyError)
                            section_data["CONVERTER BUSES"] = [deepcopy(subsection_data)]
                            continue
                        else
                            error(LOGGER, message)
                        end
                    end
                end

            elseif section == "TWO-TERMINAL DC"
                section_data = Dict{String,Any}()
                if length(split(line, ',')) == 12
                    elements = split(join(data_lines[line_number:line_number + 2], ','), ',')
                    skip_lines = 2
                end

                parse_line_element!(section_data, elements, section)

            elseif section == "MULTI-TERMINAL DC"
                if skip_sublines == 0
                    section_data = Dict{String,Any}()
                    parse_line_element!(section_data, elements, section)

                    if section_data["NCONV"] > 0
                        skip_sublines = section_data["NCONV"]
                        subsection = "NCONV"
                        continue
                    elseif section_data["NDCBS"] > 0
                        skip_sublines = section_data["NDCBS"]
                        subsection = "NDCBS"
                        continue
                    elseif section_data["NDCLN"] > 0
                        skip_sublines = section_data["NDCLN"]
                        subsection = "NDCLN"
                        continue
                    end
                end

                if skip_sublines > 0
                    skip_sublines -= 1

                    subsection_data = Dict{String,Any}()

                    for (field, dtype) in get_pti_dtypes("$section $subsection")
                        element = shift!(elements)
                        if startswith(element, "'") && endswith(element, "'")
                            subsection_data[field] = element[2:end-1]
                        else
                            subsection_data[field] = parse(dtype, element)
                        end
                    end

                    try
                        section_data["$(subsection[2:end])"] = append!(section_data["$(subsection[2:end])"], [deepcopy(subsection_data)])
                        if skip_sublines > 0 && subsection != "NDCLN"
                            continue
                        end
                    catch message
                        if isa(message, KeyError)
                            section_data["$(subsection[2:end])"] = [deepcopy(subsection_data)]
                            if skip_sublines > 0 && subsection != "NDCLN"
                                continue
                            end
                        else
                            error(LOGGER, message)
                        end
                    end

                    if skip_sublines == 0 && subsection != "NDCLN"
                        if subsection == "NDCBS"
                            skip_sublines = section_data["NDCLN"]
                            subsection = "NDCLN"
                            continue
                        elseif subsection == "NCONV"
                            skip_sublines = section_data["NDCBS"]
                            subsection = "NDCBS"
                            continue
                        end
                    elseif skip_sublines == 0 && subsection == "NDCLN"
                        subsection = ""
                    else
                        continue
                    end
                end

            elseif section == "GNE DEVICE"
                # TODO: handle multiple lines of GNE Device
                warn(LOGGER, "GNE DEVICE parsing is not supported.")
            end
        end
        if subsection != ""
            debug(LOGGER, "appending data")
        end
        add_section_data!(pti_data, section_data, section)
    end

    return pti_data
end


"""
    parse_pti(filename)

Open PTI raw file given by `filename`, passing the file contents as a string
to the main PTI parser, returning a `Dict` of all the data parsed into the
proper types.
"""
function parse_pti(filename::String)::Dict
    data_string = readstring(open(filename))
    pti_data = parse_pti_data(data_string, get_pti_sections())
    pti_data["CASE IDENTIFICATION"][1]["NAME"] = match(r"[\/\\]*(?:.*[\/\\])*(.*)\.raw", lowercase(filename)).captures[1]

    return pti_data
end
