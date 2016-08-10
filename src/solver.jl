##########################################################################################################
# The purpose of this file is to define functionality for building solvers and their parameterization
# from a JSON specification file
##########################################################################################################

export build_solver, build_solver_file, build_solver_dict
export IPOPT_SOLVER, CPLEX_SOLVER, MOSEK_SOLVER, BONMIN_SOLVER, SCS_SOLVER, GUROBI_SOLVER, CBC_SOLVER, KNITRO_SOLVER

const IPOPT_SOLVER = "IPOPT"
const CPLEX_SOLVER = "CPLEX"
const MOSEK_SOLVER = "MOSEK"
const BONMIN_SOLVER = "BONMIN"
const SCS_SOLVER = "SCS"
const GUROBI_SOLVER = "GUROBI"
const CBC_SOLVER = "CBC"
const KNITRO_SOLVER = "KNITRO"


if (Pkg.installed("CPLEX") != nothing)
  using CPLEX
end

if (Pkg.installed("KNITRO") != nothing)
  using KNITRO
end


if (Pkg.installed("Gurobi") != nothing)
  using Gurobi
end


if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)
  using AmplNLWriter
  using CoinOptServices

  # note that AmplNLWriter.AmplNLSolver is the solver type of bonmin
  solver_status_lookup[AmplNLWriter.AmplNLSolver] = Dict(:Optimal => :LocalOptimal, :Infeasible => :LocalInfeasible)

  #println("SOLVER STATUS!!!")
  #println(solver_status_lookup)
end

if (Pkg.installed("Mosek") != nothing)
  using Mosek
end

if (Pkg.installed("SCS") != nothing)
  using SCS
end

if (Pkg.installed("Cbc") != nothing)
  using Cbc
end


# translates solver status codes to our status codes

function solver_status_dict(solver_type, status)
    for (st, solver_stat_dict) in solver_status_lookup
      if solver_type == st
        if status in keys(solver_stat_dict)
            return solver_stat_dict[status]
        else
            return status
        end
      end
    end
    return status
end



#Builds the solver from a json file
function build_solver_file(json_file)
  data_string = readall(open(json_file))
  json_data = JSON.parse(data_string)

  return build_solver_dict(json_data)
end

#Builds the solver from a dictionary
function build_solver_dict(json_data)
  solver = json_data["solver"]
  delete!(json_data, "solver")

  symbol_data = Dict{Symbol,Any}()

  for (key,value) in json_data
    symbol_data[symbol(key)] = value
  end

  return build_solver(solver; symbol_data...)
end


#Builds the solver from a function and arguments
function build_solver(solver; kwargs...)
  #println(solver)
  #println(kwargs)

  if (solver == IPOPT_SOLVER)
      return build_ipopt(; kwargs...)
  end

  if (solver == CPLEX_SOLVER)
    return build_cplex(; kwargs...)
  end

  if (solver == GUROBI_SOLVER)
    return build_gurobi(; kwargs...)
  end
  
  
  if (solver == MOSEK_SOLVER)
    return build_mosek(; kwargs...)
  end

  if (solver == BONMIN_SOLVER)
    return build_bonmin(; kwargs...)
  end

  if (solver == SCS_SOLVER)
    return build_scs(; kwargs...)
  end

  if (solver == CBC_SOLVER)
    return build_cbc(; kwargs...)
  end

  if (solver == KNITRO_SOLVER)
    return build_knitro(; kwargs...)
  end
  
  
  println("Solver $solver not found!")
  return nothing  
end




function set_defaults(args_array; kwagrs...)
  defined_names = [k for (k,v) in args_array]
  for kwarg in kwagrs
    if ~(kwarg[1] in defined_names)
      push!(args_array, kwarg)
    end
  end
  return args_array
end

function args_to_string(prefix; kwagrs...)
  arg_list = ASCIIString[]
  for kwarg in kwagrs
      push!(arg_list, "$(prefix).$(kwarg[1])=$(kwarg[2])")
  end
  return arg_list
end


# builds the ipopt solver
function build_ipopt(; kwargs...)
  kwargs = set_defaults(kwargs, tol=1e-6, print_level=1)
  return IpoptSolver(; kwargs...)
end

# builds the cplex solver
if (Pkg.installed("CPLEX") != nothing)
  function build_cplex(; kwargs...)
    kwargs = set_defaults(kwargs)
    return CplexSolver(; kwargs...)
  end
end

# builds the gurobi solver
if (Pkg.installed("Gurobi") != nothing)
  function build_gurobi(; kwargs...)
    kwargs = set_defaults(kwargs)
    return GurobiSolver(; kwargs...)
  end
end

# builds the gurobi solver
if (Pkg.installed("KNITRO") != nothing)
  function build_knitro(; kwargs...)
    kwargs = set_defaults(kwargs)
    return KnitroSolver(; kwargs...)
  end
end


# builds the mosek solver   
if (Pkg.installed("Mosek") != nothing)
  function build_mosek(; kwargs...)
    kwargs = set_defaults(kwargs)
    return MosekSolver(; kwargs...)
  end
end   

# builds the bonmin solver
if (Pkg.installed("AmplNLWriter") != nothing && Pkg.installed("CoinOptServices") != nothing)
  function build_bonmin(; kwargs...)
    kwargs = set_defaults(kwargs)

    # NOTE this encoding not perfect, does not support full .opt file specification 
    # for example passing ipopt parameters to bomin
    arg_list = args_to_string("bonmin"; kwargs...)
    return BonminNLSolver(arg_list)
  end
end

# builds the scs solver
if (Pkg.installed("SCS") != nothing)
  function build_scs(; kwargs...)
    kwargs = set_defaults(kwargs, max_iters=1000000)
    return SCSSolver(; kwargs...)
  end
end

# builds the cbc solver
if (Pkg.installed("Cbc") != nothing)
  function build_cbc(; kwargs...)
    kwargs = set_defaults(kwargs)
    return CbcSolver(; kwargs...)
  end
end
