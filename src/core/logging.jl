"""
    _pm_metafmt(level::Logging.LogLevel, _module, group, id, file, line)

MetaFormatter for PowerModels log messages.
"""
function _pm_metafmt(level::Logging.LogLevel, _module, group, id, file, line)
    @nospecialize
    color = Logging.default_logcolor(level)
    prefix = "$(_module) | " * (level == Logging.Warn ? "Warning" : string(level)) * " ] :"
    suffix = ""
    Logging.Info <= level < Logging.Warn && return color, prefix, suffix
    _module !== nothing && (suffix *= "$(_module)")
    if file !== nothing
        _module !== nothing && (suffix *= " ")
        suffix *= Base.contractuser(file)
        if line !== nothing
            suffix *= ":$(isa(line, UnitRange) ? "$(first(line))-$(last(line))" : line)"
        end
    end
    !isempty(suffix) && (suffix = "@ " * suffix)

    return color, prefix, suffix
end


"""
    silence!()

Sets loglevel for PowerModels to `:Error`, silencing Info and Warn.
"""
function silence!()
    set_logging_level!(:Error)
end


"""
    set_logging_level!(level::Symbol)

Sets the logging level for PowerModels: `:Info`, `:Warn`, `:Error`.
"""
function set_logging_level!(level::Symbol)
    _IM.set_module_log_level!(PowerModels, getfield(Logging, level))
    return
end


"""
    reset_logging_level!()

Removes PowerModels' log level override, restoring default behavior.
"""
function reset_logging_level!()
    _IM.reset_module_log_level!(PowerModels)
    return
end


"""
    restore_global_logger!()

Restores the global logger to its default state (before InfrastructureModels was loaded).
"""
function restore_global_logger!()
    _IM.restore_global_logger!()
    return
end
