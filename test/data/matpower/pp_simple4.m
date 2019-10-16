%% MATPOWER Case Format : Version 2
function mpc = 
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 1;
%% bus data
%    bus_i    type    Pd    Qd    Gs    Bs    area    Vm    Va    baseKV    zone    Vmax    Vmin
mpc.bus = [
	1	3	0.0	0.0	0.0	0.0	0	1.0	0.0	10.0	1	1.00000001	0.99999999				
	2	1	0.0	0.0	0.0	0.0	0	1.0	0.0	0.4	1	2.0	0.0				
	3	1	0.009999999999999998	0.005	0.0	0.0	0	1.0	0.0	0.4	1	2.0	0.0				
	4	1	0.015	0.008	0.0	0.0	0	1.0	0.0	0.4	1	2.0	0.0				
];

%% generator data
%    bus    Pg    Qg    Qmax    Qmin    Vg    mBase    status    Pmax    Pmin    Pc1    Pc2    Qc1min    Qc1max    Qc2min    Qc2max    ramp_agc    ramp_10    ramp_30    ramp_q    apf
mpc.gen = [
	1	0.0	0.0	1.0e9	-1.0e9	1.0	0.0	1	1.0e9	-1.0e9															
];

%% branch data
%    fbus    tbus    r    x    b    rateA    rateB    rateC    ratio    angle    status    angmin    angmax
mpc.branch = [
	2	3	2.0062499999999996	0.25937499999999997	5.277875658030853e-6	250.0	250.0	250.0	0	0	1	-59.99999999999999	59.99999999999999								
	3	4	2.0062499999999996	0.25937499999999997	5.277875658030853e-6	250.0	250.0	250.0	0	0	1	-59.99999999999999	59.99999999999999								
	1	2	0.047996851199999996	0.15263247010263137	-1.3736526686505982e-8	250.0	250.0	250.0	1.05	29.999999999999996	1	-59.99999999999999	59.99999999999999								
];

%%-----  OPF Data  -----%%
%% cost data
%    1    startup    shutdown    n    x1    y1    ...    xn    yn
%    2    startup    shutdown    n    c(n-1)    ...    c0
mpc.gencost = [
	2	0.0	0.0	2	1.0	0.0
];

