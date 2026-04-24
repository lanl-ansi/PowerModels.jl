# using PowerModels
using Graphs
using SimpleWeightedGraphs
using LinearAlgebra
include("../../../../../config.jl")
push!(LOAD_PATH, DATA_PATH)
function find_nearest_generators_khop(file_path::String; top_k::Int=100)
    # 1. Parse the MATPOWER file
    data = PowerModels.parse_file(file_path)

    # 2. Create Mappings (Bus ID -> Graph Index)
    bus_ids = sort([parse(Int, k) for k in keys(data["bus"])])
    n_buses = length(bus_ids)
    
    id_to_idx = Dict(id => i for (i, id) in enumerate(bus_ids))
    idx_to_id = Dict(i => id for (i, id) in enumerate(bus_ids))

    # 3. Build the Unweighted Graph
    g = SimpleGraph(n_buses) # Changed to an unweighted graph
    
    for (k, branch) in data["branch"]
        u_real = branch["f_bus"]
        v_real = branch["t_bus"]
        
        # Skip isolated buses if they aren't in our main map
        if !haskey(id_to_idx, u_real) || !haskey(id_to_idx, v_real)
            continue
        end

        u = id_to_idx[u_real]
        v = id_to_idx[v_real]
        
        # Weight is removed. Every edge is exactly 1 hop.
        add_edge!(g, u, v)
    end

    # 4. Identify Targets (Generators) and Sources (Loads)
    gen_bus_ids = unique([gen["gen_bus"] for (k, gen) in data["gen"]])
    load_bus_ids = unique([bus["bus_i"] for (k, bus) in data["bus"]])

    # 5. Compute Shortest Paths and Rank
    results = Dict{Int, Vector{Int}}()

    for l_id in load_bus_ids
        src_idx = id_to_idx[l_id]
        
        # 'gdistances' uses BFS to count the exact number of hops to all other nodes
        dists = gdistances(g, src_idx)
        
        # Collect distances to all generators (using Int for hops instead of Float64)
        gen_distances = Vector{Tuple{Int, Int}}()
        
        for g_id in gen_bus_ids
            target_idx = id_to_idx[g_id]
            d = dists[target_idx]
            push!(gen_distances, (g_id, d))
        end
        
        # Sort by k-hop distance (smallest first) and take top K
        sort!(gen_distances, by = x -> x[2])
        safe_k = min(length(gen_distances), top_k)
        results[l_id] = [g[1] for g in gen_distances[1:safe_k]]
    end

    return results
end

# # # --- Usage Example ---
# CASE_NAME = "case300"
# file_pth = joinpath(DATA_PATH, "test_cases/network_info/$CASE_NAME/$(CASE_NAME).m")
# results = find_nearest_generators(file_pth)
# for (load_bus, gens) in results
#     println("Load Bus $load_bus Nearest Gens: $gens")
# end