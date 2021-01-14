
function generate_pm_dicts(file_case; import_all=true)
    file_tmp = "../test/data/tmp.raw"
    case_base = PowerModels.parse_file(file_case, import_all=import_all)

    export_pti(file_tmp, case_base)

    case_tmp = PowerModels.parse_file(file_tmp, import_all=import_all)
    rm(file_tmp)

    return case_base, case_tmp
end

@testset "Test Buses:" begin

    for file in readdir("data/pti")

        non_sense_cases = [
            "case0.raw",
            "parser_test_b.raw",
            "parser_test_d.raw",
            "parser_test_defaults.raw",
            "parser_test_j.raw",
            ]

        skip_cases = [
            "frankenstein_20.raw",
            "frankenstein_70.raw",
            "three_winding_mag_test.raw",
            "three_winding_test.raw",
            "three_winding_test_2.raw"
        ]

        if file in vcat(non_sense_cases, skip_cases)
            continue
        end

        @testset "Test Buses @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)

            @test InfrastructureModels.compare_dict(case_base["bus"], case_tmp["bus"])
        end
    end  

    #@testset "Test Buses (case3.m)" begin
    ## MP -> PM -> PSSE -> PM
#
    #file_case = "../test/data/matpower/case3.m"
    #case_base, case_tmp = generate_pm_dicts(file_case, import_all=false)
#
    #file_tmp = "../test/data/tmp.m"
    #export_matpower(file_tmp, case_tmp)
    #case_tmp = PowerModels.parse_file(file_tmp, import_all=false)
#
    #@test InfrastructureModels.compare_dict(case_base["bus"], case_tmp["bus"])
    #end
end

@testset "Test Loads:" begin

    for file in readdir("data/pti")

        non_sense_cases = [
            ]

        skip_cases = [

        ]

        if file in non_sense_cases
            continue
        end

        @testset "Test Loads @ $(file)" begin
            file_case = "../test/data/pti/" * file
            case_base, case_tmp = generate_pm_dicts(file_case, import_all=true)

            @test InfrastructureModels.compare_dict(case_base["load"], case_tmp["load"])
        end
    end  
end