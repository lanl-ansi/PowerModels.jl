# PowerModels Results
This section presents results of running PowerModel.jl on 
collections of established power network test cases from 
[NESTA](https://arxiv.org/abs/1411.0359). This provides validation of the 
PowerModel.jl as well as a results baseline for these test cases.
All models were solved using [IPOPT](https://link.springer.com/article/10.1007/s10107-004-0559-y).


## Experiment Design
This experiment consists of running the following PowerModels commands,
```
result_ac  = run_opf(case, ACPPowerModel, IpoptSolver(tol=1e-6))
result_soc = run_opf(case, SOCWRPowerModel, IpoptSolver(tol=1e-6))
result_qc  = run_opf(case, QCWRPowerModel, IpoptSolver(tol=1e-6))
```
for each case in the NESTA archive.
If the value of `result["status"]` is `:LocalOptimal` then the
values of `result["objective"]` and `result["solve_time"]` are reported,
otherwise an `err.` or `--` is displayed.  The optimality gap is defined as,
```
soc_gap = 100*(result_ac["objective"] - result_soc["objective"])/result_ac["objective"]
```

It is important to note that the `result["solve_time"]`
value in this experiment includes Julia's JIT time.
Excluding the JIT time will reduce the runtime by 2-5 seconds.


## Software Versions
**[PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl):** v0.3.1-18-ga0785a2, a0785a28341986f92cebeee9a4be3482a6dd4d2e

**[Ipopt.jl](https://github.com/JuliaOpt/Ipopt.jl):** v0.2.6, 959b9c67e396a6e2307fc022d26b0d95692ee6a4

**[NESTA](https://github.com/nicta/nesta):** v0.6.1, 466cd045d852c8c2cd86167b91ad8fa842ddf3da

**Hardware:** Dual Intel 2.10GHz CPUs, 128GB RAM


## Typical Operating Conditions (TYP)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_cc | 3 | 3 | 2.0756e+02 | 1.55 | 1.62 | 5 | 2 | 2 |
| nesta_case3_cgs | 3 | 3 | 1.0171e+02 | 1.69 | 1.69 | 5 | 2 | 2 |
| nesta_case3_lmbd | 3 | 3 | 5.8126e+03 | 1.22 | 1.32 | 5 | 2 | 2 |
| nesta_case3_ch | 3 | 5 | 9.8740e+01 | 100.01 | 100.01 | 5 | 2 | 2 |
| nesta_case4_gs | 4 | 4 | 1.5643e+02 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case5_pjm | 5 | 6 | 1.7552e+04 | 14.55 | 14.55 | 5 | 2 | 2 |
| nesta_case5_lsdp | 5 | 7 | 2.3989e+03 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case6_c | 6 | 7 | 2.3206e+01 | 0.30 | 0.30 | 5 | 2 | 2 |
| nesta_case6_ww | 6 | 11 | 3.1440e+03 | 0.62 | 0.63 | 5 | 3 | 2 |
| nesta_case7_lsdp | 7 | 9 | 1.0344e+02 | 0.16 | 0.16 | 5 | 2 | 2 |
| nesta_case9_wscc | 9 | 9 | 5.2967e+03 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case14_ieee | 14 | 20 | 2.4405e+02 | 0.11 | 0.11 | 5 | 2 | 2 |
| nesta_case24_ieee_rts | 24 | 38 | 6.3352e+04 | 0.02 | 0.02 | 5 | 3 | 3 |
| nesta_case29_edin | 29 | 99 | 2.9895e+04 | 0.10 | 0.12 | 5 | 3 | 3 |
| nesta_case30_as | 30 | 41 | 8.0313e+02 | 0.06 | 0.06 | 5 | 2 | 3 |
| nesta_case30_fsr | 30 | 41 | 5.7577e+02 | 0.39 | 0.39 | 5 | 3 | 3 |
| nesta_case30_ieee | 30 | 41 | 2.0497e+02 | 15.65 | 15.89 | 5 | 2 | 2 |
| nesta_case30_test | 30 | 44 | 6.1510e+02 | 7.05 | 7.05 | 5 | 3 | 3 |
| nesta_case39_epri | 39 | 46 | 9.6506e+04 | 0.05 | 0.05 | 5 | 3 | 3 |
| nesta_case57_ieee | 57 | 80 | 1.1433e+03 | 0.07 | 0.07 | 5 | 3 | 2 |
| nesta_case73_ieee_rts | 73 | 120 | 1.8976e+05 | 0.04 | 0.04 | 5 | 3 | 3 |
| nesta_case89_pegase | 89 | 210 | 5.8198e+03 | 0.17 | 0.17 | 5 | 4 | 3 |
| nesta_case118_ieee | 118 | 186 | 3.7186e+03 | 1.57 | 1.83 | 5 | 3 | 3 |
| nesta_case162_ieee_dtc | 162 | 284 | 4.2302e+03 | 3.96 | 4.03 | 6 | 4 | 3 |
| nesta_case189_edin | 189 | 206 | 8.4929e+02 | 0.22 | 0.22 | 5 | 4 | 3 |
| nesta_case300_ieee | 300 | 411 | 1.6891e+04 | 1.18 | 1.18 | 6 | 5 | 3 |
| nesta_case1354_pegase | 1354 | 1991 | 7.4069e+04 | 0.08 | 0.08 | 10 | 23 | 24 |
| nesta_case1397sp_eir | 1418 | 1919 | 3.8890e+03 | 0.69 | 0.94 | 10 | 20 | 9 |
| nesta_case1394sop_eir | 1418 | 1920 | 1.3668e+03 | 0.58 | 0.83 | 9 | 29 | 9 |
| nesta_case1460wp_eir | 1481 | 1988 | 4.6402e+03 | 0.65 | 0.89 | 10 | 21 | 10 |
| nesta_case2224_edin | 2224 | 3207 | 3.8128e+04 | 6.03 | 6.09 | 18 | 46 | 15 |
| nesta_case2383wp_mp | 2383 | 2896 | 1.8685e+06 | 0.99 | 1.05 | 17 | 32 | 19 |
| nesta_case2736sp_mp | 2736 | 3504 | 1.3079e+06 | 0.29 | 0.30 | 15 | 35 | 15 |
| nesta_case2737sop_mp | 2737 | 3506 | 7.7763e+05 | 0.25 | 0.26 | 13 | 31 | 12 |
| nesta_case2746wop_mp | 2746 | 3514 | 1.2083e+06 | 0.36 | 0.37 | 14 | 32 | 14 |
| nesta_case2746wp_mp | 2746 | 3514 | 1.6318e+06 | 0.32 | 0.33 | 15 | 33 | 15 |
| nesta_case2869_pegase | 2869 | 4582 | 1.3400e+05 | 0.09 | 0.09 | 17 | 55 | 47 |
| nesta_case3012wp_mp | 3012 | 3572 | 2.6008e+06 | 0.98 | 1.03 | 21 | 46 | 25 |
| nesta_case3120sp_mp | 3120 | 3693 | 2.1457e+06 | 0.54 | 0.55 | 19 | 45 | 19 |
| nesta_case3375wp_mp | 3375 | 4161 | 7.4357e+06 | 0.50 | 0.52 | 25 | 347 | 73 |
| nesta_case9241_pegase | 9241 | 16049 | 3.1591e+05 | err. | 1.64 | 173 | err. | 582 |


## Congested Operating Conditions (API)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd__api | 3 | 3 | 3.6774e+02 | -- | 2.38 | 5 | 2 | 2 |
| nesta_case4_gs__api | 4 | 4 | 7.6727e+02 | 0.66 | 0.66 | 5 | 2 | 2 |
| nesta_case5_pjm__api | 5 | 6 | 2.9985e+03 | 0.29 | 0.29 | 5 | 2 | 2 |
| nesta_case6_c__api | 6 | 7 | 8.1440e+02 | 0.35 | 0.35 | 5 | 2 | 2 |
| nesta_case9_wscc__api | 9 | 9 | 6.5660e+02 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case14_ieee__api | 14 | 20 | 3.2556e+02 | 1.35 | 1.35 | 5 | 2 | 2 |
| nesta_case24_ieee_rts__api | 24 | 38 | 6.4364e+03 | 11.89 | 20.76 | 5 | 3 | 2 |
| nesta_case29_edin__api | 29 | 99 | 2.9547e+05 | 0.42 | 0.43 | 5 | 3 | 3 |
| nesta_case30_as__api | 30 | 41 | 5.7113e+02 | 4.76 | 4.76 | 5 | 3 | 2 |
| nesta_case30_fsr__api | 30 | 41 | 3.7214e+02 | 45.97 | 45.97 | 5 | 3 | 2 |
| nesta_case30_ieee__api | 30 | 41 | 4.1553e+02 | 1.01 | 1.01 | 5 | 3 | 2 |
| nesta_case39_epri__api | 39 | 46 | 7.4663e+03 | 2.98 | 3.00 | 5 | 3 | 2 |
| nesta_case57_ieee__api | 57 | 80 | 1.4307e+03 | 0.21 | 0.21 | 5 | 3 | 2 |
| nesta_case73_ieee_rts__api | 73 | 120 | 2.0069e+04 | 11.19 | 14.40 | 5 | 3 | 3 |
| nesta_case89_pegase__api | 89 | 210 | 4.2880e+03 | 20.39 | 20.43 | 6 | 4 | 3 |
| nesta_case118_ieee__api | 118 | 186 | 1.0315e+04 | 43.72 | 43.92 | 6 | 3 | 3 |
| nesta_case162_ieee_dtc__api | 162 | 284 | 6.1117e+03 | 1.26 | 1.35 | 6 | 4 | 3 |
| nesta_case189_edin__api | 189 | 206 | 2.0098e+03 | 5.67 | 5.67 | 6 | 4 | 3 |
| nesta_case300_ieee__api | 300 | 411 | 1.9879e+04 | 0.64 | 0.72 | 6 | 5 | 3 |
| nesta_case1354_pegase__api | 1354 | 1991 | 5.2487e+04 | 0.37 | 0.38 | 12 | 24 | 10 |
| nesta_case1397sp_eir__api | 1418 | 1919 | 6.6699e+03 | 1.09 | 1.32 | 11 | 28 | 10 |
| nesta_case1394sop_eir__api | 1418 | 1920 | 2.8348e+03 | 0.81 | 0.87 | 12 | 30 | 10 |
| nesta_case1460wp_eir__api | 1481 | 1988 | 6.4527e+03 | 1.55 | 1.70 | 10 | 20 | 10 |
| nesta_case2224_edin__api | 2224 | 3207 | 4.5879e+04 | 3.57 | 3.58 | 19 | 45 | 15 |
| nesta_case2383wp_mp__api | 2383 | 2896 | 2.3503e+04 | 0.74 | 0.75 | 14 | 28 | 12 |
| nesta_case2736sp_mp__api | 2736 | 3504 | 2.5898e+04 | 2.19 | 2.19 | 15 | 32 | 15 |
| nesta_case2737sop_mp__api | 2737 | 3506 | 2.1673e+04 | 0.40 | 0.40 | 15 | 34 | 14 |
| nesta_case2746wop_mp__api | 2746 | 3514 | 2.2813e+04 | 0.49 | 0.49 | 14 | 33 | 14 |
| nesta_case2746wp_mp__api | 2746 | 3514 | 2.5976e+04 | 0.58 | 0.59 | 15 | 33 | 14 |
| nesta_case2869_pegase__api | 2869 | 4582 | 9.7458e+04 | 0.76 | 0.76 | 24 | 63 | 23 |
| nesta_case3012wp_mp__api | 3012 | 3572 | 2.8422e+04 | 1.04 | 1.07 | 21 | 71 | 50 |
| nesta_case3120sp_mp__api | 3120 | 3693 | 2.2835e+04 | 3.69 | 3.70 | 21 | 46 | 17 |
| nesta_case3375wp_mp__api | 3375 | 4161 | 4.8969e+04 | 0.68 | 0.69 | 23 | 217 | 90 |
| nesta_case9241_pegase__api | 9241 | 16049 | 2.3734e+05 | err. | 2.54 | 150 | err. | 136 |


## Small Angle Difference Conditions (SAD)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd__sad | 3 | 3 | 5.9927e+03 | 0.79 | 4.28 | 5 | 2 | 2 |
| nesta_case4_gs__sad | 4 | 4 | 3.2402e+02 | 0.78 | 4.88 | 5 | 2 | 2 |
| nesta_case5_pjm__sad | 5 | 6 | 2.6423e+04 | 1.10 | 3.61 | 5 | 2 | 2 |
| nesta_case6_c__sad | 6 | 7 | 2.4428e+01 | 0.40 | 1.36 | 5 | 2 | 2 |
| nesta_case6_ww__sad | 6 | 11 | 3.1495e+03 | 0.21 | 0.81 | 5 | 2 | 2 |
| nesta_case9_wscc__sad | 9 | 9 | 5.5901e+03 | 0.37 | 1.46 | 5 | 2 | 2 |
| nesta_case14_ieee__sad | 14 | 20 | 2.4415e+02 | 0.06 | 0.06 | 5 | 2 | 2 |
| nesta_case24_ieee_rts__sad | 24 | 38 | 7.9805e+04 | 3.46 | 11.25 | 5 | 3 | 3 |
| nesta_case29_edin__sad | 29 | 99 | 4.6933e+04 | 20.41 | 34.45 | 6 | 3 | 3 |
| nesta_case30_as__sad | 30 | 41 | 9.1444e+02 | 3.05 | 9.02 | 5 | 3 | 2 |
| nesta_case30_fsr__sad | 30 | 41 | 5.7773e+02 | 0.56 | 0.62 | 5 | 3 | 2 |
| nesta_case30_ieee__sad | 30 | 41 | 2.0511e+02 | 3.96 | 5.64 | 5 | 2 | 2 |
| nesta_case39_epri__sad | 39 | 46 | 9.7219e+04 | -0.03 | 0.00 | 5 | 3 | 2 |
| nesta_case57_ieee__sad | 57 | 80 | 1.1439e+03 | 0.10 | 0.12 | 5 | 3 | 3 |
| nesta_case73_ieee_rts__sad | 73 | 120 | 2.3524e+05 | 3.16 | 8.18 | 5 | 3 | 3 |
| nesta_case89_pegase__sad | 89 | 210 | 5.8270e+03 | 0.14 | 0.16 | 5 | 3 | 3 |
| nesta_case118_ieee__sad | 118 | 186 | 4.3242e+03 | 8.11 | 12.56 | 5 | 3 | 3 |
| nesta_case162_ieee_dtc__sad | 162 | 284 | 4.3692e+03 | 6.75 | 7.08 | 6 | 4 | 3 |
| nesta_case189_edin__sad | 189 | 206 | 9.1461e+02 | 0.43 | 0.45 | 6 | 4 | 3 |
| nesta_case300_ieee__sad | 300 | 411 | 1.6910e+04 | -- | -- | 6 | 76 | 34 |
| nesta_case1354_pegase__sad | 1354 | 1991 | 7.4072e+04 | -- | -- | 10 | 562 | 385 |
| nesta_case1397sp_eir__sad | 1418 | 1919 | 4.5819e+03 | 13.70 | 13.87 | 11 | 22 | 8 |
| nesta_case1394sop_eir__sad | 1418 | 1920 | 1.5776e+03 | 10.74 | 11.77 | 10 | 38 | 9 |
| nesta_case1460wp_eir__sad | 1481 | 1988 | 5.3677e+03 | 0.73 | 0.92 | 10 | 18 | 9 |
| nesta_case2224_edin__sad | 2224 | 3207 | 3.8385e+04 | -- | -- | 19 | 181 | 208 |
| nesta_case2383wp_mp__sad | 2383 | 2896 | 1.9353e+06 | 2.89 | 3.99 | 21 | 32 | 19 |
| nesta_case2736sp_mp__sad | 2736 | 3504 | 1.3370e+06 | 2.00 | 2.34 | 20 | 35 | 17 |
| nesta_case2737sop_mp__sad | 2737 | 3506 | 7.9541e+05 | 2.21 | 2.43 | 19 | 31 | 13 |
| nesta_case2746wop_mp__sad | 2746 | 3514 | 1.2420e+06 | 2.47 | 2.94 | 19 | 27 | 14 |
| nesta_case2746wp_mp__sad | 2746 | 3514 | 1.6722e+06 | 1.82 | 2.44 | 18 | 33 | 17 |
| nesta_case2869_pegase__sad | 2869 | 4582 | 1.3407e+05 | 0.13 | 0.15 | 21 | 62 | 166 |
| nesta_case3012wp_mp__sad | 3012 | 3572 | 2.6354e+06 | 1.87 | 2.11 | 25 | 50 | 21 |
| nesta_case3120sp_mp__sad | 3120 | 3693 | 2.2038e+06 | 2.54 | 2.77 | 28 | 56 | 21 |
| nesta_case3375wp_mp__sad | 3375 | 4161 | 7.4364e+06 | -- | -- | 28 | 2270 | 678 |
| nesta_case9241_pegase__sad | 9241 | 16049 | 3.1593e+05 | err. | 0.81 | 169 | err. | 2280 |


## Radial Topologies (RAD)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case9_kds__rad | 9 | 8 | inf. | -- | -- | 5 | 2 | 2 |
| nesta_case9_l_kds__rad | 9 | 8 | inf. | -- | -- | 5 | 2 | 2 |
| nesta_case30_fsr_kds__rad | 30 | 29 | 6.1904e+02 | 1.74 | 1.74 | 5 | 3 | 2 |
| nesta_case30_fsr_l_kds__rad | 30 | 29 | 4.4584e+02 | 2.25 | 2.25 | 5 | 3 | 2 |
| nesta_case30_kds__rad | 30 | 29 | 4.7943e+03 | 11.47 | 11.47 | 5 | 3 | 3 |
| nesta_case30_l_kds__rad | 30 | 29 | 4.5623e+03 | 33.47 | 33.47 | 5 | 3 | 2 |
| nesta_case57_kds__rad | 57 | 56 | 1.2101e+04 | 13.58 | 13.58 | 5 | 3 | 3 |
| nesta_case57_l_kds__rad | 57 | 56 | 1.0173e+04 | 17.43 | 17.43 | 5 | 3 | 2 |


## Non-Convex Optimization Cases (NCO)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case9_na_cao__nco | 9 | 9 | -2.1243e+02 | -15.05 | -18.12 | 5 | 2 | 2 |
| nesta_case9_nb_cao__nco | 9 | 9 | -2.4742e+02 | -15.62 | -19.31 | 5 | 2 | 2 |
| nesta_case14_s_cao__nco | 14 | 20 | 9.6704e+03 | 3.83 | 3.83 | 5 | 3 | 2 |


