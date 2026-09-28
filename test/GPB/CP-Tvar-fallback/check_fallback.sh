#!/bin/bash
# CP-Tvar-fallback gate: FOO(L) is not in burcat.yaml and takes the INI constants (cp 1800, rho 1000,
# h0 -1e7 J/kg at 298.15 K, so h(298 K) = -10000270); AL2O3(L) comes from burcat.yaml with ITS density
# 2500, row for row equal to CP-Tvar-dispersed's table on 280..320 K.
set -u
f=${1:-fromATLAStoSolver/part-properties.dat}
rc=0
awk -v want='298.0 1800.000000 1000.000000 -10000270.000000' '
  /^ZONE/ { z = $0; next }
  z ~ /FOO\(L\)/ && $1 + 0 == 298 { seen = 1; if ($0 == want) print "PASS FOO(L) at 298 K: " $0; else { print "FAIL FOO(L) at 298 K: " $0; bad = 1 } }
  END { if (!seen) { print "FAIL no FOO(L) row at 298 K"; bad = 1 }; exit bad }' "$f" || rc=1
awk '/^ZONE/ { z = $0; next } z ~ /AL2O3\(L\)/ && NF == 4' "$f" > fromATLAStoSolver/al2o3.rows
awk '$1 + 0 >= 280 && $1 + 0 <= 320 && NF == 4' ../CP-Tvar-dispersed/reference/properties.dat > fromATLAStoSolver/al2o3.ref
if [ -s fromATLAStoSolver/al2o3.rows ] && awk -v tol=1e-6 -f ../../numdiff.awk fromATLAStoSolver/al2o3.ref fromATLAStoSolver/al2o3.rows; then
  echo "PASS AL2O3(L) rows equal CP-Tvar-dispersed's on 280..320 K"
else
  echo "FAIL AL2O3(L) rows differ from CP-Tvar-dispersed's (or are missing)"; rc=1
fi
exit $rc
