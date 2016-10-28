export
    SOCWRPowerModel, SOCWRForm,
    QCWRPowerModel, QCWRForm

abstract AbstractWRForm <: AbstractPowerFormulation

type SOCWRForm <: AbstractWRForm end
typealias SOCWRPowerModel GenericPowerModel{SOCWRForm}

# default SOC constructor
function SOCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, SOCWRForm(); kwargs...)
end

function variable_complex_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_complex_voltage_product(pm; kwargs...)
end

function constraint_complex_voltage{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)

    for (i,j) in pm.set.buspair_indexes
        relaxation_complex_product(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end

function constraint_theta_ref{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    # Do nothing, no way to represent this in these variables
    return Set()
end

function constraint_voltage_magnitude_setpoint{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus; epsilon = 0.0)
    i = bus["index"]
    w = getvariable(pm.model, :w)[i]

    if epsilon == 0.0
        c = @constraint(pm.model, w == bus["vm"]^2)
        return Set([c])
    else
        @assert epsilon > 0.0
        c1 = @constraint(pm.model, w <= bus["vm"]^2 + epsilon)
        c2 = @constraint(pm.model, w >= bus["vm"]^2 - epsilon)
        return Set([c1, c2])
    end
end

function constraint_active_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    c = @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*w[i])
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

function constraint_reactive_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    c = @constraint(pm.model, sum{q[a], a in bus_branches} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*w[i])
    return Set([c])
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


# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p_fr = getvariable(pm.model, :p)[f_idx]
    p_to = getvariable(pm.model, :p)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

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


function constraint_reactive_ohms_yt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    q_fr = getvariable(pm.model, :q)[f_idx]
    q_to = getvariable(pm.model, :q)[t_idx]
    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    wr = getvariable(pm.model, :wr)[(f_bus, t_bus)]
    wi = getvariable(pm.model, :wi)[(f_bus, t_bus)]

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

function constraint_phase_angle_difference{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.set.buspairs[pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        wr = getvariable(pm.model, :wr)[pair]
        wi = getvariable(pm.model, :wi)[pair]

        c1 = @constraint(pm.model, wi <= buspair["angmax"]*wr)
        c2 = @constraint(pm.model, wi >= buspair["angmin"]*wr)
        return Set([c1, c2])
    end
    return Set()
end


function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end




function variable_complex_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_voltage_magnitude_sqr_from_on_off(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_on_off(pm; kwargs...)

    variable_complex_voltage_product_on_off(pm; kwargs...)
end

function constraint_complex_voltage_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    z = getvariable(pm.model, :line_z)

    w_from = getvariable(pm.model, :w_from)
    w_to = getvariable(pm.model, :w_to)

    cs = Set()
    cs1 = constraint_voltage_magnitude_sqr_from_on_off(pm)
    cs2 = constraint_voltage_magnitude_sqr_to_on_off(pm)
    cs3 = constraint_complex_voltage_product_on_off(pm)
    cs = union(cs, cs1, cs2, cs3)

    for (l,i,j) in pm.set.arcs_from
        cs4 = relaxation_complex_product_on_off(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        cs5 = relaxation_equality_on_off(pm.model, w[i], w_from[l], z[l])
        cs6 = relaxation_equality_on_off(pm.model, w[j], w_to[l], z[l])
        cs = union(cs, cs4, cs5, cs6)
    end

    return cs
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


function constraint_voltage_magnitude_sqr_from_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.set.branches

    w_from = getvariable(pm.model, :w_from)
    z = getvariable(pm.model, :line_z)

    cs = Set()
    for i in pm.set.branch_indexes
        c1 = @constraint(pm.model, w_from[i] <= z[i]*buses[branches[i]["f_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_from[i] >= z[i]*buses[branches[i]["f_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

function constraint_voltage_magnitude_sqr_to_on_off{T}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.set.branches

    w_to = getvariable(pm.model, :w_to)
    z = getvariable(pm.model, :line_z)

    cs = Set()
    for i in pm.set.branch_indexes
        c1 = @constraint(pm.model, w_to[i] <= z[i]*buses[branches[i]["t_bus"]]["vmax"]^2)
        c2 = @constraint(pm.model, w_to[i] >= z[i]*buses[branches[i]["t_bus"]]["vmin"]^2)
        push!(cs, c1)
        push!(cs, c2)
    end
    return cs
end

function constraint_complex_voltage_product_on_off{T}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.set.buspairs, pm.set.buspair_indexes)

    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.set.branches])

    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    z = getvariable(pm.model, :line_z)

    cs = Set()
    for b in pm.set.branch_indexes
        c1 = @constraint(pm.model, wr[b] <= z[b]*wr_max[bi_bp[b]])
        c2 = @constraint(pm.model, wr[b] >= z[b]*wr_min[bi_bp[b]])
        c3 = @constraint(pm.model, wi[b] <= z[b]*wi_max[bi_bp[b]])
        c4 = @constraint(pm.model, wi[b] >= z[b]*wi_min[bi_bp[b]])
        push!(cs, c1)
        push!(cs, c2)
        push!(cs, c3)
        push!(cs, c4)
    end
    return cs
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
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

function constraint_reactive_ohms_yt_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
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

function constraint_phase_angle_difference_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]

    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    c1 = @constraint(pm.model, wi <= branch["angmax"]*wr)
    c2 = @constraint(pm.model, wi >= branch["angmin"]*wr)
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



function variable_complex_voltage_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T}; kwargs...)
    variable_voltage_magnitude_sqr_from_ne(pm; kwargs...)
    variable_voltage_magnitude_sqr_to_ne(pm; kwargs...)
    variable_complex_voltage_product_ne(pm; kwargs...)
end

function variable_voltage_magnitude_sqr_from_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.ext[:ne].branches
    @variable(pm.model, 0 <= w_from_ne[i in pm.ext[:ne].branch_indexes] <= buses[branches[i]["f_bus"]]["vmax"]^2, start = getstart(pm.set.buses, i, "w_from_start", 1.001))
    return w_from_ne
end

function variable_voltage_magnitude_sqr_to_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    buses = pm.set.buses
    branches = pm.ext[:ne].branches
    @variable(pm.model, 0 <= w_to_ne[i in pm.ext[:ne].branch_indexes] <= buses[branches[i]["t_bus"]]["vmax"]^2, start = getstart(pm.set.buses, i, "w_to", 1.001))
    return w_to_ne
end

function variable_complex_voltage_product_ne{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    wr_min, wr_max, wi_min, wi_max = compute_voltage_product_bounds(pm.ext[:ne].buspairs, pm.ext[:ne].buspair_indexes)
    bi_bp = Dict([(i, (b["f_bus"], b["t_bus"])) for (i,b) in pm.ext[:ne].branches])
    @variable(pm.model, min(0, wr_min[bi_bp[b]]) <= wr_ne[b in pm.ext[:ne].branch_indexes] <= max(0, wr_max[bi_bp[b]]), start = getstart(pm.ext[:ne].buspairs, bi_bp[b], "wr_start", 1.0))
    @variable(pm.model, min(0, wi_min[bi_bp[b]]) <= wi_ne[b in pm.ext[:ne].branch_indexes] <= max(0, wi_max[bi_bp[b]]), start = getstart(pm.ext[:ne].buspairs, bi_bp[b], "wi_start"))
    return wr_ne, wi_ne
end






type QCWRForm <: AbstractWRForm end
typealias QCWRPowerModel GenericPowerModel{QCWRForm}

# default QC constructor
function QCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, QCWRForm(); kwargs...)
end

function variable_complex_voltage(pm::QCWRPowerModel; kwargs...)
    variable_phase_angle(pm; kwargs...)
    variable_voltage_magnitude(pm; kwargs...)

    variable_voltage_magnitude_sqr(pm; kwargs...)
    variable_complex_voltage_product(pm; kwargs...)

    variable_phase_angle_difference(pm; kwargs...)
    variable_voltage_magnitude_product(pm; kwargs...)
    variable_cosine(pm; kwargs...)
    variable_sine(pm; kwargs...)
    variable_current_magnitude_sqr(pm; kwargs...)
end

function constraint_complex_voltage(pm::QCWRPowerModel)
    v = getvariable(pm.model, :v)
    t = getvariable(pm.model, :t)

    td = getvariable(pm.model, :td)
    si = getvariable(pm.model, :si)
    cs = getvariable(pm.model, :cs)
    vv = getvariable(pm.model, :vv)

    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)

    const_set = Set()
    for (i,b) in pm.set.buses
        cs1 = relaxation_sqr(pm.model, v[i], w[i])
        const_set = union(const_set, cs1)
    end

    for bp in pm.set.buspair_indexes
        i,j = bp
        c1 = @constraint(pm.model, t[i] - t[j] == td[bp])
        push!(const_set, c1)

        cs1 = relaxation_sin(pm.model, td[bp], si[bp])
        cs2 = relaxation_cos(pm.model, td[bp], cs[bp])
        cs3 = relaxation_product(pm.model, v[i], v[j], vv[bp])
        cs4 = relaxation_product(pm.model, vv[bp], cs[bp], wr[bp])
        cs5 = relaxation_product(pm.model, vv[bp], si[bp], wi[bp])

        const_set = union(const_set, cs1, cs2, cs3, cs4, cs5)
        # this constraint is redudant and useful for debugging
        #relaxation_complex_product(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in pm.set.branches
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = pm.set.buspairs[pair]

        # to prevent this constraint from being posted on multiple parallel lines
        if buspair["line"] == i
            cs1 = constraint_power_magnitude_sqr(pm, branch)
            cs2 = constraint_power_magnitude_link(pm, branch)
            const_set = union(const_set, cs1, cs2)
        end
    end

    return const_set
end




function constraint_power_magnitude_sqr(pm::QCWRPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    f_idx = (i, f_bus, t_bus)

    w_i = getvariable(pm.model, :w)[f_bus]
    p_fr = getvariable(pm.model, :p)[f_idx]
    q_fr = getvariable(pm.model, :q)[f_idx]
    cm = getvariable(pm.model, :cm)[pair]

    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c = @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm*cm)
    return Set([c])
end

function constraint_power_magnitude_link(pm::QCWRPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    f_idx = (i, f_bus, t_bus)

    w_fr = getvariable(pm.model, :w)[f_bus]
    w_to = getvariable(pm.model, :w)[t_bus]
    q_fr = getvariable(pm.model, :q)[f_idx]
    wr = getvariable(pm.model, :wr)[pair]
    wi = getvariable(pm.model, :wi)[pair]
    cm = getvariable(pm.model, :cm)[pair]

    g = branch["g"]
    b = branch["b"]
    c = branch["br_b"]
    tr = branch["tr"]
    ti = branch["ti"]
    tm = tr^2 + ti^2

    c = @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
    return Set([c])
end


function constraint_theta_ref(pm::QCWRPowerModel)
    @constraint(pm.model, getvariable(pm.model, :t)[pm.set.ref_bus] == 0)
end

function constraint_phase_angle_difference(pm::QCWRPowerModel, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.set.buspairs[pair]

    td = getvariable(pm.model, :td)[pair]

    if getlowerbound(td) < branch["angmin"]
        setlowerbound(td, branch["angmin"])
    end

    if getupperbound(td) > branch["angmax"]
        setupperbound(td, branch["angmax"])
    end

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        wr = getvariable(pm.model, :wr)[pair]
        wi = getvariable(pm.model, :wi)[pair]

        c1 = @constraint(pm.model, wi <= buspair["angmax"]*wr)
        c2 = @constraint(pm.model, wi >= buspair["angmin"]*wr)
        return Set([c1, c2])
    end
    return Set()
end

function add_bus_voltage_setpoint(sol, pm::QCWRPowerModel)
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end
