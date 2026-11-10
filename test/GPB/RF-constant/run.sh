#!/bin/bash
# RF-constant: `thermo = constant` (cp, rho, mu, k, a of the section) against the constants; without a the speed of
# sound is 500 m/s with a WARNING; a missing or non-positive property stops GPB (usage: run.sh <ATLAS.sh>).
atlas=$1
# the checker needs numpy: the conda environment of ATLAS.sh, unless ATLAS_PYTHON names an interpreter
if [ -z "${ATLAS_PYTHON:-}" ] && command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)" && conda activate "${ATLAS_CONDA_ENV:-ct-env}" || exit 1
fi
py=${ATLAS_PYTHON:-python3}
fail() { echo "[FAIL] $*"; exit 1; }

# deck <dir> <sed expression>: the deck of this directory edited
deck() { rm -rf "$1"; mkdir "$1"; sed "$2" input.ini > "$1/input.ini"; }

rm -rf fromATLAStoSolver
"$atlas" GPB > gpb.log 2>&1 || { cat gpb.log; fail "GPB stopped"; }
"$py" check.py fromATLAStoSolver/lox-thermo.dat fromATLAStoSolver/lox-transport.dat 900 || exit 1
! grep -q -F 'speed of sound fallback' gpb.log || fail "WARNING about the speed of sound with a given"

deck _run-nosound '/^a /d'
(cd _run-nosound && "$atlas" GPB > gpb.log 2>&1) || { cat _run-nosound/gpb.log; fail "GPB stopped without a"; }
grep -q -F 'speed of sound fallback (500 m/s)' _run-nosound/gpb.log || fail "no WARNING about the speed of sound"
"$py" check.py _run-nosound/fromATLAStoSolver/lox-thermo.dat _run-nosound/fromATLAStoSolver/lox-transport.dat 500 || exit 1

deck _run-nok '/^k /d'
if (cd _run-nok && "$atlas" GPB > gpb.log 2>&1); then fail "a missing k was accepted"; fi
grep -q -F 'k [W/m/K] not defined' _run-nok/gpb.log || { cat _run-nok/gpb.log; fail "no message about k"; }

deck _run-negative 's/^rho .*/rho    = -1/'
if (cd _run-negative && "$atlas" GPB > gpb.log 2>&1); then fail "a negative rho was accepted"; fi
grep -q -F 'must be positive' _run-negative/gpb.log || { cat _run-negative/gpb.log; fail "no message about rho"; }
echo "[ok] RF-constant"
