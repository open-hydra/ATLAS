#!/bin/bash
# RF-custom: a RealFluid of custom.py (a calorically perfect gas) against its closed form; the same fluid without a
# speed of sound gets 500 m/s and a WARNING (usage: run.sh <ATLAS.sh>).
atlas=$1
py=${ATLAS_PYTHON:-python3}
fail() { echo "[FAIL] $*"; exit 1; }

rm -rf fromATLAStoSolver _run-nosound
"$atlas" GPB > gpb.log 2>&1 || { cat gpb.log; fail "GPB stopped"; }
"$py" check.py fromATLAStoSolver/air-thermo.dat fromATLAStoSolver/air-transport.dat formula || exit 1

mkdir _run-nosound && cp custom.py _run-nosound/
sed 's/^fluid .*/fluid  = PerfectAirNoSound/' input.ini > _run-nosound/input.ini
(cd _run-nosound && "$atlas" GPB > gpb.log 2>&1) || { cat _run-nosound/gpb.log; fail "GPB stopped on PerfectAirNoSound"; }
grep -q -F 'speed of sound fallback (500 m/s)' _run-nosound/gpb.log || fail "no WARNING about the speed of sound"
"$py" check.py _run-nosound/fromATLAStoSolver/air-thermo.dat _run-nosound/fromATLAStoSolver/air-transport.dat 500 || exit 1
echo "[ok] RF-custom"
