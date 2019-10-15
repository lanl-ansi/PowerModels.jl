#================================================
    # exact non-convex models
    ACPPowerModel, ACRPowerModel, ACTPowerModel

    # linear approximations
    DCPPowerModel, DCMPPowerModel, NFAPowerModel

    # quadratic approximations
    DCPLLPowerModel, LPACCPowerModel

    # quadratic relaxations
    SOCWRPowerModel, SOCWRConicPowerModel,
    SOCBFPowerModel, SOCBFConicPowerModel,
    QCRMPowerModel, QCLSPowerModel,

    # sdp relaxations
    SDPWRMPowerModel, SparseSDPWRMPowerModel
================================================#

##### Top Level Abstract Types #####

"active power only models"
abstract type AbstractActivePowerModel <: AbstractPowerModel end

"variants that target conic solvers"
abstract type AbstractConicModel <: AbstractPowerModel end

"for branch flow models"
abstract type AbstractBFModel <: AbstractPowerModel end

"for variants of branch flow models that target QP or NLP solvers"
abstract type AbstractBFQPModel <: AbstractBFModel end

"for variants of branch flow models that target conic solvers"
abstract type AbstractBFConicModel <: AbstractBFModel end





##### Exact Non-Convex Models #####

""
abstract type AbstractACPModel <: AbstractPowerModel end

"""
AC power flow Model with polar bus voltage variables.

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
  title = {{History of optimal power flow and Models}},
  year = {2012}
  pages = {1--36},
  url = {https://www.ferc.gov/industries/electric/indus-act/market-planning/opf-papers/acopf-1-history-Model-testing.pdf}
}
```
"""
mutable struct ACPPowerModel <: AbstractACPModel @pm_fields end

""
abstract type AbstractACRModel <: AbstractPowerModel end


"""
AC power flow Model with rectangular bus voltage variables.

```
@techreport{Cain2012,
  author = {Cain, Mary B and {O' Neill}, Richard P and Castillo, Anya},
  pages = {1--36},
  title = {{History of optimal power flow and Models}},
  url = {https://www.ferc.gov/industries/electric/indus-act/market-planning/opf-papers/acopf-1-history-Model-testing.pdf}
  year = {2012}
}
```
"""
mutable struct ACRPowerModel <: AbstractACRModel @pm_fields end


""
abstract type AbstractACTModel <: AbstractPowerModel end

"""
AC power flow Model (nonconvex) with variables for voltage angle, voltage magnitude squared, and real and imaginary part of voltage crossproducts. A tangens constraint is added to represent meshed networks in an exact manner.
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
mutable struct ACTPowerModel <: AbstractACTModel @pm_fields end






##### Linear Approximations #####



abstract type AbstractDCPModel <: AbstractActivePowerModel end


"""
Linearized 'DC' power flow Model with polar voltage variables.

This model is a basic linear active-power-only approximation, which uses branch susceptance values
`br_b = -br_x / (br_x^2 + br_x^2)` for determining the network phase angles.  Furthermore, transformer
parameters such as tap ratios and phase shifts are not considered as part of this model.

It is important to note that it is also common for active-power-only approximations to use `1/br_x` for
determining the network phase angles, instead of the `br_b` value that is used here.  Small discrepancies
in solutions should be expected when comparing active-power-only approximations across multiple tools.

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
mutable struct DCPPowerModel <: AbstractDCPModel @pm_fields end


abstract type AbstractDCMPPModel <: AbstractDCPModel end

"""
Linearized 'DC' power flow model with polar voltage variables. 

Similar to the DCPPowerModel with the following changes:

- It uses branch susceptance values `br_b = -1 / br_x` for determining the network phase angles.
- Transformer parameters such as tap ratios and phase shifts are considered.

The results should be equal to the results of matpower calculations.
"""
mutable struct DCMPPowerModel <: AbstractDCMPPModel @pm_fields end


abstract type AbstractNFAModel <: AbstractDCPModel end

"""
The an active power only network flow approximation, also known as the transportation model.
"""
mutable struct NFAPowerModel <: AbstractNFAModel @pm_fields end





##### Quadratic Approximations #####


