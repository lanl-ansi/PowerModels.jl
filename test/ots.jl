
facts("test ac ots") do
#  Omitting this test, until bugs can be resolved
#    context("3-bus case") do
#        result = run_ots_file(;file = "../test/data/case3.json", model_builder = AC_OTS, solver = build_solver(BONMIN_SOLVER, bb_log_level=0, nlp_log_level=0))
#
#        check_br_status(result["solution"])
#
#        @fact result["status"] --> :LocalOptimal
#        @fact result["objective"] --> roughly(5812, 1e0)
#    end
    context("5-bus case") do
        result = run_ots_file(;file = "../test/data/case5.json", model_builder = AC_OTS, solver = build_solver(BONMIN_SOLVER, bb_log_level=0, nlp_log_level=0))

        check_br_status(result["solution"])

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(15174, 1e0)
    end
end



# at the moment only Gurobi is reliable enough to solve these models
if (Pkg.installed("Gurobi") != nothing)

    facts("test dc ots") do
        context("3-bus case") do
            result = run_ots_file(;file = "../test/data/case3.json", model_builder = DC_OTS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(5695.8, 1e0)
        end

        context("5-bus case") do
            result = run_ots_file(;file = "../test/data/case5.json", model_builder = DC_OTS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(14991.2, 1e0)
        end
    end


    facts("test dc-losses ots") do
        context("3-bus case") do
            result = run_ots_file(;file = "../test/data/case3.json", model_builder = DC_LL_OTS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(5787.1, 1e0)
        end

        context("5-bus case") do
            result = run_ots_file(;file = "../test/data/case5.json", model_builder = DC_LL_OTS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(15275.2, 1e0)
        end
    end


    facts("test soc ots") do
        context("3-bus case") do
            result = run_ots_file(;file = "../test/data/case3.json", model_builder = SOC_OTS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(5736.2, 1e0)
        end
        context("5-bus rts case") do
            result = run_ots_file(;file = "../test/data/case5.json", model_builder = SOC_OTS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(14999.7, 1e0)
        end
    end

end
