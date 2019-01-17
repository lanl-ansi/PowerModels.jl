
"In the literature this constraints are called the Lifted Nonlinear Cuts (LNCs)"
function cut_complex_product_and_angle_difference(m, wf, wt, wr, wi, angmin, angmax)
    @assert angmin >= -pi/2 && angmin <= pi/2
    @assert angmax >= -pi/2 && angmax <= pi/2
    @assert angmin < angmax

    vfub = sqrt(JuMP.upper_bound(wf))
    vflb = sqrt(JuMP.lower_bound(wf))
    vtub = sqrt(JuMP.upper_bound(wt))
    vtlb = sqrt(JuMP.lower_bound(wt))
    tdub = angmax
    tdlb = angmin

    phi = (tdub + tdlb)/2
    d   = (tdub - tdlb)/2

    sf = vflb + vfub
    st = vtlb + vtub

    JuMP.@constraint(m, sf*st*(cos(phi)*wr + sin(phi)*wi) - vtub*cos(d)*st*wf - vfub*cos(d)*sf*wt >=  vfub*vtub*cos(d)*(vflb*vtlb - vfub*vtub))
    JuMP.@constraint(m, sf*st*(cos(phi)*wr + sin(phi)*wi) - vtlb*cos(d)*st*wf - vflb*cos(d)*sf*wt >= -vflb*vtlb*cos(d)*(vflb*vtlb - vfub*vtub))
end


"general relaxation of a sine term, in -pi/2 to pi/2"
function relaxation_sin(m, x, y)
    ub = JuMP.upper_bound(x)
    lb = JuMP.lower_bound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    if lb < 0 && ub > 0
        JuMP.@constraint(m, y <= cos(max_ad/2)*(x - max_ad/2) + sin(max_ad/2))
        JuMP.@constraint(m, y >= cos(max_ad/2)*(x + max_ad/2) - sin(max_ad/2))
    end
    if ub <= 0
        JuMP.@constraint(m, y <= (sin(lb) - sin(ub))/(lb-ub)*(x - lb) + sin(lb))
        JuMP.@constraint(m, y >= cos(max_ad/2)*(x + max_ad/2) - sin(max_ad/2))
    end
    if lb >= 0
        JuMP.@constraint(m, y <= cos(max_ad/2)*(x - max_ad/2) + sin(max_ad/2))
        JuMP.@constraint(m, y >= (sin(lb) - sin(ub))/(lb-ub)*(x - lb) + sin(lb))
    end
end


"general relaxation of a cosine term, in -pi/2 to pi/2"
function relaxation_cos(m, x, y)
    ub = JuMP.upper_bound(x)
    lb = JuMP.lower_bound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    JuMP.@constraint(m, y <= 1 - (1-cos(max_ad))/(max_ad*max_ad)*(x^2))
    JuMP.@constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))
end


"general relaxation of a sine term, in -pi/2 to pi/2"
function relaxation_sin_on_off(m, x, y, z, M_x)
    ub = JuMP.upper_bound(x)
    lb = JuMP.lower_bound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    JuMP.@constraint(m, y <= z*sin(ub))
    JuMP.@constraint(m, y >= z*sin(lb))

    JuMP.@constraint(m,  y - cos(max_ad/2)*(x) <= z*(sin(max_ad/2) - cos(max_ad/2)*max_ad/2) + (1-z)*(cos(max_ad/2)*M_x))
    JuMP.@constraint(m, -y + cos(max_ad/2)*(x) <= z*(sin(max_ad/2) + cos(max_ad/2)*max_ad/2) + (1-z)*(cos(max_ad/2)*M_x))

    JuMP.@constraint(m, y <= z*(sin(max_ad/2) + cos(max_ad/2)*max_ad/2))
    JuMP.@constraint(m, -y <= z*(sin(max_ad/2) + cos(max_ad/2)*max_ad/2))

    JuMP.@constraint(m, cos(max_ad/2)*x <= z*(sin(max_ad/2) - cos(max_ad/2)*max_ad/2 + sin(max_ad)) + (1-z)*(cos(max_ad/2)*M_x))
    JuMP.@constraint(m, -cos(max_ad/2)*x <= z*(sin(max_ad/2) - cos(max_ad/2)*max_ad/2 + sin(max_ad)) + (1-z)*(cos(max_ad/2)*M_x))
end


"general relaxation of a cosine term, in -pi/2 to pi/2"
function relaxation_cos_on_off(m, x, y, z, M_x)
    ub = JuMP.upper_bound(x)
    lb = JuMP.lower_bound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    JuMP.@constraint(m, y <= z)
    JuMP.@constraint(m, y >= z*cos(max_ad))
    # can this be integrated?
    #JuMP.@constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))

    JuMP.@constraint(m, y <= z - (1-cos(max_ad))/(max_ad^2)*(x^2) + (1-z)*((1-cos(max_ad))/(max_ad^2)*(M_x^2)))
end


