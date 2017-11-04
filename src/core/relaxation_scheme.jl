"constraint: `c^2 + d^2 <= a*b`"
function relaxation_complex_product(m, a, b, c, d)
    @assert (getlowerbound(a) >= 0 && getlowerbound(b) >= 0) || (getupperbound(a) <= 0 && getupperbound(b) <= 0)
    @constraint(m, c^2 + d^2 <= a*b)
end

"In the literature this constraints are called the Lifted Nonlinear Cuts (LNCs)"
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

    @constraint(m, sf*st*(cos(phi)*wr + sin(phi)*wi) - vtub*cos(d)*st*wf - vfub*cos(d)*sf*wt >=  vfub*vtub*cos(d)*(vflb*vtlb - vfub*vtub))
    @constraint(m, sf*st*(cos(phi)*wr + sin(phi)*wi) - vtlb*cos(d)*st*wf - vflb*cos(d)*sf*wt >= -vflb*vtlb*cos(d)*(vflb*vtlb - vfub*vtub))
end

"""
```
c^2 + d^2 <= a*b*getupperbound(z)
c^2 + d^2 <= getupperbound(a)*b*getupperbound(z)
c^2 + d^2 <= a*getupperbound(b)*z
```
"""
function relaxation_complex_product_on_off(m, a, b, c, d, z)
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

"`x - getupperbound(x)*(1-z) <= y <= x - getlowerbound(x)*(1-z)`"
function relaxation_equality_on_off(m, x, y, z)
    # assumes 0 is in the domain of y when z is 0

    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)

    @constraint(m, y >= x - x_ub*(1-z))
    @constraint(m, y <= x - x_lb*(1-z))
end

"""
general relaxation of a square term

```
x^2 <= y <= (getupperbound(x)+getlowerbound(x))*x - getupperbound(x)*getlowerbound(x)
```
"""
function relaxation_sqr(m, x, y)
    @constraint(m, y >= x^2)
    @constraint(m, y <= (getupperbound(x)+getlowerbound(x))*x - getupperbound(x)*getlowerbound(x))
end

"general relaxation of a sine term, in -pi/2 to pi/2"
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


"general relaxation of a cosine term, in -pi/2 to pi/2"
function relaxation_cos(m, x, y)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    @constraint(m, y <= 1 - (1-cos(max_ad))/(max_ad*max_ad)*(x^2))
    @constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))
end


"general relaxation of a sine term, in -pi/2 to pi/2"
function relaxation_sin_on_off(m, x, y, z, M_x)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    @constraint(m, y <= z*sin(ub))
    @constraint(m, y >= z*sin(lb))

    @constraint(m,  y - cos(max_ad/2)*(x) <= z*(sin(max_ad/2) - cos(max_ad/2)*max_ad/2) + (1-z)*(cos(max_ad/2)*M_x))
    @constraint(m, -y + cos(max_ad/2)*(x) <= z*(sin(max_ad/2) + cos(max_ad/2)*max_ad/2) + (1-z)*(cos(max_ad/2)*M_x))

    @constraint(m, y <= z*(sin(max_ad/2) + cos(max_ad/2)*max_ad/2))
    @constraint(m, -y <= z*(sin(max_ad/2) + cos(max_ad/2)*max_ad/2))

    @constraint(m, cos(max_ad/2)*x <= z*(sin(max_ad/2) - cos(max_ad/2)*max_ad/2 + sin(max_ad)) + (1-z)*(cos(max_ad/2)*M_x))
    @constraint(m, -cos(max_ad/2)*x <= z*(sin(max_ad/2) - cos(max_ad/2)*max_ad/2 + sin(max_ad)) + (1-z)*(cos(max_ad/2)*M_x))
end


"general relaxation of a cosine term, in -pi/2 to pi/2"
function relaxation_cos_on_off(m, x, y, z, M_x)
    ub = getupperbound(x)
    lb = getlowerbound(x)
    @assert lb >= -pi/2 && ub <= pi/2

    max_ad = max(abs(lb),abs(ub))

    @constraint(m, y <= z)
    @constraint(m, y >= z*cos(max_ad))
    # can this be integrated?
    #@constraint(m, y >= (cos(lb) - cos(ub))/(lb-ub)*(x - lb) + cos(lb))

    @constraint(m, y <= z - (1-cos(max_ad))/(max_ad^2)*(x^2) + (1-z)*((1-cos(max_ad))/(max_ad^2)*(M_x^2)))
end


