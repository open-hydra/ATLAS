#!/bin/bash
# CP-fixmat-h0 gate: the fixed-cp + h0 branch must write an ABSOLUTE enthalpy column,
#   h(T) = cp*T + (h0 - cp*298.15)  with cp = 4184, h0 = -15865000  =>  h(298 K) = -15865627.6
# and tag it Enthalpy_abs. Rows are integer kelvin (IGLOO contract), so the datum row is T = 298.
set -u
f=${1:-fromATLAStoSolver/part-properties.dat}
rc=0
grep -q '"Enthalpy_abs"' "$f" && echo "PASS header Enthalpy_abs" || { echo "FAIL header: $(sed -n 2p "$f")"; rc=1; }
awk -v want=-15865627.6 -v tol=1e-3 '
  NR > 4 && $1 + 0 == 298 { seen = 1; d = $4 - want; if (d < 0) d = -d
    if (d <= tol) { print "PASS h(298 K) = " $4 } else { print "FAIL h(298 K) = " $4 " (want " want ")"; bad = 1 } }
  END { if (!seen) { print "FAIL no 298 K row"; bad = 1 }; exit bad }' "$f" || rc=1
exit $rc
