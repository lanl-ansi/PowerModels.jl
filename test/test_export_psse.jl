
function generate_pm_dicts(file_case; import_all=true)
    # Get Original Case
    case_base = PowerModels.parse_file(file_case, import_all=import_all)
    
    # Export to tmp fie
    file_tmp = "../test/data/tmp.raw"
    export_pti(file_tmp, case_base)

    # Get tmp file
    case_tmp = PowerModels.parse_file(file_tmp, import_all=import_all)
    rm(file_tmp)

    return case_base, case_tmp
end

@testset "Test Buses:" begin

    # PSSE -> PM1 -> PSSE -> PM2, checks PM1 == PM2
    for file in readdir("data/pti")
        
        skip_cases = [
            "case0.raw",
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            "frankenstein_20.raw", # this because 3w tran
            "frankenstein_70.raw",
            "three_winding_mag_test.raw",
            "three_winding_test.raw",
            "three_winding_test_2.raw"
            ]
            
            if file in skip_cases
                continue
            end
            
            @testset "Test Buses @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)
            
            @test InfrastructureModels.compare_dict(case_base["bus"], case_tmp["bus"])
            end
    end  
        
    # MATPOWER-> PSSE -> PM1 -> PSSE -> PM2 -> PSSE -> PM3, checks PM2 == PM3
    for file in readdir("data/matpower")
        @testset "Test Buses @ $(file)" begin
        # From MATPOWER -> PM
        file_case = "../test/data/matpower/" * file
        case_base = PowerModels.parse_file(file_case, import_all=import_all)
        
        # Export to tmp fiel 
        # From PM -> PSSE
        new_base = "../test/data/tmp.raw"
        export_pti(new_base, case_base)
        
        # Check PM -> PSSE ->PM
        case_base, case_tmp = generate_pm_dicts(new_base, import_all=true)
        
        @test InfrastructureModels.compare_dict(case_base["bus"], case_tmp["bus"])
        end
    end  
    
    ## MATPOWER -> PM1 -> PSSE -> PM2, checks PM1 == PM2
    #for file in readdir("data/matpower")
    #    @testset "Test Buses @ $(file)" begin
    #    # From MATPOWER -> PM1
    #    file_case = "../test/data/matpower/" * file
#
    #    # PM1 -> PSSE -> PM2
    #    case_base, case_tmp = generate_pm_dicts(file_case, import_all=false)
    #    
    #    @test InfrastructureModels.compare_dict(case_base["bus"], case_tmp["bus"])
    #    end
    #end  
end

@testset "Test Loads:" begin

    for file in readdir("data/pti")

        skip_cases = [
            "case0.raw",
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            ]

        if file in skip_cases
            continue
        end

        @testset "Test Loads @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)

            @test InfrastructureModels.compare_dict(case_base["load"], case_tmp["load"])
        end
    end  
end

@testset "Test Shunts:" begin

    for file in readdir("data/pti")

        skip_cases = [
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            "case0.raw",
            "case14.raw", # sw shunt
            "case24.raw", # sw shunt
            "case30.raw", # sw shunt
            "case73.raw", # sw shunt
            "frankenstein_20.raw", # sw shunt
            "frankenstein_70.raw", # sw shunt
            ]

        if file in skip_cases
            continue
        end

        @testset "Test Shunts @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)

            @test InfrastructureModels.compare_dict(case_base["shunt"], case_tmp["shunt"])
        end
    end  
end

@testset "Test Generators:" begin

    for file in readdir("data/pti")

        skip_cases = [
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            "case0.raw"
            ]

        if file in skip_cases
            continue
        end

        @testset "Test Generators @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)

            @test InfrastructureModels.compare_dict(case_base["gen"], case_tmp["gen"])
        end
    end  
end

@testset "Test Branches:" begin

    for file in readdir("data/pti")

        skip_cases = [
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            "case0.raw"
            ]

        if file in skip_cases
            continue
        end

        @testset "Test Branches @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)
            
            for (i, branch_base) in case_base["branch"]
                if branch_base["transformer"]
                    continue
                end
                branch_tmp = case_tmp["branch"][i]

                @test InfrastructureModels.compare_dict(branch_base, branch_tmp)
            end
        end
    end  
end

@testset "Test Transformers:" begin

    for file in readdir("data/pti")

        skip_cases = [
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            "case0.raw"
            ]

        if file in skip_cases
            continue
        end

        @testset "Test Transformers @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)
            
            for (i, branch_base) in case_base["branch"]
                if ! branch_base["transformer"]
                    continue
                end
                branch_tmp = case_tmp["branch"][i]

                @test InfrastructureModels.compare_dict(branch_base, branch_tmp)
            end
        end
    end  
end


