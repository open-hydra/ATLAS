#!/bin/bash
# IG-custom: the species N2 and O2 of custom.py (the NASA 7-coefficient polynomials of Cantera's nasa_gas.yaml) write the
# same product files as thermo = NASA7 does; with CEA-file, thermo = custom is ignored without being loaded (the shipped
# custom.py has no gas species): a WARNING, and the reference files of ceafile-reactive-OG (usage: run.sh <ATLAS.sh>).
atlas=$1
fail() { echo "[FAIL] $*"; exit 1; }

rm -rf fromATLAStoSolver _run-nasa7 _run-cea-custom && mkdir _run-nasa7 _run-cea-custom
"$atlas" GPB > gpb.log 2>&1 || { cat gpb.log; fail "GPB stopped with thermo = custom"; }
sed 's/^thermo    = custom/thermo    = NASA7/' input.ini > _run-nasa7/input.ini
(cd _run-nasa7 && "$atlas" GPB > gpb.log 2>&1) || { cat _run-nasa7/gpb.log; fail "GPB stopped with thermo = NASA7"; }
for f in thermo.dat transport.dat phase.txt composition.txt; do
  cmp fromATLAStoSolver/$f _run-nasa7/fromATLAStoSolver/$f || fail "$f differs between thermo = custom and thermo = NASA7"
done

# the deck of the test ceafile-reactive-OG with thermo = custom: its reference files, and a WARNING
cea=../IG-ceafile-reactive-OG
cp $cea/CEA.inp _run-cea-custom/
awk '{ print } /^type = ideal-gas$/ { print "thermo = custom" }' $cea/input.ini > _run-cea-custom/input.ini
grep -q '^thermo = custom$' _run-cea-custom/input.ini || fail "no thermo = custom in the CEA-file deck"
(cd _run-cea-custom && "$atlas" GPB > gpb.log 2>&1) || { cat _run-cea-custom/gpb.log; fail "GPB stopped with CEA-file and thermo = custom"; }
grep -q -F 'thermo = custom is ignored with CEA-file' _run-cea-custom/gpb.log || fail "no WARNING that thermo = custom is ignored"
for f in phase.txt composition.txt chemistry-info.txt; do
  diff _run-cea-custom/fromATLAStoSolver/$f $cea/reference/$f || fail "$f differs from ceafile-reactive-OG with thermo = custom"
done
echo "[ok] IG-custom"
