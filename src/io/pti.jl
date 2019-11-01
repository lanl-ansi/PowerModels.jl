#####################################################################
#                                                                   #
# This file provides functions for interfacing with pti .raw files  #
#                                                                   #
#####################################################################


"""
A list of data file sections in the order that they appear in a PTI v33 file
"""
const _pti_sections = ["CASE IDENTIFICATION", "BUS", "LOAD", "FIXED SHUNT",
    "GENERATOR", "BRANCH", "TRANSFORMER", "AREA INTERCHANGE",
    "TWO-TERMINAL DC", "VOLTAGE SOURCE CONVERTER", "IMPEDANCE CORRECTION",
    "MULTI-TERMINAL DC", "MULTI-SECTION LINE", "ZONE", "INTER-AREA TRANSFER",
    "OWNER", "FACTS CONTROL DEVICE", "SWITCHED SHUNT", "GNE DEVICE",
    "INDUCTION MACHINE"]


const _transaction_dtypes = [("IC", Int64), ("SBASE", Float64), ("REV", Int64),
    ("XFRRAT", Float64), ("NXFRAT", Float64), ("BASFRQ", Float64)]

const _bus_dtypes = [("I", Int64), ("NAME", String), ("BASKV", Float64),
    ("IDE", Int64), ("AREA", Int64), ("ZONE", Int64), ("OWNER", Int64),
    ("VM", Float64), ("VA", Float64), ("NVHI", Float64), ("NVLO", Float64),
    ("EVHI", Float64), ("EVLO", Float64)]

const _load_dtypes = [("I", Int64), ("ID", String), ("STATUS", Int64),
    ("AREA", Int64), ("ZONE", Int64), ("PL", Float64), ("QL", Float64),
    ("IP", Float64), ("IQ", Float64), ("YP", Float64), ("YQ", Float64),
    ("OWNER", Int64), ("SCALE", Int64), ("INTRPT", Int64)]

const _fixed_shunt_dtypes = [("I", Int64), ("ID", String), ("STATUS", Int64),
    ("GL", Float64), ("BL", Float64)]

const _generator_dtypes = [("I", Int64), ("ID", String), ("PG", Float64),
    ("QG", Float64), ("QT", Float64), ("QB", Float64), ("VS", Float64),
    ("IREG", Int64), ("MBASE", Float64), ("ZR", Float64), ("ZX", Float64),
    ("RT", Float64), ("XT", Float64), ("GTAP", Float64), ("STAT", Int64),
    ("RMPCT", Float64), ("PT", Float64), ("PB", Float64), ("O1", Int64),
    ("F1", Float64), ("O2", Int64), ("F2", Float64), ("O3", Int64),
    ("F3", Float64), ("O4", Int64), ("F4", Float64), ("WMOD", Int64),
    ("WPF", Float64)]

const _branch_dtypes = [("I", Int64), ("J", Int64), ("CKT", String),
    ("R", Float64), ("X", Float64), ("B", Float64), ("RATEA", Float64),
    ("RATEB", Float64), ("RATEC", Float64), ("GI", Float64), ("BI", Float64),
    ("GJ", Float64), ("BJ", Float64), ("ST", Int64), ("MET", Int64),
    ("LEN", Float64), ("O1", Int64), ("F1", Float64), ("O2", Int64),
    ("F2", Float64), ("O3", Int64), ("F3", Float64), ("O4", Int64),
    ("F4", Float64)]

const _transformer_dtypes = [("I", Int64), ("J", Int64), ("K", Int64),
    ("CKT", String), ("CW", Int64), ("CZ", Int64), ("CM", Int64),
    ("MAG1", Float64), ("MAG2", Float64), ("NMETR", Int64), ("NAME", String),
    ("STAT", Int64), ("O1", Int64), ("F1", Float64), ("O2", Int64),
    ("F2", Float64), ("O3", Int64), ("F3", Float64), ("O4", Int64),
    ("F4", Float64), ("VECGRP", String)]

const _transformer_3_1_dtypes = [("R1-2", Float64), ("X1-2", Float64),
    ("SBASE1-2", Float64), ("R2-3", Float64), ("X2-3", Float64),
    ("SBASE2-3", Float64), ("R3-1", Float64), ("X3-1", Float64),
    ("SBASE3-1", Float64), ("VMSTAR", Float64), ("ANSTAR", Float64)]

const _transformer_3_2_dtypes = [("WINDV1", Float64), ("NOMV1", Float64),
    ("ANG1", Float64), ("RATA1", Float64), ("RATB1", Float64),
    ("RATC1", Float64), ("COD1", Int64), ("CONT1", Int64), ("RMA1", Float64),
    ("RMI1", Float64), ("VMA1", Float64), ("VMI1", Float64), ("NTP1", Float64),
    ("TAB1", Int64), ("CR1", Float64), ("CX1", Float64), ("CNXA1", Float64)]

const _transformer_3_3_dtypes = [("WINDV2", Float64), ("NOMV2", Float64),
    ("ANG2", Float64), ("RATA2", Float64), ("RATB2", Float64),
    ("RATC2", Float64), ("COD2", Int64), ("CONT2", Int64), ("RMA2", Float64),
    ("RMI2", Float64), ("VMA2", Float64), ("VMI2", Float64), ("NTP2", Float64),
    ("TAB2", Int64), ("CR2", Float64), ("CX2", Float64), ("CNXA2", Float64)]

