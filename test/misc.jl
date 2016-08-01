facts("test ac api") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = AC_API, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(1.3375, 1e-3)
    end
    context("5-bus pjm case") do
        result = run_opf_file(;file = "../test/data/case5.json", model_builder = AC_API, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(2.6885, 1e-3)
    end
    context("30-bus ieee case") do
        result = run_opf_file(;file = "../test/data/case30.json", model_builder = AC_API, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(1.6632, 1e-3)
    end
end


facts("test ac sad") do
    context("3-bus case") do
        result = run_opf_file(;file = "../test/data/case3.json", model_builder = AC_SAD, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0.3144, 1e-2)
    end
    context("5-bus pjm case") do
        result = run_opf_file(;file = "../test/data/case5.json", model_builder = AC_SAD, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0.02233, 1e-2)
    end
    context("30-bus ieee case") do
        result = run_opf_file(;file = "../test/data/case30.json", model_builder = AC_SAD, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0.1537, 1e-2)
    end
end
