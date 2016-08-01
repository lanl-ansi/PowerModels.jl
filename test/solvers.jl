

facts("test solver builders") do
    # NOTE these tests should only include the subset of solvers used in unit testing

    context("ipopt solver") do
        solver = build_solver(IPOPT_SOLVER)
        @fact length(solver.options) --> 2
    end

    context("scs solver") do
        solver = build_solver(SCS_SOLVER)
        @fact length(solver.options) --> 1
    end
end


facts("test solver builders settings") do

    context("default value overide") do
        solver = build_solver(IPOPT_SOLVER, tol=1.0)
        @fact length(solver.options) --> 2
        @fact solver.options[1][2] --> 1.0
    end

    context("default extra values") do
        solver = build_solver(IPOPT_SOLVER, param="bloop")
        @fact length(solver.options) --> 3
        @fact solver.options[1][1] --> :param
        @fact solver.options[1][2] --> "bloop"
    end

    context("load from file") do
        solver = build_solver_file("../test/data/ipopt.json")
        @fact length(solver.options) --> 2
    end
end