const _transformer_3_4_dtypes = [("WINDV3", Float64), ("NOMV3", Float64),
    ("ANG3", Float64), ("RATA3", Float64), ("RATB3", Float64),
    ("RATC3", Float64), ("COD3", Int64), ("CONT3", Int64), ("RMA3", Float64),
    ("RMI3", Float64), ("VMA3", Float64), ("VMI3", Float64), ("NTP3", Float64),
    ("TAB3", Int64), ("CR3", Float64), ("CX3", Float64), ("CNXA3", Float64)]

const _transformer_2_1_dtypes = [("R1-2", Float64), ("X1-2", Float64), 
    ("SBASE1-2", Float64)]

const _transformer_2_2_dtypes = [("WINDV1", Float64), ("NOMV1", Float64),
    ("ANG1", Float64), ("RATA1", Float64), ("RATB1", Float64),
    ("RATC1", Float64), ("COD1", Int64), ("CONT1", Int64), ("RMA1", Float64),
    ("RMI1", Float64), ("VMA1", Float64), ("VMI1", Float64), ("NTP1", Float64),
    ("TAB1", Int64), ("CR1", Float64), ("CX1", Float64), ("CNXA1", Float64)]

const _transformer_2_3_dtypes = [("WINDV2", Float64), ("NOMV2", Float64)]

const _area_interchange_dtypes = [("I", Int64), ("ISW", Int64), 
    ("PDES", Float64), ("PTOL", Float64), ("ARNAME", String)]

const _two_terminal_line_dtypes = [("NAME", String), ("MDC", Int64),
    ("RDC", Float64), ("SETVL", Float64), ("VSCHD", Float64),
    ("VCMOD", Float64), ("RCOMP", Float64), ("DELTI", Float64),
    ("METER", String), ("DCVMIN", Float64), ("CCCITMX", Int64),
    ("CCCACC", Float64), ("IPR", Int64), ("NBR", Int64), ("ANMXR", Float64),
    ("ANMNR", Float64), ("RCR", Float64), ("XCR", Float64), ("EBASR", Float64),
    ("TRR", Float64), ("TAPR", Float64), ("TMXR", Float64), ("TMNR", Float64),
    ("STPR", Float64), ("ICR", Int64), ("IFR", Int64), ("ITR", Int64),
    ("IDR", String), ("XCAPR", Float64), ("IPI", Int64), ("NBI", Int64),
    ("ANMXI", Float64), ("ANMNI", Float64), ("RCI", Float64), ("XCI", Float64),
    ("EBASI", Float64), ("TRI", Float64), ("TAPI", Float64), ("TMXI", Float64),
    ("TMNI", Float64), ("STPI", Float64), ("ICI", Int64), ("IFI", Int64),
    ("ITI", Int64), ("IDI", String), ("XCAPI", Float64)]

const _vsc_line_dtypes = [("NAME", String), ("MDC", Int64), ("RDC", Float64),
    ("O1", Int64), ("F1", Float64), ("O2", Int64), ("F2", Float64),
    ("O3", Int64), ("F3", Float64), ("O4", Int64), ("F4", Float64)]

const _vsc_subline_dtypes = [("IBUS", Int64), ("TYPE", Int64), ("MODE", Int64),
    ("DCSET", Float64), ("ACSET", Float64), ("ALOSS", Float64),
    ("BLOSS", Float64), ("MINLOSS", Float64), ("SMAX", Float64),
    ("IMAX", Float64), ("PWF", Float64), ("MAXQ", Float64), ("MINQ", Float64),
    ("REMOT", Int64), ("RMPCT", Float64)]

const _impedance_correction_dtypes = [("I", Int64), ("T1", Float64),
    ("F1", Float64), ("T2", Float64), ("F2", Float64), ("T3", Float64),
    ("F3", Float64), ("T4", Float64), ("F4", Float64), ("T5", Float64),
    ("F5", Float64), ("T6", Float64), ("F6", Float64), ("T7", Float64),
    ("F7", Float64), ("T8", Float64), ("F8", Float64), ("T9", Float64),
    ("F9", Float64), ("T10", Float64), ("F10", Float64), ("T11", Float64),
    ("F11", Float64)]

const _multi_term_main_dtypes = [("NAME", String), ("NCONV", Int64),
    ("NDCBS", Int64), ("NDCLN", Int64), ("MDC", Int64), ("VCONV", Int64),
    ("VCMOD", Float64), ("VCONVN", Float64)]

const _multi_term_nconv_dtypes = [("IB", Int64), ("N", Int64),
    ("ANGMX", Float64), ("ANGMN", Float64), ("RC", Float64), ("XC", Float64),
    ("EBAS", Float64), ("TR", Float64), ("TAP", Float64), ("TPMX", Float64),
    ("TPMN", Float64), ("TSTP", Float64), ("SETVL", Float64),
    ("DCPF", Float64), ("MARG", Float64), ("CNVCOD", Int64)]

const _multi_term_ndcbs_dtypes = [("IDC", Int64), ("IB", Int64),
    ("AREA", Int64), ("ZONE", Int64), ("DCNAME", String), ("IDC2", Int64),
    ("RGRND", Float64), ("OWNER", Int64)]

const _multi_term_ndcln_dtypes = [("IDC", Int64), ("JDC", Int64),
    ("DCCKT", String), ("MET", Int64), ("RDC", Float64), ("LDC", Float64)]

const _multi_section_dtypes = [("I", Int64), ("J", Int64), ("ID", String),
    ("MET", Int64), ("DUM1", Int64), ("DUM2", Int64), ("DUM3", Int64),
    ("DUM4", Int64), ("DUM5", Int64), ("DUM6", Int64), ("DUM7", Int64),
    ("DUM8", Int64), ("DUM9", Int64)]

