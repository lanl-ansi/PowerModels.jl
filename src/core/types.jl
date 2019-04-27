export
    # exact non-convex models
    ACPPowerModel, StandardACPForm,
    ACRPowerModel, StandardACRForm,
    ACTPowerModel, StandardACTForm,

    # linear approximations
    DCPPowerModel, DCPlosslessForm,
    NFAPowerModel, NFAForm,

    # quadratic approximations
    DCPLLPowerModel, StandardDCPLLForm,
    LPACCPowerModel, AbstractLPACCForm,

    # quadratic relaxations
    SOCWRPowerModel, SOCWRForm,
    QCWRPowerModel, QCWRForm,
    SOCWRConicPowerModel, SOCWRConicForm,
    QCWRTriPowerModel, QCWRTriForm,
    SOCBFPowerModel, SOCBFForm,
    SOCBFConicPowerModel, SOCBFConicForm,

    # sdp relaxations
    SDPWRMPowerModel, SDPWRMForm,
    SparseSDPWRMPowerModel, SparseSDPWRMForm



##### Top Level Abstract Types #####

"active power only models"
abstract type AbstractActivePowerFormulation <: AbstractPowerFormulation end

"variants that target conic solvers"
abstract type AbstractConicPowerFormulation <: AbstractPowerFormulation end

"for branch flow models"
abstract type AbstractBFForm <: AbstractPowerFormulation end

"for variants of branch flow models that target QP or NLP solvers"
abstract type AbstractBFQPForm <: AbstractBFForm end

"for variants of branch flow models that target conic solvers"
abstract type AbstractBFConicForm <: AbstractBFForm end





##### Exact Non-Convex Models #####

""
abstract type AbstractACPForm <: AbstractPowerFormulation end

""
abstract type StandardACPForm <: AbstractACPForm end

"""
AC power flow formulation with polar bus voltage variables.

The seminal reference of AC OPF:
```
@article{carpentier1962contribution,
  title={Contribution to the economic dispatch problem},
  author={Carpentier, J},
  journal={Bulletin de la Societe Francoise des Electriciens},
  volume={3},
  number={8},
  pages={431--447},
  year={1962}
}
```

History and discussion:
```
@techreport{Cain2012,
  author = {Cain, Mary B and {O' Neill}, Richard P and Castillo, Anya},
  title = {{History of optimal power flow and formulations}},
  year = {2012}
  pages = {1--36},
  url = {https://www.ferc.gov/industries/electric/indus-act/market-planning/opf-papers/acopf-1-history-formulation-testing.pdf}
}
```
"""
const ACPPowerModel = GenericPowerModel{StandardACPForm}

""
ACPPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, StandardACPForm; kwargs...)


""
abstract type AbstractACRForm <: AbstractPowerFormulation end

""
abstract type StandardACRForm <: AbstractACRForm end

"""
AC power flow formulation with rectangular bus voltage variables.

```
@techreport{Cain2012,
  author = {Cain, Mary B and {O' Neill}, Richard P and Castillo, Anya},
  pages = {1--36},
  title = {{History of optimal power flow and formulations}},
  url = {https://www.ferc.gov/industries/electric/indus-act/market-planning/opf-papers/acopf-1-history-formulation-testing.pdf}
  year = {2012}
}
```
"""
const ACRPowerModel = GenericPowerModel{StandardACRForm}

"default rectangular AC constructor"
ACRPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, StandardACRForm; kwargs...)

""
abstract type AbstractACTForm <: AbstractPowerFormulation end

""
abstract type StandardACTForm <: AbstractACTForm end

"""
AC power flow formulation (nonconvex) with variables for voltage angle, voltage magnitude squared, and real and imaginary part of voltage crossproducts. A tangens constraint is added to represent meshed networks in an exact manner.
```
@ARTICLE{4349090,
  author={R. A. Jabr},
  title={A Conic Quadratic Format for the Load Flow Equations of Meshed Networks},
  journal={IEEE Transactions on Power Systems},
  year={2007},
  month={Nov},
  volume={22},
  number={4},
  pages={2285-2286},
  doi={10.1109/TPWRS.2007.907590},
  ISSN={0885-8950}
}
```
"""
const ACTPowerModel = GenericPowerModel{StandardACTForm}

"default AC constructor"
ACTPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, StandardACTForm; kwargs...)







##### Linear Approximations #####


""
abstract type AbstractDCPForm <: AbstractActivePowerFormulation end

"active power only formulations where p[(i,j)] = -p[(j,i)]"
abstract type DCPlosslessForm <: AbstractDCPForm end


"""
Linearized 'DC' power flow formulation with polar voltage variables.

```
@ARTICLE{4956966,
  author={B. Stott and J. Jardim and O. Alsac},
  journal={IEEE Transactions on Power Systems},
  title={DC Power Flow Revisited},
  year={2009},
  month={Aug},
  volume={24},
  number={3},
  pages={1290-1300},
  doi={10.1109/TPWRS.2009.2021235},
  ISSN={0885-8950}
}
```
"""
const DCPPowerModel = GenericPowerModel{DCPlosslessForm}

