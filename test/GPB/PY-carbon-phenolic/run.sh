#!/bin/bash
# PY-carbon-phenolic: [GPB-Pyrolysis<n>] (BC 506). The deck's two tables (gas-only, strip) against the identities and
# the other engine (check_pyrolysis.py) and the reference at 1e-8; side decks: strip without a hydrocarbon in the gas
# list, T-min below the polynomial range (WARNING), an unnamed gas phase (pyrolysis.dat), p-min/p-max/p-n with log
# spacing; every refusal of the section: rc 1, the message, no product, no staging directory; a negative mass fraction
# returned by the solve: refused naming (p, T, species) (D18, check_negative.py) (usage: run.sh <ATLAS.sh>).
atlas=$1
# the checker needs numpy, Cantera and cea: the conda environment of ATLAS.sh, unless ATLAS_PYTHON names an interpreter
if [ -z "${ATLAS_PYTHON:-}" ] && command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)" && conda activate "${ATLAS_CONDA_ENV:-ct-env}" || exit 1
fi
py=${ATLAS_PYTHON:-python3}
fail() { echo "[FAIL] $*"; exit 1; }

# deck <dir> <sed expression>: the deck of this directory edited, with the CEA inputs
deck() { rm -rf "$1"; mkdir "$1"; cp species.inp noHC.inp noC.inp "$1/"; sed "$2" input.ini > "$1/input.ini"; }
# accepted <dir>: GPB runs; refused <dir> <message>: rc 1, the message, nothing left behind
accepted() { (cd "$1" && "$atlas" GPB > gpb.log 2>&1) || { cat "$1/gpb.log"; fail "$1: GPB stopped"; }; }
refused() {
  (cd "$1" && "$atlas" GPB > gpb.log 2>&1); rc=$?
  test $rc -eq 1 || { cat "$1/gpb.log"; fail "$1: rc $rc"; }
  grep -q -F -- "$2" "$1/gpb.log" || { cat "$1/gpb.log"; fail "$1: no message '$2'"; }
  test ! -e "$1/fromATLAStoSolver" || fail "$1: a product was left"
  ! ls -d "$1"/.gpb-tmp-* > /dev/null 2>&1 || fail "$1: a staging directory was left"
}

rm -rf fromATLAStoSolver
"$atlas" GPB > gpb.log 2>&1 || { cat gpb.log; fail "GPB stopped"; }
"$py" -B check_pyrolysis.py fromATLAStoSolver/gas-pyrolysis.dat fromATLAStoSolver/gas-phase.txt || exit 1
awk -v tol=1e-8 -f ../../numdiff.awk reference/gas-pyrolysis.dat fromATLAStoSolver/gas-pyrolysis.dat || fail "reference"

deck _run-noHC-strip 's/^CEA-file  = species.inp$/CEA-file  = noHC.inp/;/^treatment = strip$/d;s/^massf     = \(.*\)$/massf     = \1\ntreatment = strip/'
accepted _run-noHC-strip
grep -q '^table MX4926$' _run-noHC-strip/fromATLAStoSolver/gas-pyrolysis.dat || fail "_run-noHC-strip: no table"
deck _run-cold '/^\[GPB-Pyrolysis2\]$/,$d;s/^T         = 1500 3000 500$/T         = 100 400 100/'
accepted _run-cold
grep -q -F 'T-min = 100 K is below the polynomial range of 10 species' _run-cold/gpb.log || fail "_run-cold: no WARNING"
deck _run-unnamed '/^name      = gas$/d'
accepted _run-unnamed
test -f _run-unnamed/fromATLAStoSolver/pyrolysis.dat || fail "_run-unnamed: no pyrolysis.dat"
deck _run-plog 's/^p         = 1e5 4e6 6.1e6$/p-min     = 1e5\np-max     = 1e7\np-n       = 3\np-spacing = log/'
accepted _run-plog
sed -n '/^pressures 3$/{n;p;q}' _run-plog/fromATLAStoSolver/gas-pyrolysis.dat | grep -q '1.0000000000000000E+05  1.0000000000000000E+06  1.0000000000000000E+07' || fail "_run-plog: levels"