const _zone_dtypes = [("I", Int64), ("ZONAME", String)]

const _interarea_dtypes = [("ARFROM", Int64), ("ARTO", Int64),
    ("TRID", String), ("PTRAN", Float64)]

const _owner_dtypes = [("I", Int64), ("OWNAME", String)]

const _FACTS_dtypes = [("NAME", String), ("I", Int64), ("J", Int64),
    ("MODE", Int64), ("PDES", Float64), ("QDES", Float64), ("VSET", Float64),
    ("SHMX", Float64), ("TRMX", Float64), ("VTMN", Float64), ("VTMX", Float64),
    ("VSMX", Float64), ("IMX", Float64), ("LINX", Float64), ("RMPCT", Float64),
    ("OWNER", Int64), ("SET1", Float64), ("SET2", Float64), ("VSREF", Int64),
    ("REMOT", Int64), ("MNAME", String)]

const _switched_shunt_dtypes = [("I", Int64), ("MODSW", Int64),
    ("ADJM", Int64), ("STAT", Int64), ("VSWHI", Float64), ("VSWLO", Float64),
    ("SWREM", Int64), ("RMPCT", Float64), ("RMIDNT", String), ("BINIT", Float64),
    ("N1", Int64), ("B1", Float64), ("N2", Int64), ("B2", Float64),
    ("N3", Int64), ("B3", Float64), ("N4", Int64), ("B4", Float64),
    ("N5", Int64), ("B5", Float64), ("N6", Int64), ("B6", Float64),
    ("N7", Int64), ("B7", Float64), ("N8", Int64), ("B8", Float64)]

# TODO: Account for multiple lines in GNE Device entries
const _gne_device_dtypes = [("NAME", String), ("MODEL", String),
    ("NTERM", Int64), ("BUSi", Int64), ("NREAL", Int64), ("NINTG", Int64),
    ("NCHAR", Int64), ("STATUS", Int64), ("OWNER", Int64), ("NMETR", Int64),
    ("REALi", Float64), ("INTGi", Int64), ("CHARi", String)]

const _induction_machine_dtypes = [("I", Int64), ("ID", String),
    ("STAT", Int64), ("SCODE", Int64), ("DCODE", Int64), ("AREA", Int64),
    ("ZONE", Int64), ("OWNER", Int64), ("TCODE", Int64), ("BCODE", Int64),
    ("MBASE", Float64), ("RATEKV", Float64), ("PCODE", Int64),
    ("PSET", Float64), ("H", Float64), ("A", Float64), ("B", Float64),
    ("D", Float64), ("E", Float64), ("RA", Float64), ("XA", Float64),
    ("XM", Float64), ("R1", Float64), ("X1", Float64), ("R2", Float64),
    ("X2", Float64), ("X3", Float64), ("E1", Float64), ("SE1", Float64),
    ("E2", Float64), ("SE2", Float64), ("IA1", Float64), ("IA2", Float64),
    ("XAMULT", Float64)]


"""
lookup array of data types for PTI file sections given by
`field_name`, as enumerated by PSS/E Program Operation Manual.
"""
const _pti_dtypes = Dict{String,Array}(
    "BUS" => _bus_dtypes,
    "LOAD" => _load_dtypes,
    "FIXED SHUNT" => _fixed_shunt_dtypes,
    "GENERATOR" => _generator_dtypes,
    "BRANCH" => _branch_dtypes,
    "TRANSFORMER" => _transformer_dtypes,
    "TRANSFORMER TWO-WINDING LINE 1" => _transformer_2_1_dtypes,
    "TRANSFORMER TWO-WINDING LINE 2" => _transformer_2_2_dtypes,
    "TRANSFORMER TWO-WINDING LINE 3" => _transformer_2_3_dtypes,
    "TRANSFORMER THREE-WINDING LINE 1" => _transformer_3_1_dtypes,
    "TRANSFORMER THREE-WINDING LINE 2" => _transformer_3_2_dtypes,
    "TRANSFORMER THREE-WINDING LINE 3" => _transformer_3_3_dtypes,
    "TRANSFORMER THREE-WINDING LINE 4" => _transformer_3_4_dtypes,
    "AREA INTERCHANGE" => _area_interchange_dtypes,
    "TWO-TERMINAL DC" => _two_terminal_line_dtypes,
    "VOLTAGE SOURCE CONVERTER" => _vsc_line_dtypes,
    "VOLTAGE SOURCE CONVERTER SUBLINES" => _vsc_subline_dtypes,
    "IMPEDANCE CORRECTION" => _impedance_correction_dtypes,
    "MULTI-TERMINAL DC" => _multi_term_main_dtypes,
    "MULTI-TERMINAL DC NCONV" => _multi_term_nconv_dtypes,
    "MULTI-TERMINAL DC NDCBS" => _multi_term_ndcbs_dtypes,
    "MULTI-TERMINAL DC NDCLN" => _multi_term_ndcln_dtypes,
    "MULTI-SECTION LINE" => _multi_section_dtypes,
    "ZONE" => _zone_dtypes,
    "INTER-AREA TRANSFER" => _interarea_dtypes,
    "OWNER" => _owner_dtypes,
    "FACTS CONTROL DEVICE" => _FACTS_dtypes,
    "SWITCHED SHUNT" => _switched_shunt_dtypes,
    "CASE IDENTIFICATION" => _transaction_dtypes,
    "GNE DEVICE" => _gne_device_dtypes,
    "INDUCTION MACHINE" => _induction_machine_dtypes
)