"default DC constructor"
DCPPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, DCPlosslessForm; kwargs...)



abstract type NFAForm <: DCPlosslessForm end

"""
The an active power only network flow approximation, also known as the transportation model.
"""
const NFAPowerModel = GenericPowerModel{NFAForm}

"default DC constructor"
NFAPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, NFAForm; kwargs...)






##### Quadratic Approximations #####


""
abstract type AbstractDCPLLForm <: AbstractDCPForm end

""
abstract type StandardDCPLLForm <: AbstractDCPLLForm end

""
const DCPLLPowerModel = GenericPowerModel{StandardDCPLLForm}

"default DC constructor"
DCPLLPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, StandardDCPLLForm; kwargs...)



""
abstract type AbstractLPACForm <: AbstractPowerFormulation end

abstract type AbstractLPACCForm <: AbstractLPACForm end

"""
The LPAC Cold-Start AC Power Flow Approximation.

Note that the LPAC Cold-Start model requires the least amount of information
but is also the least accurate variant of the LPAC formulations.  If a
nominal AC operating point is available, the LPAC Warm-Start model will provide
improved accuracy.

The original publication suggests to use polyhedral outer approximations for
the cosine and line thermal lit constraints.  Given the recent improvements in
MIQCQP solvers, this implementation uses quadratic functions for those
constraints.

```
@article{doi:10.1287/ijoc.2014.0594,
  author = {Coffrin, Carleton and Van Hentenryck, Pascal},
  title = {A Linear-Programming Approximation of AC Power Flows},
  journal = {INFORMS Journal on Computing},
  volume = {26},
  number = {4},
  pages = {718-734},
  year = {2014},
  doi = {10.1287/ijoc.2014.0594},
  eprint = {https://doi.org/10.1287/ijoc.2014.0594}
}
```
"""
const LPACCPowerModel = GenericPowerModel{AbstractLPACCForm}

"default LPACC constructor"
LPACCPowerModel(data::Dict{String,<:Any}; kwargs...) =
    GenericPowerModel(data, AbstractLPACCForm; kwargs...)






##### Quadratic Relaxations #####

""
abstract type AbstractWRForm <: AbstractPowerFormulation end

""
abstract type AbstractWRConicForm <: AbstractConicPowerFormulation end

""
abstract type SOCWRConicForm <: AbstractWRConicForm end

""
abstract type SOCWRForm <: AbstractWRForm end

"""
Second-order cone relaxation of bus injection model of AC OPF.

The implementation casts this as a convex quadratically constrained problem.
```
@article{1664986,
  author={R. A. Jabr},
  title={Radial distribution load flow using conic programming},
  journal={IEEE Transactions on Power Systems},
  year={2006},
  month={Aug},
  volume={21},
  number={3},
  pages={1458-1459},
  doi={10.1109/TPWRS.2006.879234},
  ISSN={0885-8950}
}
```
"""
const SOCWRPowerModel = GenericPowerModel{SOCWRForm}

"""
Second-order cone relaxation of bus injection model of AC OPF.

This implementation casts the problem as a convex conic problem.
"""
const SOCWRConicPowerModel = GenericPowerModel{SOCWRConicForm}

"default SOC constructor"
SOCWRPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, SOCWRForm; kwargs...)

SOCWRConicPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, SOCWRConicForm; kwargs...)


""
abstract type QCWRForm <: AbstractWRForm end

"""
"Quadratic-Convex" relaxation of AC OPF
```
@Article{Hijazi2017,
  author="Hijazi, Hassan and Coffrin, Carleton and Hentenryck, Pascal Van",
  title="Convex quadratic relaxations for mixed-integer nonlinear programs in power systems",
  journal="Mathematical Programming Computation",
  year="2017",
  month="Sep",
  volume="9",
  number="3",
  pages="321--367",
  issn="1867-2957",
  doi="10.1007/s12532-016-0112-z",
  url="https://doi.org/10.1007/s12532-016-0112-z"
}
```
"""
const QCWRPowerModel = GenericPowerModel{QCWRForm}

"default QC constructor"
QCWRPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, QCWRForm; kwargs...)



""
abstract type QCWRTriForm <: QCWRForm end

"""
"Quadratic-Convex" relaxation of AC OPF with convex hull of triple product
```
@Article{Hijazi2017,
  author="Hijazi, Hassan and Coffrin, Carleton and Hentenryck, Pascal Van",
  title="Convex quadratic relaxations for mixed-integer nonlinear programs in power systems",
  journal="Mathematical Programming Computation",
  year="2017",
  month="Sep",
  volume="9",
  number="3",
  pages="321--367",
  issn="1867-2957",
  doi="10.1007/s12532-016-0112-z",
  url="https://doi.org/10.1007/s12532-016-0112-z"
}
```
"""
const QCWRTriPowerModel = GenericPowerModel{QCWRTriForm}

"default QC trilinear model constructor"
QCWRTriPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, QCWRTriForm; kwargs...)



