
function test_case(filename::AbstractString)
    temp_file = "temp.m"
    source_data = PowerModels.parse_file(filename)        

    io = open(temp_file, "w")         
    PowerModels.export_matpower(io, source_data)
    close(io)    
    destination_data = PowerModels.parse_file(temp_file)  
    
    @test InfrastructureModels.compare_dict(source_data, destination_data) == true
            
    rm(temp_file)
end  

@testset "test idempotent matpower export" begin
    @testset "test frankenstein_00" begin
        file = "../test/data/matpower/frankenstein_00.m"
        test_case(file)    
    end
    
    @testset "test case14" begin
        file = "../test/data/matpower/case14.m"
        test_case(file)    
    end
    
    @testset "test case2" begin
        file = "../test/data/matpower/case2.m"
        test_case(file)    
    end
    
    @testset "test case24" begin
        file = "../test/data/matpower/case24.m"
        test_case(file)    
    end
    
    @testset "test case3_tnep" begin
        file = "../test/data/matpower/case3_tnep.m"
        test_case(file)    
    end
    
    @testset "test case30" begin
        file = "../test/data/matpower/case30.m"
        test_case(file)    
    end

    @testset "test case5 asym" begin
        file = "../test/data/matpower/case5_asym.m"
        test_case(file)    
    end

    @testset "test case5 gap" begin
        file = "../test/data/matpower/case5_gap.m"
        test_case(file)    
    end

    @testset "test case5 pwlc" begin
        file = "../test/data/matpower/case5_pwlc.m"
        test_case(file)    
    end

    @testset "test case5" begin
        file = "../test/data/matpower/case5.m"
        test_case(file)    
    end

    @testset "test case6" begin
        file = "../test/data/matpower/case6.m"
        test_case(file)    
    end

    @testset "test extra components" begin
        file = "../test/data/matpower/extra_components.m"
        test_case(file)    
    end

    @testset "test case3" begin
        file = "../test/data/matpower/case3.m"
        test_case(file)    
    end

    @testset "test case5 dc" begin
        file = "../test/data/matpower/case5_dc.m"
        test_case(file)    
    end  

    @testset "test case5 tnep" begin
        file = "../test/data/matpower/case5_tnep.m"
        test_case(file)    
    end

    @testset "test case7 tplgy" begin
        file = "../test/data/matpower/case7_tplgy.m"
        test_case(file)    
    end
        
end