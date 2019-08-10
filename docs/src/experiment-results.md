# PowerModels Experiment Results
This section presents results of running PowerModel.jl on collections of established power network test cases from [NESTA](https://arxiv.org/abs/1411.0359). This provides validation of the PowerModel.jl as well as a results baseline for these test cases. All models were solved using [IPOPT](https://link.springer.com/article/10.1007/s10107-004-0559-y).


## Experiment Design
This experiment consists of running the following PowerModels commands,
```
result_ac  = run_opf(case,   ACPPowerModel, with_optimizer(Ipopt.Optimizer, tol=1e-6))
result_soc = run_opf(case, SOCWRPowerModel, with_optimizer(Ipopt.Optimizer, tol=1e-6))
result_qc  = run_opf(case,  QCWRPowerModel, with_optimizer(Ipopt.Optimizer, tol=1e-6))
```
for each `case` in the NESTA archive. If the value of `result["termination_status"]` is `LOCALLY_SOLVED` then the values of `result["objective"]` and `result["solve_time"]` are reported, otherwise an `err.` or `--` is displayed. A value of `n.d.` indicates that no data was available. The optimality gap is defined as,
```
soc_gap = 100*(result_ac["objective"] - result_soc["objective"])/result_ac["objective"]
```

It is important to note that the `result["solve_time"]` value in this experiment does not include Julia's JIT time, about 2-5 seconds. The results were computed using the [HSL](http://www.hsl.rl.ac.uk/ipopt/) ma27 solver in IPOPT. The default linear solver provided with Ipopt.jl will increase the runtime by 2-6x.


## Software Versions
**[PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl):** v0.3.4-27-g115de85, 115de853fd4103b712d051e902540e7fa2b627be

**[Ipopt.jl](https://github.com/JuliaOpt/Ipopt.jl):** v0.2.6, 959b9c67e396a6e2307fc022d26b0d95692ee6a4

**[NESTA](https://github.com/nicta/nesta):** v0.7.0-1-gb10c1e1, b10c1e1ea0a4259f91a3efd50fbad72b22d2fb9f

**Hardware:** Dual Intel 2.10GHz CPUs, 128GB RAM


## Typical Operating Conditions (TYP)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd | 3 | 3 | 5.8126e+03 | 1.22 | 1.32 | <1 | <1 | <1 |
| nesta_case4_gs | 4 | 4 | 1.5643e+02 | 0.01 | 0.01 | <1 | <1 | <1 |
| nesta_case5_pjm | 5 | 6 | 1.7552e+04 | 14.55 | 14.55 | <1 | <1 | <1 |
| nesta_case6_c | 6 | 7 | 2.3206e+01 | 0.30 | 0.30 | <1 | <1 | <1 |
| nesta_case6_ww | 6 | 11 | 3.1440e+03 | 0.62 | 0.63 | <1 | <1 | <1 |
| nesta_case9_wscc | 9 | 9 | 5.2967e+03 | 0.01 | 0.01 | <1 | <1 | <1 |
| nesta_case14_ieee | 14 | 20 | 2.4405e+02 | 0.11 | 0.11 | <1 | <1 | <1 |
| nesta_case24_ieee_rts | 24 | 38 | 6.3352e+04 | 0.02 | 0.02 | <1 | <1 | <1 |
| nesta_case29_edin | 29 | 99 | 2.9895e+04 | 0.10 | 0.12 | <1 | <1 | <1 |
| nesta_case30_as | 30 | 41 | 8.0313e+02 | 0.06 | 0.06 | <1 | <1 | <1 |
| nesta_case30_fsr | 30 | 41 | 5.7577e+02 | 0.39 | 0.39 | <1 | <1 | <1 |
| nesta_case30_ieee | 30 | 41 | 2.0497e+02 | 15.65 | 15.89 | <1 | <1 | <1 |
| nesta_case39_epri | 39 | 46 | 9.6506e+04 | 0.05 | 0.05 | <1 | <1 | <1 |
| nesta_case57_ieee | 57 | 80 | 1.1433e+03 | 0.07 | 0.07 | <1 | <1 | <1 |
| nesta_case73_ieee_rts | 73 | 120 | 1.8976e+05 | 0.04 | 0.04 | <1 | <1 | <1 |
| nesta_case89_pegase | 89 | 210 | 5.8198e+03 | 0.17 | 0.17 | <1 | <1 | <1 |
| nesta_case118_ieee | 118 | 186 | 3.7186e+03 | 1.57 | 1.83 | <1 | <1 | <1 |
| nesta_case162_ieee_dtc | 162 | 284 | 4.2302e+03 | 3.96 | 4.03 | <1 | <1 | <1 |
| nesta_case189_edin | 189 | 206 | 8.4929e+02 | 0.22 | 0.22 | <1 | <1 | <1 |
| nesta_case240_wecc | 240 | 448 | 7.5136e+04 | 5.27 | 5.74 | 4 | 4 | 2 |
| nesta_case300_ieee | 300 | 411 | 1.6891e+04 | 1.18 | 1.18 | <1 | <1 | <1 |
| nesta_case1354_pegase | 1354 | 1991 | 7.4069e+04 | 0.08 | 0.08 | 4 | 11 | 13 |
| nesta_case1397sp_eir | 1418 | 1919 | 3.8890e+03 | 0.69 | 0.94 | 4 | 6 | 2 |
| nesta_case1394sop_eir | 1418 | 1920 | 1.3668e+03 | 0.58 | 0.83 | 3 | 6 | 2 |
| nesta_case1460wp_eir | 1481 | 1988 | 4.6402e+03 | 0.65 | 0.89 | 4 | 7 | 3 |
| nesta_case1888_rte | 1888 | 2531 | 5.9805e+04 | 0.38 | 0.38 | 26 | 7 | 46 |
| nesta_case1951_rte | 1951 | 2596 | 8.1738e+04 | 0.07 | 0.08 | 16 | 9 | 10 |
| nesta_case2224_edin | 2224 | 3207 | 3.8128e+04 | 6.03 | 6.09 | 10 | 16 | 5 |
| nesta_case2383wp_mp | 2383 | 2896 | 1.8685e+06 | 0.99 | 1.05 | 10 | 11 | 6 |
| nesta_case2736sp_mp | 2736 | 3504 | 1.3079e+06 | 0.29 | 0.30 | 8 | 12 | 5 |
| nesta_case2737sop_mp | 2737 | 3506 | 7.7763e+05 | 0.25 | 0.26 | 7 | 10 | 4 |
| nesta_case2746wop_mp | 2746 | 3514 | 1.2083e+06 | 0.36 | 0.37 | 7 | 11 | 4 |
| nesta_case2746wp_mp | 2746 | 3514 | 1.6318e+06 | 0.32 | 0.33 | 8 | 11 | 5 |
| nesta_case2848_rte | 2848 | 3776 | 5.3022e+04 | 0.08 | 0.08 | 61 | 10 | 48 |
| nesta_case2868_rte | 2868 | 3808 | 7.9795e+04 | 0.07 | 0.07 | 31 | 13 | 9 |
| nesta_case2869_pegase | 2869 | 4582 | 1.3400e+05 | 0.09 | 0.09 | 10 | 20 | 55 |
| nesta_case3012wp_mp | 3012 | 3572 | 2.6008e+06 | 0.98 | 1.03 | 12 | 16 | 9 |
| nesta_case3120sp_mp | 3120 | 3693 | 2.1457e+06 | 0.54 | 0.55 | 12 | 17 | 6 |
| nesta_case3375wp_mp | 3375 | 4161 | 7.4357e+06 | 0.50 | 0.52 | 15 | 496 | 26 |
| nesta_case6468_rte | 6468 | 9000 | 8.6829e+04 | 0.23 | 0.23 | 99 | 64 | 464 |
| nesta_case6470_rte | 6470 | 9005 | 9.8348e+04 | 0.17 | 0.18 | 80 | 56 | 39 |
| nesta_case6495_rte | 6495 | 9019 | 1.0632e+05 | 0.49 | 0.49 | 55 | 53 | 37 |
| nesta_case6515_rte | 6515 | 9037 | 1.0987e+05 | 0.43 | 0.43 | 55 | 45 | 321 |
| nesta_case9241_pegase | 9241 | 16049 | 3.1591e+05 | 1.02 | 1.64 | 93 | 109 | 298 |
| nesta_case13659_pegase | 13659 | 20467 | 3.8612e+05 | 0.94 | 1.43 | 288 | 157 | 375 |


## Congested Operating Conditions (API)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd__api | 3 | 3 | 3.6744e+02 | 1.79 | 3.26 | <1 | <1 | <1 |
| nesta_case4_gs__api | 4 | 4 | 7.6667e+02 | 0.64 | 0.64 | <1 | <1 | <1 |
| nesta_case5_pjm__api | 5 | 6 | 2.9963e+03 | 0.27 | 0.27 | <1 | <1 | <1 |
| nesta_case6_c__api | 6 | 7 | 8.1387e+02 | 0.34 | 0.34 | <1 | <1 | <1 |
| nesta_case9_wscc__api | 9 | 9 | 6.5623e+02 | 0.01 | 0.01 | <1 | <1 | <1 |
| nesta_case14_ieee__api | 14 | 20 | 3.2513e+02 | 1.27 | 1.27 | <1 | <1 | <1 |
| nesta_case24_ieee_rts__api | 24 | 38 | 6.4267e+03 | 11.88 | 20.70 | <1 | <1 | <1 |
| nesta_case29_edin__api | 29 | 99 | 2.9529e+05 | 0.41 | 0.41 | <1 | <1 | <1 |
| nesta_case30_as__api | 30 | 41 | 5.7008e+02 | 4.64 | 4.64 | <1 | <1 | <1 |
| nesta_case30_fsr__api | 30 | 41 | 3.6656e+02 | 45.20 | 45.20 | <1 | <1 | <1 |
| nesta_case30_ieee__api | 30 | 41 | 4.1499e+02 | 0.93 | 0.93 | <1 | <1 | <1 |
| nesta_case39_epri__api | 39 | 46 | 7.4604e+03 | 2.98 | 3.00 | <1 | <1 | <1 |
| nesta_case57_ieee__api | 57 | 80 | 1.4307e+03 | 0.21 | 0.21 | <1 | <1 | <1 |
| nesta_case73_ieee_rts__api | 73 | 120 | 1.9995e+04 | 10.98 | 14.20 | <1 | <1 | <1 |
| nesta_case89_pegase__api | 89 | 210 | 4.2554e+03 | 19.83 | 19.88 | <1 | <1 | <1 |
| nesta_case118_ieee__api | 118 | 186 | 1.0270e+04 | 43.50 | 43.70 | <1 | <1 | <1 |
| nesta_case162_ieee_dtc__api | 162 | 284 | 6.1069e+03 | 1.25 | 1.34 | <1 | <1 | <1 |
| nesta_case189_edin__api | 189 | 206 | 1.9141e+03 | 1.70 | 1.70 | <1 | <1 | <1 |
| nesta_case240_wecc__api | 240 | 448 | 1.4267e+05 | 0.58 | 0.70 | 4 | 6 | 2 |
| nesta_case300_ieee__api | 300 | 411 | 1.9868e+04 | 0.64 | 0.71 | <1 | <1 | <1 |
| nesta_case1354_pegase__api | 1354 | 1991 | 5.2449e+04 | 0.36 | 0.36 | 6 | 9 | 4 |
| nesta_case1397sp_eir__api | 1418 | 1919 | 6.6658e+03 | 1.07 | 1.29 | 5 | 5 | 3 |
| nesta_case1394sop_eir__api | 1418 | 1920 | 3.3776e+03 | 0.37 | 0.39 | 6 | 6 | 3 |
| nesta_case1460wp_eir__api | 1481 | 1988 | 6.4449e+03 | 1.54 | 1.69 | 4 | 7 | 3 |
| nesta_case1888_rte__api | 1888 | 2531 | 5.8546e+04 | 0.71 | 0.71 | 9 | 14 | 6 |
| nesta_case1951_rte__api | 1951 | 2596 | 7.5639e+04 | 0.13 | 0.14 | 11 | 12 | 41 |
| nesta_case2224_edin__api | 2224 | 3207 | 4.4435e+04 | 2.41 | 2.42 | 11 | 15 | 5 |
| nesta_case2383wp_mp__api | 2383 | 2896 | 2.3489e+04 | 0.74 | 0.75 | 7 | 9 | 4 |
| nesta_case2736sp_mp__api | 2736 | 3504 | 2.5884e+04 | 2.18 | 2.19 | 8 | 11 | 5 |
| nesta_case2737sop_mp__api | 2737 | 3506 | 2.1675e+04 | 0.39 | 0.40 | 8 | 11 | 5 |
| nesta_case2746wop_mp__api | 2746 | 3514 | 2.2803e+04 | 0.49 | 0.49 | 8 | 11 | 4 |
| nesta_case2746wp_mp__api | 2746 | 3514 | 2.5964e+04 | 0.58 | 0.59 | 7 | 10 | 4 |
| nesta_case2848_rte__api | 2848 | 3776 | 4.4032e+04 | 0.23 | 0.23 | 25 | 18 | 10 |
| nesta_case2868_rte__api | 2868 | 3808 | 7.5506e+04 | 0.20 | 0.21 | 32 | 22 | 8 |
| nesta_case2869_pegase__api | 2869 | 4582 | 9.8415e+04 | 0.59 | 0.60 | 15 | 22 | 9 |
| nesta_case3012wp_mp__api | 3012 | 3572 | 2.8334e+04 | 1.04 | 1.07 | 9 | 12 | 6 |
| nesta_case3120sp_mp__api | 3120 | 3693 | 2.3715e+04 | 2.73 | 2.75 | 12 | 14 | 5 |
| nesta_case3375wp_mp__api | 3375 | 4161 | 4.8939e+04 | 0.68 | 0.69 | 13 | 57 | 51 |
| nesta_case6468_rte__api | 6468 | 9000 | 6.8149e+04 | 0.89 | 0.91 | 124 | 59 | 246 |
| nesta_case6470_rte__api | 6470 | 9005 | 9.0583e+04 | 0.80 | 0.82 | 63 | 50 | 22 |
| nesta_case6495_rte__api | 6495 | 9019 | 8.8944e+04 | 1.24 | 1.26 | 64 | 47 | 24 |
| nesta_case6515_rte__api | 6515 | 9037 | 9.7217e+04 | 1.07 | 1.10 | 72 | 51 | 25 |
| nesta_case9241_pegase__api | 9241 | 16049 | 2.3890e+05 | 1.67 | 2.45 | 88 | 108 | 42 |
| nesta_case13659_pegase__api | 13659 | 20467 | 3.0285e+05 | 1.13 | 1.74 | 155 | 148 | 76 |


## Small Angle Difference Conditions (SAD)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd__sad | 3 | 3 | 5.9593e+03 | 1.42 | 3.75 | <1 | <1 | <1 |
| nesta_case4_gs__sad | 4 | 4 | 3.1584e+02 | 1.53 | 4.53 | <1 | <1 | <1 |
| nesta_case5_pjm__sad | 5 | 6 | 2.6115e+04 | 0.99 | 3.62 | <1 | <1 | <1 |
| nesta_case6_c__sad | 6 | 7 | 2.4376e+01 | 0.43 | 1.32 | <1 | <1 | <1 |
| nesta_case6_ww__sad | 6 | 11 | 3.1463e+03 | 0.18 | 0.70 | <1 | <1 | <1 |
| nesta_case9_wscc__sad | 9 | 9 | 5.5283e+03 | 0.54 | 1.57 | <1 | <1 | <1 |
| nesta_case14_ieee__sad | 14 | 20 | 2.4405e+02 | 0.05 | 0.08 | <1 | <1 | <1 |
| nesta_case24_ieee_rts__sad | 24 | 38 | 7.6943e+04 | 2.93 | 9.56 | <1 | <1 | <1 |
| nesta_case29_edin__sad | 29 | 99 | 4.1258e+04 | 16.57 | 25.91 | <1 | <1 | <1 |
| nesta_case30_as__sad | 30 | 41 | 8.9749e+02 | 2.32 | 7.88 | <1 | <1 | <1 |
| nesta_case30_fsr__sad | 30 | 41 | 5.7679e+02 | 0.41 | 0.47 | <1 | <1 | <1 |
| nesta_case30_ieee__sad | 30 | 41 | 2.0497e+02 | 4.17 | 6.79 | <1 | <1 | <1 |
| nesta_case39_epri__sad | 39 | 46 | 9.6745e+04 | 0.05 | 0.08 | <1 | <1 | <1 |
| nesta_case57_ieee__sad | 57 | 80 | 1.1433e+03 | 0.05 | 0.07 | <1 | <1 | <1 |
| nesta_case73_ieee_rts__sad | 73 | 120 | 2.2775e+05 | 2.54 | 6.75 | <1 | <1 | <1 |
| nesta_case89_pegase__sad | 89 | 210 | 5.8198e+03 | 0.14 | 0.15 | <1 | <1 | <1 |
| nesta_case118_ieee__sad | 118 | 186 | 4.1067e+03 | 4.62 | 8.29 | <1 | <1 | <1 |
| nesta_case162_ieee_dtc__sad | 162 | 284 | 4.2535e+03 | 4.31 | 4.56 | <1 | <1 | <1 |
| nesta_case189_edin__sad | 189 | 206 | 8.6482e+02 | 0.99 | 0.99 | <1 | <1 | <1 |
| nesta_case240_wecc__sad | 240 | 448 | 7.6495e+04 | 5.29 | 7.41 | 4 | 4 | 2 |
| nesta_case300_ieee__sad | 300 | 411 | 1.6894e+04 | 1.10 | 1.18 | <1 | <1 | <1 |
| nesta_case1354_pegase__sad | 1354 | 1991 | 7.4070e+04 | 0.07 | 0.08 | 4 | 7 | 6 |
| nesta_case1397sp_eir__sad | 1418 | 1919 | 4.2378e+03 | 7.27 | 7.42 | 5 | 8 | 3 |
| nesta_case1394sop_eir__sad | 1418 | 1920 | 1.4493e+03 | 3.33 | 4.34 | 4 | 5 | 3 |
| nesta_case1460wp_eir__sad | 1481 | 1988 | 5.3370e+03 | 0.84 | 1.03 | 4 | 6 | 3 |
| nesta_case1888_rte__sad | 1888 | 2531 | 5.9806e+04 | 0.37 | 0.38 | 28 | 8 | 101 |
| nesta_case1951_rte__sad | 1951 | 2596 | 8.1786e+04 | 0.11 | 0.13 | 17 | 10 | 9 |
| nesta_case2224_edin__sad | 2224 | 3207 | 3.8265e+04 | 5.52 | 6.10 | 11 | 15 | 5 |
| nesta_case2383wp_mp__sad | 2383 | 2896 | 1.9165e+06 | 2.16 | 3.13 | 12 | 11 | 6 |
| nesta_case2736sp_mp__sad | 2736 | 3504 | 1.3294e+06 | 1.53 | 1.80 | 11 | 12 | 5 |
| nesta_case2737sop_mp__sad | 2737 | 3506 | 7.9266e+05 | 1.92 | 2.10 | 10 | 11 | 4 |
| nesta_case2746wop_mp__sad | 2746 | 3514 | 1.2344e+06 | 2.00 | 2.37 | 9 | 9 | 4 |
| nesta_case2746wp_mp__sad | 2746 | 3514 | 1.6674e+06 | 1.68 | 2.21 | 9 | 11 | 6 |
| nesta_case2848_rte__sad | 2848 | 3776 | 5.3031e+04 | 0.08 | 0.09 | 59 | 13 | 10 |
| nesta_case2868_rte__sad | 2868 | 3808 | 7.9818e+04 | 0.08 | 0.10 | 42 | 13 | 10 |
| nesta_case2869_pegase__sad | 2869 | 4582 | 1.3402e+05 | 0.09 | 0.10 | 11 | 25 | 19 |
| nesta_case3012wp_mp__sad | 3012 | 3572 | 2.6213e+06 | 1.41 | 1.62 | 14 | 17 | 7 |
| nesta_case3120sp_mp__sad | 3120 | 3693 | 2.1755e+06 | 1.42 | 1.61 | 16 | 17 | 7 |
| nesta_case3375wp_mp__sad | 3375 | 4161 | 7.4357e+06 | 0.47 | 0.52 | 16 | 30 | 43 |
| nesta_case6468_rte__sad | 6468 | 9000 | 8.6829e+04 | 0.22 | 0.23 | 127 | 59 | 118 |
| nesta_case6470_rte__sad | 6470 | 9005 | 9.8357e+04 | 0.16 | 0.18 | 74 | 42 | 38 |
| nesta_case6495_rte__sad | 6495 | 9019 | 1.0632e+05 | 0.48 | 0.49 | 60 | 60 | 39 |
| nesta_case6515_rte__sad | 6515 | 9037 | 1.0995e+05 | 0.49 | 0.51 | 52 | 46 | 36 |
| nesta_case9241_pegase__sad | 9241 | 16049 | 3.1592e+05 | 0.80 | 0.82 | 87 | 100 | 649 |
| nesta_case13659_pegase__sad | 13659 | 20467 | 3.8614e+05 | 0.70 | 0.71 | 193 | 127 | 139 |


## Radial Topologies (RAD)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case9_kds__rad | 9 | 8 | inf. | -- | -- | <1 | <1 | <1 |
| nesta_case9_l_kds__rad | 9 | 8 | inf. | -- | -- | <1 | <1 | <1 |
| nesta_case30_fsr_kds__rad | 30 | 29 | 6.1904e+02 | 1.74 | 1.74 | <1 | <1 | <1 |
| nesta_case30_fsr_l_kds__rad | 30 | 29 | 4.4584e+02 | 2.25 | 2.25 | <1 | <1 | <1 |
| nesta_case30_kds__rad | 30 | 29 | 4.7943e+03 | 11.47 | 11.47 | <1 | <1 | <1 |
| nesta_case30_l_kds__rad | 30 | 29 | 4.5623e+03 | 33.47 | 33.47 | <1 | <1 | <1 |
| nesta_case57_kds__rad | 57 | 56 | 1.2101e+04 | 13.58 | 13.58 | <1 | <1 | <1 |
| nesta_case57_l_kds__rad | 57 | 56 | 1.0173e+04 | 17.43 | 17.43 | <1 | <1 | <1 |


## Non-Convex Optimization Cases (NCO)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case5_bgm__nco | 5 | 6 | 1.0823e+03 | 10.29 | 10.74 | <1 | <1 | <1 |
| nesta_case9_bgm__nco | 9 | 9 | 3.0878e+03 | 10.85 | 10.85 | <1 | <1 | <1 |
| nesta_case9_na_cao__nco | 9 | 9 | -2.1243e+02 | -15.05 | -18.12 | <1 | <1 | <1 |
| nesta_case9_nb_cao__nco | 9 | 9 | -2.4742e+02 | -15.62 | -19.31 | <1 | <1 | <1 |
| nesta_case14_s_cao__nco | 14 | 20 | 9.6704e+03 | 3.83 | 3.83 | <1 | <1 | <1 |
| nesta_case39_1_bgm__nco | 39 | 46 | 1.1221e+04 | 3.73 | 3.74 | <1 | <1 | <1 |


## Utility Cases (UTL)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_cc__utl | 3 | 3 | 2.0756e+02 | 1.55 | 1.62 | <1 | <1 | <1 |
| nesta_case3_cgs__utl | 3 | 3 | 1.0171e+02 | 1.69 | 1.69 | <1 | <1 | <1 |
| nesta_case3_ch__utl | 3 | 5 | 9.8740e+01 | 100.01 | 100.01 | <1 | <1 | <1 |
| nesta_case5_lmbd__utl | 5 | 7 | 2.3989e+03 | 0.01 | 0.01 | <1 | <1 | <1 |
| nesta_case7_lmbd__utl | 7 | 9 | 1.0344e+02 | 0.16 | 0.16 | <1 | <1 | <1 |
| nesta_case22_bgm__utl | 22 | 22 | 4.5388e+03 | 0.00 | 0.01 | <1 | <1 | <1 |
| nesta_case30_test__utl | 30 | 44 | 6.1510e+02 | 7.05 | 7.05 | <1 | <1 | <1 |


