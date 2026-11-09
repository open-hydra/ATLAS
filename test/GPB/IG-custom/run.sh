#!/bin/bash
# IG-custom: the species N2 and O2 of custom.py (the NASA 7-coefficient polynomials of Cantera's nasa_gas.yaml) write the
# same product files as thermo = NASA7 does (usage: run.sh <ATLAS.sh>).
atlas=$1
fail() { echo "[FAIL] $*"; exit 1; }

rm -rf fromATLAStoSolver _run-nasa7 && mkdir _run-nasa7
"$atlas" GPB > gpb.log 2>&1 || { cat gpb.log; fail "GPB stopped with thermo = custom"; }
sed 's/^thermo    = custom/thermo    = NASA7/' input.ini > _run-nasa7/input.ini
(cd _run-nasa7 && "$atlas" GPB > gpb.log 2>&1) || { cat _run-nasa7/gpb.log; fail "GPB stopped with thermo = NASA7"; }
for f in thermo.dat transport.dat phase.txt composition.txt; do
  cmp fromATLAStoSolver/$f _run-nasa7/fromATLAStoSolver/$f || fail "$f differs between thermo = custom and thermo = NASA7"
done
echo "[ok] IG-custom"
