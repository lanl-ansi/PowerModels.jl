##########################################################################################################
# The purpose of this file is to define commonly used and created constraints used in power flow models
# This will hopefully make everything more compositional
##########################################################################################################

using JuMP

include("relaxation_scheme.jl")

function constraint_active_kcl_shunt_const(m, p, pg, bus, bus_branches, bus_gens; v=1.0, pd = bus["pd"])
  @constraint(m, sum{p[a], a=bus_branches} == sum{pg[g], g=bus_gens} - pd - bus["gs"]*v^2)
end

# Creates Kirchoff constraints for AC models
function constraint_active_kcl_shunt_v(m, p, pg, v, bus, bus_branches, bus_gens; pd = bus["pd"])
  @constraint(m, sum{p[a], a=bus_branches} == sum{pg[g], g=bus_gens} - pd - bus["gs"]*v^2)
end

function constraint_reactive_kcl_shunt_v(m, q, qg, v, bus, bus_branches, bus_gens; qd = bus["qd"])
  @constraint(m, sum{q[a], a=bus_branches} == sum{qg[g], g=bus_gens} - qd + bus["bs"]*v^2)
end

function constraint_active_kcl_shunt_w(m, p, pg, w, bus, bus_branches, bus_gens; pd = bus["pd"])
  @constraint(m, sum{p[a], a=bus_branches} == sum{pg[g], g=bus_gens} - pd - bus["gs"]*w)
end

function constraint_reactive_kcl_shunt_w(m, q, qg, w, bus, bus_branches, bus_gens; qd = bus["qd"])
  @constraint(m, sum{q[a], a=bus_branches} == sum{qg[g], g=bus_gens} - qd + bus["bs"]*w)
end


function constraint_active_kcl_shunt_v(m, v, t, pg, v_bus, bus, bus_branches_from, bus_branches_to, bus_gens, branches; pd = bus["pd"])
  g = [l => branch["g"] for (l, branch) in branches]
  b = [l => branch["b"] for (l, branch) in branches]
  c = [l => branch["br_b"] for (l, branch) in branches]
  tr = [l => branch["tr"] for (l, branch) in branches]
  ti = [l => branch["ti"] for (l, branch) in branches]
  tm = [l => tr[l]^2 + ti[l]^2 for (l, branch) in branches]

  # NL experssions not supported in JuMP?

#  from_expr = [l => g[l]/tm[l]*v[i]^2 + (-g[l]*tr[l]+b[l]*ti[l])/tm[l]*(v[i]*v[j]*cos(t[i]-t[j])) + (-b[l]*tr[l]-g[l]*ti[l])/tm[l]*(v[i]*v[j]*sin(t[i]-t[j])) for (l,i,j) in bus_branches_from]

#  to_expr = [l => g[l]*v[i]^2 + (-g[l]*tr[l]-b[l]*ti[l])/tm[l]*(v[i]*v[j]*cos(t[i]-t[j])) + (-b[l]*tr[l]+g[l]*ti[l])/tm[l]*(v[i]*v[j]*sin(t[i]-t[j])) for (l,i,j) in bus_branches_to]