const _default_case_identification = Dict("IC" => 0, "SBASE" => 100.0,
    "REV" => 33, "XFRRAT" => 0, "NXFRAT" => 0, "BASFRQ" => 60)

const _default_bus = Dict("BASKV" => 0.0, "IDE" => 1, "AREA" => 1, "ZONE" => 1,
    "OWNER" => 1, "VM" => 1.0, "VA" => 0.0, "NVHI" => 1.1, "NVLO" => 0.9,
    "EVHI" => 1.1, "EVLO" => 0.9, "NAME" => "            ")

const _default_load = Dict("ID" => 1, "STATUS" => 1, "PL" => 0.0, "QL" => 0.0,
    "IP" => 0.0, "IQ" => 0.0, "YP" => 0.0, "YQ" => 0.0, "SCALE" => 1,
    "INTRPT" => 0, "AREA" => nothing, "ZONE" => nothing, "OWNER" => nothing)

const _default_fixed_shunt = Dict("ID" => 1, "STATUS" => 1, "GL" => 0.0, "BL" => 0.0)

const _default_generator = Dict("ID" => 1, "PG" => 0.0, "QG" => 0.0, "QT" => 9999.0,
    "QB" => -9999.0, "VS" => 1.0, "IREG" => 0, "MBASE" => nothing, "ZR" => 0.0,
    "ZX" => 1.0, "RT" => 0.0, "XT" => 0.0, "GTAP" => 1.0, "STAT" => 1,
    "RMPCT" => 100.0, "PT" => 9999.0, "PB" => -9999.0, "O1" => nothing,
    "O2" => 0, "O3" => 0, "O4" => 0, "F1" => 1.0,"F2" => 1.0, "F3" => 1.0,
    "F4" => 1.0, "WMOD" => 0, "WPF" => 1.0)

const _default_branch = Dict("CKT" => 1, "B" => 0.0, "RATEA" => 0.0,
    "RATEB" => 0.0, "RATEC" => 0.0, "GI" => 0.0, "BI" => 0.0, "GJ" => 0.0,
    "BJ" => 0.0, "ST" => 1, "MET" => 1, "LEN" => 0.0, "O1" => nothing,
    "O2" => 0, "O3" => 0, "O4" => 0, "F1" => 1.0, "F2" => 1.0, "F3" => 1.0,
    "F4" => 1.0)

const _default_transformer = Dict("K" => 0, "CKT" => 1, "CW" => 1, "CZ" => 1,
    "CM" => 1, "MAG1" => 0.0, "MAG2" => 0.0, "NMETR" => 2,
    "NAME" => "            ", "STAT" => 1, "O1" => nothing, "O2" => 0,
    "O3" => 0, "O4" => 0, "F1" => 1.0, "F2" => 1.0, "F3" => 1.0, "F4" => 1.0,
    "VECGRP" => "            ", "R1-2" => 0.0, "SBASE1-2" => nothing,
    "R2-3" => 0.0, "SBASE2-3" => nothing, "R3-1" => 0.0, "SBASE3-1" => nothing,
    "VMSTAR" => 1.0, "ANSTAR" => 0.0,
    "WINDV1" => nothing,
    "NOMV1" => 0.0, "ANG1" => 0.0, "RATA1" => 0.0,
    "RATB1" => 0.0, "RATC1" => 0.0, "COD1" => 0,
    "CONT1" => 0, "RMA1" => 1.1, "RMI1" => 0.9,
    "VMA1" => 1.1, "VMI1" => 0.9, "NTP1" => 33,
    "TAB1" => 0, "CR1" => 0.0, "CX1" => 0.0, "CNXA1" => 0.0,
    "WINDV2" => nothing,
    "NOMV2" => 0.0, "ANG2" => 0.0, "RATA2" => 0.0,
    "RATB2" => 0.0, "RATC2" => 0.0, "COD2" => 0,
    "CONT2" => 0, "RMA2" => 1.1, "RMI2" => 0.9,
    "VMA2" => 1.1, "VMI2" => 0.9, "NTP2" => 33,
    "TAB2" => 0, "CR2" => 0.0, "CX2" => 0.0,
    "CNXA2" => 0.0,
    "WINDV3" => nothing,
    "NOMV3" => 0.0, "ANG3" => 0.0, "RATA3" => 0.0,
    "RATB3" => 0.0, "RATC3" => 0.0, "COD3" => 0,
    "CONT3" => 0, "RMA3" => 1.1, "RMI3" => 0.9,
    "VMA3" => 1.1, "VMI3" => 0.9, "NTP3" => 33,
    "TAB3" => 0, "CR3" => 0.0, "CX3" => 0.0,
    "CNXA3" => 0.0)

const _default_area_interchange = Dict("ISW" => 0, "PDES" => 0.0,
    "PTOL" => 10.0, "ARNAME" => "            ")

const _default_two_terminal_dc = Dict("MDC" => 0, "VCMOD" => 0.0,
    "RCOMP" => 0.0, "DELTI" => 0.0, "METER" => "I", "DCVMIN" => 0.0,
    "CCCITMX" => 20, "CCCACC" => 1.0, "TRR" => 1.0, "TAPR" => 1.0,
    "TMXR" => 1.5, "TMNR" => 0.51, "STPR" => 0.00625, "ICR" => 0, "IFR" => 0,
    "ITR" => 0, "IDR" => "1", "XCAPR" => 0.0, "TRI" => 1.0, "TAPI" => 1.0,
    "TMXI" => 1.5, "TMNI" => 0.51, "STPI" => 0.00625, "ICI" => 0, "IFI" => 0,
    "ITI" => 0, "IDI" => "1", "XCAPI" => 0.0)

