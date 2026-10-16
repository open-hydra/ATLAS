#!/usr/bin/env python3
"""CP-psat-water: the vapour columns Lv, Mv and Cpv of the water pair, against oracles independent of their writer.

psat-vapour = H2O pairs H2O(L) with the vapour H2O of nasa9.yaml; beside "Psat" [Pa] the table carries the latent
heat "Lv" [J/kg], the vapour molar mass "Mv" [kg/kmol] and the vapour specific heat "Cpv" [J/(kg K)] of the pair.
  V1  the header is "Temperature", "Cp", "Density", "Enthalpy_abs", "Psat", "Lv", "Mv", "Cpv";
  V2  Mv = 2 x 1.008 + 15.999 = 18.015 kg/kmol on every row (conventional atomic weights): the unit of the column;
  V3  Clausius-Clapeyron between two columns: on every 1-K interval ln(p(T+1)/p(T)) of the Psat column (held to
      IAPWS by check_psat.sh) is (Lv(T) + Lv(T+1))/2 Mv/R (1/T - 1/(T+1)) within 1e-4 (the %.6e text of Psat
      leaves 1.5e-5), and within 5e-3 on the interval that holds 373.15 K, where the H2O(L) fit changes its
      coefficient set and its g/RT jumps by 5.8e-5 (1.6e-3 there);
  V4  Cpv(300 K) Mv = 33.596 J/(mol K), the NIST-JANAF table of H2O(g), within 1e-3;
  V5  Lv(298.15 K) = (285.830 - 241.826) kJ/mol / 18.015 g/mol = 2442631 J/kg, from the NIST-JANAF formation
      enthalpies of H2O(l) and H2O(g), the column interpolated linearly between 298 and 299 K, within 1e-3.
  python3 check_vapour.py <part-properties.dat>
Python >= 3.6, standard library only.
"""
import math
import re
import sys

HEADER = ["Temperature", "Cp", "Density", "Enthalpy_abs", "Psat", "Lv", "Mv", "Cpv"]
R = 8314.46261815324                     # molar gas constant [J/(kmol K)]
MV = 2 * 1.008 + 15.999                  # H2O [kg/kmol]
CP_JANAF_300 = 33.596                    # H2O(g) at 300 K [J/(mol K)]
LV_JANAF_298 = (285.830 - 241.826) * 1e3 / (MV * 1e-3)   # [J/kg]
T_BREAK = 373.15                         # the H2O(L) fit's two temperature ranges meet here


def main():
    with open(sys.argv[1]) as f:
        lines = f.read().splitlines()
    bad = 0

    def check(ok, label):
        nonlocal bad
        print(("PASS " if ok else "FAIL ") + label)
        bad += 0 if ok else 1

    names = re.findall(r'"([^"]*)"', lines[1]) if len(lines) > 1 else []
    check(names == HEADER, "V1 header %s" % ", ".join(names))
    if names != HEADER:
        sys.exit(1)
    rows = []
    for line in lines[2:]:
        tok = line.split()
        if len(tok) == len(HEADER) and not line.lstrip().upper().startswith(("ZONE", "I=")):
            rows.append(dict(zip(HEADER, (float(t) for t in tok))))
    zones = sum(1 for line in lines if line.lstrip().upper().startswith("ZONE"))
    if zones != 1 or not rows:
        print("FAIL one zone of rows expected: %d zones, %d rows" % (zones, len(rows)))
        sys.exit(1)

    mv_text = {line.split()[HEADER.index("Mv")] for line in lines[2:]
               if len(line.split()) == len(HEADER) and not line.lstrip().upper().startswith(("ZONE", "I="))}
    check(mv_text == {"%.6f" % MV}, "V2 Mv on every row: %s (expected %.6f kg/kmol)" % (sorted(mv_text), MV))

    worst, worst_at, on_break, n = 0.0, None, None, 0
    for a, b in zip(rows, rows[1:]):
        T0, T1 = a["Temperature"], b["Temperature"]
        if T1 - T0 != 1.0:
            print("FAIL V3 rows %g and %g are not 1 K apart" % (T0, T1))
            sys.exit(1)
        lhs = math.log(b["Psat"] / a["Psat"])
        rhs = 0.5 * (a["Lv"] + b["Lv"]) * a["Mv"] / R * (1.0 / T0 - 1.0 / T1)
        res = abs(lhs / rhs - 1.0)
        n += 1
        if T0 < T_BREAK < T1:
            on_break = (T0, res)
        elif res > worst:
            worst, worst_at = res, T0
    check(worst <= 1e-4, "V3 Clausius-Clapeyron on %d intervals: worst %.3e at [%g, %g] K (tolerance 1e-4)"
          % (n - (on_break is not None), worst, worst_at, worst_at + 1))
    check(on_break is not None and on_break[1] <= 5e-3, "V3 the interval [%g, %g] K that holds %.2f K: %.3e "
          "(tolerance 5e-3)" % (on_break[0], on_break[0] + 1, T_BREAK, on_break[1]) if on_break
          else "V3 no interval holds %.2f K" % T_BREAK)

    at = {r["Temperature"]: r for r in rows}
    if 300.0 in at:
        cp = at[300.0]["Cpv"] * at[300.0]["Mv"] / 1e3
        check(abs(cp / CP_JANAF_300 - 1.0) <= 1e-3, "V4 Cpv(300 K) Mv = %.4f J/(mol K), JANAF %.3f (%+.1e)"
              % (cp, CP_JANAF_300, cp / CP_JANAF_300 - 1.0))
    else:
        check(False, "V4 no row at 300 K")
    if 298.0 in at and 299.0 in at:
        lv = at[298.0]["Lv"] + 0.15 * (at[299.0]["Lv"] - at[298.0]["Lv"])
        check(abs(lv / LV_JANAF_298 - 1.0) <= 1e-3, "V5 Lv(298.15 K) = %.0f J/kg, JANAF %.0f (%+.1e)"
              % (lv, LV_JANAF_298, lv / LV_JANAF_298 - 1.0))
    else:
        check(False, "V5 no rows at 298 and 299 K")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
