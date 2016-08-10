##########################################################################################################
# The purpose of this file is to define commonly used and created variables used in power flow models
# This will hopefully make everything more compositional
##########################################################################################################

# TODO need to find a way to pass-through extra args to varibles maco (look into ... syntax) 

# creates a default start vector
function create_default_start(indexes, value, tag)
  start = Dict()
  for (i in indexes)
    start[i] = Dict(tag => value)
  end
  return start
end

# Creates variables associated with phase angles at each bus
function phase_angle_variables(m, bus_indexes; start = create_default_start(bus_indexes,0,"theta_start"))
  @variable(m, theta[i in bus_indexes], start = start[i]["theta_start"])
  return theta
end

# TODO: isolate this issue and post a JuMP issue
function phase_angle_variables_1(m, buses)
  @variable(m, theta[b in values(buses)])
  return theta
end


# Create variables associated with voltage magnitudes
function voltage_magnitude_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes, 1.0, "v_start"))
  @variable(m, buses[i]["vmin"] <= v[i in bus_indexes] <= buses[i]["vmax"], start = start[i]["v_start"])
  return v
end

# Creates real generation variables for each generator in the model
function active_generation_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes,0, "pg_start"))
  @variable(m, gens[i]["pmin"] <= pg[i in gen_indexes] <= gens[i]["pmax"], start = start[i]["pg_start"])
  return pg
end

# Creates reactive generation variables for each generator in the model
function reactive_generation_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes,0, "qg_start"))
  @variable(m, gens[i]["qmin"] <= qg[i in gen_indexes] <= gens[i]["qmax"], start = start[i]["qg_start"])
  return qg
end

# Creates generator indicator variables
function generator_indicator_variables(m, gens, gen_indexes; start = create_default_start(gen_indexes,1, "uc_start"))
  @variable(m, 0 <= uc[i in gen_indexes] <= 1, Int, start = start[i]["uc_start"])
  return uc
end


# Creates real load variables for each bus in the model
function active_load_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes,0, "pd_start"))
  pd_min = [i => 0.0 for i in bus_indexes] 
  pd_max = [i => 0.0 for i in bus_indexes] 
  for i in bus_indexes
    if (buses[i]["pd"] >= 0)  
      pd_min[i] = 0
      pd_max[i] = buses[i]["pd"]
    else      
      pd_min[i] = buses[i]["pd"]
      pd_max[i] = 0   
    end
  end    
  @variable(m, pd_min[i] <= pd[i in bus_indexes] <= pd_max[i], start = start[i]["pd_start"])
  return pd
end

# Creates reactive load variables for each bus in the model
function reactive_load_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes,0, "qd_start"))
  qd_min = [i => 0.0 for i in bus_indexes] 
  qd_max = [i => 0.0 for i in bus_indexes] 
  for i in bus_indexes
    if (buses[i]["qd"] >= 0)  
      qd_min[i] = 0.0
      qd_max[i] = buses[i]["qd"]
    else      
      qd_min[i] = buses[i]["qd"]
      qd_max[i] = 0.0   
    end
  end    
  @variable(m, qd_min[i] <= qd[i in bus_indexes] <= qd_max[i], start = start[i]["qd_start"])
  return qd
end

# Create variables associated with real flows on a line... this sets the start value of (l,i,j) annd (l,j,i) to be the same
function line_flow_variables(m, arcs, branches, branch_indexes; tag = "f_start", start = create_default_start(branch_indexes,0,tag))
  @variable(m, -branches[l]["rate_a"] <= f[(l,i,j) in arcs] <= branches[l]["rate_a"], start = start[l][tag])
  return f
end

# Create variables associated with real flows on a line
function line_indicator_variables(m, branch_indexes; start = create_default_start(branch_indexes,1,"z_start"))
  # Bin does not seem to be recognized by gurobi interface
  #@variable(m, z[l in branch_indexes], Bin, start = start)
  @variable(m, 0 <= z[l in branch_indexes] <= 1, Int, start = start[l]["z_start"])
  #@variable(m, z[l in branch_indexes], Int, start = start)
  return z