const _default_vsc_dc = Dict("MDC" => 1, "O1" => nothing, "O2" => 0, "O3" => 0,
    "O4" => 0, "F1" => 1.0, "F2" => 1.0, "F3" => 1.0, "F4" => 1.0,
    "CONVERTER BUSES" => Dict("MODE" => 1, "ACSET" => 1.0, "ALOSS" => 1.0,
        "BLOSS" => 0.0, "MINLOSS" => 0.0, "SMAX" => 0.0, "IMAX" => 0.0,
        "PWF" => 1.0, "MAXQ" => 9999.0, "MINQ" => -9999.0, "REMOT" => 0,
        "RMPCT" => 100.0)
    )

const _default_impedance_correction = Dict("T1" => 0.0, "T2" => 0.0, "T3" => 0.0,
    "T4" => 0.0, "T5" => 0.0, "T6" => 0.0, "T7" => 0.0, "T8" => 0.0, "T9" => 0.0,
    "T10" => 0.0, "T11" => 0.0, "F1" => 0.0, "F2" => 0.0, "F3" => 0.0,
    "F4" => 0.0, "F5" => 0.0, "F6" => 0.0, "F7" => 0.0, "F8" => 0.0,
    "F9" => 0.0, "F10" => 0.0, "F11" => 0.0)

const _default_multi_term_dc = Dict("MDC" => 0, "VCMOD" => 0.0, "VCONVN" => 0,
    "CONV" => Dict("TR" => 1.0, "TAP" => 1.0, "TPMX" => 1.5, "TPMN" => 0.51,
        "TSTP" => 0.00625,"DCPF" => 1, "MARG" => 0.0, "CNVCOD" => 1),
    "DCBS" => Dict("IB" => 0.0, "AREA" => 1, "ZONE" => 1,
        "DCNAME" => "            ", "IDC2" => 0, "RGRND" => 0.0, "OWNER" => 1),
    "DCLN" => Dict("DCCKT" => 1, "MET" => 1, "LDC" => 0.0)
    )

const _default_multi_section = Dict("ID" => "&1", "MET" => 1)

const _default_zone = Dict("ZONAME" => "            ")

const _default_interarea = Dict("TRID" => 1, "PTRAN" => 0.0)

const _default_owner = Dict("OWNAME" => "            ")

const _default_facts = Dict("J" => 0, "MODE" => 1, "PDES" => 0.0, "QDES" => 0.0,
    "VSET" => 1.0, "SHMX" => 9999.0, "TRMX" => 9999.0, "VTMN" => 0.9,
    "VTMX" => 1.1, "VSMX" => 1.0, "IMX" => 0.0, "LINX" => 0.05,
    "RMPCT" => 100.0, "OWNER" => 1, "SET1" => 0.0, "SET2" => 0.0, "VSREF" => 0,
    "REMOT" => 0, "MNAME" => "")

const _default_switched_shunt = Dict("MODSW" => 1, "ADJM" => 0, "STAT" => 1,
    "VSWHI" => 1.0, "VSWLO" => 1.0, "SWREM" => 0, "RMPCT" => 100.0,
    "RMIDNT" => "", "BINIT" => 0.0,
    "N1" => 0.0, "N2" => 0.0, "N3" => 0.0, "N4" => 0.0, "N5" => 0.0,
    "N6" => 0.0, "N7" => 0.0, "N8" => 0.0,
    "B1" => 0.0, "B2" => 0.0, "B3" => 0.0, "B4" => 0.0, "B5" => 0.0,
    "B6" => 0.0, "B7" => 0.0, "B8" => 0.0)

const _default_gne_device = Dict("NTERM" => 1, "NREAL" => 0, "NINTG" => 0,
    "NCHAR" => 0, "STATUS" => 1, "OWNER" => nothing, "NMETR" => nothing,
    "REAL" => 0, "INTG" => nothing,
    "CHAR" => "1")

const _default_induction_machine = Dict("ID" => 1, "STAT" => 1, "SCODE" => 1,
    "DCODE" => 2, "AREA" => nothing, "ZONE" => nothing, "OWNER" => nothing,
    "TCODE" => 1, "BCODE" => 1, "MBASE" => nothing, "RATEKV" => 0.0,
    "PCODE" => 1, "H" => 1.0, "A" => 1.0, "B" => 1.0, "D" => 1.0, "E" => 1.0,
    "RA" => 0.0, "XA" => 0.0, "XM" => 2.5, "R1" => 999.0, "X1" => 999.0,
    "R2" => 999.0, "X2" => 999.0, "X3" => 0.0, "E1" => 1.0, "SE1" => 0.0,
    "E2" => 1.2, "SE2" => 0.0, "IA1" => 0.0, "IA2" => 0.0, "XAMULT" => 1)

const _pti_defaults = Dict("BUS" => _default_bus,
    "LOAD" => _default_load,
    "FIXED SHUNT" => _default_fixed_shunt,
    "GENERATOR" => _default_generator,
    "BRANCH" => _default_branch,
    "TRANSFORMER" => _default_transformer,
    "AREA INTERCHANGE" => _default_area_interchange,
    "TWO-TERMINAL DC" => _default_two_terminal_dc,
    "VOLTAGE SOURCE CONVERTER" => _default_vsc_dc,
    "IMPEDANCE CORRECTION" => _default_impedance_correction,
    "MULTI-TERMINAL DC" => _default_multi_term_dc,
    "MULTI-SECTION LINE" => _default_multi_section,
    "ZONE" => _default_zone,
    "INTER-AREA TRANSFER" => _default_interarea,
    "OWNER" => _default_owner,
    "FACTS CONTROL DEVICE" => _default_facts,
    "SWITCHED SHUNT" => _default_switched_shunt,
    "CASE IDENTIFICATION" => _default_case_identification,
    "GNE DEVICE" => _default_gne_device,
    "INDUCTION MACHINE" => _default_induction_machine
    )



