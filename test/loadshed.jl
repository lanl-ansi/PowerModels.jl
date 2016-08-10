

@testset "test ac ls" begin
    @testset "3-bus case" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = AC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 4.44; atol = 1e-2)
    end
    @testset "24-bus rts case" begin
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = AC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 34.29; atol = 1e-2)
    end
    
    @testset "3-bus case UC" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = AC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 4.44; atol = 1e-2)
    end
    @testset "24-bus rts case UC" begin
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = AC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 34.29; atol = 1e-2)
    end
end


@testset "test dc ls" begin
    @testset "3-bus case" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = DC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 3.15; atol = 1e-2)
    end
    @testset "24-bus rts case" begin
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = DC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 28.45; atol = 1e-2)
    end
    
    
    @testset "3-bus case UC" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = DC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 3.15; atol = 1e-2)
    end
    @testset "24-bus rts case UC" begin
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = DC_LS_UC, solver = build_solver(BONMIN_SOLVER))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 28.46; atol = 1e-2)
    end
    
end


@testset "test soc ls" begin
    @testset "3-bus case" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = SOC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 4.44; atol = 1e-2)
    end
    @testset "24-bus rts case" begin
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = SOC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 34.29; atol = 1e-2)
    end
    
#    @testset "3-bus case UC" begin
 #       result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = SOC_LS_UC, solver = build_solver(BONMIN_SOLVER))

  #      @test result["status"] == :LocalOptimal
   #     @test isapprox(result["objective"], 4.44; atol = 1e-2)
   # end
   # @testset "24-bus rts case UC" begin
    #    result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = SOC_LS_UC, solver = build_solver(BONMIN_SOLVER))

     #   @test result["status"] == :LocalOptimal
     #   @test isapprox(result["objective"], 34.29; atol = 1e-2)
    #end
end


@testset "test qc ls" begin
    @testset "3-bus case" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = QC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 4.44; atol = 1e-2)
    end
    @testset "24-bus rts case" begin
        result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = QC_LS, solver = build_solver(IPOPT_SOLVER, print_level=0))

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 34.29; atol = 1e-2)
    end
    
#    @testset "3-bus case UC" begin
 #       result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = QC_LS_UC, solver = build_solver(BONMIN_SOLVER))

  #      @test result["status"] == :LocalOptimal
   #     @test isapprox(result["objective"], 4.44; atol = 1e-2)
   # end
   # @testset "24-bus rts case UC" begin
    #    result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = QC_LS_UC, solver = build_solver(BONMIN_SOLVER))

     #   @test result["status"] == :LocalOptimal
     #   @test isapprox(result["objective"], 34.29; atol = 1e-2)
    #end
    
end


@testset "test SDP ls" begin
    @testset "3-bus case" begin
        result = run_load_shed_file(;file = "../test/data/case3.json", model_builder = SDP_LS, solver = build_solver(SCS_SOLVER, verbose=0))

        @test result["status"] == :Optimal
        @test isapprox(result["objective"], 4.4; atol = 1e-1)
    end
    
    
    
    # TODO replace this with smaller case, way too slow for regression testing
    #@testset "24-bus rts case" begin
    #    result = run_load_shed_file(;file = "../test/data/case24.json", model_builder = SDP_LS, solver =  build_solver(SCS_SOLVER, verbose=0))
    #
    #    @test result["status"] == :Optimal
    #    @test isapprox(result["objective"], 34.29; atol = 1e-2)
    #end
end






@testset "test ac ls uc ts" begin
    @testset "3-bus case" begin
        result = run_ots_file(;file = "../test/data/case3.json", model_builder = AC_LS_UC_TS, solver = build_solver(BONMIN_SOLVER, bb_log_level=0, nlp_log_level=0))

        check_br_status(result["solution"])

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 4.45; atol = 1e-2)
    end
    @testset "5-bus case" begin
        result = run_ots_file(;file = "../test/data/case5.json", model_builder = AC_LS_UC_TS, solver = build_solver(BONMIN_SOLVER, bb_log_level=0, nlp_log_level=0))

        check_br_status(result["solution"])

        @test result["status"] == :LocalOptimal
        @test isapprox(result["objective"], 13.28; atol = 1e-1)
    end
end



# at the moment only Gurobi is reliable enough to solve these models
if (Pkg.installed("Gurobi") != nothing)

    @testset "test dc ls uc ts" begin
        @testset "3-bus case" begin
            result = run_ots_file(;file = "../test/data/case3.json", model_builder = DC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 3.15; atol = 1e-2)
        end

        @testset "5-bus case" begin
            result = run_ots_file(;file = "../test/data/case5.json", model_builder = DC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 10.0; atol = 1e-2)
        end
    end

    @testset "test soc ls uc ts" begin
        @testset "3-bus case" begin
            result = run_ots_file(;file = "../test/data/case3.json", model_builder = SOC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 4.45; atol = 1e-2)
        end
        @testset "5-bus rts case" begin
            result = run_ots_file(;file = "../test/data/case5.json", model_builder = SOC_LS_UC_TS, solver = build_solver(GUROBI_SOLVER, OutputFlag=0))

            check_br_status(result["solution"])

            @test result["status"] == :Optimal
            @test isapprox(result["objective"], 13.28; atol = 1e-2)
        end
    end

end



















