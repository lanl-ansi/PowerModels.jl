
# used by data.jl and multinetwork.jl
function compare_dict(d1, d2)
    for (k1,v1) in d1
        if !haskey(d2, k1)
            #@test false
            return false
        end
        v2 = d2[k1]

        if isa(v1, Number)
            #@test isapprox(v1, v2)
            if !isapprox(v1, v2)
                return false
            end
        elseif isa(v1, Dict)
            if !compare_dict(v1, v2)
                return false
            end
        else
            #@test v1 == v2
            if v1 != v2
                return false
            end
        end
    end
    return true
end

