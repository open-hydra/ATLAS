#!/bin/bash
# CP-custom: thermo = custom with a custom.py in the case directory (usage: run.sh <ATLAS.sh>).
# 1. a liquid with a saturation pressure, and a Graphite that replaces the one of database/thermo/custom.py
# 2. a material with an absolute enthalpy (the column is named Enthalpy_abs)
# 3. the refusals: mixed enthalpy data, an unknown material, a negative cp, a custom.py that fails
atlas=$1
py=${ATLAS_PYTHON:-python3}
fail() { echo "[FAIL] $*"; exit 1; }

# run <dir>: GPB in <dir>, its log in <dir>/gpb.log
run() { (cd "$1" && rm -rf fromATLAStoSolver && "$atlas" GPB > gpb.log 2>&1); }
# refuses <dir> <text>: GPB stops, says <text>, and writes no product
refuses() {
  if run "$1"; then cat "$1/gpb.log"; fail "$1: GPB did not stop"; fi
  grep -q -F "$2" "$1/gpb.log" || { cat "$1/gpb.log"; fail "$1: no '$2' in the log"; }
  [ -z "$(ls "$1/fromATLAStoSolver" 2>/dev/null)" ] || fail "$1: GPB wrote products"
}
# variant <dir> <material line>: the deck of this directory with another material, with its custom.py
variant() { rm -rf "$1"; mkdir "$1"; cp custom.py "$1/"; sed "s/^material = .*/material = $2/" input.ini > "$1/input.ini"; }

run . || { cat gpb.log; fail "GPB stopped"; }
grep -q -F 'the condensed material Graphite of' gpb.log || fail "GPB did not say that Graphite is replaced"
"$py" check.py fromATLAStoSolver/drop-properties.dat Enthalpy Foam Graphite || exit 1

variant _run-abs Wax
run _run-abs || { cat _run-abs/gpb.log; fail "GPB stopped on Wax"; }
"$py" check.py _run-abs/fromATLAStoSolver/drop-properties.dat Enthalpy_abs Wax || exit 1

variant _run-mixed "Foam Wax"
refuses _run-mixed 'mix absolute and relative enthalpy data'
variant _run-name Nope
refuses _run-name "no condensed material 'Nope' in custom.py"
refuses bad-cp 'custom condensed material Bad: cp(550 K) = 0 is not a valid value (positive)'
refuses bad-syntax 'RuntimeError: no data yet'
echo "[ok] CP-custom"
