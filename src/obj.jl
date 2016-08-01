##########################################################################################################
# The purpose of this file is to define commonly used and created constraints used in power flow models
# This will hopefully make everything more compositional
##########################################################################################################

using JuMP


# min var array
function objective_min_vars(m, vars)
#  @objective(m, Min, sum{v, v=vars} )
  # TODO can this be done cleaner???
  @objective(m, Min, sum{vars[k[1]], k=keys(vars)} )
end


# add objective function criteria associated with quadratic generator costs
function objective_min_fuel_cost(m, pg, gens, gen_indexes)
  @objective(m, Min, sum{ gens[i]["cost"][1]*pg[i]^2 + gens[i]["cost"][2]*pg[i] + gens[i]["cost"][3], i=gen_indexes} )
end

function objective_min_fuel_cost_nl(m, pg, gens, gen_indexes)
  println("NL OBJ!")
  @NLobjective(m, Min, sum{ gens[i]["cost"][1]*pg[i]^2 + gens[i]["cost"][2]*pg[i] + gens[i]["cost"][3], i=gen_indexes} )
end

# TODO figure out how to do this better
# Why does this not work!
#@objective(m, Min, sum{ c*pg[i]^(p-1), i=gen_indexes, (p,c) = enumerate(reverse(gens[i]["cost"]))} )

#@setNLObjective(m, Min, sum{ c*pg[i]^(p-1), i=gen_indexes, (p,c) = enumerate(reverse(gens[i]["cost"]))} )


# for conic solvers which only support linear objective functions (e.g. SCS) 
function objective_min_fuel_cost_conic(m, pg, gens, gen_indexes)
  @variable(m, gens[i]["pmin"]^2 <= pg_sqr[i in gen_indexes] <= gens[i]["pmax"]^2, start = 0)

  for (i,gen) in gens
    @constraint(m, norm([2*pg[i], pg_sqr[i]-1]) <= pg_sqr[i]+1)
  end

  @objective(m, Min, sum{ gens[i]["cost"][1]*pg_sqr[i] + gens[i]["cost"][2]*pg[i] + gens[i]["cost"][3], i=gen_indexes} )
end

# maximize how much active load is served
function objective_max_active_load(m, pd, buses, bus_indexes)
  c_pd = [bp => 1 for bp in bus_indexes] 
  
  for (i,bus) in buses
    if (buses[i]["pd"] < 0)  
      c_pd[i] = -1
    end
  end
  
  @objective(m, Max, sum{ pd[i] * c_pd[i], i=bus_indexes} )
end

# maximize how much reactive load is served
# Surprise... objectives are not compositional, @objective replaces the last objective added...
function objective_max_active_and_reactive_load(m, pd, qd, buses, bus_indexes)
  c_qd = [bp => 1 for bp in bus_indexes] 
  c_pd = [bp => 1 for bp in bus_indexes] 
    
  for (i,bus) in buses
    if (buses[i]["qd"] < 0)  
      c_qd[i] = -1
    end  
    if (buses[i]["pd"] < 0)  
      c_pd[i] = -1
    end
  end
  
  @objective(m, Max, sum{pd[i] * c_pd[i] + qd[i] * c_qd[i], i=bus_indexes} )
end


# quadratic generator costs with virtual bus penalties 
function objective_min_fuel_cost_decent_va(m, pg, t, gens, gen_indexes, bus_indexes, virtual_bus_indexes, settings)
  ro = settings["ro"]
  wi = string(settings["worker_id"])

  worker_indexes = keys(settings["workers"])
  worker_indexes = collect(filter(i -> i != wi, worker_indexes))

  #println("worker indexes ", worker_indexes)

  worker_bus_indexes = [w => keys(settings["workers"][w]["bus"]) for w in worker_indexes]
  for w in worker_indexes
    worker_bus_indexes[w] = collect(filter(i -> int(i) in bus_indexes && !(int(i) in virtual_bus_indexes) in bus_indexes && settings["workers"][w]["bus"][i]["virtual"], worker_bus_indexes[w]))
  end

  #println("worker bus indexes ", worker_bus_indexes)

  tw    = [ w => [ i => settings["workers"][w]["bus"][i]["va"] for i in worker_bus_indexes[w] ] for w in worker_indexes]
  tw_mu = [ w => [ i => settings["workers"][w]["bus"][i]["mu"] for i in worker_bus_indexes[w] ] for w in worker_indexes]

  #println("tw ", tw)
  #println("tw_mu ", tw_mu)

  tv_remote = [i => NaN for i in virtual_bus_indexes]
  for w in worker_indexes
    for i in keys(settings["workers"][w]["bus"])
      bus = settings["workers"][w]["bus"][i]
      if int(i) in virtual_bus_indexes && !bus["virtual"]
        @assert isnan(tv_remote[int(i)])
        tv_remote[int(i)] = bus["va"]
      end
    end
  end


  #println("tv_remote ", tv_remote)

  tv    = [ i => settings["workers"][wi]["bus"][string(i)]["va"] for i in virtual_bus_indexes ]
  tv_mu = [ i => settings["workers"][wi]["bus"][string(i)]["mu"] for i in virtual_bus_indexes ]

  #println("tv ", tv)
  #println("tv_mu ", tv_mu)

  @objective(m, Min, 
    sum{ gens[i]["cost"][1]*pg[i]^2 + gens[i]["cost"][2]*pg[i] + gens[i]["cost"][3], i=gen_indexes} + 

    sum{ tv_mu[i]*(tv_remote[i] - t[i]), i=virtual_bus_indexes} + 
    ro/2*sum{ (tv_remote[i] - t[i])^2, i=virtual_bus_indexes} +

    sum{ sum{ tw_mu[w][i]*(t[int(i)] - tw[w][i]), i=worker_bus_indexes[w]}, w=worker_indexes} + 
    ro/2*sum{ sum{ (t[int(i)] - tw[w][i])^2, i=worker_bus_indexes[w]}, w=worker_indexes}
  )
end