end

# Create variables for modeling v^2 lifted to w
function voltage_magnitude_sqr_variables(m, buses, bus_indexes; start = create_default_start(bus_indexes,1.001, "w_start"))
  @variable(m, buses[i]["vmin"]^2 <= w[i in bus_indexes] <= buses[i]["vmax"]^2, start = start[i]["w_start"])
  return w
end

function voltage_magnitude_sqr_from_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,0, "w_from_start"))
  @variable(m, 0 <= w_from[i in branch_indexes] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = start[i]["w_from_start"])

  for i in branch_indexes
    @constraint(m, w_from[i] <= z[i]*buses[branches[i]["f_bus"]]["vmax"]^2)
    @constraint(m, w_from[i] >= z[i]*buses[branches[i]["f_bus"]]["vmin"]^2)
  end

  return w_from
end

function voltage_magnitude_sqr_to_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,0, "w_to_start"))
  @variable(m, 0 <= w_to[i in branch_indexes] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = start[i]["w_to_start"])

  for i in branch_indexes
    @constraint(m, w_to[i] <= z[i]*buses[branches[i]["t_bus"]]["vmax"]^2)
    @constraint(m, w_to[i] >= z[i]*buses[branches[i]["t_bus"]]["vmin"]^2)
  end

  return w_to
end


# Creates variables associated with cosine terms in the AC power flow models for SOC models
function real_complex_product_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,1.0, "wr_start"))
  wr_min = [bp => -Inf for bp in buspair_indexes] 
  wr_max = [bp =>  Inf for bp in buspair_indexes] 

  for bp in buspair_indexes
    i,j = bp
    buspair = buspairs[bp]
    if buspair["angmin"] >= 0
      wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*cos(buspair["angmin"])
      wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*cos(buspair["angmax"])
    end
    if buspair["angmax"] <= 0
      wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*cos(buspair["angmax"])
      wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*cos(buspair["angmin"])
    end
    if buspair["angmin"] < 0 && buspair["angmax"] > 0
      wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*1.0
      wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*min(cos(buspair["angmin"]), cos(buspair["angmax"]))
    end
  end
  
  @variable(m, wr_min[bp] <= wr[bp in buspair_indexes] <= wr_max[bp], start = start[bp]["wr_start"]) 
  return wr
end

# Creates variables associated with sine terms in the AC power flow models for SOC models
function imaginary_complex_product_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,0, "wi_start"))
  wi_min = [bp => -Inf for bp in buspair_indexes]
  wi_max = [bp =>  Inf for bp in buspair_indexes] 

  for bp in buspair_indexes
    i,j = bp
    buspair = buspairs[bp]
    if buspair["angmin"] >= 0
      wi_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmax"])
      wi_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*sin(buspair["angmin"])
    end
    if buspair["angmax"] <= 0
      wi_max[bp] = buspair["v_from_min"]*buspair["v_to_min"]*sin(buspair["angmax"])
      wi_min[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmin"])
    end
    if buspair["angmin"] < 0 && buspair["angmax"] > 0
      wi_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmax"])
      wi_min[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmin"])
    end
  end
  
  @variable(m, wi_min[bp] <= wi[bp in buspair_indexes] <= wi_max[bp], start = start[bp]["wi_start"])
  return wi 
end



# Creates variables associated with cosine terms in the AC power flow models for SOC models
function real_complex_product_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,0, "wr_start"))
  wr_min = [b => -Inf for b in branch_indexes]
  wr_max = [b =>  Inf for b in branch_indexes] 

  for b in branch_indexes
    branch = branches[b]
    i = branch["f_bus"]
    j = branch["t_bus"]

    if branch["angmin"] >= 0
      wr_max[b] = buses[i]["vmax"]*buses[j]["vmax"]*cos(branch["angmin"])
      wr_min[b] = buses[i]["vmin"]*buses[j]["vmin"]*cos(branch["angmax"])
    end
    if branch["angmax"] <= 0
      wr_max[b] = buses[i]["vmax"]*buses[j]["vmax"]*cos(branch["angmax"])
      wr_min[b] = buses[i]["vmin"]*buses[j]["vmin"]*cos(branch["angmin"])
    end
    if branch["angmin"] < 0 && branch["angmax"] > 0
      wr_max[b] = buses[i]["vmax"]*buses[j]["vmax"]*1.0
      wr_min[b] = buses[i]["vmin"]*buses[j]["vmin"]*min(cos(branch["angmin"]), cos(branch["angmax"]))
    end
  end
  
  @variable(m, min(0, wr_min[b]) <= wr[b in branch_indexes] <= max(0, wr_max[b]), start = start[b]["wr_start"]) 

  for b in branch_indexes
    @constraint(m, wr[b] <= z[b]*wr_max[b])
    @constraint(m, wr[b] >= z[b]*wr_min[b])
  end

  return wr
