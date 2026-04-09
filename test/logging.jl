import LoggingExtras

@testset "logging" begin

    @testset "meta formatter" begin
        # Info level: prefix contains module and level, suffix is empty
        color, prefix, suffix = PowerModels._pm_metafmt(Logging.Info, PowerModels, :default, :id, "file.jl", 42)
        @test occursin("PowerModels", prefix)
        @test occursin("Info", prefix)
        @test suffix == ""

        # Warn level: prefix says "Warning", suffix has file and line
        color, prefix, suffix = PowerModels._pm_metafmt(Logging.Warn, PowerModels, :default, :id, "file.jl", 42)
        @test occursin("Warning", prefix)
        @test occursin("file.jl", suffix)
        @test occursin("42", suffix)

        # Error level: prefix says "Error", suffix has file and line
        color, prefix, suffix = PowerModels._pm_metafmt(Logging.Error, PowerModels, :default, :id, "file.jl", 42)
        @test occursin("Error", prefix)
        @test occursin("file.jl", suffix)
        @test occursin("42", suffix)

        # Debug level: prefix says "Debug", suffix has file and line
        color, prefix, suffix = PowerModels._pm_metafmt(Logging.Debug, PowerModels, :default, :id, "file.jl", 42)
        @test occursin("Debug", prefix)
        @test occursin("file.jl", suffix)

        # Line as UnitRange
        _, _, suffix = PowerModels._pm_metafmt(Logging.Warn, PowerModels, :default, :id, "file.jl", 10:20)
        @test occursin("10-20", suffix)

        # nil module and file
        _, prefix, suffix = PowerModels._pm_metafmt(Logging.Info, nothing, :default, :id, nothing, nothing)
        @test suffix == ""
    end

    @testset "silence!" begin
        PowerModels.reset_logging_level!()

        PowerModels.silence!()
        logger = Logging.global_logger()
        @test logger isa LoggingExtras.EarlyFilteredLogger

        PowerModels.silence!()  # cleanup
    end

    @testset "set_logging_level!" begin
        PowerModels.set_logging_level!(:Warn)
        @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger

        PowerModels.set_logging_level!(:Error)
        @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger

        PowerModels.set_logging_level!(:Info)
        @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger

        PowerModels.silence!()  # cleanup
    end

    @testset "reset_logging_level!" begin
        PowerModels.silence!()
        @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger

        PowerModels.reset_logging_level!()
        @test Logging.global_logger() isa Logging.ConsoleLogger

        PowerModels.silence!()  # cleanup
    end

    @testset "restore_global_logger!" begin
        original = InfrastructureModels._DEFAULT_LOGGER

        PowerModels.restore_global_logger!()
        @test Logging.global_logger() === original

        # restore PM logger for rest of tests
        PowerModels.reset_logging_level!()
        PowerModels.silence!()
    end

    @testset "per-module independence" begin
        # Silence PM only — IM should be unaffected
        PowerModels.reset_logging_level!()
        InfrastructureModels.reset_logging_level!()

        PowerModels.silence!()

        # PM is silenced
        @test haskey(InfrastructureModels._MODULE_LOG_LEVELS, PowerModels)
        # IM is not silenced
        @test !haskey(InfrastructureModels._MODULE_LOG_LEVELS, InfrastructureModels)

        # Filter correctly discriminates
        filter = InfrastructureModels._should_log
        @test filter((level=Logging.Warn, _module=PowerModels)) == false
        @test filter((level=Logging.Error, _module=PowerModels)) == true
        @test filter((level=Logging.Warn, _module=InfrastructureModels)) == true

        PowerModels.silence!()  # cleanup
    end

    @testset "dispatching formatter routes to PM" begin
        # PM formatter is registered
        @test haskey(InfrastructureModels._MODULE_FORMATTERS, PowerModels)

        # Dispatching formatter routes PM module to _pm_metafmt
        _, prefix1, _ = InfrastructureModels._dispatching_metafmt(Logging.Info, PowerModels, :default, :id, "file.jl", 1)
        _, prefix2, _ = PowerModels._pm_metafmt(Logging.Info, PowerModels, :default, :id, "file.jl", 1)
        @test prefix1 == prefix2
    end

    @testset "legacy API wrappers" begin
        PowerModels.silence()
        @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger

        for level in ["info", "warn", "error", "debug"]
            PowerModels.logger_config!(level)
            @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger
        end

        PowerModels.silence!()  # cleanup
    end

    @testset "silence and reset round-trip" begin
        PowerModels.reset_logging_level!()
        @test Logging.global_logger() isa Logging.ConsoleLogger

        PowerModels.silence!()
        @test Logging.global_logger() isa LoggingExtras.EarlyFilteredLogger

        PowerModels.reset_logging_level!()
        @test Logging.global_logger() isa Logging.ConsoleLogger

        PowerModels.silence!()  # cleanup
    end

end
