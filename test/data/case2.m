% Case to test space based matlab matrix
% And other hard to parse cases
% also test data without a generator cost model

function mpc = case2
mpc.version = '2';
mpc.baseMVA =  100.00;

mpc.bus = [
      1 3      0.00     0.00      0.00     0.00    1 1.0000     0.00000   20.00   1   1.100	0.900     0.00     0.00 0  0
  % comment in a matrix
    144 1    184.31	52.53      0.00     0.00    1 1.0000	0.00000  100.00   1   1.100   0.900     0.00	0.00 0  0];

mpc.gen = [1   1098.17    140.74    952.77   -186.22  1.0400   2246.86 1   2042.60    0    612.78   2042.60   -186.22    952.77   -186.22    952.77 0 0 0 0  20.4260 0 0 0 0];

mpc.branch = [
    144       1  0.00122  0.04896   0.00000   2042.60   9999.00   9999.00 1.02000    0.000 1    0.00    0.00  -1096.78    -85.26   1098.17    140.74 0 0 0 0  % line comment
];

mpc.bus_name = {
    'Bus 1     LV';
    'Bus 144   HV';
};