#  @NLconstraint(m, sum{pg[g], g=bus_gens} - pd - bus["gs"]*v_bus^2 == 
#    sum{ from_expr[br[0]], br=bus_branches_from} +
#    sum{ to_expr[br[0]], br=bus_branches_to}
#  )

  @NLconstraint(m, sum{pg[g], g=bus_gens} - pd - bus["gs"]*v_bus^2 == 
    sum{ g[br[1]]/tm[br[1]]*v[br[2]]^2 + (-g[br[1]]*tr[br[1]]+b[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*cos(t[br[2]]-t[br[3]])) + (-b[br[1]]*tr[br[1]]-g[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*sin(t[br[2]]-t[br[3]])), 
    br=bus_branches_from} +
    sum{ g[br[1]]*v[br[2]]^2 + (-g[br[1]]*tr[br[1]]-b[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*cos(t[br[2]]-t[br[3]])) + (-b[br[1]]*tr[br[1]]+g[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*sin(t[br[2]]-t[br[3]])),
    br=bus_branches_to}
  )

#  @NLconstraint(m, sum{pg[g], g=bus_gens} - pd - bus["gs"]*v_bus^2 == 
#    sum{ g[l]/tm[l]*v[i]^2 + (-g[l]*tr[l]+b[l]*ti[l])/tm[l]*(v[i]*v[j]*cos(t[i]-t[j])) + (-b[l]*tr[l]-g[l]*ti[l])/tm[l]*(v[i]*v[j]*sin(t[i]-t[j])), 
#    (l,i,j)=bus_branches_from} +
#    sum{ g[l]*v[i]^2 + (-g[l]*tr[l]-b[l]*ti[l])/tm[l]*(v[i]*v[j]*cos(t[i]-t[j])) + (-b[l]*tr[l]+g[l]*ti[l])/tm[l]*(v[i]*v[j]*sin(t[i]-t[j])),
#    (l,i,j)=bus_branches_to}
#  )
end


function constraint_reactive_kcl_shunt_v(m, v, t, qg, v_bus, bus, bus_branches_from, bus_branches_to, bus_gens, branches; qd = bus["qd"])
  g = [l => branch["g"] for (l, branch) in branches]
  b = [l => branch["b"] for (l, branch) in branches]
  c = [l => branch["br_b"] for (l, branch) in branches]
  tr = [l => branch["tr"] for (l, branch) in branches]
  ti = [l => branch["ti"] for (l, branch) in branches]
  tm = [l => tr[l]^2 + ti[l]^2 for (l, branch) in branches]

  @NLconstraint(m, sum{qg[g], g=bus_gens} - qd + bus["bs"]*v_bus^2 == 
    sum{ -(b[br[1]]+c[br[1]]/2)/tm[br[1]]*v[br[2]]^2 - (-b[br[1]]*tr[br[1]]-g[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*cos(t[br[2]]-t[br[3]])) + (-g[br[1]]*tr[br[1]]+b[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*sin(t[br[2]]-t[br[3]])), 
    br=bus_branches_from} +
    sum{ -(b[br[1]]+c[br[1]]/2)*v[br[2]]^2 - (-b[br[1]]*tr[br[1]]+g[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*cos(t[br[2]]-t[br[3]])) + (-g[br[1]]*tr[br[1]]-b[br[1]]*ti[br[1]])/tm[br[1]]*(v[br[2]]*v[br[3]]*sin(t[br[2]]-t[br[3]])),
    br=bus_branches_to}
  )

#  @NLconstraint(m, sum{qg[g], g=bus_gens} - qd + bus["bs"]*v_bus^2 == 
#    sum{ -(b[l]+c[l]/2)/tm[l]*v[i]^2 - (-b[l]*tr[l]-g[l]*ti[l])/tm[l]*(v[i]*v[j]*cos(t[i]-t[j])) + (-g[l]*tr[l]+b[l]*ti[l])/tm[l]*(v[i]*v[j]*sin(t[i]-t[j])), 
#    (l,i,j)=bus_branches_from} +
#    sum{ -(b[l]+c[l]/2)*v[i]^2 - (-b[l]*tr[l]+g[l]*ti[l])/tm[l]*(v[i]*v[j]*cos(t[i]-t[j])) + (-g[l]*tr[l]-b[l]*ti[l])/tm[l]*(v[i]*v[j]*sin(t[i]-t[j])),
#    (l,i,j)=bus_branches_to}
#    )
end


function constraint_active_gen_setpoint(m, pg, gen)
  @constraint(m, pg == gen["pg"])
end

function constraint_reactive_gen_setpoint(m, qg, gen)
  @constraint(m, qg == gen["qg"])
end

function constraint_voltage_magnitude_setpoint(m, v, bus; epsilon = 0.0)
  if epsilon == 0.0
    @constraint(m, v == bus["vm"])
  else
    @assert epsilon > 0.0
    @constraint(m, v <= bus["vm"] + epsilon)
    @constraint(m, v >= bus["vm"] - epsilon)
  end
end

function constraint_voltage_magnitude_setpoint_w(m, w, bus)
  @constraint(m, w == bus["vm"]^2)
end



function constraint_min_edge_count(m, z, buses)
  @constraint(m, sum{z[k[1]], k=keys(z)} >= length(buses)-1)
end


# if z = 1, x = y
# if z = 0, x = free, y = 0
function constraint_var_link_on_off(m, x, y, z)
  x_ub = getupperbound(x)
  x_lb = getlowerbound(x)

  @constraint(m, y >= x - x_ub*(1-z))
  @constraint(m, y <= x - x_lb*(1-z))

  # assume other constraints force y to 0 when z is 0
end



# Creates Ohms constraints for AC models (y post fix indicates that Y values are in rectangular form)
function constraint_active_ohms_v_y(m, p_fr, p_to, v_fr, v_to, t_fr, t_to, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tap"]
  as = branch["shift"]

  @NLconstraint(m, p_fr == g*(v_fr/tr)^2 + -g*v_fr/tr*v_to*cos(t_fr-t_to-as) + -b*v_fr/tr*v_to*sin(t_fr-t_to-as) )
  @NLconstraint(m, p_to ==      g*v_to^2 + -g*v_to*v_fr/tr*cos(t_to-t_fr+as) + -b*v_to*v_fr/tr*sin(t_to-t_fr+as) )
end

function constraint_reactive_ohms_v_y(m, q_fr, q_to, v_fr, v_to, t_fr, t_to, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tap"]
  as = branch["shift"]

  @NLconstraint(m, q_fr == -(b+c/2)*(v_fr/tr)^2 + b*v_fr/tr*v_to*cos(t_fr-t_to-as) + -g*v_fr/tr*v_to*sin(t_fr-t_to-as) )
  @NLconstraint(m, q_to ==      -(b+c/2)*v_to^2 + b*v_to*v_fr/tr*cos(t_fr-t_to+as) + -g*v_to*v_fr/tr*sin(t_to-t_fr+as) )
end


# Creates Ohms constraints for AC models (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_v_yt(m, p_fr, p_to, v_fr, v_to, t_fr, t_to, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(m, p_fr == g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
  @NLconstraint(m, p_to ==    g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
end

function constraint_reactive_ohms_v_yt(m, q_fr, q_to, v_fr, v_to, t_fr, t_to, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(m, q_fr == -(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to)) )
  @NLconstraint(m, q_to ==    -(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr)) )
end


function constraint_active_ohms_v_yt_on_off(m, p_fr, p_to, v_fr, v_to, t_fr, t_to, z, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(m, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
  @NLconstraint(m, p_to ==    z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
end

function constraint_reactive_ohms_v_yt_on_off(m, q_fr, q_to, v_fr, v_to, t_fr, t_to, z, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @NLconstraint(m, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
  @NLconstraint(m, q_to ==    z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
end


function constraint_active_ohms_w_yt(m, p_fr, p_to, w_fr, w_to, wr_fr, wi_fr, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @constraint(m, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr_fr) + (-b*tr-g*ti)/tm*(wi_fr) )
  @constraint(m, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr_fr) + (-b*tr+g*ti)/tm*(-wi_fr) )
end

function constraint_reactive_ohms_w_yt(m, q_fr, q_to, w_fr, w_to, wr_fr, wi_fr, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @constraint(m, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr_fr) + (-g*tr+b*ti)/tm*(wi_fr) )
  @constraint(m, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr_fr) + (-g*tr-b*ti)/tm*(-wi_fr) )
end


# Creates Ohms constraints for linearized DC models
function constraint_active_ohms_linear(m, p_fr, p_to, t_fr, t_to, branch)   
  @constraint(m, p_fr == -p_to)
  @constraint(m, p_fr == -branch["b"]*(t_fr - t_to))
end

# Creates Ohms constraints for linearized DC models
function constraint_active_ohms_linear(m, p_fr, t_fr, t_to, branch)   
  @constraint(m, p_fr == -branch["b"]*(t_fr - t_to))
end

# Creates Ohms constraints for linearized DC models with on/off variable
function constraint_active_ohms_linear_on_off(m, p_fr, t_fr, t_to, z, t_min, t_max, branch)   
  @constraint(m, p_fr <= -branch["b"]*(t_fr - t_to + t_max*(1-z)) )
  @constraint(m, p_fr >= -branch["b"]*(t_fr - t_to + t_min*(1-z)) )

  @constraint(m, p_fr <= getupperbound(p_fr)*z )
  @constraint(m, p_fr >= getlowerbound(p_fr)*z )
end

# Creates Ohms constraints for linear DC models with quadratic loss and on/off variable
function constraint_active_ohms_loss_on_off(m, p_fr, p_to, t_fr, t_to, z, t_min, t_max, branch)
  constraint_active_ohms_linear_on_off(m, p_fr, t_fr, t_to, z, t_min, t_max, branch)

  t_m = max(abs(t_min),abs(t_max))
  @constraint(m, p_fr + p_to >= branch["br_r"]*( (-branch["b"]*(t_fr - t_to))^2 - (-branch["b"]*(t_m))^2*(1-z) ) )

  @constraint(m, p_to <= getupperbound(p_to)*z )
  @constraint(m, p_to >= getlowerbound(p_to)*z )
end


function constraint_active_loss_lb(m, p_from, p_to, branch)
  @assert branch["br_r"] >= 0
  @constraint(m, p_from + p_to >= 0)
end

function constraint_reactive_loss_lb(m, q_from, q_to, w_from, w_to, branch)
  @assert branch["br_x"] >= 0
  @constraint(m, q_from + q_to >= -branch["br_b"]/2*(w_from/branch["tap"]^2 + w_to))
end



# Creates angle different constraints
function constraint_phase_angle_diffrence_t(m, t_fr, t_to, branch)
  @constraint(m, t_fr - t_to <= branch["angmax"])
  @constraint(m, t_fr - t_to >= branch["angmin"])
end

function constraint_phase_angle_diffrence_t_on_off(m, t_fr, t_to, z, t_min, t_max, branch)
  @constraint(m, t_fr - t_to <= branch["angmax"]*z + t_max*(1-z))
  @constraint(m, t_fr - t_to >= branch["angmin"]*z + t_min*(1-z))
end

function constraint_phase_angle_diffrence_t_on_off_nl(m, t_fr, t_to, z, branch)
  @constraint(m, z*(t_fr - t_to) <= branch["angmax"])
  @constraint(m, z*(t_fr - t_to) >= branch["angmin"])
end

function constraint_phase_angle_diffrence_w(m, wr, wi, buspair)
  @constraint(m, wi <= buspair["angmax"]*wr)
  @constraint(m, wi >= buspair["angmin"]*wr)
end


function constraint_thermal_limit(m, p, q, branch) 
  @constraint(m, p^2 + q^2 <= branch["rate_a"]^2)
end

#TODO one day it would be nice if JuMP could unify these two constraints
function constraint_thermal_limit_conic(m, p, q, branch) 
  @constraint(m, norm([p; q]) <= branch["rate_a"])
end

function constraint_thermal_limit_on_off(m, p, q, z, branch) 
  @constraint(m, p^2 + q^2 <= branch["rate_a"]^2*z^2)
end



function constraint_power_magnitude_sqr(m, p, q, w, cm, branch)
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 
  @constraint(m, p^2 + q^2 <= w/tm*cm)
end

function constraint_power_magnitude_link(m, w_fr, w_to, wr, wi, cm, q, branch)
  g = branch["g"]
  b = branch["b"]
  c = branch["br_b"]
  tr = branch["tr"]
  ti = branch["ti"]
  tm = tr^2 + ti^2 

  @constraint(m, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q - ((c/2)/tm)^2*w_fr)
end

# Creates a constraint that allows generators to be turned on or off
function constraint_active_generation(m, pg, gen; var = 1)
  @constraint(m, pg <= gen["pmax"] * var)
  @constraint(m, gen["pmin"] * var <= pg)    

  # this feels like a hack...      
  setlowerbound(pg, min(0,gen["pmin"]))  
  setupperbound(pg, max(0,gen["pmax"]))  
    
end

# Creates a constraint that allows generators to be turned on or off
function constraint_reactive_generation(m, qg, gen; var = 1)
  @constraint(m, qg <= gen["qmax"] * var)
  @constraint(m, gen["qmin"] * var <= qg)
    
  # this feels like a hack...      
  setlowerbound(qg, min(0,gen["qmin"]))  
  setupperbound(qg, max(0,gen["qmax"]))  
        
end
