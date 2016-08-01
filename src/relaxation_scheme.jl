using JuMP

# TODO add LNC cuts to this 
function complex_product_relaxation(m, a, b, c, d)
    @constraint(m, c^2 + d^2 <= a*b)
end

# TODO add LNC cuts to this 
function complex_product_relaxation_on_off(m, a, b, c, d, z)
    @assert getlowerbound(c) <= 0 && getupperbound(c) >= 0
    @assert getlowerbound(d) <= 0 && getupperbound(d) >= 0
    # assume c and d are already linked to z in other constraints 
    # and will be forced to 0 when z is 0

    a_ub = getupperbound(a)
    b_ub = getupperbound(b)
    z_ub = getupperbound(z)

    @constraint(m, c^2 + d^2 <= a*b*z_ub)
    @constraint(m, c^2 + d^2 <= a_ub*b*z)
    @constraint(m, c^2 + d^2 <= a*b_ub*z)
end


# general relaxation of a square term
function sqr_relaxation(m, x, y)
    @constraint(m, y >= x^2)
    @constraint(m, y <= (getupperbound(x)+getlowerbound(x))*x - getupperbound(x)*getlowerbound(x))
end

# general relaxation of a sin term
function sin_relaxation(m, x, y)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))
    
    if lb < 0 && ub > 0
        @constraint(m, y <= cos(max_ad/2)*(x - max_ad/2) + sin(max_ad/2))
        @constraint(m, y >= cos(max_ad/2)*(x + max_ad/2) - sin(max_ad/2))
    end
    if ub <= 0
        @constraint(m, y <= (sin(lb) - sin(ub))/(lb-ub)*(x - lb) + sin(lb))
        @constraint(m, y >= cos(max_ad/2)*(x + max_ad/2) - sin(max_ad/2))
    end
    if lb >= 0
        @constraint(m, y <= cos(max_ad/2)*(x - max_ad/2) + sin(max_ad/2))
        @constraint(m, y >= (sin(lb) - sin(ub))/(lb-ub)*(x - lb) + sin(lb))
    end
end

# general relaxation of a cosine term
function cos_relaxation(m, x, y)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))
    
    @constraint(m, y <= 1 - (1-cos(max_ad))/(max_ad*max_ad)*(x^2))
    @constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))
end

# general relaxation of binlinear term (McCormick)
function product_relaxation(m, x, y, z)
    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)
    y_ub = getupperbound(y)
    y_lb = getlowerbound(y)

    @constraint(m, z >= x_lb*y + y_lb*x - x_lb*y_lb)
    @constraint(m, z >= x_ub*y + y_ub*x - x_ub*y_ub)
    @constraint(m, z <= x_lb*y + y_ub*x - x_lb*y_ub)
    @constraint(m, z <= x_ub*y + y_lb*x - x_ub*y_lb)
end