end

# Creates variables associated with sine terms in the AC power flow models for SOC models
function imaginary_complex_product_on_off_variables(m, z, branch_indexes, branches, buses; start = create_default_start(branch_indexes,0, "wi_start"))
  wi_min = [b => -Inf for b in branch_indexes]
  wi_max = [b =>  Inf for b in branch_indexes] 

  for b in branch_indexes
    branch = branches[b]
    i = branch["f_bus"]
    j = branch["t_bus"]

    if branch["angmin"] >= 0
      wi_max[b] = buses[i]["vmax"]*buses[j]["vmax"]*sin(branch["angmax"])
      wi_min[b] = buses[i]["vmin"]*buses[j]["vmin"]*sin(branch["angmin"])
    end
    if branch["angmax"] <= 0
      wi_max[b] = buses[i]["vmin"]*buses[j]["vmin"]*sin(branch["angmax"])
      wi_min[b] = buses[i]["vmax"]*buses[j]["vmax"]*sin(branch["angmin"])
    end
    if branch["angmin"] < 0 && branch["angmax"] > 0
      wi_max[b] = buses[i]["vmax"]*buses[j]["vmax"]*sin(branch["angmax"])
      wi_min[b] = buses[i]["vmax"]*buses[j]["vmax"]*sin(branch["angmin"])
    end
  end
  
  @variable(m, min(0, wi_min[b]) <= wi[b in branch_indexes] <= max(0, wi_max[b]), start = start[b]["wi_start"])

  for b in branch_indexes
    @constraint(m, wi[b] <= z[b]*wi_max[b])
    @constraint(m, wi[b] >= z[b]*wi_min[b])
  end

  return wi 
end



# Creates variables associated with differences in phase angles
function phase_angle_diffrence_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,0, "td_start"))
  @variable(m, buspairs[bp]["angmin"] <= td[bp in buspair_indexes] <= buspairs[bp]["angmax"], start = start[bp]["td_start"])
  return td
end

# Creates the V_i * V_j variables
function voltage_magnitude_product_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,0, "vv_start"))
  vv_min = [bp => buspairs[bp]["v_from_min"]*buspairs[bp]["v_to_min"] for bp in buspair_indexes]
  vv_max = [bp => buspairs[bp]["v_from_max"]*buspairs[bp]["v_to_max"] for bp in buspair_indexes] 

  @variable(m,  vv_min[bp] <= vv[bp in buspair_indexes] <=  vv_max[bp], start = start[bp]["vv_start"])
  return vv
end

function cosine_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,0, "cs_start"))
  cos_min = [bp => -Inf for bp in buspair_indexes]
  cos_max = [bp =>  Inf for bp in buspair_indexes] 

  for bp in buspair_indexes
    buspair = buspairs[bp]
    if buspair["angmin"] >= 0
      cos_max[bp] = cos(buspair["angmin"])
      cos_min[bp] = cos(buspair["angmax"])
    end
    if buspair["angmax"] <= 0
      cos_max[bp] = cos(buspair["angmax"])
      cos_min[bp] = cos(buspair["angmin"])
    end
    if buspair["angmin"] < 0 && buspair["angmax"] > 0
      cos_max[bp] = 1.0
      cos_min[bp] = min(cos(buspair["angmin"]), cos(buspair["angmax"]))
    end
  end

  @variable(m, cos_min[bp] <= cs[bp in buspair_indexes] <= cos_max[bp], start = start[bp]["cs_start"])
  return cs
