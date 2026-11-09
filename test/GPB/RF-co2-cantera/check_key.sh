#!/bin/bash
# RF-thermo-key: the real-fluid section selects its source with thermo; model is the former name of the key
# (usage: check_key.sh <ATLAS.sh>). thermo and model give the same tables, model is said to be deprecated, and the two
# together, if they differ, are refused.
atlas=$1
fail() { echo "[FAIL] $*"; exit 1; }

# deck <dir> <lines>: the deck of this directory with <lines> in place of its thermo line
deck() { rm -rf "$1"; mkdir "$1"; python3 -c "
import sys
print(open('input.ini').read().replace('thermo = redlich-kwong', sys.argv[1]), end='')" "$2" > "$1/input.ini"; }

deck _run-thermo 'thermo = redlich-kwong'
(cd _run-thermo && "$atlas" GPB > gpb.log 2>&1) || { cat _run-thermo/gpb.log; fail "GPB stopped with thermo"; }
! grep -q -F 'deprecated' _run-thermo/gpb.log || fail "thermo is said to be deprecated"

deck _run-model 'model = redlich-kwong'
(cd _run-model && "$atlas" GPB > gpb.log 2>&1) || { cat _run-model/gpb.log; fail "GPB stopped with model"; }
grep -q -F 'model is deprecated: write thermo = redlich-kwong' _run-model/gpb.log || fail "no WARNING about model"
for f in co2-phase.txt co2-thermo.dat co2-transport.dat; do
  cmp _run-thermo/fromATLAStoSolver/$f _run-model/fromATLAStoSolver/$f || fail "$f differs between thermo and model"
done

deck _run-both 'thermo = redlich-kwong
model = peng-robinson'
if (cd _run-both && "$atlas" GPB > gpb.log 2>&1); then fail "thermo and model that differ were accepted"; fi
grep -q -F 'model is the former name of thermo, give thermo only' _run-both/gpb.log || { cat _run-both/gpb.log; fail "no message about thermo and model"; }
echo "[ok] RF-thermo-key"
