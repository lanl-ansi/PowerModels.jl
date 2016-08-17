export 
    SOCWRPowerModel, SOCWRForm,
    LSSOCWRPowerModel, LSSOCWRForm,
    QCWRPowerModel, QCWRForm

abstract AbstractWRForm <: AbstractPowerFormulation

type SOCWRForm <: AbstractWRForm end
typealias SOCWRPowerModel GenericPowerModel{SOCWRForm}

# default SOC constructor
function SOCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, SOCWRForm(); kwargs...)
end

function init_vars{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    voltage_magnitude_sqr_variables(pm)
    complex_voltage_product_variables(pm)

    active_generation_variables(pm)
    reactive_generation_variables(pm)

    active_line_flow_variables(pm)
    reactive_line_flow_variables(pm)
end

function free_bounded_variables{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    for (i,bus) in pm.set.buses
        w = getvariable(pm.model, :w)[i]
        setupperbound(w, Inf)
        setlowerbound(w, 0)
    end
    for (i,j) in pm.set.buspair_indexes
        wr = getvariable(pm.model, :wr)[(i,j)]
        setupperbound(wr,  Inf)
        setlowerbound(wr, -Inf)
        wi = getvariable(pm.model, :wi)[(i,j)]
        setupperbound(wi,  Inf)
        setlowerbound(wi, -Inf)
    end
    for (i,gen) in pm.set.gens
        pg = getvariable(pm.model, :pg)[i]
        setupperbound(pg,  Inf)
        setlowerbound(pg, -Inf)
        qg = getvariable(pm.model, :pg)[i]
        setupperbound(pg,  Inf)
        setlowerbound(pg, -Inf)
    end
    for arc in pm.set.arcs
        p = getvariable(pm.model, :p)[arc]
        setupperbound(p,  Inf)
        setlowerbound(p, -Inf)
        q = getvariable(pm.model, :p)[arc]
        setupperbound(q,  Inf)
        setlowerbound(q, -Inf)
    end
end

function constraint_universal(pm::SOCWRPowerModel)
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    
    for (i,j) in pm.set.buspair_indexes
        complex_product_relaxation(pm.model, w[i], w[j], wr[(i,j)], wi[(i,j)])
    end
end


function constraint_theta_ref{T <: AbstractWRForm}(pm::GenericPowerModel{T})
    # Do nothing, no way to represent this in these variables
end

function constraint_voltage_magnitude_setpoint{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus; epsilon = 0.0)
    i = bus["index"]
    w = getvariable(pm.model, :w)[i]

    if epsilon == 0.0
        @constraint(pm.model, w == bus["vm"]^2)
    else
        @assert epsilon > 0.0
        @constraint(pm.model, w <= bus["vm"]^2 + epsilon)
        @constraint(pm.model, w >= bus["vm"]^2 - epsilon)
    end
end

function constraint_active_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    p = getvariable(pm.model, :p)
    pg = getvariable(pm.model, :pg)

    @constraint(pm.model, sum{p[a], a in bus_branches} == sum{pg[g], g in bus_gens} - bus["pd"] - bus["gs"]*w[i])
end

function constraint_reactive_kcl_shunt{T <: AbstractWRForm}(pm::GenericPowerModel{T}, bus)
    i = bus["index"]
    bus_branches = pm.set.bus_branches[i]
    bus_gens = pm.set.bus_gens[i]

    w = getvariable(pm.model, :w)
    q = getvariable(pm.model, :q)
    qg = getvariable(pm.model, :qg)

    @constraint(pm.model, sum{q[a], a in bus_branches} == sum{qg[g], g in bus_gens} - bus["qd"] + bus["bs"]*w[i])
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

    @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
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

    @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

function constraint_phase_angle_diffrence{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    pair = (f_bus, t_bus)
    buspair = pm.set.buspairs[pair]

    # to prevent this constraint from being posted on multiple parallel lines
    if buspair["line"] == i
        wr = getvariable(pm.model, :wr)[pair]
        wi = getvariable(pm.model, :wi)[pair]

        @constraint(pm.model, wi <= buspair["angmax"]*wr)
        @constraint(pm.model, wi >= buspair["angmin"]*wr)
    end
end


function add_bus_voltage_setpoint{T <: AbstractWRForm}(sol, pm::GenericPowerModel{T})
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :w; scale = (x,item) -> sqrt(x))
    # What should the default value be?
    #add_setpoint(sol, pm, "bus", "bus_i", "va", :t; default_value = 0)
end




abstract AbstractLSWRPForm <: AbstractWRForm

type LSSOCWRForm <: AbstractLSWRPForm end
typealias LSSOCWRPowerModel GenericPowerModel{LSSOCWRForm}

# default AC constructor
function LSSOCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, LSSOCWRForm(); kwargs...)
end

function init_vars{T <: AbstractLSWRPForm}(pm::GenericPowerModel{T})
    # super method
    voltage_magnitude_sqr_variables(pm)
    #complex_voltage_product_variables(pm)

    active_generation_variables(pm)
    reactive_generation_variables(pm)

    active_line_flow_variables(pm)
    reactive_line_flow_variables(pm)

    # extentions
    line_indicator_variables(pm)

    voltage_magnitude_sqr_from_on_off_variables(pm)
    voltage_magnitude_sqr_to_on_off_variables(pm)

    complex_voltage_product_on_off_variables(pm)
end

function constraint_universal(pm::LSSOCWRPowerModel)
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    z = getvariable(pm.model, :line_z)
    
    w_from = getvariable(pm.model, :w_from)
    w_to = getvariable(pm.model, :w_to)

    for (l,i,j) in pm.set.arcs_from
        complex_product_on_off_relaxation(pm.model, w[i], w[j], wr[l], wi[l], z[l])
        equality_on_off_relaxation(pm.model, w[i], w_from[l], z[l])
        equality_on_off_relaxation(pm.model, w[j], w_to[l], z[l])
    end
end

# Creates Ohms constraints (yt post fix indicates that Y and T values are in rectangular form)
function constraint_active_ohms_yt_on_off{T <: AbstractLSWRPForm}(pm::GenericPowerModel{T}, branch)
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

    @constraint(pm.model, p_fr == g/tm*w_fr + (-g*tr+b*ti)/tm*(wr) + (-b*tr-g*ti)/tm*( wi) )
    @constraint(pm.model, p_to ==    g*w_to + (-g*tr-b*ti)/tm*(wr) + (-b*tr+g*ti)/tm*(-wi) )
end

function constraint_reactive_ohms_yt_on_off{T <: AbstractLSWRPForm}(pm::GenericPowerModel{T}, branch)
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

    @constraint(pm.model, q_fr == -(b+c/2)/tm*w_fr - (-b*tr-g*ti)/tm*(wr) + (-g*tr+b*ti)/tm*( wi) )
    @constraint(pm.model, q_to ==    -(b+c/2)*w_to - (-b*tr+g*ti)/tm*(wr) + (-g*tr-b*ti)/tm*(-wi) )
end

function constraint_phase_angle_diffrence_on_off{T <: AbstractWRForm}(pm::GenericPowerModel{T}, branch)
    i = branch["index"]

    wr = getvariable(pm.model, :wr)[i]
    wi = getvariable(pm.model, :wi)[i]

    @constraint(pm.model, wi <= branch["angmax"]*wr)
    @constraint(pm.model, wi >= branch["angmin"]*wr)
end

function getsolution{T <: AbstractLSWRPForm}(pm::GenericPowerModel{T})
    sol = Dict{AbstractString,Any}()
    add_bus_voltage_setpoint(sol, pm)
    add_generator_power_setpoint(sol, pm)
    add_branch_flow_setpoint(sol, pm)
    add_branch_status_setpoint(sol, pm)
    return sol
end







type QCWRForm <: AbstractWRForm end
typealias QCWRPowerModel GenericPowerModel{QCWRForm}

# default QC constructor
function QCWRPowerModel(data::Dict{AbstractString,Any}; kwargs...)
    return GenericPowerModel(data, QCWRForm(); kwargs...)
end

function init_vars(pm::QCWRPowerModel)
    # TODO seem if calling the more abstract method is possible
    # Discussion here https://github.com/JuliaLang/julia/pull/13123
    #invoke(init_vars, Tuple{GenericPowerModel{T<:super(QCWRForm)}}, pm)
    
    # super method
    phase_angle_variables(pm)
    voltage_magnitude_variables(pm)

    voltage_magnitude_sqr_variables(pm)
    complex_voltage_product_variables(pm)

    active_generation_variables(pm)
    reactive_generation_variables(pm)

    active_line_flow_variables(pm)
    reactive_line_flow_variables(pm)

    # extentions
    phase_angle_diffrence_variables(pm)
    voltage_magnitude_product_variables(pm)
    cosine_variables(pm)
    sine_variables(pm)
    current_magnitude_sqr_variables(pm)
end

function constraint_universal(pm::QCWRPowerModel)
    v = getvariable(pm.model, :v)
    t = getvariable(pm.model, :t)

    td = getvariable(pm.model, :td)
    si = getvariable(pm.model, :si)
    cs = getvariable(pm.model, :cs)
    vv = getvariable(pm.model, :vv)
    
    w = getvariable(pm.model, :w)
    wr = getvariable(pm.model, :wr)
    wi = getvariable(pm.model, :wi)
    
    for (i,b) in pm.set.buses
        sqr_relaxation(pm.model, v[i], w[i])
    end

    for bp in pm.set.buspair_indexes
        i,j = bp
        @constraint(pm.model, t[i] - t[j] == td[bp])

        sin_relaxation(pm.model, td[bp], si[bp])
        cos_relaxation(pm.model, td[bp], cs[bp])
        product_relaxation(pm.model, v[i], v[j], vv[bp])
        product_relaxation(pm.model, vv[bp], cs[bp], wr[bp])
        product_relaxation(pm.model, vv[bp], si[bp], wi[bp])

        # this constraint is redudant and useful for debugging
        #complex_product_relaxation(pm.model, w[i], w[j], wr[bp], wi[bp])
   end

   for (i,branch) in pm.set.branches
        pair = (branch["f_bus"], branch["t_bus"])
        buspair = pm.set.buspairs[pair]

        # to prevent this constraint from being posted on multiple parallel lines
        if buspair["line"] == i
            constraint_power_magnitude_sqr(pm, branch)
            constraint_power_magnitude_link(pm, branch)
        end
    end
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

  @constraint(pm.model, p_fr^2 + q_fr^2 <= w_i/tm*cm)
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

  @constraint(pm.model, cm == (g^2 + b^2)*(w_fr/tm + w_to - 2*(tr*wr + ti*wi)/tm) - c*q_fr - ((c/2)/tm)^2*w_fr)
end


function constraint_theta_ref(pm::QCWRPowerModel)
    @constraint(pm.model, getvariable(pm.model, :t)[pm.set.ref_bus] == 0)
end

function constraint_phase_angle_diffrence(pm::QCWRPowerModel, branch)
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

        @constraint(pm.model, wi <= buspair["angmax"]*wr)
        @constraint(pm.model, wi >= buspair["angmin"]*wr)
    end
end

function add_bus_voltage_setpoint(sol, pm::QCWRPowerModel)
    add_setpoint(sol, pm, "bus", "bus_i", "vm", :v)
    add_setpoint(sol, pm, "bus", "bus_i", "va", :t)
end





