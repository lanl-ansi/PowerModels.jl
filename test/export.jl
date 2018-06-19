
function test_case(filename::AbstractString)
    temp_file = "temp.m"
    source_data = PowerModels.parse_file(filename)        

    io = open(temp_file, "w")         
    PowerModels.export_matpower(io, source_data)
    close(io)    
    destination_data = PowerModels.parse_file(temp_file)  
    
    @test InfrastructureModels.compare_dict(source_data, destination_data) == true
            
    #rm(temp_file)
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
end