#!/bin/bash
# IG-mixture-cantera gate: the "mix" zone of a Cantera-transport air table must hold AIR at 300 K:
#   mu = 184.6e-7 Pa s within 2 %, k = 26.3e-3 W/(m K) within 5 %  (Incropera & DeWitt, Table A.4, air at 1 atm).
# A mixture evaluated at the last pure species of the per-species loop (O2 in NASA9 order) gives mu +11 %, k +8 %.
set -u
f=${1:-fromATLAStoSolver/gas-transport.dat}
awk -v mu0=184.6e-7 -v k0=26.3e-3 '
  /^ZONE/ { inmix = ($0 ~ /T="mix"/); next }
  inmix && $1 + 0 == 300 { seen = 1
    dmu = $2 / mu0 - 1; dk = $3 / k0 - 1
    if (dmu < 0) dmu = -dmu
    if (dk < 0) dk = -dk
    if (dmu <= 0.02) print "PASS mu(300 K) = " $2; else { print "FAIL mu(300 K) = " $2 " (air " mu0 ")"; bad = 1 }
    if (dk <= 0.05) print "PASS k(300 K) = " $3; else { print "FAIL k(300 K) = " $3 " (air " k0 ")"; bad = 1 } }
  END { if (!seen) { print "FAIL no 300 K row in the mix zone"; bad = 1 }; exit bad }' "$f"
