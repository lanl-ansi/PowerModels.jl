
# TODO replace with the version from InfrastructureModels
# used by data.jl and multinetwork.jl
function compare_dict(d1, d2)
    for (k1,v1) in d1
        if !haskey(d2, k1)
            #println(k1)
            return false
        end
        v2 = d2[k1]

        if isa(v1, Number)
            if isnan(v1)
                #println("1.1")
                if !isnan(v2)
                    #println(v1, " ", v2)
                    return false
                end
            else
                #println("1.2")
                if !isapprox(v1, v2)
                    #println(v1, " ", v2)
                    return false
                end
            end
        elseif isa(v1, Dict)
            if !compare_dict(v1, v2)
                #println(v1, " ", v2)
                return false
            end
        else
            #println("2")
            if v1 != v2
                #println(v1, " ", v2)
                return false
            end
        end
    end
    return true
end

