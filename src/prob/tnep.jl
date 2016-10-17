#### General Assumptions of these TNEP Models ####
#
#

export run_tnep

function run_tnep(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_tnep; data_processor = process_raw_mp_ne_data, solution_builder = get_tnep_solution, kwargs...) 
end

# the general form of the tnep optimization model
function post_tnep{T}(pm::GenericPowerModel{T})
    variable_line_ne(pm) 

    variable_complex_voltage(pm)
    variable_complex_voltage_ne(pm)

    variable_active_generation(pm)
    variable_reactive_generation(pm)

    variable_active_line_flow(pm)
    variable_active_line_flow_ne(pm)
    variable_reactive_line_flow(pm)
    variable_reactive_line_flow_ne(pm)

    objective_tnep_cost(pm)
       
    constraint_theta_ref(pm)

    constraint_complex_voltage(pm)
    constraint_complex_voltage_ne(pm)

    for (i,bus) in pm.set.buses
        constraint_active_kcl_shunt_ne(pm, bus)
        constraint_reactive_kcl_shunt_ne(pm, bus)
    end
    
    for (i,branch) in pm.ext[:ne].branches
        constraint_active_ohms_yt_ne(pm, branch)
        constraint_reactive_ohms_yt_ne(pm, branch) 

        constraint_phase_angle_difference_ne(pm, branch)
        constraint_thermal_limit_from_ne(pm, branch)
        constraint_thermal_limit_to_ne(pm, branch)
    end
        
    for (i,branch) in pm.set.branches
        constraint_active_ohms_yt(pm, branch)
        constraint_reactive_ohms_yt(pm, branch)

        constraint_phase_angle_difference(pm, branch)
        constraint_thermal_limit_from(pm, branch)
        constraint_thermal_limit_to(pm, branch)
    end  
end



##### TNEP specific base and solution code

type TNEPDataSets
    branches
    branch_indexes
    arcs_from
    arcs_to
    arcs
    bus_branches
    buspairs
    buspair_indexes
end

#### create some tnep specific sets
function build_ne_sets(data::Dict{AbstractString,Any})    
    bus_lookup = Dict([(Int(bus["index"]), bus) for bus in data["bus"]])
    branch_lookup = Dict([(Int(branch["index"]), branch) for branch in data["branch_ne"]])

    # filter turned off stuff
    bus_lookup = filter((i, bus) -> bus["bus_type"] != 4, bus_lookup)
    branch_lookup = filter((i, branch) -> branch["br_status"] == 1 && branch["f_bus"] in keys(bus_lookup) && branch["t_bus"] in keys(bus_lookup), branch_lookup)

    arcs_from = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in branch_lookup]
    arcs_to   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in branch_lookup]
    arcs = [arcs_from; arcs_to]

    bus_branches = Dict([(i, []) for (i,bus) in bus_lookup])
    for (l,i,j) in arcs_from
        push!(bus_branches[i], (l,i,j))
        push!(bus_branches[j], (l,j,i))
    end

    bus_idxs = collect(keys(bus_lookup))
    #gen_idxs = collect(keys(gen_lookup))
    branch_idxs = collect(keys(branch_lookup))

    buspair_indexes = collect(Set([(i,j) for (l,i,j) in arcs_from]))
    buspairs = buspair_parameters(buspair_indexes, branch_lookup, bus_lookup)

    return TNEPDataSets(branch_lookup, branch_idxs, arcs_from, arcs_to, arcs, bus_branches, buspairs, buspair_indexes)
end

function process_raw_mp_ne_data(data::Dict{AbstractString,Any})
    # TODO, see if there is a clean way of reusing 'process_raw_mp_data'
    # would be fine, except for on/off phase angle calc
    make_per_unit(data)

    min_theta_delta = calc_min_phase_angle_ne(data)
    max_theta_delta = calc_max_phase_angle_ne(data)

    unify_transformer_taps(data["branch"])
    add_branch_parameters(data["branch"], min_theta_delta, max_theta_delta)

    unify_transformer_taps(data["branch_ne"])
    add_branch_parameters(data["branch_ne"], min_theta_delta, max_theta_delta)

    standardize_cost_order(data)
    sets = build_sets(data)
    ne_sets = build_ne_sets(data)

    ext = Dict{Symbol,Any}()
    ext[:ne] = ne_sets

    return data, sets, ext
end

