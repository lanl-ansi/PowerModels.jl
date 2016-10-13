#### General Assumptions of these Expansion Models ####
#
# - if the branch has a field called "construction_cost", then it is assumed to be a buildable edge
#

export run_expansion

function run_expansion(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_expansion; solution_builder = get_expansion_solution, kwargs...) 
end

# the general form of the expansion optimization model
function post_expansion{T}(pm::GenericPowerModel{T})
    build_expansion_sets(pm) ## create the data sets we need
    
    variable_line_expansion(pm) 
    variable_complex_voltage_on_off(pm)

    variable_active_generation(pm)
    variable_reactive_generation(pm)

    variable_active_line_flow(pm)
    variable_reactive_line_flow(pm)

    objective_expansion_cost(pm)

    constraint_theta_ref(pm)
    constraint_complex_voltage_expansion_on_off(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt(pm, bus)
        constraint_reactive_kcl_shunt(pm, bus)
    end

    for i in pm.data["new_branches"]
        branch = pm.set.branches[i] 
        constraint_active_ohms_yt_expansion_on_off(pm, branch)
        constraint_reactive_ohms_yt_expansion_on_off(pm, branch) 

        constraint_phase_angle_difference_expansion_on_off(pm, branch)

        constraint_thermal_limit_from_expansion_on_off(pm, branch)
        constraint_thermal_limit_to_expansion_on_off(pm, branch)
    end
    
    for (i,branch) in pm.set.branches
        if !in(i,pm.data["new_branches"])    
            constraint_active_ohms_yt_expansion(pm, branch)
            constraint_reactive_ohms_yt_expansion(pm, branch)
            constraint_phase_angle_difference_expansion(pm, branch)
            constraint_thermal_limit_from(pm, branch)
            constraint_thermal_limit_to(pm, branch)
        end
    end    
end

function get_expansion_solution{T}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_expansion_setpoint(sol, pm)
    return sol
end

#### Expansion specific variables

## Variables associated with building new lines
function variable_line_expansion{T}(pm::GenericPowerModel{T})
    @variable(pm.model, 0 <= line_exp[l in pm.data["new_branches"]] <= 1, Int, start = getstart(pm.set.branches, l, "line_exp_start", 1.0))
    return line_exp
end

#### Expansion specific objectives

### Cost of building lines
function objective_expansion_cost{T}(pm::GenericPowerModel{T})
    line_exp = getvariable(pm.model, :line_exp)
    return @objective(pm.model, Min, sum{ pm.set.branches[i]["construction_cost"]*line_exp[i], i in pm.data["new_branches"]} )
end

#### Expansion specific constraints

function constraint_active_ohms_yt_expansion{T}(pm::GenericPowerModel{T}, branch)
    return constraint_active_ohms_yt(pm, branch)
end

function constraint_reactive_ohms_yt_expansion{T}(pm::GenericPowerModel{T}, branch)
    return constraint_reactive_ohms_yt(pm, branch)
end

function constraint_phase_angle_difference_expansion{T}(pm::GenericPowerModel{T}, branch)
    return constraint_phase_angle_difference(pm, branch)
end

function constraint_phase_angle_difference_expansion{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.set.buspairs[pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        wr = getvariable(pm.model, :wr)[i]
        wi = getvariable(pm.model, :wi)[i]

        c1 = @constraint(pm.model, wi <= buspair["angmax"]*wr)
        c2 = @constraint(pm.model, wi >= buspair["angmin"]*wr)
        return Set([c1, c2])
    end
    return Set()
end


function constraint_active_ohms_yt_expansion{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_reactive_ohms_yt_expansion{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c1 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end
 

function constraint_active_ohms_yt_expansion_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_exp)[i]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    c1 = @NLconstraint(pm.model, p_fr == z*(g/tm*v_fr^2 + (-g*tr+b*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-b*tr-g*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    c2 = @NLconstraint(pm.model, p_to ==    z*(g*v_to^2 + (-g*tr-b*ti)/tm*(v_to*v_fr*cos(t_to-t_fr)) + (-b*tr+g*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end

function constraint_active_ohms_yt_expansion_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_exp)[i]

    b = branch["b"]
    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

function constraint_active_ohms_yt_expansion_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_exp)[i]

    b = branch["b"]
    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    t_m = max(abs(t_min),abs(t_max))
    c3 = @constraint(pm.model, p_fr + p_to >= branch["br_r"]*( (-branch["b"]*(t_fr - t_to))^2 - (-branch["b"]*(t_m))^2*(1-z) ) )
    return Set([c1, c2, c3])
end

function constraint_active_ohms_yt_expansion_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    w_fr = getvariable(pm.model, :w_from)[i]
    w_to = getvariable(pm.model, :w_to)[i]
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c1 = @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    c2 = @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_reactive_ohms_yt_expansion_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_exp)[i]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2 

    c1 = @NLconstraint(pm.model, q_fr == z*(-(b+c/2)/tm*v_fr^2 - (-b*tr-g*ti)/tm*(v_fr*v_to*cos(t_fr-t_to)) + (-g*tr+b*ti)/tm*(v_fr*v_to*sin(t_fr-t_to))) )
    c2 = @NLconstraint(pm.model, q_to ==    z*(-(b+c/2)*v_to^2 - (-b*tr+g*ti)/tm*(v_to*v_fr*cos(t_fr-t_to)) + (-g*tr-b*ti)/tm*(v_to*v_fr*sin(t_to-t_fr))) )
    return Set([c1, c2])
end

function constraint_reactive_ohms_yt_expansion_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    # Do nothing, this model does not have reactive variables
    return Set()
end

function constraint_reactive_ohms_yt_expansion_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    w_fr = getvariable(pm.model, :w_from)[i]
    w_to = getvariable(pm.model, :w_to)[i]
    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c1 = @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    c2 = @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
    return Set([c1, c2])
end

function constraint_phase_angle_difference_expansion_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_exp)[i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= branch["angmax"])
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= branch["angmin"])
    return Set([c1, c2])
end

function constraint_phase_angle_difference_expansion_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_exp)[i]

    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, t_fr - t_to <= branch["angmax"]*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= branch["angmin"]*z + t_min*(1-z))
    return Set([c1, c2])
end

function constraint_phase_angle_difference_expansion_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]

    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    c1 = @constraint(pm.model, wi <= branch["angmax"]*wr)
    c2 = @constraint(pm.model, wi >= branch["angmin"]*wr)
    return Set([c1, c2])
end

# Generic on/off thermal limit constraint
function constraint_thermal_limit_from_expansion_on_off{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    z = getvariable(pm.model, :line_exp)[i]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2*z^2*scale)
    return Set([c])
end

function constraint_thermal_limit_from_expansion_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    z = getvariable(pm.model, :line_exp)[i]

    c1 = @constraint(pm.model, p_fr <= getupperbound(p_fr)*z)
    c2 = @constraint(pm.model, p_fr >= getlowerbound(p_fr)*z)
    return Set([c1, c2])
end

function constraint_thermal_limit_to_expansion_on_off{T}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p)[t_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    z = getvariable(pm.model, :line_exp)[i]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2*z^2*scale)
    return Set([c])
end

function constraint_thermal_limit_to_expansion_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch; scale = 1.0)
  # nothing to do, from handles both sides
  return Set()
