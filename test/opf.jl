

facts("test ac opf") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = AC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(5812, 1e0)
    end
    context("24-bus rts case") do
        result = run_opf_file(;file = "../test/data/case24.json", model_builder = AC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(79804, 1e0)
    end
end


facts("test dc opf") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = DC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(5695, 1e0)
    end
    # TODO verify this is really infeasible
    #context("24-bus rts case") do
    #    result = run_opf_file(;file = "../test/data/case24.json", model_builder = DC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

    #    @fact result["status"] --> :LocalOptimal
    #    @fact result["objective"] --> roughly(79804, 1e0)
    #end
end


facts("test soc opf") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = SOC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(5735.9, 1e0)
    end
    context("24-bus rts case") do
        result = run_opf_file(;file = "../test/data/case24.json", model_builder = SOC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(70831, 1e0)
    end
end


facts("test qc opf") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = QC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(5742.0, 1e0)
    end
    context("24-bus rts case") do
        result = run_opf_file(;file = "../test/data/case24.json", model_builder = QC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(77049, 1e0)
    end
end


facts("test SDP opf") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = SDP_OPF, solver = build_solver(SCS_SOLVER, verbose=0))

        @fact result["status"] --> :Optimal
        @fact result["objective"] --> roughly(5788.7, 1e0)
    end
    # TODO replace this with smaller case, way too slow for regression testing
    #context("24-bus rts case") do
    #    result = run_opf_file(;file = "../test/data/case24.json", model_builder = SDP_OPF, solver = build_solver(SCS_SOLVER, verbose=0))
    #
    #    @fact result["status"] --> :Optimal
    #    @fact result["objective"] --> roughly(75153, 1e0)
    #end
end