function calc_max_phase_angle_ne(data::Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    angle_max = [branch["angmax"] for branch in data["branch"]]
    if haskey(data, "branch_ne")
        angle_max_ne = [branch["angmax"] for branch in data["branch_ne"]]
        angle_max = [angle_max; angle_max_ne]
    end
    sort!(angle_max, rev=true)
    if length(angle_max) > 1
        return sum(angle_max[1:bus_count-1])
    end
    return angle_max[1]
end

function calc_min_phase_angle_ne(data::Dict{AbstractString,Any})
    bus_count = length(data["bus"])
    angle_min = [branch["angmin"] for branch in data["branch"]]
    if haskey(data, "branch_ne")
        angle_min_ne = [branch["angmin"] for branch in data["branch_ne"]]
        angle_min = [angle_min; angle_min_ne]
    end
    sort!(angle_min)
    if length(angle_min) > 1
        return sum(angle_min[1:bus_count-1])
    end
    return angle_min[1]
end

function get_tnep_solution{T}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_flow_setpoint_ne(sol, pm)    
    add_branch_ne_setpoint(sol, pm)
    return sol
end

function add_branch_ne_setpoint{T}(sol, pm::GenericPowerModel{T})
  add_setpoint(sol, pm, "branch_ne", "index", "built", :line_ne; default_value = (item) -> 1)
end

function add_branch_flow_setpoint_ne{T}(sol, pm::GenericPowerModel{T})
    # check the line flows were requested
    if haskey(pm.setting, "output") && haskey(pm.setting["output"], "line_flows") && pm.setting["output"]["line_flows"] == true
        mva_base = pm.data["baseMVA"]

        add_setpoint(sol, pm, "branch_ne", "index", "p_from", :p_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch_ne", "index", "q_from", :q_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["f_bus"], item["t_bus"])])
        add_setpoint(sol, pm, "branch_ne", "index",   "p_to", :p_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
        add_setpoint(sol, pm, "branch_ne", "index",   "q_to", :q_ne; scale = (x,item) -> x*mva_base, extract_var = (var,idx,item) -> var[(idx, item["t_bus"], item["f_bus"])])
    end
end


#### TNEP specific variables

## Variables associated with building new lines
function variable_line_ne{T}(pm::GenericPowerModel{T})
    branches = pm.ext[:ne].branches
    @variable(pm.model, 0 <= line_ne[l in pm.ext[:ne].branch_indexes] <= 1, Int, start = getstart(branches, l, "line_tnep_start", 1.0))
    return line_ne
end

function variable_complex_voltage_ne{T}(pm::GenericPowerModel{T}; kwargs...)
end

function variable_complex_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr_from_ne(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm; kwargs...)
    variable_complex_voltage_product_ne(pm; kwargs...)
end


function variable_voltage_magnitude_sqr_from_ne{T}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.ext[:ne].branches
    @variable(pm.model, 0 <= w_from_ne[i in pm.ext[:ne].branch_indexes] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.set.buses, i, "w_from_start", 1.001))
    return w_from_ne
end

function variable_voltage_magnitude_sqr_to_ne{T}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.ext[:ne].branches
    @variable(pm.model, 0 <= w_to_ne[i in pm.ext[:ne].branch_indexes] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.set.buses, i, "w_to", 1.001))
    return w_to_ne
end

function variable_complex_voltage_product_ne{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ext[:ne].buspairs, pm.ext[:ne].buspair_indexes)
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ext[:ne].branches])
    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr_ne[b in pm.ext[:ne].branch_indexes] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ext[:ne].buspairs, bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi_ne[b in pm.ext[:ne].branch_indexes] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ext[:ne].buspairs, bi_bp[b], "wi_start"))
    return wr_ne, wi_ne
end

function variable_active_line_flow_ne{T}(pm::GenericPowerModel{T})
    @variable(pm.model, -pm.ext[:ne].branches[l]["rate_a"] <= p_ne[(l,i,j) in pm.ext[:ne].arcs] <= pm.ext[:ne].branches[l]["rate_a"], start = getstart(pm.ext[:ne].branches, l, "p_start"))
    return p_ne
end