end

function constraint_thermal_limit_to_expansion_on_off{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, branch; scale = 1.0)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p)[t_idx]
    z = getvariable(pm.model, :line_exp)[i]

    c1 = @constraint(pm.model, p_to <= getupperbound(p_to)*z)
    c2 = @constraint(pm.model, p_to >= getlowerbound(p_to)*z)
    return Set([c1, c2])
end

function constraint_complex_voltage_expansion_on_off{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage constraints
    return Set()
end

function constraint_complex_voltage_expansion_on_off{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_complex_voltage_expansion_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.set.branches
    
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm)
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.set.branches])
          
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    z = getvariable(pm.model, :line_exp)

    w_from = getvariable(pm.model, :w_from)
    w_to = getvariable(pm.model, :w_to)

    cs = Set()
    for (l,i,j) in pm.set.arcs_from
        if in(l,pm.data["new_branches"])
            cs = Set()
         
            c1 = @constraint(pm.model, w_from[l] <= z[l]*buses[branches[l]["f_bus"]]["vmax"]^2)
            c2 = @constraint(pm.model, w_from[l] >= z[l]*buses[branches[l]["f_bus"]]["vmin"]^2)
            
            c3 = @constraint(pm.model, wr[l] <= z[l]*wr_max[bi_bp[l]])
            c4 = @constraint(pm.model, wr[l] >= z[l]*wr_min[bi_bp[l]])
            c5 = @constraint(pm.model, wi[l] <= z[l]*wi_max[bi_bp[l]])
            c6 = @constraint(pm.model, wi[l] >= z[l]*wi_min[bi_bp[l]])
              
            c7 = @constraint(pm.model, w_to[l] <= z[l]*buses[branches[l]["t_bus"]]["vmax"]^2)
            c8 = @constraint(pm.model, w_to[l] >= z[l]*buses[branches[l]["t_bus"]]["vmin"]^2)
         
            c9 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
            c10 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
            c11 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
            cs = Set([cs, c1, c2, c3, c4, c5, c6, c7, c8,c9, c10, c11])    
        else
            c = relaxation_complex_product(pm.model, w[i], w[j], wr[l], wi[l])
            cs = Set([cs, c])   
        end
    end
    return cs
end

##### Expansion specific solution extractors
function add_branch_expansion_setpoint{T}(sol, pm::GenericPowerModel{T})
  add_setpoint(sol, pm, "branch", "index", "built", :line_exp; default_value = (item) -> 1)
end

#### create some expansion specific sets
function build_expansion_sets{T}(pm::GenericPowerModel{T})
    new_branches       = collect(keys(filter((i, branch) -> haskey(branch, "construction_cost"), pm.set.branches))) 
    pm.data["new_branches"] = new_branches
end


