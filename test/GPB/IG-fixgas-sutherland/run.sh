#!/bin/bash
# IG-fixgas-sutherland: mil-law = sutherland on two fixed species: the transport table against the law (check.py), with
# the conductivity from Pr and from a constant kl; the check fails on the table of another S-mil; every combination of
# the law with mil, kl, Pr and its coefficients that GPB refuses stops it with its message and leaves no product;
# transport = sutherland without the law is a transport value like any other: the simplified law, with its WARNING
# (usage: run.sh <ATLAS.sh>).
atlas=$1
# the checker needs numpy: the conda environment of ATLAS.sh, unless ATLAS_PYTHON names an interpreter
if [ -z "${ATLAS_PYTHON:-}" ] && command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)" && conda activate "${ATLAS_CONDA_ENV:-ct-env}" || exit 1
fi
py=${ATLAS_PYTHON:-python3}
fail() { echo "[FAIL] $*"; exit 1; }

# deck <dir> <sed expression>: the deck of this directory edited
deck() { rm -rf "$1"; mkdir "$1"; sed "$2" input.ini > "$1/input.ini"; }
# refused <dir> <sed expression> <message>: GPB stops on the edited deck with the message and leaves no product
refused() {
  deck "$1" "$2"
  if (cd "$1" && "$atlas" GPB > gpb.log 2>&1); then fail "$1: the deck was accepted"; fi
  grep -q -F "$3" "$1/gpb.log" || { cat "$1/gpb.log"; fail "$1: no message '$3'"; }
  [ ! -e "$1/fromATLAStoSolver" ] || fail "$1: a product was left"
}
# fallback <dir>: GPB accepts the deck of <dir>, transport = sutherland without the law, with the simplified law
fallback() {
  (cd "$1" && "$atlas" GPB > gpb.log 2>&1) || { cat "$1/gpb.log"; fail "$1: GPB stopped"; }
  grep -q -F '[WARNING] GPB: transport = sutherland is not cantera, CEA or constant: simplified law applied' "$1/gpb.log" \
    || { cat "$1/gpb.log"; fail "$1: no WARNING of the simplified law"; }
  [ -s "$1/fromATLAStoSolver/gasS-transport.dat" ] || fail "$1: no transport table"
}

rm -rf fromATLAStoSolver
"$atlas" GPB > gpb.log 2>&1 || { cat gpb.log; fail "GPB stopped"; }
"$py" check.py fromATLAStoSolver/gasS-transport.dat Pr || exit 1
[ ! -e fromATLAStoSolver/gasS-diffusion.dat ] || fail "a diffusion table was written for a law of fixed species"

deck _run-kl 's/^Pr .*/kl      = 0.026 0.15/'
(cd _run-kl && "$atlas" GPB > gpb.log 2>&1) || { cat _run-kl/gpb.log; fail "GPB stopped with kl"; }
"$py" check.py _run-kl/fromATLAStoSolver/gasS-transport.dat kl || exit 1

deck _run-wrong 's/^S-mil .*/S-mil   = 110.5 79.4/'
(cd _run-wrong && "$atlas" GPB > gpb.log 2>&1) || { cat _run-wrong/gpb.log; fail "GPB stopped with S-mil 110.5"; }
if "$py" check.py _run-wrong/fromATLAStoSolver/gasS-transport.dat Pr; then fail "the check accepted the table of S-mil = 110.5"; fi

refused _run-mil      '$a mil     = 1e-5 1e-5'                  'mil and mil-law = sutherland both give the viscosity'
refused _run-noS      '/^S-mil /d'                              'mil-law = sutherland needs mil-ref, T-ref and S-mil (S-mil not given)'
refused _run-nok      '/^Pr /d'                                 ': neither given'
refused _run-Prkl     '$a kl      = 0.026 0.15'                 ': both given'
refused _run-count    's/^mil-ref .*/mil-ref = 1.716e-5/'       'mil-ref = 1.716e-5 is not 2 positive number(s)'
refused _run-negative 's/^S-mil .*/S-mil   = -110.4 79.4/'      'is not 2 positive number(s) [K]'
refused _run-comment  's/^T-ref .*/T-ref   = 273.15 273.0 ; K/' 'T-ref = 273.15 273.0 ; K is not 2 positive number(s)'
refused _run-law      's/^mil-law .*/mil-law = sutherlnd/'      'mil-law = sutherlnd is not a viscosity law'
refused _run-nolaw    '/^mil-law /d'                            'mil-ref, T-ref, S-mil given without mil-law = sutherland'
refused _run-nofix    '/^cp /d;/^gamma /d'                      'a viscosity law is a property of fixed species'
refused _run-dbname   's/^species .*/species = N2 heS/'         'the section also builds N2'

deck _run-typed-fix '/^mil-law /d;/^mil-ref /d;/^T-ref /d;/^S-mil /d;s/^Pr .*/transport = sutherland/'
fallback _run-typed-fix
rm -rf _run-typed-mix; mkdir _run-typed-mix
printf '[GPB-Phase1]\nname      = gasS\ntype      = ideal-gas\nmixture   = {N2: 75.4} {O2: 23.3} {Ar: 1.3}\nthermo    = NASA9\ntransport = sutherland\nTmax      = 400\n' > _run-typed-mix/input.ini
fallback _run-typed-mix
echo "[ok] IG-fixgas-sutherland"
