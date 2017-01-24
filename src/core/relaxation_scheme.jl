function relaxation_complex_product(m, a, b, c, d)
    c = @constraint(m, c^2 + d^2 <= a*b)
    return Set([c])
end

# In the literature this constraints are called the Lifted Nonlinear Cuts (LNCs)
function cut_complex_product_and_angle_difference(m, wf, wt, wr, wi, angmin, angmax)
    @assert angmin >= -pi/2 && angmin <= pi/2
    @assert angmax >= -pi/2 && angmax <= pi/2
    @assert angmin < angmax

    vfub = sqrt(getupperbound(wf))
    vflb = sqrt(getlowerbound(wf))
    vtub = sqrt(getupperbound(wt))
    vtlb = sqrt(getlowerbound(wt))
    tdub = angmax
    tdlb = angmin

    phi = (tdub + tdlb)/2
    d   = (tdub - tdlb)/2

    sf = vflb + vfub
    st = vtlb + vtub

    c1 = @constraint(m, sf*st*(cos(phi)*wr + sin(phi)*wi) - vtub*cos(d)*st*wf - vfub*cos(d)*sf*wt >=  vfub*vtub*cos(d)*(vflb*vtlb - vfub*vtub))
    c2 = @constraint(m, sf*st*(cos(phi)*wr + sin(phi)*wi) - vtlb*cos(d)*st*wf - vflb*cos(d)*sf*wt >= -vflb*vtlb*cos(d)*(vflb*vtlb - vfub*vtub))

    return Set([c1, c2])
end

function relaxation_complex_product_on_off(m, a, b, c, d, z)
    # TODO add LNC cuts to this
    @assert getlowerbound(c) <= 0 && getupperbound(c) >= 0
    @assert getlowerbound(d) <= 0 && getupperbound(d) >= 0
    # assume c and d are already linked to z in other constraints
    # and will be forced to 0 when z is 0

    a_ub = getupperbound(a)
    b_ub = getupperbound(b)
    z_ub = getupperbound(z)

    c1 = @constraint(m, c^2 + d^2 <= a*b*z_ub)
    c2 = @constraint(m, c^2 + d^2 <= a_ub*b*z)
    c3 = @constraint(m, c^2 + d^2 <= a*b_ub*z)
    return Set([c1, c2, c3])
end

function relaxation_equality_on_off(m, x, y, z)
    # assumes 0 is in the domain of y when z is 0

    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)

    c1 = @constraint(m, y >= x - x_ub*(1-z))
    c2 = @constraint(m, y <= x - x_lb*(1-z))

    return Set([c1, c2])
end

# general relaxation of a square term
function relaxation_sqr(m, x, y)
    c1 = @constraint(m, y >= x^2)
    c2 = @constraint(m, y <= (getupperbound(x)+getlowerbound(x))*x - getupperbound(x)*getlowerbound(x))
    return Set([c1, c2])
end

# general relaxation of a sin term
function relaxation_sin(m, x, y)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    if lb < 0 && ub > 0
        c1 = @constraint(m, y <= cos(max_ad/2)*(x - max_ad/2) + sin(max_ad/2))
        c2 = @constraint(m, y >= cos(max_ad/2)*(x + max_ad/2) - sin(max_ad/2))
    end
    if ub <= 0
        c1 = @constraint(m, y <= (sin(lb) - sin(ub))/(lb-ub)*(x - lb) + sin(lb))
        c2 = @constraint(m, y >= cos(max_ad/2)*(x + max_ad/2) - sin(max_ad/2))
    end
    if lb >= 0
        c1 = @constraint(m, y <= cos(max_ad/2)*(x - max_ad/2) + sin(max_ad/2))
        c2 = @constraint(m, y >= (sin(lb) - sin(ub))/(lb-ub)*(x - lb) + sin(lb))
    end
    return Set([c1, c2])
end

# general relaxation of a cosine term
function relaxation_cos(m, x, y)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    c1 = @constraint(m, y <= 1 - (1-cos(max_ad))/(max_ad*max_ad)*(x^2))
    c2 = @constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))
    return Set([c1, c2])
end

# general relaxation of binlinear term (McCormick)
function relaxation_product(m, x, y, z)
    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)
    y_ub = getupperbound(y)
    y_lb = getlowerbound(y)

    c1 = @constraint(m, z >= x_lb*y + y_lb*x - x_lb*y_lb)
    c2 = @constraint(m, z >= x_ub*y + y_ub*x - x_ub*y_ub)
    c3 = @constraint(m, z <= x_lb*y + y_ub*x - x_lb*y_ub)
    c4 = @constraint(m, z <= x_ub*y + y_lb*x - x_ub*y_lb)

    return Set([c1, c2, c3, c4])
end