end

function sine_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,0,"si_start"))
  @variable(m, sin(buspairs[bp]["angmin"]) <= si[bp in buspair_indexes] <= sin(buspairs[bp]["angmax"]), start = start[bp]["si_start"])
  return si
end

function current_magnitude_sqr_variables(m, buspairs, buspair_indexes; start = create_default_start(buspair_indexes,0, "cm_start")) 
  cm_min = [bp => 0 for bp in buspair_indexes] 
  cm_max = [bp => (buspairs[bp]["rate_a"]*buspairs[bp]["tap"]/buspairs[bp]["v_from_min"])^2 for bp in buspair_indexes]       
  @variable(m,  cm_min[bp] <= cm[bp in buspair_indexes] <=  cm_max[bp], start = start[bp]["cm_start"])
  return cm
end


function complex_product_matrix_variables(m, buspairs, buspair_indexes, buses, bus_indexes)
  w_index = 1:length(bus_indexes)
  lookup_w_index = [bi => i for (i,bi) in enumerate(bus_indexes)]

  wr_min = [bp => -Inf for bp in buspair_indexes] 
  wr_max = [bp =>  Inf for bp in buspair_indexes] 
  wi_min = [bp => -Inf for bp in buspair_indexes] 
  wi_max = [bp =>  Inf for bp in buspair_indexes] 

  for bp in buspair_indexes
      i,j = bp
      buspair = buspairs[bp]
      if buspair["angmin"] >= 0
          wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*cos(buspair["angmin"])
          wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*cos(buspair["angmax"])
          wi_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmax"])
          wi_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*sin(buspair["angmin"])
      end
      if buspair["angmax"] <= 0
          wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*cos(buspair["angmax"])
          wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*cos(buspair["angmin"])
          wi_max[bp] = buspair["v_from_min"]*buspair["v_to_min"]*sin(buspair["angmax"])
          wi_min[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmin"])
      end
      if buspair["angmin"] < 0 && buspair["angmax"] > 0
          wr_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*1.0
          wr_min[bp] = buspair["v_from_min"]*buspair["v_to_min"]*min(cos(buspair["angmin"]), cos(buspair["angmax"]))
          wi_max[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmax"])
          wi_min[bp] = buspair["v_from_max"]*buspair["v_to_max"]*sin(buspair["angmin"])
      end
  end

  @variable(m, WR[1:length(bus_indexes), 1:length(bus_indexes)], Symmetric)
  @variable(m, WI[1:length(bus_indexes), 1:length(bus_indexes)])

  # bounds on diagonal
  for (i,bus) in buses
    w_idx = lookup_w_index[i]
    wr_ii = WR[w_idx,w_idx]
    wi_ii = WR[w_idx,w_idx]

    setlowerbound(wr_ii, bus["vmin"]^2)
    setupperbound(wr_ii, bus["vmax"]^2)

    #this breaks SCS on the 3 bus exmple
    #setlowerbound(wi_ii, 0)
    #setupperbound(wi_ii, 0)
  end

  # bounds on off-diagonal
  for (i,j) in buspair_indexes
    wi_idx = lookup_w_index[i]
    wj_idx = lookup_w_index[j]

    setupperbound(WR[wi_idx, wj_idx], wr_max[(i,j)])
    setlowerbound(WR[wi_idx, wj_idx], wr_min[(i,j)])

    setupperbound(WI[wi_idx, wj_idx], wi_max[(i,j)])
    setlowerbound(WI[wi_idx, wj_idx], wi_min[(i,j)])
  end

  return WR, WI, lookup_w_index
end
