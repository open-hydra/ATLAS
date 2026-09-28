#!/bin/bash
# CP-psat-water gate: psat-vapour = H2O pairs the material H2O(L) with the vapour H2O of nasa9.yaml, and the
# table gains a 5th column "Psat" [Pa], p_sat(T) = 1e5*exp(-(g_H2O - g_H2O(L))/(R T)).
# Oracle: the IAPWS saturation line (Wagner & Pruss 2002, eq. 2.5), 3536.8 Pa at 300 K and 41682 Pa at 350 K.
# The NASA9 pair sits at -0.09 % and -0.85 % there; p_ref = 101325 Pa instead of the polynomials' 1 bar
# puts 300 K at +1.23 % (outside 0.5 %), a sign slip at orders of magnitude.
set -u
f=${1:-fromATLAStoSolver/part-properties.dat}
rc=0
sed -n 2p "$f" | grep -q '"Enthalpy_abs", "Psat"$' && echo "PASS header ends Enthalpy_abs, Psat" || { echo "FAIL header: $(sed -n 2p "$f")"; rc=1; }
awk '
  NR > 4 && NF >= 5 { if (seen && $5 + 0 < last) dec = 1; last = $5 + 0; seen = 1; p[$1 + 0] = $5 }
  END {
    n = split("300 3536.8 0.005 350 41682 0.015", a, " ")
    for (k = 1; k <= n; k += 3) {
      T = a[k]; want = a[k + 1]; tol = a[k + 2]
      if (!(T in p)) { print "FAIL no Psat at " T " K"; bad = 1; continue }
      r = p[T] / want - 1; d = r < 0 ? -r : r
      if (d <= tol) printf("PASS Psat(%s K) = %s Pa (%+.3f %% vs IAPWS %s)\n", T, p[T], 100 * r, want)
      else { printf("FAIL Psat(%s K) = %s Pa (%+.3f %% vs IAPWS %s, tol %.1f %%)\n", T, p[T], 100 * r, want, 100 * tol); bad = 1 }
    }
    if (dec) { print "FAIL Psat decreases with T"; bad = 1 }
    exit bad
  }' "$f" || rc=1
exit $rc