function variable_active_line_flow_ne{T <: StandardDCPForm}(pm::GenericPowerModel{T})
    @variable(pm.model, -pm.ext[:ne].branches[l]["rate_a"] <= p_ne[(l,i,j) in pm.ext[:ne].arcs_from] <= pm.ext[:ne].branches[l]["rate_a"], start = getstart(pm.ext[:ne].branches, l, "p_start"))
 
    p_ne_expr = Dict([((l,i,j), 1.0*p_ne[(l,i,j)]) for (l,i,j) in pm.ext[:ne].arcs_from])
    p_ne_expr = merge(p_ne_expr, Dict([((l,j,i), -1.0*p_ne[(l,i,j)]) for (l,i,j) in pm.ext[:ne].arcs_from]))

    pm.model.ext[:p_ne_expr] = p_ne_expr
end

function variable_reactive_line_flow_ne{T}(pm::GenericPowerModel{T})
    @variable(pm.model, -pm.ext[:ne].branches[l]["rate_a"] <= q_ne[(l,i,j) in pm.ext[:ne].arcs] <= pm.ext[:ne].branches[l]["rate_a"], start = getstart(pm.ext[:ne].branches, l, "q_start"))
    return q_ne
end

function variable_reactive_line_flow_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}; bounded = true)
    # do nothing, this model does not have reactive variables
end


#### TNEP specific objectives

### Cost of building lines
function objective_tnep_cost{T}(pm::GenericPowerModel{T})
    line_ne = getvariable(pm.model, :line_ne)
    branches = pm.ext[:ne].branches
    return @objective(pm.model, Min, sum{ branches[i]["construction_cost"]*line_ne[i], (i,branch) in branches} )
end


#### TNEP specific constraints

function constraint_active_ohms_yt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

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

function constraint_active_ohms_yt_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    b = branch["b"]
    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )
    return Set([c1, c2])
end

function constraint_active_ohms_yt_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    b = branch["b"]
    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, p_fr <= -b*(t_fr - t_to + t_max*(1-z)) )
    c2 = @constraint(pm.model, p_fr >= -b*(t_fr - t_to + t_min*(1-z)) )

    t_m = max(abs(t_min),abs(t_max))
    c3 = @constraint(pm.model, p_fr + p_to >= branch["br_r"]*( (-branch["b"]*(t_fr - t_to))^2 - (-branch["b"]*(t_m))^2*(1-z) ) )
    return Set([c1, c2, c3])
end

function constraint_active_ohms_yt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    p_to = getvariable(pm.model, :p_ne)[t_idx]
    w_fr = getvariable(pm.model, :w_from_ne)[i]
    w_to = getvariable(pm.model, :w_to_ne)[i]
    wr = getvariable(pm.model, :wr_ne)[i]
    wi = getvariable(pm.model, :wi_ne)[i]

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

function constraint_reactive_ohms_yt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    v_fr = getvariable(pm.model, :v)[f_bus]
    v_to = getvariable(pm.model, :v)[t_bus]
    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

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

function constraint_reactive_ohms_yt_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    # Do nothing, this model does not have reactive variables
    return Set()
end

function constraint_reactive_ohms_yt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    w_fr = getvariable(pm.model, :w_from_ne)[i]
    w_to = getvariable(pm.model, :w_to_ne)[i]
    wr = getvariable(pm.model, :wr_ne)[i]
    wi = getvariable(pm.model, :wi_ne)[i]

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

function constraint_phase_angle_difference_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, z*(t_fr - t_to) <= branch["angmax"])
    c2 = @constraint(pm.model, z*(t_fr - t_to) >= branch["angmin"])
    return Set([c1, c2])
end

function constraint_phase_angle_difference_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    t_fr = getvariable(pm.model, :t)[f_bus]
    t_to = getvariable(pm.model, :t)[t_bus]
    z = getvariable(pm.model, :line_ne)[i]

    t_min = branch["off_angmin"]
    t_max = branch["off_angmax"]

    c1 = @constraint(pm.model, t_fr - t_to <= branch["angmax"]*z + t_max*(1-z))
    c2 = @constraint(pm.model, t_fr - t_to >= branch["angmin"]*z + t_min*(1-z))
    return Set([c1, c2])
end

function constraint_phase_angle_difference_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]

    wr = getvariable(pm.model, :wr_ne)[i]
    wi = getvariable(pm.model, :wi_ne)[i]

    c1 = @constraint(pm.model, wi <= branch["angmax"]*wr)
    c2 = @constraint(pm.model, wi >= branch["angmin"]*wr)
    return Set([c1, c2])
end