""
abstract type SOCBFForm <: AbstractBFQPForm end

"""
Second-order cone relaxation of branch flow model

The implementation casts this as a convex quadratically constrained problem.
```
@INPROCEEDINGS{6425870,
  author={M. Farivar and S. H. Low},
  title={Branch flow model: Relaxations and convexification},
  booktitle={2012 IEEE 51st IEEE Conference on Decision and Control (CDC)},
  year={2012},
  month={Dec},
  pages={3672-3679},
  doi={10.1109/CDC.2012.6425870},
  ISSN={0191-2216}
}
```
Extended as discussed in:
```
@misc{1506.04773,
  author = {Carleton Coffrin and Hassan L. Hijazi and Pascal Van Hentenryck},
  title = {DistFlow Extensions for AC Transmission Systems},
  year = {2018},
  eprint = {arXiv:1506.04773},
  url = {https://arxiv.org/abs/1506.04773}
}
```
"""
const SOCBFPowerModel = GenericPowerModel{SOCBFForm}

"default SOC constructor"
SOCBFPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, SOCBFForm; kwargs...)


""
abstract type SOCBFConicForm <: AbstractBFConicForm end

""
const SOCBFConicPowerModel = GenericPowerModel{SOCBFConicForm}

"default SOC constructor"
SOCBFConicPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, SOCBFConicForm; kwargs...)






###### SDP Relaxations ######

""
abstract type AbstractWRMForm <: AbstractConicPowerFormulation end


""
abstract type SDPWRMForm <: AbstractWRMForm end

"""
Semi-definite relaxation of AC OPF

Originally proposed by:
```
@article{BAI2008383,
  author = "Xiaoqing Bai and Hua Wei and Katsuki Fujisawa and Yong Wang",
  title = "Semidefinite programming for optimal power flow problems",
  journal = "International Journal of Electrical Power & Energy Systems",
  volume = "30",
  number = "6",
  pages = "383 - 392",
  year = "2008",
  issn = "0142-0615",
  doi = "https://doi.org/10.1016/j.ijepes.2007.12.003",
  url = "http://www.sciencedirect.com/science/article/pii/S0142061507001378",
}
```
First paper to use "W" variables in the BIM of AC OPF:
```
@INPROCEEDINGS{6345272,
  author={S. Sojoudi and J. Lavaei},
  title={Physics of power networks makes hard optimization problems easy to solve},
  booktitle={2012 IEEE Power and Energy Society General Meeting},
  year={2012},
  month={July},
  pages={1-8},
  doi={10.1109/PESGM.2012.6345272},
  ISSN={1932-5517}
}
```
"""
const SDPWRMPowerModel = GenericPowerModel{SDPWRMForm}

""
SDPWRMPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, SDPWRMForm; kwargs...)


abstract type SparseSDPWRMForm <: SDPWRMForm end

"""
Sparsity-exploiting semidefinite relaxation of AC OPF

Proposed in:
```
@article{doi:10.1137/S1052623400366218,
  author = {Fukuda, M. and Kojima, M. and Murota, K. and Nakata, K.},
  title = {Exploiting Sparsity in Semidefinite Programming via Matrix Completion I: General Framework},
  journal = {SIAM Journal on Optimization},
  volume = {11},
  number = {3},
  pages = {647-674},
  year = {2001},
  doi = {10.1137/S1052623400366218},
  URL = {https://doi.org/10.1137/S1052623400366218},
  eprint = {https://doi.org/10.1137/S1052623400366218}
}
```
Original application to OPF by:
```
@ARTICLE{6064917,
  author={R. A. Jabr},
  title={Exploiting Sparsity in SDP Relaxations of the OPF Problem},
  journal={IEEE Transactions on Power Systems},
  volume={27},
  number={2},
  pages={1138-1139},
  year={2012},
  month={May},
  doi={10.1109/TPWRS.2011.2170772},
  ISSN={0885-8950}
}
```
"""
const SparseSDPWRMPowerModel = GenericPowerModel{SparseSDPWRMForm}

""
SparseSDPWRMPowerModel(data::Dict{String,<:Any}; kwargs...) = GenericPowerModel(data, SparseSDPWRMForm; kwargs...)





##### Union Types #####
#
# These types should not be exported because they exist only to prevent code
# replication
#
# Note that Union types are discouraged in Julia,
# https://docs.julialang.org/en/v1/manual/style-guide/#Avoid-strange-type-Unions-1
# and should be used with discretion.
#
# If you are about to add a union type, first double check if refactoring the 
# type hierarchy can resolve the issue instead.
#

AbstractWRForms = Union{AbstractACTForm, AbstractWRForm, AbstractWRConicForm, AbstractWRMForm}
AbstractWForms = Union{AbstractWRForms, AbstractBFForm}
AbstractPForms = Union{AbstractACPForm, AbstractACTForm, AbstractDCPForm, AbstractLPACForm}

"union of all conic form branches"
AbstractConicForms = Union{AbstractConicPowerFormulation, AbstractBFConicForm}


