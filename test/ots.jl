
if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)

    @testset "test ac ots" begin
    #  Omitting this test, until bugs can be resolved
    #    @testset "3-bus case" begin
    #        result = run_ots_file(;file = "../test/data/case3.json", model_builder = AC_OTS, solver = BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))
    #
    #        check_br_status(result["solution"])
    #
    #        @test result["status"] == :LocalOptimal
    #        @test isapprox(result["objective"], 5812; atol = 1e0)
    #    end
        @testset "5-bus case" begin
            result = run_ots("../test/data/case5.json", ACPPowerModel, BonminNLSolver(["bonmin.bb_log_level=0", "bonmin.nlp_log_level=0"]))

            check_br_status(result["solution"])

            @test result["status"] == :LocalOptimal
            @test isapprox(result["objective"], 15174; atol = 1e0)
        end
    end

end


function run_nl_ots(file, model_constructor, solver; kwargs...)
    data = PowerModels.parse_file(file)

    pm = model_constructor(data; solver = solver, kwargs...)

    PowerModels.post_ots(pm)

    pg = JuMP.getvariable(pm.model, :pg)[1]
    lb = JuMP.getlowerbound(pg)
    JuMP.@NLconstraint(pm.model, pg >= lb)

    status, solve_time = solve(pm)

    return PowerModels.build_solution(pm, status, solve_time; solution_builder = PowerModels.get_ots_solution)
end

@testset "test dc ots" begin
    @testset "3-bus case" begin
        result = run_nl_ots("../test/data/case3.json", DCPPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5695.8; atol = 1e0)
    end

    @testset "5-bus case" begin
        result = run_nl_ots("../test/data/case5.json", DCPPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14991.2; atol = 1e0)
    end
end

@testset "test dc-losses ots" begin
    @testset "3-bus case" begin
        result = run_nl_ots("../test/data/case3.json", DCPLLPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5787.1; atol = 1e0)
    end

    @testset "5-bus case" begin
        result = run_nl_ots("../test/data/case5.json", DCPLLPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 15275.2; atol = 1e0)
    end
end

@testset "test soc ots" begin
    @testset "3-bus case" begin
        result = run_nl_ots("../test/data/case3.json", SOCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 5736.2; atol = 1e0)
    end
    @testset "5-bus rts case" begin
        result = run_nl_ots("../test/data/case5.json", SOCWRPowerModel, pajarito_solver)

        check_br_status(result["solution"])

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 14999.7; atol = 1e0)
    end
end