"""
general relaxation of binlinear term (McCormick)

```
z >= getlowerbound(x)*y + getlowerbound(y)*x - getlowerbound(x)*getlowerbound(y)
z >= getupperbound(x)*y + getupperbound(y)*x - getupperbound(x)*getupperbound(y)
z <= getlowerbound(x)*y + getupperbound(y)*x - getlowerbound(x)*getupperbound(y)
z <= getupperbound(x)*y + getlowerbound(y)*x - getupperbound(x)*getlowerbound(y)
```
"""
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


"""
On/Off variant of binlinear term (McCormick)
requires that all variables (x,y,z) go to zero with ind
"""
function relaxation_product_on_off(m, x, y, z, ind)
    @assert getlowerbound(x) <= 0 && getupperbound(x) >= 0
    @assert getlowerbound(y) <= 0 && getupperbound(y) >= 0
    @assert getlowerbound(z) <= 0 && getupperbound(z) >= 0

    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)
    y_ub = getupperbound(y)
    y_lb = getlowerbound(y)

    @constraint(m, z >= x_lb*y + y_lb*x - ind*x_lb*y_lb)
    @constraint(m, z >= x_ub*y + y_ub*x - ind*x_ub*y_ub)
    @constraint(m, z <= x_lb*y + y_ub*x - ind*x_lb*y_ub)
    @constraint(m, z <= x_ub*y + y_lb*x - ind*x_ub*y_lb)
end

"""
convex hull relaxation of trilinear term

```
w₁ = getlowerbound(x)*getlowerbound(y)*getlowerbound(z)
w₂ = getlowerbound(x)*getlowerbound(y)*getupperbound(z)
w₃ = getlowerbound(x)*getupperbound(y)*getlowerbound(z)
w₄ = getlowerbound(x)*getupperbound(y)*getupperbound(z)
w₅ = getupperbound(x)*getlowerbound(y)*getlowerbound(z)
w₆ = getupperbound(x)*getlowerbound(y)*getupperbound(z)
w₇ = getupperbound(x)*getupperbound(y)*getlowerbound(z)
w₈ = getupperbound(x)*getupperbound(y)*getupperbound(z)
w = λ₁*w₁ + λ₂*w₂ + λ₃*w₃ + λ₄*w₄ + λ₅*w₅ + λ₆*w₆ + λ₇*w₇ + λ₈*w₈
x = (λ₁ + λ₂ + λ₃ + λ₄)*getlowerbound(x) + (λ₅ + λ₆ + λ₇ + λ₈)*getupperbound(x)
y = (λ₁ + λ₂ + λ₅ + λ₆)*getlowerbound(x) + (λ₃ + λ₄ + λ₇ + λ₈)*getupperbound(x)
z = (λ₁ + λ₃ + λ₅ + λ₇)*getlowerbound(x) + (λ₂ + λ₄ + λ₆ + λ₈)*getupperbound(x)
λ₁ + λ₂ + λ₃ + λ₄ + λ₅ + λ₆ + λ₇ + λ₈ = 1
```
"""
function relaxation_trilinear(m, x, y, z, w, lambda)
    x_ub = getupperbound(x)
    x_lb = getlowerbound(x)
    y_ub = getupperbound(y)
    y_lb = getlowerbound(y)
    z_ub = getupperbound(z)
    z_lb = getlowerbound(z)

    @assert length(lambda) == 8

    w_val = [x_lb * y_lb * z_lb 
             x_lb * y_lb * z_ub  
             x_lb * y_ub * z_lb
             x_lb * y_ub * z_ub 
             x_ub * y_lb * z_lb
             x_ub * y_lb * z_ub
             x_ub * y_ub * z_lb
             x_ub * y_ub * z_ub]

    @constraint(m, w == sum(w_val[i]*lambda[i] for i in 1:8))
    @constraint(m, x == (lambda[1] + lambda[2] + lambda[3] + lambda[4])*x_lb + 
                        (lambda[5] + lambda[6] + lambda[7] + lambda[8])*x_ub)
    @constraint(m, y == (lambda[1] + lambda[2] + lambda[5] + lambda[6])*y_lb + 
                        (lambda[3] + lambda[4] + lambda[7] + lambda[8])*y_ub)
    @constraint(m, z == (lambda[1] + lambda[3] + lambda[5] + lambda[7])*z_lb + 
                        (lambda[2] + lambda[4] + lambda[6] + lambda[8])*z_ub)
    @constraint(m, sum(lambda) == 1)
end 