function _correct_nothing_values!(data::Dict)
    if !haskey(data, "BUS")
        return
    end

    sbase = data["CASE IDENTIFICATION"][1]["SBASE"]
    bus_lookup = Dict(bus["I"] => bus for bus in data["BUS"])

    if haskey(data, "LOAD")
        for load in data["LOAD"]
            load_bus = bus_lookup[load["I"]]
            if load["AREA"] == nothing
                load["AREA"] = load_bus["AREA"]
            end
            if load["ZONE"] == nothing
                load["ZONE"] = load_bus["ZONE"]
            end
            if load["OWNER"] == nothing
                load["OWNER"] = load_bus["OWNER"]
            end
        end
    end

    if haskey(data, "GENERATOR")
        for gen in data["GENERATOR"]
            gen_bus = bus_lookup[gen["I"]]
            if haskey(gen, "OWNER") && gen["OWNER"] == nothing
                gen["OWNER"] = gen_bus["OWNER"]
            end
            if gen["MBASE"] == nothing
                gen["MBASE"] = sbase
            end
        end
    end

    if haskey(data, "BRANCH")
        for branch in data["BRANCH"]
            branch_bus = bus_lookup[branch["I"]]
            if haskey(branch, "OWNER") && branch["OWNER"] == nothing
                branch["OWNER"] = branch_bus["OWNER"]
            end
        end
    end

    if haskey(data, "TRANSFORMER")
        for transformer in data["TRANSFORMER"]
            transformer_bus = bus_lookup[transformer["I"]]
            for base_id in ["SBASE1-2", "SBASE2-3", "SBASE3-1"]
                if haskey(transformer, base_id) && transformer[base_id] == nothing
                    transformer[base_id] = sbase
                end
            end
            for winding_id in ["WINDV1", "WINDV2", "WINDV3"]
                if haskey(transformer, winding_id) &&  transformer[winding_id] == nothing
                    if transformer["CW"] == 2
                        transformer[winding_id] = transformer_bus["BASKV"]
                    else
                        transformer[winding_id] = 1.0
                    end
                end
            end
        end
    end

    #=
    # TODO update this default value
    if haskey(data, "VOLTAGE SOURCE CONVERTER")
        for mdc in data["VOLTAGE SOURCE CONVERTER"]
            mdc["O1"] = Expr(:call, :_get_component_property, data["BUS"], "OWNER", "I", get(get(component, "CONVERTER BUSES", [Dict()])[1], "IBUS", 0))
        end
    end
    =#

    if haskey(data, "GNE DEVICE")
        for gne in data["GNE DEVICE"]
            gne_bus = bus_lookup[gne["I"]]
            if haskey(gne, "OWNER") && gne["OWNER"] == nothing
                gne["OWNER"] = gne_bus["OWNER"]
            end
            if haskey(gne, "NMETR") && gne["NMETR"] == nothing
                gne["NMETR"] = gne_bus["NTERM"]
            end
        end
    end

    if haskey(data, "INDUCTION MACHINE")
        for indm in data["INDUCTION MACHINE"]
            indm_bus = bus_lookup[indm["I"]]
            if indm["AREA"] == nothing
                indm["AREA"] = indm_bus["AREA"]
            end
            if indm["ZONE"] == nothing
                indm["ZONE"] = indm_bus["ZONE"]
            end
            if indm["OWNER"] == nothing
                indm["OWNER"] = indm_bus["OWNER"]
            end
            if indm["MBASE"] == nothing
                indm["MBASE"] = sbase
            end
        end
    end
end



"""
This is an experimental method for parsing elements and setting defaults at the same time.
It is not currently working but would reduce memory allocations if implemented correctly.
"""
function _parse_elements(elements::Array, dtypes::Array, defaults::Dict, section::AbstractString)
    data = Dict{String,Any}()

    if length(elements) > length(dtypes)
        Memento.warn(_LOGGER, "ignoring $(length(elements) - length(dtypes)) extra values in section $section, only $(length(dtypes)) items are defined")
        elements = elements[1:length(dtypes)]
    end

    for (i,element) in enumerate(elements)
        field, dtype = dtypes[i]

        element = strip(element)

        if dtype == String
            if startswith(element, "'") && endswith(element, "'")
                data[field] = element[2:end-1]
            else
                data[field] = element
            end
        else
            if length(element) <= 0
                # this will be set to a default in the cleanup phase
                data[field] = nothing
            else
                try
                    data[field] = parse(dtype, element)
                catch message
                    if isa(message, Meta.ParseError)
                        data[field] = element
                    else
                        Memento.error(_LOGGER, "value '$element' for $field in section $section is not of type $dtype.")
                    end
                end
            end
        end
    end

    if length(elements) < length(dtypes)
        for (field, dtype) in dtypes[length(elements):end]
            data[field] = defaults[field]
            #=
            if length(missing_fields) > 0
                for field in missing_fields
                    data[field] = ""
                end
                missing_str = join(missing_fields, ", ")
                if !(section == "SWITCHED SHUNT" && startswith(missing_str, "N")) &&
                    !(section == "MULTI-SECTION LINE" && startswith(missing_str, "DUM")) &&
                    !(section == "IMPEDANCE CORRECTION" && startswith(missing_str, "T"))
                    Memento.warn(_LOGGER, "The following fields in $section are missing: $missing_str")
                end
            end
            =#
        end
    end

    return data
