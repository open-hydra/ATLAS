#!/bin/bash
# IG-carbon-phenolic-refused: the 506 deck of IG-carbon-phenolic with one fault each; BCB stops (rc 1) with the message
# and writes no bc.txt (usage: run.sh <ATLAS.sh>).
atlas=$1
fail() { echo "[FAIL] $*"; exit 1; }
src=../IG-carbon-phenolic
# deck <dir> <sed expression> [no-table]: the deck of IG-carbon-phenolic edited, with its mesh, phase and table
deck() {
  rm -rf "$1"; mkdir "$1"; cp $src/mesh.tec $src/phase.txt "$1/"
  [ "$3" = no-table ] || cp $src/pyrolysis.dat "$1/"
  sed "$2" $src/input.ini > "$1/input.ini"
}
refused() {
  out=$(cd "$1" && "$atlas" BCB 2>&1 < /dev/null); rc=$?
  test $rc -eq 1 || { echo "$out" | tail -n 5; fail "$1: rc $rc"; }
  grep -q -F -- "$2" <<< "$out" || { echo "$out" | tail -n 5; fail "$1: no message '$2'"; }
  [ -z "$3" ] || grep -q -F -- "$3" <<< "$out" || { echo "$out" | tail -n 5; fail "$1: no message '$3'"; }
  test ! -e "$1/fromATLAStoSolver/bc.txt" || fail "$1: bc.txt written"
}
deck _run-old 's/^pyrolysis-gas     = MX4926$/pyrolysis-model   = HTPB/'
refused _run-old '[ERROR] section [wall] (gsi): pyrolysis-model and surface-reactions together are no longer a variant'
deck _run-name 's/^pyrolysis-gas     = MX4926$/pyrolysis-gas     = MX4927/'
refused _run-name '[ERROR] key pyrolysis-gas of section [wall]: no table MX4927 in pyrolysis.dat (its tables: TACOT MX4926)'
deck _run-file '' no-table
refused _run-file '[ERROR] key pyrolysis-gas of section [wall]: pyrolysis.dat is neither in the case directory nor in fromATLAStoSolver/'
deck _run-phi 's/^phi               = 0.247342$/phi               = -0.1/'
refused _run-phi '[ERROR] key phi of section [wall]: value -0.1 outside the allowed range >=0'
# phi-file 0.2 - 0.5 x: below 0 from the cell centre x = 0.41 (i = 21) on (0.005 at x = 0.39, -0.005 at x = 0.41: the
# 50 cells of face 4 have their centres at x = 0.02 i - 0.01); face 4 of IG-ablation's mesh is one row (n = 1)
deck _run-phi-file 's/^phi               = 0.247342$/direction         = x\nphi-file          = phi.dat/'
printf '0.0 0.2\n1.0 -0.3\n' > _run-phi-file/phi.dat
refused _run-phi-file '[ERROR] section [wall] (phi-file): phi = ' \
  'at the cell (m, n) = (21, 1) of face 4 of block 1: phi = rho_v/rho_ch - 1 is 0 or positive'
deck _run-hv0 '/^hv0 /d'
refused _run-hv0 '[ERROR] section [wall] (gsi, BC 506): no hv0 for a cell: give hv0 or a hv0-file whose range covers the face'
deck _run-range 's/^phi               = 0.247342$/direction         = x\nphi-file          = phi.dat/'
printf '0.3 0.2\n1.0 0.3\n' > _run-range/phi.dat
refused _run-range '[ERROR] section [wall] (gsi, BC 506): no phi for a cell: give phi or a phi-file whose range covers the face'
echo "[ok] IG-carbon-phenolic-refused"
