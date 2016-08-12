export 
    ACPPowerModel, DCPPowerModel, WRPowerModel, GenericPowerModel, testit,
    ACPData, DCPData, WRData

abstract AbstractPowerModel

type GenericPowerModel{T} <: AbstractPowerModel
    model::Model
    data::Dict{AbstractString,Any}
    settings::Dict{AbstractString,Any}
    solution::Dict{AbstractString,Any}
    ext::T
end

# default generic constructor
function GenericPowerModel{T}(data::Dict{AbstractString,Any}, ext::T; settings::Dict{AbstractString,Any} = Dict{AbstractString,Any}())
    make_per_unit(data)
    return GenericPowerModel{T}(
        Model(), # model
        data, # data
        settings, # settings
        Dict{AbstractString,Any}(), # solution
        ext # extension
    )
end


type ACPData end
typealias ACPPowerModel GenericPowerModel{ACPData}

# default AC constructor
function ACPPowerModel(data::Dict{AbstractString,Any}; settings::Dict{AbstractString,Any} = Dict{AbstractString,Any}(), ext::ACPData = ACPData())
    return GenericPowerModel(data, ext; settings = settings)
end


type DCPData end
typealias DCPPowerModel GenericPowerModel{DCPData}

# default DC constructor
function DCPPowerModel(data::Dict{AbstractString,Any}; settings::Dict{AbstractString,Any} = Dict{AbstractString,Any}(), ext::DCPData = DCPData())
    return GenericPowerModel(data, ext; settings = settings)
end


type WRData end
typealias WRPowerModel GenericPowerModel{WRData}

# default WR constructor
function WRPowerModel(data::Dict{AbstractString,Any}; settings::Dict{AbstractString,Any} = Dict{AbstractString,Any}(), ext::WRData = WRData())
    return GenericPowerModel(data, ext; settings = settings)
end



#function testit(val::ACPPowerModel)
#    println("AC Model!")
#    typeof(val)
#end

#function testit(val::DCPPowerModel)
#    println("DC Model!")
#    typeof(val)
#end

#function testit{T}(val::GenericPowerModel{T})
#    println("Any Model!")
#    typeof(val)
#    typeof(T)
#end


function setdata(pm::GenericPowerModel{Any}, data::Dict{AbstractString,Any})
    make_per_unit(data)

    pm.model = Model()
    pm.solution = Dict{AbstractString,Any}()
    pm.data = data
end

function setsolver(pm::GenericPowerModel{Any}, solver::MathProgBase.AbstractMathProgSolver)
    pm.model.setsolver(s)
end




not_pu = Set(["rate_a","rate_b","rate_c","bs","gs","pd","qd","pg","qg","pmax","pmin","qmax","qmin"])
not_rad = Set(["angmax","angmin","shift","va"])

function make_per_unit(data::Dict{AbstractString,Any})
    if !haskey(data, "perUnit") || data["perUnit"] == false
        make_per_unit(data["baseMVA"], data)
        data["perUnit"] = true
    end
end

function make_per_unit(mva_base::Number, data::Dict{AbstractString,Any})
    for k in keys(data)
        if k == "gencost"
            for cost_model in data[k]
                if cost_model["model"] != 2
                    println("WARNING: Skipping generator cost model of tpye other than 2")
                    continue
                end
                degree = length(cost_model["cost"])
                for (i, item) in enumerate(cost_model["cost"])
                    cost_model["cost"][i] = item*mva_base^(degree-i)
                end
            end
        elseif isa(data[k], Number)
            if k in not_pu
                data[k] = data[k]/mva_base
            end
            if k in not_rad
                data[k] = pi*data[k]/180.0
            end
            #println("$(k) $(data[k])")
        else
            make_per_unit(mva_base, data[k])
        end
    end
end

function make_per_unit(mva_base::Number, data::Array{Any,1})
    for item in data
        make_per_unit(mva_base, item)
    end
end

function make_per_unit(mva_base::Number, data::AbstractString)
    #nothing to do
    #println("$(parent) $(data)")
end

function make_per_unit(mva_base::Number, data::Number)
    #nothing to do
    #println("$(parent) $(data)")
end

function unify_transformer_taps(data::Dict{AbstractString,Any})
    for branch in data["branch"]
        if branch["tap"] == 0.0
            branch["tap"] = 1.0
        end
    end
end
