@testset "test matpower export" begin
    file = "../test/data/matpower/case30.m"
    data = PowerModels.parse_file(file)
    
    buses = Dict{Int, Dict}()
    for (idx,bus) in data["bus"]
        buses[bus["index"]] = bus
    end
    
    loads = Dict{Int, Dict}()
    for (idx,load) in data["load"]
        loads[load["index"]] = load
    end        
 
    i = 1
    for (idx, bus) in sort(buses)
        bus["name"] = string(i)
        i = i + 1     
    end    
        
    i = 100
    for (idx, load) in sort(loads)
        load["extra"] = i
        i = i + 1     
    end    
    
    components = Dict{String, Dict}()
    component = Dict{String, Any}()
    component["index"] = 1
    component["number"] = 1000.0
    component["string"] = "temp"         
    components["1"] = component
    data["component"] = components
    
    PowerModels.export_matpower(STDOUT, data)
end