end


"""
    _parse_line_element!(data, elements, section)

Internal function. Parses a single "line" of data elements from a PTI file, as
given by `elements` which is an array of the line, typically split at `,`.
Elements are parsed into data types given by `section` and saved into `data::Dict`.
"""
function _parse_line_element!(data::Dict, elements::Array, section::AbstractString)
    missing_fields = []
    for (i, (field, dtype)) in enumerate(_pti_dtypes[section])
        if i > length(elements)
            Memento.debug(_LOGGER, "Have run out of elements in $section at $field")
            push!(missing_fields, field)
            continue
        else
            element = strip(elements[i])
        end

        try
            if dtype != String && element != ""
                data[field] = parse(dtype, element)
            else
                if dtype == String && startswith(element, "'") && endswith(element, "'")
                    data[field] = chop(element[nextind(element,1):end])
                else
                    data[field] = element
                end
            end
        catch message
            if isa(message, Meta.ParseError)
                data[field] = element
            else
                Memento.error(_LOGGER, "value '$element' for $field in section $section is not of type $dtype.")
            end
        end
    end

    if length(missing_fields) > 0
        for field in missing_fields
            data[field] = ""
        end
        missing_str = join(missing_fields, ", ")
        if !(section == "SWITCHED SHUNT" && startswith(missing_str, "N")) &&
            !(section == "MULTI-SECTION LINE" && startswith(missing_str, "DUM")) &&
            !(section == "IMPEDANCE CORRECTION" && startswith(missing_str, "T"))
            Memento.warn(_LOGGER, "The following fields in $section are missing: $missing_str")
        end
    end
end



const _comment_split = r"(?!\B[\'][^\']*)[\/](?![^\']*[\']\B)"
const _split_string = r",(?=(?:[^']*'[^']*')*[^']*$)"

"""
    _get_line_elements(line)

Internal function. Uses regular expressions to extract all separate data
elements from a line of a PTI file and populate them into an `Array{String}`.
Comments, typically indicated at the end of a line with a `'/'` character,
are also extracted separately, and `Array{Array{String}, String}` is returned.
"""
function _get_line_elements(line::AbstractString)
    if count(i->(i=="'"), line) % 2 == 1
        throw(Memento.error(_LOGGER, "There are an uneven number of single-quotes in \"{line}\", the line cannot be parsed."))
    end

    line_comment = split(line, _comment_split, limit=2)
    line = strip(line_comment[1])
    comment = length(line_comment) > 1 ? strip(line_comment[2]) : ""

    elements = split(line, _split_string)

    return (elements, comment)
end


