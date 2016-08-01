

facts("test ac pf") do
    context("3-bus case") do
        result = run_pf_file(;file = "../test/data/case3.json", model_builder = AC_PF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0, 1e-2)

        @fact result["solution"]["gen"][1]["pg"] --> roughly(148.0, 1e-1)
        @fact result["solution"]["gen"][1]["qg"] --> roughly(54.6, 1e-1)

        @fact result["solution"]["bus"][1]["vm"] --> roughly(1.10000, 1e-3)
        @fact result["solution"]["bus"][1]["va"] --> roughly(0.00000, 1e-3)

        @fact result["solution"]["bus"][2]["vm"] --> roughly(0.92617, 1e-3)
        @fact result["solution"]["bus"][2]["va"] --> roughly(7.25886, 1e-3)

        @fact result["solution"]["bus"][3]["vm"] --> roughly(0.90000, 1e-3)
        @fact result["solution"]["bus"][3]["va"] --> roughly(-17.26711, 1e-3)
    end
    context("24-bus rts case") do
        result = run_pf_file(;file = "../test/data/case24.json", model_builder = AC_PF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0, 1e-2)
    end
end


facts("test dc pf") do
    context("3-bus case") do
        result = run_pf_file(;file = "../test/data/case3.json", model_builder = DC_PF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0, 1e-2)

        @fact result["solution"]["gen"][1]["pg"] --> roughly(144.99, 1e-1)

        @fact result["solution"]["bus"][1]["va"] --> roughly(0.00000, 1e-3)
        @fact result["solution"]["bus"][2]["va"] --> roughly(5.24122, 1e-3)
        @fact result["solution"]["bus"][3]["va"] --> roughly(-16.21006, 1e-3)
    end
    context("24-bus rts case") do
        result = run_pf_file(;file = "../test/data/case24.json", model_builder = DC_PF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0, 1e-2)
    end
end


facts("test soc pf") do
    context("3-bus case") do
        result = run_pf_file(;file = "../test/data/case3.json", model_builder = SOC_PF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["solution"]["gen"][1]["pg"] >= 148.0 --> true

        @fact result["solution"]["bus"][1]["vm"] --> roughly(1.09999, 1e-3)
        @fact result["solution"]["bus"][2]["vm"] --> roughly(0.92616, 1e-3)
        @fact result["solution"]["bus"][3]["vm"] --> roughly(0.89999, 1e-3)

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0, 1e-2)
    end
    context("24-bus rts case") do
        result = run_pf_file(;file = "../test/data/case24.json", model_builder = SOC_PF, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @fact result["status"] --> :LocalOptimal
        @fact result["objective"] --> roughly(0, 1e-2)
    end
end






