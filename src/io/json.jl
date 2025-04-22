# Copyright (c) 2016: Los Alamos National Security, LLC
#
# Use of this source code is governed by a BSD-style license that can be found
# in the LICENSE.md file.

# Parse PowerModels data from JSON exports of PowerModels data structures.

function _jsonver2juliaver!(pm_data)
    if haskey(pm_data, "source_version") && isa(pm_data["source_version"], Dict)
        pm_data["source_version"] = "$(pm_data["source_version"]["major"]).$(pm_data["source_version"]["minor"]).$(pm_data["source_version"]["patch"])"
    end
end

_json_parse(io::IO) = JSON.parse(io)
_json_parse(io::String) = JSON.parsefile(io; use_mmap = false)

"Parses json from iostream or string"
function parse_json(io::Union{IO,String}; validate = true)::Dict{String,Any}
    pm_data = _json_parse(io)

    _jsonver2juliaver!(pm_data)

    if haskey(pm_data, "conductors")
        Memento.warn(_LOGGER, "The JSON data contains the conductor parameter, but only single conductors are supported.  Consider using PowerModelsDistribution.")
    end

    if validate
        PowerModels.correct_network_data!(pm_data)
    end

    return pm_data
end