# Generic on/off thermal limit constraint
function constraint_thermal_limit_from_ne{T}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    q_fr = getvariable(pm.model, :q_ne)[f_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2*z^2)
    return Set([c])
end

function constraint_thermal_limit_from_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    p_fr = getvariable(pm.model, :p_ne)[f_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, p_fr <= getupperbound(p_fr)*z)
    c2 = @constraint(pm.model, p_fr >= getlowerbound(p_fr)*z)
    return Set([c1, c2])
end

function constraint_thermal_limit_to_ne{T}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p_ne)[t_idx]
    q_to = getvariable(pm.model, :q_ne)[t_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c = @constraint(pm.model, p_to^2 + q_to^2 <= branch["rate_a"]^2*z^2)
    return Set([c])
end

function constraint_thermal_limit_to_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, branch)
  # nothing to do, from handles both sides
  return Set()
end

function constraint_thermal_limit_to_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    p_to = getvariable(pm.model, :p_ne)[t_idx]
    z = getvariable(pm.model, :line_ne)[i]

    c1 = @constraint(pm.model, p_to <= getupperbound(p_to)*z)
    c2 = @constraint(pm.model, p_to >= getlowerbound(p_to)*z)
    return Set([c1, c2])
end

function constraint_complex_voltage_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage constraints
    return Set()
end

function constraint_complex_voltage_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T})
    # do nothing, this model does not have complex voltage variables
end

function constraint_complex_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.ext[:ne].branches
    
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ext[:ne].buspairs, pm.ext[:ne].buspair_indexes)
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in branches])
          
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr_ne)
    wi = getvariable(pm.model, :wi_ne)
    z = getvariable(pm.model, :line_ne)

    w_from = getvariable(pm.model, :w_from_ne)
    w_to = getvariable(pm.model, :w_to_ne)

    cs = Set()
    for (l,i,j) in pm.ext[:ne].arcs_from
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
    end
    return cs
end

function constraint_active_kcl_shunt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_branches_ne = pm.ext[:ne].bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    v = getvariable(pm.model, :v)
    p = getvariable(pm.model, :p)
    p_ne = getvariable(pm.model, :p_ne)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum{p[a], a in bus_branches} + sum{p_ne[a], a in bus_branches_ne} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*v[i]^2)
    return Set([c])
end

function constraint_active_kcl_shunt_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_branches_ne = pm.ext[:ne].bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    pg = getvariable(pm.model, :pg)
    p_expr = pm.model.ext[:p_expr]
    p_ne_expr = pm.model.ext[:p_ne_expr]

    c = @constraint(pm.model, sum{p_expr[a], a in bus_branches} + sum{p_ne_expr[a], a in bus_branches_ne} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*1.0^2)
    return Set([c])
end

function constraint_active_kcl_shunt_ne{T <: AbstractDCPLLForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_branches_ne = pm.ext[:ne].bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    p = getvariable(pm.model, :p)
    p_ne = getvariable(pm.model, :p_ne)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum{p[a], a in bus_branches} + sum{p_ne[a], a in bus_branches_ne} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*1.0^2)
    return Set([c])
end

function constraint_active_kcl_shunt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_branches_ne = pm.ext[:ne].bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    p = getvariable(pm.model, :p)
    p_ne = getvariable(pm.model, :p_ne)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum{p[a], a in bus_branches} + sum{p_ne[a], a in bus_branches_ne} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*w[i])
    return Set([c])
end

function constraint_reactive_kcl_shunt_ne{T <: AbstractACPForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_branches_ne = pm.ext[:ne].bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    v = getvariable(pm.model, :v)
    q = getvariable(pm.model, :q)
    q_ne = getvariable(pm.model, :q_ne)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum{q[a], a in bus_branches} + sum{q_ne[a], a in bus_branches_ne} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*v[i]^2)
    return Set([c])
end

function constraint_reactive_kcl_shunt_ne{T <: AbstractDCPForm}(pm::GenericPowerModel{T}, bus)
    # Do nothing, this model does not have reactive variables
    return Set()
end

function constraint_reactive_kcl_shunt_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_branches_ne = pm.ext[:ne].bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    q = getvariable(pm.model, :q)
    q_ne = getvariable(pm.model, :q_ne)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum{q[a], a in bus_branches} + sum{q_ne[a], a in bus_branches_ne} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*w[i])
    return Set([c])
end




