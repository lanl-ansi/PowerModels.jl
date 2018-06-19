%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 100.0;

%% bus data
%    bus_i    type    Pd    Qd    Gs    Bs    area    Vm    Va    baseKV    zone    Vmax    Vmin
mpc.bus = [
	1002	2	0	0	0	0	101	0.998928	2.936030	345	201	1.1	0.9
	1005	2	0	0	0	0	101	1.019998	0.129820	87	201	1.1	0.9
	1008	1	18.9	18.9	0	0	101	1.020363	-0.002170	87	201	1.1	0.9
	1009	3	10.5	10.5	0	105.3	101	1.030000	0.000000	87	201	1.1	0.9
];

%% generator data
%    bus    Pg    Qg    Qmax    Qmin    Vg    mBase    status    Pmax    Pmin    Pc1    Pc2    Qc1min    Qc1max    Qc2min    Qc2max    ramp_agc    ramp_10    ramp_30    ramp_q    apf
mpc.gen = [
	1002	27.5	2	2	2	1.020000	31.3	1	27.5	16	0	0	0	0	0	0	0	0	0	0	27.5
	1005	20	-242.52	250	-250	1.020000	320	1	200	-200	0	0	0	0	0	0	0	0	0	0	200
	1009	-17.73	109.28	250	-250	1.030000	100	1	250	-250	0	0	0	0	0	0	0	0	0	0	250
];

%% branch data
%    fbus    tbus    r    x    b    rateA    rateB    rateC    ratio    angle    status    angmin    angmax
mpc.branch = [
	1005	1002	0.005210	0.177370	0.000000	84	84	84	1.025	0.000000	1	-60.000140	60.000140
	1008	1005	0.001278	0.012294	0.227080	1086	1195	1086	1	0.000000	1	-60.000140	60.000140
	1005	1009	0.000475	0.004680	0.082000	1044	1170	1044	1	0.000000	1	-60.000140	60.000140
];

%%-----  OPF Data  -----%%
%% generator cost data
%    1    startup    shutdown    n    x1    y1    ...    xn    yn
%    2    startup    shutdown    n    c(n-1)    ...    c0
mpc.gencost = [
	2	0	0	3	0.000000	1.000000	0.000000
	2	0	0	3	0.000000	1.000000	0.000000
	2	0	0	3	0.000000	1.000000	0.000000
];

%column_names% number string 
mpc.bus_data = {
	 1	'FAV SPOT 02'
	 2	'FAV PLACE 05'
	 3	'FAV PLC 08'
	 4	'FAV PLACE 09'
};

%column_names% pt qf qt pf 
mpc.branch_data = {
	0.275	-0.0066	0.020099999999999996	-0.2746
	0.1898	-0.068	-0.1679	-0.1898
	-0.2823	-2.2508	2.1869	0.2845
};

%column_names% extra 
mpc.load_data = {
	100
	101
};

%column_names% string number 
mpc.component_data = {
	'temp'	1000.0
};
