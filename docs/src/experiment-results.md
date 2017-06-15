# PowerModels Experiment Results
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
otherwise an `err.` or `--` is displayed.  A value of `n.d.` indicates that no data was available.
  The optimality gap is defined as,
```
soc_gap = 100*(result_ac["objective"] - result_soc["objective"])/result_ac["objective"]
```

It is important to note that the `result["solve_time"]`
value in this experiment includes Julia's JIT time.
Excluding the JIT time will reduce the runtime by 2-5 seconds.


## Software Versions
**[PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl):** v0.3.1, 4488d66ae45c2ad523c1514a384ae4cb15242e2b

**[Ipopt.jl](https://github.com/JuliaOpt/Ipopt.jl):** v0.2.6, 959b9c67e396a6e2307fc022d26b0d95692ee6a4

**[NESTA](https://github.com/nicta/nesta):** v0.7.0, ce1ecc76f5f6d3afec9fc5e9d23c82862d96667e

**Hardware:** Dual Intel 2.10GHz CPUs, 128GB RAM


## Typical Operating Conditions (TYP)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd | 3 | 3 | 5.8126e+03 | 1.22 | 1.32 | 5 | 2 | 2 |
| nesta_case4_gs | 4 | 4 | 1.5643e+02 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case5_pjm | 5 | 6 | 1.7552e+04 | 14.55 | 14.55 | 5 | 2 | 2 |
| nesta_case6_c | 6 | 7 | 2.3206e+01 | 0.30 | 0.30 | 5 | 2 | 2 |
| nesta_case6_ww | 6 | 11 | 3.1440e+03 | 0.62 | 0.63 | 5 | 3 | 2 |
| nesta_case9_wscc | 9 | 9 | 5.2967e+03 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case14_ieee | 14 | 20 | 2.4405e+02 | 0.11 | 0.11 | 5 | 2 | 2 |
| nesta_case24_ieee_rts | 24 | 38 | 6.3352e+04 | 0.02 | 0.02 | 5 | 3 | 3 |
| nesta_case29_edin | 29 | 99 | 2.9895e+04 | 0.10 | 0.12 | 5 | 3 | 3 |
| nesta_case30_as | 30 | 41 | 8.0313e+02 | 0.06 | 0.06 | 5 | 3 | 3 |
| nesta_case30_fsr | 30 | 41 | 5.7577e+02 | 0.39 | 0.39 | 5 | 3 | 3 |
| nesta_case30_ieee | 30 | 41 | 2.0497e+02 | 15.65 | 15.89 | 5 | 2 | 2 |
| nesta_case39_epri | 39 | 46 | 9.6506e+04 | 0.05 | 0.05 | 5 | 3 | 3 |
| nesta_case57_ieee | 57 | 80 | 1.1433e+03 | 0.07 | 0.07 | 5 | 3 | 2 |
| nesta_case73_ieee_rts | 73 | 120 | 1.8976e+05 | 0.04 | 0.04 | 5 | 3 | 3 |
| nesta_case89_pegase | 89 | 210 | 5.8198e+03 | 0.17 | 0.17 | 5 | 4 | 3 |
| nesta_case118_ieee | 118 | 186 | 3.7186e+03 | 1.57 | 1.83 | 5 | 3 | 3 |
| nesta_case162_ieee_dtc | 162 | 284 | 4.2302e+03 | 3.96 | 4.03 | 6 | 4 | 3 |
| nesta_case189_edin | 189 | 206 | 8.4929e+02 | 0.22 | 0.22 | 5 | 4 | 3 |
| nesta_case240_wecc | 240 | 448 | 7.5136e+04 | 5.27 | 5.74 | 9 | 12 | 5 |
| nesta_case300_ieee | 300 | 411 | 1.6891e+04 | 1.18 | 1.18 | 6 | 5 | 3 |
| nesta_case1354_pegase | 1354 | 1991 | 7.4069e+04 | 0.08 | 0.08 | 10 | 24 | 23 |
| nesta_case1397sp_eir | 1418 | 1919 | 3.8890e+03 | 0.69 | 0.94 | 10 | 20 | 8 |
| nesta_case1394sop_eir | 1418 | 1920 | 1.3668e+03 | 0.58 | 0.83 | 9 | 28 | 9 |
| nesta_case1460wp_eir | 1481 | 1988 | 4.6402e+03 | 0.65 | 0.89 | 9 | 20 | 10 |
| nesta_case1888_rte | 1888 | 2531 | 5.9805e+04 | 0.38 | 0.38 | 41 | 22 | 175 |
| nesta_case1951_rte | 1951 | 2596 | 8.1738e+04 | 0.07 | 0.08 | 25 | 26 | 26 |
| nesta_case2224_edin | 2224 | 3207 | 3.8128e+04 | 6.03 | 6.09 | 18 | 46 | 15 |
| nesta_case2383wp_mp | 2383 | 2896 | 1.8685e+06 | 0.99 | 1.05 | 18 | 33 | 18 |
| nesta_case2736sp_mp | 2736 | 3504 | 1.3079e+06 | 0.29 | 0.30 | 15 | 35 | 15 |
| nesta_case2737sop_mp | 2737 | 3506 | 7.7763e+05 | 0.25 | 0.26 | 13 | 31 | 12 |
| nesta_case2746wop_mp | 2746 | 3514 | 1.2083e+06 | 0.36 | 0.37 | 14 | 33 | 13 |
| nesta_case2746wp_mp | 2746 | 3514 | 1.6318e+06 | 0.32 | 0.33 | 16 | 33 | 15 |
| nesta_case2848_rte | 2848 | 3776 | 5.3022e+04 | 0.08 | 0.08 | 86 | 33 | 255 |
| nesta_case2868_rte | 2868 | 3808 | 7.9795e+04 | 0.07 | 0.07 | 46 | 44 | 24 |
| nesta_case2869_pegase | 2869 | 4582 | 1.3400e+05 | 0.09 | 0.09 | 17 | 53 | 48 |
| nesta_case3012wp_mp | 3012 | 3572 | 2.6008e+06 | 0.98 | 1.03 | 21 | 46 | 25 |
| nesta_case3120sp_mp | 3120 | 3693 | 2.1457e+06 | 0.54 | 0.55 | 20 | 45 | 18 |
| nesta_case3375wp_mp | 3375 | 4161 | 7.4357e+06 | 0.50 | 0.52 | 26 | 344 | 71 |
| nesta_case6468_rte | 6468 | 9000 | 8.6829e+04 | 0.23 | 0.23 | 121 | 202 | 590 |
| nesta_case6470_rte | 6470 | 9005 | 9.8348e+04 | 0.17 | 0.18 | 109 | 184 | 99 |
| nesta_case6495_rte | 6495 | 9019 | 1.0632e+05 | 0.49 | 0.49 | 74 | 173 | 90 |
| nesta_case6515_rte | 6515 | 9037 | 1.0987e+05 | 0.43 | 0.43 | 71 | 143 | 1240 |
| nesta_case9241_pegase | 9241 | 16049 | 3.1591e+05 | n.d. | 1.64 | 169 | n.d. | 586 |
| nesta_case13659_pegase | 13659 | 20467 | 3.8612e+05 | n.d. | 1.43 | 599 | n.d. | 5234 |


## Congested Operating Conditions (API)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd__api | 3 | 3 | 3.6744e+02 | -- | 2.33 | 5 | 2 | 2 |
| nesta_case4_gs__api | 4 | 4 | 7.6667e+02 | 0.64 | 0.64 | 5 | 2 | 2 |
| nesta_case5_pjm__api | 5 | 6 | 2.9963e+03 | 0.27 | 0.27 | 5 | 2 | 2 |
| nesta_case6_c__api | 6 | 7 | 8.1387e+02 | 0.34 | 0.34 | 5 | 2 | 2 |
| nesta_case9_wscc__api | 9 | 9 | 6.5623e+02 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case14_ieee__api | 14 | 20 | 3.2513e+02 | 1.27 | 1.27 | 5 | 2 | 2 |
| nesta_case24_ieee_rts__api | 24 | 38 | 6.4267e+03 | 11.88 | 20.70 | 5 | 3 | 2 |
| nesta_case29_edin__api | 29 | 99 | 2.9529e+05 | 0.41 | 0.41 | 5 | 4 | 3 |
| nesta_case30_as__api | 30 | 41 | 5.7008e+02 | 4.64 | 4.64 | 5 | 2 | 2 |
| nesta_case30_fsr__api | 30 | 41 | 3.6656e+02 | 45.20 | 45.20 | 5 | 3 | 2 |
| nesta_case30_ieee__api | 30 | 41 | 4.1499e+02 | 0.93 | 0.93 | 5 | 2 | 2 |
| nesta_case39_epri__api | 39 | 46 | 7.4604e+03 | 2.98 | 3.00 | 5 | 3 | 2 |
| nesta_case57_ieee__api | 57 | 80 | 1.4307e+03 | 0.21 | 0.21 | 5 | 3 | 3 |
| nesta_case73_ieee_rts__api | 73 | 120 | 1.9995e+04 | 10.98 | 14.20 | 5 | 3 | 3 |
| nesta_case89_pegase__api | 89 | 210 | 4.2554e+03 | 19.83 | 19.88 | 6 | 4 | 3 |
| nesta_case118_ieee__api | 118 | 186 | 1.0270e+04 | 43.50 | 43.70 | 6 | 3 | 3 |
| nesta_case162_ieee_dtc__api | 162 | 284 | 6.1069e+03 | 1.25 | 1.34 | 6 | 4 | 3 |
| nesta_case189_edin__api | 189 | 206 | 1.9141e+03 | 1.70 | 1.70 | 6 | 4 | 3 |
| nesta_case240_wecc__api | 240 | 448 | 1.4267e+05 | 0.58 | 0.70 | 10 | 15 | 6 |
| nesta_case300_ieee__api | 300 | 411 | 1.9868e+04 | 0.64 | 0.71 | 6 | 5 | 3 |
| nesta_case1354_pegase__api | 1354 | 1991 | 5.2449e+04 | 0.36 | 0.36 | 12 | 25 | 10 |
| nesta_case1397sp_eir__api | 1418 | 1919 | 6.6658e+03 | 1.07 | 1.29 | 10 | 21 | 10 |
| nesta_case1394sop_eir__api | 1418 | 1920 | 3.3776e+03 | 0.37 | 0.39 | 12 | 32 | 9 |
| nesta_case1460wp_eir__api | 1481 | 1988 | 6.4449e+03 | 1.54 | 1.69 | 10 | 21 | 10 |
| nesta_case1888_rte__api | 1888 | 2531 | 5.8546e+04 | 0.71 | 0.71 | 16 | 43 | 16 |
| nesta_case1951_rte__api | 1951 | 2596 | 7.5639e+04 | 0.13 | 0.14 | 18 | 32 | 118 |
| nesta_case2224_edin__api | 2224 | 3207 | 4.4435e+04 | 2.41 | 2.42 | 19 | 45 | 15 |
| nesta_case2383wp_mp__api | 2383 | 2896 | 2.3489e+04 | 0.74 | 0.75 | 14 | 49 | 12 |
| nesta_case2736sp_mp__api | 2736 | 3504 | 2.5884e+04 | 2.18 | 2.19 | 15 | 33 | 14 |
| nesta_case2737sop_mp__api | 2737 | 3506 | 2.1675e+04 | 0.39 | 0.40 | 14 | 34 | 15 |
| nesta_case2746wop_mp__api | 2746 | 3514 | 2.2803e+04 | 0.49 | 0.49 | 14 | 34 | 14 |
| nesta_case2746wp_mp__api | 2746 | 3514 | 2.5964e+04 | 0.58 | 0.59 | 14 | 32 | 14 |
| nesta_case2848_rte__api | 2848 | 3776 | 4.4032e+04 | 0.23 | 0.23 | 37 | 55 | 20 |
| nesta_case2868_rte__api | 2868 | 3808 | 7.5506e+04 | 0.20 | 0.21 | 47 | 56 | 21 |
| nesta_case2869_pegase__api | 2869 | 4582 | 9.8415e+04 | 0.59 | 0.60 | 24 | 60 | 23 |
| nesta_case3012wp_mp__api | 3012 | 3572 | 2.8334e+04 | 1.04 | 1.07 | 16 | 38 | 17 |
| nesta_case3120sp_mp__api | 3120 | 3693 | 2.3715e+04 | 2.73 | 2.75 | 21 | 40 | 17 |
| nesta_case3375wp_mp__api | 3375 | 4161 | 4.8939e+04 | 0.68 | 0.69 | 22 | 341 | 102 |
| nesta_case6468_rte__api | 6468 | 9000 | 6.8149e+04 | 0.89 | 0.91 | 164 | 195 | 494 |
| nesta_case6470_rte__api | 6470 | 9005 | 9.0583e+04 | 0.80 | 0.82 | 80 | 168 | 58 |
| nesta_case6495_rte__api | 6495 | 9019 | 8.8944e+04 | 1.24 | 1.26 | 85 | 166 | 58 |
| nesta_case6515_rte__api | 6515 | 9037 | 9.7217e+04 | 1.07 | 1.10 | 93 | 166 | 63 |
| nesta_case9241_pegase__api | 9241 | 16049 | 2.3890e+05 | n.d. | 2.45 | 191 | n.d. | 138 |
| nesta_case13659_pegase__api | 13659 | 20467 | 3.0284e+05 | n.d. | 1.73 | 237 | n.d. | 257 |


## Small Angle Difference Conditions (SAD)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_lmbd__sad | 3 | 3 | 5.9593e+03 | 1.00 | 3.75 | 5 | 2 | 2 |
| nesta_case4_gs__sad | 4 | 4 | 3.1584e+02 | 1.50 | 4.50 | 5 | 2 | 2 |
| nesta_case5_pjm__sad | 5 | 6 | 2.6115e+04 | 0.99 | 3.61 | 5 | 2 | 2 |
| nesta_case6_c__sad | 6 | 7 | 2.4376e+01 | 0.43 | 1.32 | 5 | 2 | 2 |
| nesta_case6_ww__sad | 6 | 11 | 3.1463e+03 | 0.18 | 0.70 | 5 | 3 | 2 |
| nesta_case9_wscc__sad | 9 | 9 | 5.5283e+03 | 0.51 | 1.55 | 5 | 2 | 2 |
| nesta_case14_ieee__sad | 14 | 20 | 2.4405e+02 | 0.05 | 0.07 | 5 | 2 | 2 |
| nesta_case24_ieee_rts__sad | 24 | 38 | 7.6943e+04 | 2.66 | 9.35 | 5 | 3 | 3 |
| nesta_case29_edin__sad | 29 | 99 | 4.1258e+04 | 16.46 | 25.90 | 5 | 3 | 3 |
| nesta_case30_as__sad | 30 | 41 | 8.9749e+02 | 2.29 | 7.87 | 5 | 3 | 2 |
| nesta_case30_fsr__sad | 30 | 41 | 5.7679e+02 | 0.41 | 0.47 | 5 | 3 | 3 |
| nesta_case30_ieee__sad | 30 | 41 | 2.0497e+02 | 4.17 | 6.57 | 5 | 3 | 2 |
| nesta_case39_epri__sad | 39 | 46 | 9.6745e+04 | 0.01 | 0.03 | 5 | 3 | 3 |
| nesta_case57_ieee__sad | 57 | 80 | 1.1433e+03 | 0.05 | 0.07 | 5 | 3 | 3 |
| nesta_case73_ieee_rts__sad | 73 | 120 | 2.2775e+05 | 2.28 | 6.53 | 5 | 3 | 3 |
| nesta_case89_pegase__sad | 89 | 210 | 5.8198e+03 | 0.13 | 0.14 | 5 | 3 | 3 |
| nesta_case118_ieee__sad | 118 | 186 | 4.1067e+03 | 4.46 | 8.23 | 5 | 3 | 3 |
| nesta_case162_ieee_dtc__sad | 162 | 284 | 4.2535e+03 | 4.31 | 4.56 | 6 | 4 | 3 |
| nesta_case189_edin__sad | 189 | 206 | 8.6482e+02 | 0.80 | 0.80 | 5 | 4 | 3 |
| nesta_case240_wecc__sad | 240 | 448 | 7.6495e+04 | 5.17 | 7.41 | 10 | 11 | 5 |
| nesta_case300_ieee__sad | 300 | 411 | 1.6894e+04 | 1.10 | 1.17 | 6 | 5 | 3 |
| nesta_case1354_pegase__sad | 1354 | 1991 | 7.4070e+04 | 0.07 | 0.08 | 10 | 19 | 16 |
| nesta_case1397sp_eir__sad | 1418 | 1919 | 4.2378e+03 | 7.23 | 7.37 | 11 | 35 | 9 |
| nesta_case1394sop_eir__sad | 1418 | 1920 | 1.4493e+03 | 3.30 | 4.32 | 10 | 26 | 9 |
| nesta_case1460wp_eir__sad | 1481 | 1988 | 5.3370e+03 | 0.72 | 0.92 | 10 | 19 | 9 |
| nesta_case1888_rte__sad | 1888 | 2531 | 5.9806e+04 | 0.37 | 0.38 | 46 | 26 | 178 |
| nesta_case1951_rte__sad | 1951 | 2596 | 8.1786e+04 | 0.11 | 0.13 | 28 | 27 | 215 |
| nesta_case2224_edin__sad | 2224 | 3207 | 3.8265e+04 | 5.45 | 6.04 | 20 | 45 | 14 |
| nesta_case2383wp_mp__sad | 2383 | 2896 | 1.9165e+06 | 2.13 | 3.12 | 19 | 33 | 18 |
| nesta_case2736sp_mp__sad | 2736 | 3504 | 1.3294e+06 | 1.52 | 1.80 | 19 | 35 | 16 |
| nesta_case2737sop_mp__sad | 2737 | 3506 | 7.9266e+05 | 1.92 | 2.10 | 17 | 34 | 13 |
| nesta_case2746wop_mp__sad | 2746 | 3514 | 1.2344e+06 | 1.99 | 2.37 | 16 | 28 | 14 |
| nesta_case2746wp_mp__sad | 2746 | 3514 | 1.6674e+06 | 1.66 | 2.21 | 17 | 32 | 17 |
| nesta_case2848_rte__sad | 2848 | 3776 | 5.3031e+04 | 0.08 | 0.09 | 92 | 41 | 26 |
| nesta_case2868_rte__sad | 2868 | 3808 | 7.9818e+04 | 0.08 | 0.10 | 92 | 45 | 26 |
| nesta_case2869_pegase__sad | 2869 | 4582 | 1.3402e+05 | 0.09 | 0.10 | 19 | 67 | 123 |
| nesta_case3012wp_mp__sad | 3012 | 3572 | 2.6213e+06 | 1.40 | 1.61 | 23 | 50 | 20 |
| nesta_case3120sp_mp__sad | 3120 | 3693 | 2.1755e+06 | 1.40 | 1.59 | 24 | 51 | 20 |
| nesta_case3375wp_mp__sad | 3375 | 4161 | 7.4357e+06 | 0.47 | 0.52 | 24 | 129 | 260 |
| nesta_case6468_rte__sad | 6468 | 9000 | 8.6829e+04 | 0.21 | 0.21 | 155 | 209 | 518 |
| nesta_case6470_rte__sad | 6470 | 9005 | 9.8357e+04 | 0.16 | 0.17 | 109 | 139 | 594 |
| nesta_case6495_rte__sad | 6495 | 9019 | 1.0632e+05 | 0.48 | 0.49 | 71 | 187 | 92 |
| nesta_case6515_rte__sad | 6515 | 9037 | 1.0995e+05 | 0.49 | 0.51 | 79 | 149 | 115 |
| nesta_case9241_pegase__sad | 9241 | 16049 | 3.1592e+05 | n.d. | 0.82 | 153 | n.d. | 840 |
| nesta_case13659_pegase__sad | 13659 | 20467 | 3.8614e+05 | n.d. | 0.71 | 505 | n.d. | 1749 |


## Radial Topologies (RAD)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case9_kds__rad | 9 | 8 | inf. | -- | -- | 5 | 2 | 2 |
| nesta_case9_l_kds__rad | 9 | 8 | inf. | -- | -- | 5 | 2 | 2 |
| nesta_case30_fsr_kds__rad | 30 | 29 | 6.1904e+02 | 1.74 | 1.74 | 5 | 3 | 2 |
| nesta_case30_fsr_l_kds__rad | 30 | 29 | 4.4584e+02 | 2.25 | 2.25 | 5 | 3 | 2 |
| nesta_case30_kds__rad | 30 | 29 | 4.7943e+03 | 11.47 | 11.47 | 5 | 3 | 2 |
| nesta_case30_l_kds__rad | 30 | 29 | 4.5623e+03 | 33.47 | 33.47 | 5 | 2 | 2 |
| nesta_case57_kds__rad | 57 | 56 | 1.2101e+04 | 13.58 | 13.58 | 5 | 3 | 3 |
| nesta_case57_l_kds__rad | 57 | 56 | 1.0173e+04 | 17.43 | 17.43 | 5 | 3 | 2 |


## Non-Convex Optimization Cases (NCO)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case5_bgm__nco | 5 | 6 | 1.0823e+03 | 9.59 | 10.06 | 5 | 2 | 2 |
| nesta_case9_bgm__nco | 9 | 9 | 3.0878e+03 | 10.85 | 10.85 | 5 | 2 | 2 |
| nesta_case9_na_cao__nco | 9 | 9 | -2.1243e+02 | -15.05 | -18.12 | 5 | 2 | 2 |
| nesta_case9_nb_cao__nco | 9 | 9 | -2.4742e+02 | -15.62 | -19.31 | 5 | 2 | 2 |
| nesta_case14_s_cao__nco | 14 | 20 | 9.6704e+03 | 3.83 | 3.83 | 5 | 2 | 3 |
| nesta_case39_1_bgm__nco | 39 | 46 | 1.1221e+04 | 3.73 | 3.74 | 5 | 3 | 3 |


## Utility Cases (UTL)
| **Case Name** | **Nodes** | **Edges** | **AC (\$/h)** | **QC Gap (%)** | **SOC Gap (%)** | **AC Time (sec.)** | **QC Time (sec.)** | **SOC Time (sec.)** |
| ------------- | --------- | --------- | ------------- | -------------- | --------------- | ------------------ | ------------------ | ------------------- |
| nesta_case3_cc__utl | 3 | 3 | 2.0756e+02 | 1.55 | 1.62 | 5 | 2 | 2 |
| nesta_case3_cgs__utl | 3 | 3 | 1.0171e+02 | 1.69 | 1.69 | 5 | 2 | 2 |
| nesta_case3_ch__utl | 3 | 5 | 9.8740e+01 | 100.01 | 100.01 | 5 | 2 | 2 |
| nesta_case5_lmbd__utl | 5 | 7 | 2.3989e+03 | 0.01 | 0.01 | 5 | 2 | 2 |
| nesta_case7_lmbd__utl | 7 | 9 | 1.0344e+02 | 0.16 | 0.16 | 5 | 2 | 2 |
| nesta_case22_bgm__utl | 22 | 22 | 4.5388e+03 | 0.00 | 0.01 | 5 | 2 | 2 |
| nesta_case30_test__utl | 30 | 44 | 6.1510e+02 | 7.05 | 7.05 | 5 | 3 | 2 |


