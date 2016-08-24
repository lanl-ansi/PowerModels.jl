

function relaxation_complex_product(m, a, b, c, d)
    # TODO add LNC cuts to this 
    @constraint(m, c^2 + d^2 <= a*b)
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

    @constraint(m, c^2 + d^2 <= a*b*z_ub)
    @constraint(m, c^2 + d^2 <= a_ub*b*z)
    @constraint(m, c^2 + d^2 <= a*b_ub*z)
end


function relaxation_equality_on_off(m, x, y, z)
    # assumes 0 is in the domain of y when z is 0

    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)

    @constraint(m, y >= x - x_ub*(1-z))
    @constraint(m, y <= x - x_lb*(1-z))
end


# general relaxation of a square term
function relaxation_sqr(m, x, y)
    @constraint(m, y >= x^2)
    @constraint(m, y <= (getupperbound(x)+getlowerbound(x))*x - getupperbound(x)*getlowerbound(x))
end


# general relaxation of a sin term
function relaxation_sin(m, x, y)
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
function relaxation_cos(m, x, y)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))
    
    @constraint(m, y <= 1 - (1-cos(max_ad))/(max_ad*max_ad)*(x^2))
    @constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))
end


# general relaxation of binlinear term (McCormick)
function relaxation_product(m, x, y, z)
    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)
    y_ub = getupperbound(y)
    y_lb = getlowerbound(y)

    @constraint(m, z >= x_lb*y + y_lb*x - x_lb*y_lb)
    @constraint(m, z >= x_ub*y + y_ub*x - x_ub*y_ub)
    @constraint(m, z <= x_lb*y + y_ub*x - x_lb*y_ub)
    @constraint(m, z <= x_ub*y + y_lb*x - x_ub*y_lb)
end


