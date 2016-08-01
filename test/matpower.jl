facts("test matpower parser") do
    context("30-bus case") do
        result = run_opf_file(;file = "../test/data/case30.m", model_builder = AC_OPF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(204.96, 1e-1)
    end
end