deck _run-element 's/^elements  = C H O$/elements  = C H Xx/'
refused _run-element "[ERROR] section [GPB-Pyrolysis1]: elements: 'Xx' is not an element symbol"
deck _run-sum 's/^massf     = 0.60957 0.10710 0.28333$/massf     = 0.6 0.1 0.2/'
refused _run-sum "[ERROR] section [GPB-Pyrolysis1]: massf = 0.6 0.1 0.2: the mass fractions sum to 0.9, not 1"
deck _run-carrier 's/^CEA-file  = species.inp$/CEA-file  = noC.inp/'
refused _run-carrier "[ERROR] section [GPB-Pyrolysis1]: element C of the makeup has no carrier"
deck _run-nogas '/^\[GPB-Phase1\]$/,/^$/d'
refused _run-nogas "[ERROR] section [GPB-Pyrolysis1]: no ideal-gas phase in this deck"
deck _run-two 's/^\[GPB-Pyrolysis1\]$/[GPB-Phase2]\nname      = hot\ntype      = ideal-gas\nCEA-file  = species.inp\nthermo    = NASA9\ntransport = CEA\n\n[GPB-Pyrolysis1]/'
refused _run-two "[ERROR] section [GPB-Pyrolysis1]: phase is not given and the deck builds 2 ideal-gas phases (gas, hot)"
deck _run-phase 's/^name      = MX4926$/name      = MX4926\nphase     = air/'
refused _run-phase "[ERROR] section [GPB-Pyrolysis1]: phase = air is not the name of an ideal-gas phase of this deck"
deck _run-infeasible 's/^CEA-file  = species.inp$/CEA-file  = noHC.inp/'
refused _run-infeasible "[ERROR] section [GPB-Pyrolysis1]: treatment = gas-only: no mixture of the species"
deck _run-hot 's/^T         = 1500 3000 500$/T         = 6000 7000 1000/'
refused _run-hot "[ERROR] section [GPB-Pyrolysis2]: treatment = strip: the CEA equilibrium did not converge at p = 100000 Pa, T = 7000 K"
deck _run-order 's/^p         = 1e5 4e6 6.1e6$/p         = 4e6 1e5/'
refused _run-order "[ERROR] section [GPB-Pyrolysis1]: the pressures must be strictly ascending"
deck _run-step 's/^T         = 1500 3000 500$/T         = 300 1000 300/'
refused _run-step "[ERROR] section [GPB-Pyrolysis1]: T = 300 1000 300: (T-max - T-min)/T-step = 2.33333333333 is not an integer"
deck _run-condensed 's/^treatment = strip$/treatment = condensed/'
refused _run-condensed "[ERROR] section [GPB-Pyrolysis2]: treatment = condensed: allowed gas-only, strip"
deck _run-twice 's/^name      = MX4926-strip$/name      = MX4926/'
refused _run-twice "[ERROR] section [GPB-Pyrolysis2]: name = MX4926: another [GPB-Pyrolysis*] section has this name"
deck _run-both 's/^p         = 1e5 4e6 6.1e6$/p         = 1e5 4e6 6.1e6\np-n       = 3/'
refused _run-both "[ERROR] section [GPB-Pyrolysis1]: p is given with p-min/p-max/p-n/p-spacing"

# D18: a solve that returns a negative mass fraction (check_negative.py replaces it) stops GPB naming (p, T, species)
rm -rf _run-negative && mkdir _run-negative
(cd _run-negative && "$py" -B ../check_negative.py "$(cd "$(dirname "$atlas")" && pwd)" > check.log 2>&1) \
  || { cat _run-negative/check.log; fail "_run-negative: the negative mass fraction was not refused"; }
grep -q -F "[ERROR] section [GPB-Pyrolysis1]: treatment = gas-only: the equilibrium at p = 100000 Pa, T = 2000 K gives the mass fraction -1.000000e-06 of CO2, below 0" _run-negative/check.log \
  || { cat _run-negative/check.log; fail "_run-negative: no message"; }
echo "[ok] PY-carbon-phenolic"
