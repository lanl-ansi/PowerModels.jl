# Formulation Details

## Notes on the mathematical model
Phase angle difference (PAD) constraints are not always considered in the canonical OPF problem. Nevertheless they are included in PowerModels mathematical model.

"Lifted nonlinear cuts" are used to improve the accuracy of PAD constraints for all formulations in the lifted S-W variable space:
- Coffrin, C., Hijazi, H., & Van Hentenryck, P. (2017). Strengthening the SDP relaxation of ac power flows with convex envelopes, bound tightening, and valid inequalities. IEEE Trans. Power Syst., 32(5), 3549–3558. https://doi.org/10.1109/TPWRS.2016.2634586

It is currently assumed thermal limits are defined in apparent power (not current).


## `ACPPowerModel`

## `ACRPowerModel`

## `ACTPowerModel`
- Jabr, R. A. (2008). Optimal power flow using an extended conic quadratic formulation. IEEE Trans. Power Syst., 23(3), 1000–1008.

## `DCPPowerModel`

## `SDPWRMPowerModel`
First use of 'W' to represent voltage products in BIM SDP:
- Sojoudi, S., & Lavaei, J. (2012). Physics of power networks makes hard optimization problems easy to solve. In IEEE Power and Energy Soc. General Meeting (pp. 1–8). San Diego, CA. https://doi.org/10.1109/PESGM.2012.6345272


## `SOCWRPowerModel`
- Jabr, R. A. (2006). Radial distribution load flow using conic programming. IEEE Trans. Power Syst., 21(3), 2005–2006. https://doi.org/10.1109/TPWRS.2006.879234


## `QCWRPowerModel`
- Hijazi, H., Coffrin, C., & Van Hentenryck, P. (2016). Convex quadratic relaxations for mixed-integer nonlinear programs in power systems. Math. Prog. Comp., 1–47.

## `QCWRTriPowerModel`
Same as `QCWRPowerModel` but with McCormick's envelopes for product of *three* variables.


## `SOCBFPowerModel`
Original work:
- Farivar, M. and Low, S. H. (2012) “Branch flow model: Relaxations and convexification,” in Proc. 51st IEEE Conf. Decision and Control.
Extended with transformers:
- Coffrin, C., Hijazi, H. L., & Van Hentenryck, P. (2015). DistFlow Extensions for AC Transmission Systems, 1–20. Retrieved from http://arxiv.org/abs/1506.04773