"""
    _parse_pti_data(data_string, sections)

Internal function. Parse a PTI raw file into a `Dict`, given the
`data_string` of the file and a list of the `sections` in the PTI
file (typically given by default by `get_pti_sections()`.
"""
function _parse_pti_data(data_io::IO)
    sections = deepcopy(_pti_sections)
    data_lines = readlines(data_io)
    skip_lines = 0
    skip_sublines = 0
    subsection = ""

    pti_data = Dict{String,Array{Dict}}()

    section = popfirst!(sections)
    section_data = Dict{String,Any}()

    for (line_number, line) in enumerate(data_lines)
        (elements, comment) = _get_line_elements(line)

        first_element = strip(elements[1])
        if line_number > 3 && length(elements) != 0 && first_element == "Q"
            break
        elseif line_number > 3 && length(elements) != 0 && first_element == "0"
            if line_number == 4
                section = popfirst!(sections)
            end

            if length(elements) > 1
                Memento.warn(_LOGGER, "At line $line_number, new section started with '0', but additional non-comment data is present. Pattern '^\\s*0\\s*[/]*.*' is reserved for section start/end.")
            elseif length(comment) > 0
                Memento.debug(_LOGGER, "At line $line_number, switched to $section")
            end

            if !isempty(sections)
                section = popfirst!(sections)
            end

            continue
        else
            if line_number == 4
                section = popfirst!(sections)
                section_data = Dict{String,Any}()
            end

            if skip_lines > 0
                skip_lines -= 1
                continue
            end

            Memento.debug(_LOGGER, join(["Section:", section], " "))
            if !(section in ["CASE IDENTIFICATION","TRANSFORMER","VOLTAGE SOURCE CONVERTER","MULTI-TERMINAL DC","TWO-TERMINAL DC","GNE DEVICE"])
                section_data = Dict{String,Any}()

                try
                    _parse_line_element!(section_data, elements, section)
                catch message
                    throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                end

            elseif section == "CASE IDENTIFICATION"
                if line_number == 1
                    try
                        _parse_line_element!(section_data, elements, section)
                    catch message
                        throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                    end

                    if section_data["REV"] != "" && section_data["REV"] < 33
                        Memento.warn(_LOGGER, "Version $(section_data["REV"]) of PTI format is unsupported, parser may not function correctly.")
                    end
                else
                    section_data["Comment_Line_$(line_number - 1)"] = line
                end

                if line_number < 3
                    continue
                end

            elseif section == "TRANSFORMER"
                section_data = Dict{String,Any}()
                if parse(Int64, _get_line_elements(line)[1][3]) == 0 # two winding transformer
                    winding = "TWO-WINDING"
                    skip_lines = 3
                elseif parse(Int64, _get_line_elements(line)[1][3]) != 0 # three winding transformer
                    winding = "THREE-WINDING"
                    skip_lines = 4
                else
                    Memento.error(_LOGGER, "Cannot detect type of Transformer")
                end

                try
                    for transformer_line in 0:4
                        if transformer_line == 0
                            temp_section = section
                        else
                            temp_section = join([section, winding, "LINE", transformer_line], " ")
                        end

                        if winding == "TWO-WINDING" && transformer_line == 4
                            break
                        else
                            elements = _get_line_elements(data_lines[line_number + transformer_line])[1]
                            _parse_line_element!(section_data, elements, temp_section)
                        end
                    end
                catch message
                    throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                end

            elseif section == "VOLTAGE SOURCE CONVERTER"
                if length(_get_line_elements(line)[1]) == 11
                    section_data = Dict{String,Any}()
                    try
                        _parse_line_element!(section_data, elements, section)
                    catch message
                        throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                    end
                    skip_sublines = 2
                    continue

                elseif skip_sublines > 0
                    skip_sublines -= 1
                    subsection_data = Dict{String,Any}()

                    for (field, dtype) in _pti_dtypes["$section SUBLINES"]
                        element = popfirst!(elements)
                        if element != ""
                            subsection_data[field] = parse(dtype, element)
                        else
                            subsection_data[field] = ""
                        end
                    end

                    if haskey(section_data, "CONVERTER BUSES")
                        push!(section_data["CONVERTER BUSES"], subsection_data)
                    else
                        section_data["CONVERTER BUSES"] = [subsection_data]
                        continue
                    end
                end

            elseif section == "TWO-TERMINAL DC"
                section_data = Dict{String,Any}()
                if length(_get_line_elements(line)[1]) == 12
                    (elements, comment) = _get_line_elements(join(data_lines[line_number:line_number + 2], ','))
                    skip_lines = 2
                end

                try
                    _parse_line_element!(section_data, elements, section)
                catch message
                    throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                end

            elseif section == "MULTI-TERMINAL DC"
                if skip_sublines == 0
                    section_data = Dict{String,Any}()
                    try
                        _parse_line_element!(section_data, elements, section)
                    catch message
                        throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                    end

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
                    try
                        _parse_line_element!(subsection_data, elements, "$section $subsection")
                    catch message
                        throw(Memento.error(_LOGGER, "Parsing failed at line $line_number: $(sprint(showerror, message))"))
                    end

                    if haskey(section_data, "$(subsection[2:end])")
                        section_data["$(subsection[2:end])"] = push!(section_data["$(subsection[2:end])"], subsection_data)
                        if skip_sublines > 0 && subsection != "NDCLN"
                            continue
                        end
                    else
                        section_data["$(subsection[2:end])"] = [subsection_data]
                        if skip_sublines > 0 && subsection != "NDCLN"
                            continue
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
                Memento.warn(_LOGGER, "GNE DEVICE parsing is not supported.")
            end
        end
        if subsection != ""
            Memento.debug(_LOGGER, "appending data")
        end

        if haskey(pti_data, section)
            push!(pti_data[section], section_data)
        else
            pti_data[section] = [section_data]
        end
    end

    _populate_defaults!(pti_data)
    _correct_nothing_values!(pti_data)

    return pti_data
end


"""
    parse_pti(filename::String)

Open PTI raw file given by `filename`, returning a `Dict` of the data parsed
into the proper types.
"""
function parse_pti(filename::String)::Dict
    pti_data = open(filename) do f
        parse_pti(f)
    end

    return pti_data
end


"""
    parse_pti(io::IO)

Reads PTI data in `io::IO`, returning a `Dict` of the data parsed into the
proper types.
"""
function parse_pti(io::IO)::Dict
    pti_data = _parse_pti_data(io)
    try
        pti_data["CASE IDENTIFICATION"][1]["NAME"] = match(r"^\<file\s[\/\\]*(?:.*[\/\\])*(.*)\.raw\>$", lowercase(io.name)).captures[1]
    catch
        throw(Memento.error(_LOGGER, "This file is unrecognized and cannot be parsed"))
    end

    return pti_data
end



"""
    _populate_defaults!(pti_data)

Internal function. Populates empty fields with PSS(R)E PTI v33 default values
"""
function _populate_defaults!(data::Dict)
    for section in _pti_sections
        if haskey(data, section)
            component_defaults = _pti_defaults[section]
            for component in data[section]
                for (field, field_value) in component
                    if isa(field_value, Array)
                        sub_component_defaults = component_defaults[field]
                        for sub_component in field_value
                            for (sub_field, sub_field_value) in sub_component
                                if sub_field_value == ""
                                    try
                                        sub_component[sub_field] = sub_component_defaults[sub_field]
                                    catch msg
                                        if isa(msg, KeyError)
                                            Memento.warn(_LOGGER, "'$sub_field' in '$field' in '$section' has no default value")
                                        else
                                            rethrow(msg)
                                        end
                                    end
                                end
                            end
                        end
                    elseif field_value == "" && !(field in ["Comment_Line_1", "Comment_Line_2"]) && !startswith(field, "DUM")
                        try
                            component[field] = component_defaults[field]
                        catch msg
                            if isa(msg, KeyError)
                                Memento.warn(_LOGGER, "'$field' in '$section' has no default value")
                            else
                                rethrow(msg)
                            end
                        end
                    end
                end
            end
        end
    end
end