""
abstract type AbstractDCPLLModel <: AbstractDCPModel end

""
mutable struct DCPLLPowerModel <: AbstractDCPLLModel @pm_fields end


""
abstract type AbstractLPACModel <: AbstractPowerModel end

abstract type AbstractLPACCModel <: AbstractLPACModel end

"""
The LPAC Cold-Start AC Power Flow Approximation.

Note that the LPAC Cold-Start model requires the least amount of information
but is also the least accurate variant of the LPAC Models.  If a
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
  journal = {INModels Journal on Computing},
  volume = {26},
  number = {4},
  pages = {718-734},
  year = {2014},
  doi = {10.1287/ijoc.2014.0594},
  eprint = {https://doi.org/10.1287/ijoc.2014.0594}
}
```
"""
mutable struct LPACCPowerModel <: AbstractLPACCModel @pm_fields end




##### Quadratic Relaxations #####

""
abstract type AbstractWRModel <: AbstractPowerModel end

""
abstract type AbstractWRConicModel <: AbstractConicModel end

""
abstract type AbstractSOCWRModel <: AbstractWRModel end

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
mutable struct SOCWRPowerModel <: AbstractSOCWRModel @pm_fields end


""
abstract type AbstractSOCWRConicModel <: AbstractWRConicModel end

"""
Second-order cone relaxation of bus injection model of AC OPF.

This implementation casts the problem as a convex conic problem.
"""
mutable struct SOCWRConicPowerModel <: AbstractSOCWRConicModel @pm_fields end



""
abstract type AbstractQCWRModel <: AbstractWRModel end

abstract type AbstractQCRMPowerModel <: AbstractQCWRModel end

"""
The "Quadratic-Convex" relaxation of the AC power flow equations.
Recursive McCormik relaxations are used for the trilinear terms (i.e. QCRM).
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
mutable struct QCRMPowerModel <: AbstractQCRMPowerModel @pm_fields end


""
abstract type AbstractQCLSModel <: AbstractQCWRModel end

"""
A strengthened version of the "Quadratic-Convex" relaxation of the AC power flow equations.
An extreme-point encoding of trilinar terms is used along with a constraint to link the
lambda variables in multiple trilinar terms (i.e. QCLS).
```
@misc{1809.04565,
  author="Kaarthik Sundar and Harsha Nagarajan and Sidhant Misra and Mowen Lu and Carleton Coffrin and Russell Bent",
  title="Optimization-Based Bound Tightening using a Strengthened QC-Relaxation of the Optimal Power Flow Problem",
  year="2018",
  Eprint = "arXiv:1809.04565",
}
```

The original model derivation is available in,
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
mutable struct QCLSPowerModel <: AbstractQCLSModel @pm_fields end



""
abstract type AbstractSOCBFModel <: AbstractBFQPModel end

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
mutable struct SOCBFPowerModel <: AbstractSOCBFModel @pm_fields end


""
abstract type AbstractSOCBFConicModel <: AbstractBFConicModel end

""
mutable struct SOCBFConicPowerModel <: AbstractSOCBFConicModel @pm_fields end






###### SDP Relaxations ######

""
abstract type AbstractWRMModel <: AbstractConicModel end


""
abstract type AbstractSDPWRMModel <: AbstractWRMModel end

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
mutable struct SDPWRMPowerModel <: AbstractSDPWRMModel @pm_fields end


abstract type AbstractSparseSDPWRMModel <: AbstractSDPWRMModel end

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
mutable struct SparseSDPWRMPowerModel <: AbstractSparseSDPWRMModel @pm_fields end



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

AbstractWRModels = Union{AbstractACTModel, AbstractWRModel, AbstractWRConicModel, AbstractWRMModel}
AbstractWModels = Union{AbstractWRModels, AbstractBFModel}

AbstractAPLossLessModels = Union{DCPPowerModel, DCMPPowerModel, AbstractNFAModel}

AbstractPolarModels = Union{AbstractACPModel, AbstractACTModel, AbstractLPACModel, AbstractDCPModel}

"union of all conic Model branches"
AbstractConicModels = Union{AbstractConicModel, AbstractBFConicModel}
