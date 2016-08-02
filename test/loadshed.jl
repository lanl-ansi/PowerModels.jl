

facts("test ac ls") do
    context("3-bus case") do
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = AC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(4.44, 1e-2)
    end
    context("24-bus rts case") do
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = AC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(34.29, 1e-2)
    end
    
    context("3-bus case UC") do
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = AC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(4.44, 1e-2)
    end
    context("24-bus rts case UC") do
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = AC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(34.29, 1e-2)
    end
end


facts("test dc ls") do
    context("3-bus case") do
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = DC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(3.15, 1e-2)
    end
    context("24-bus rts case") do
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = DC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(28.45, 1e-2)
    end
    
    
    context("3-bus case UC") do
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = DC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(3.15, 1e-2)
    end
    context("24-bus rts case UC") do
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = DC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(28.46, 1e-2)
    end
    
end


facts("test soc ls") do
    context("3-bus case") do
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = SOC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(4.44, 1e-2)
    end
    context("24-bus rts case") do
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = SOC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(34.29, 1e-2)
    end
    
#    context("3-bus case UC") do
 #       result = run_load_shed_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = SOC_LS_UC, solver = build_solver(BONMIN_SOLVER))

  #      @fact result["status"] --> :LocalOptimal
   #     @fact result["objective"] --> roughly(4.44, 1e-2)
   # end
   # context("24-bus rts case UC") do
    #    result = run_load_shed_file(;file = "../test/data/nesta_case24_ieee_rts__sad.json", model_builder = SOC_LS_UC, solver = build_solver(BONMIN_SOLVER))

     #   @fact result["status"] --> :LocalOptimal
     #   @fact result["objective"] --> roughly(34.29, 1e-2)
    #end
end


facts("test qc ls") do
    context("3-bus case") do
        result = run_load_shed_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = QC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(4.44, 1e-2)
    end
    context("24-bus rts case") do
        result = run_load_shed_file(;file = "../test/data/nesta_case24_ieee_rts__sad.json", model_builder = QC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(34.29, 1e-2)
    end
    
#    context("3-bus case UC") do
 #       result = run_load_shed_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = QC_LS_UC, solver = build_solver(BONMIN_SOLVER))

  #      @fact result["status"] --> :LocalOptimal
   #     @fact result["objective"] --> roughly(4.44, 1e-2)
   # end
   # context("24-bus rts case UC") do
    #    result = run_load_shed_file(;file = "../test/data/nesta_case24_ieee_rts__sad.json", model_builder = QC_LS_UC, solver = build_solver(BONMIN_SOLVER))

     #   @fact result["status"] --> :LocalOptimal
     #   @fact result["objective"] --> roughly(34.29, 1e-2)
    #end
    
end


facts("test SDP ls") do
    context("3-bus case") do
        result = run_load_shed_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = SDP_LS, solver = build_solver(SCS_SOLVER, verbose=0))

        @fact result["status"] --> :Optimal
        @fact result["objective"] --> roughly(4.4, 1e-1)
    end
    
    
    
    # TODO replace this with smaller case, way too slow for regression testing
    #context("24-bus rts case") do
    #    result = run_load_shed_file(;file = "../test/data/nesta_case24_ieee_rts__sad.json", model_builder = SDP_LS, solver =  build_solver(SCS_SOLVER, verbose=0))
    #
    #    @fact result["status"] --> :Optimal
    #    @fact result["objective"] --> roughly(34.29, 1e-2)
    #end
end






facts("test ac ls uc ts") do
    context("3-bus case") do
        result = run_ots_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = AC_LS_UC_TS, solver = build_solver(BONMIN_SOLVER, bb_log_level=0, nlp_log_level=0))

        check_br_status(result["solution"])

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(4.45, 1e-2)
    end
    context("5-bus case") do
        result = run_ots_file(;file = "../test/data/nesta_case5_pjm.json", model_builder = AC_LS_UC_TS, solver = build_solver(BONMIN_SOLVER, bb_log_level=0, nlp_log_level=0))

        check_br_status(result["solution"])

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(13.28, 1e-1)
    end
end



# at the moment only Gurobi is reliable enough to solve these models
if (Pkg.installed("Gurobi") != nothing)

    facts("test dc ls uc ts") do
        context("3-bus case") do
            result = run_ots_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = DC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(3.15, 1e-2)
        end

        context("5-bus case") do
            result = run_ots_file(;file = "../test/data/nesta_case5_pjm.json", model_builder = DC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(10.0, 1e-2)
        end
    end

    facts("test soc ls uc ts") do
        context("3-bus case") do
            result = run_ots_file(;file = "../test/data/nesta_case3_lmbd.json", model_builder = SOC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(4.45, 1e-2)
        end
        context("5-bus rts case") do
            result = run_ots_file(;file = "../test/data/nesta_case5_pjm.json", model_builder = SOC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @fact result["status"] --> :Optimal
            @fact result["objective"] --> roughly(13.28, 1e-2)
        end
    end

end



















