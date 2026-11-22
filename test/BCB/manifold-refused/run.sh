#!/bin/bash
# manifold-refused: one bad form of the deck at a time (variants.txt: a sed expression and the message BCB must
# print, apart by |). Each run must exit 1, print the message and write nothing.
#   run.sh <ATLAS root>
set -u
ATLAS="$1"
cd "$(dirname "$0")" || exit 2
i=0
fail=0
while IFS='|' read -r expr msg; do
  [ -z "$expr" ] && continue
  i=$((i+1))
  rm -rf _v && mkdir _v && cp input.ini mesh.tec phase.txt _v/
  ( cd _v && sed -i "$expr" input.ini )
  out=$(cd _v && "$ATLAS/ATLAS.sh" BCB 2>&1 < /dev/null)
  rc=$?
  if [ $rc -ne 1 ] || ! grep -q -F "$msg" <<< "$out" || [ -e _v/fromATLAStoSolver/bc.txt ]; then
    echo "[FAIL] variant $i ($expr): exit $rc, expected 1 with the message"
    echo "       $msg"
    echo "$out" | grep -i "error" | head -3
    fail=1
  else
    echo "[ok]   variant $i: $msg"
  fi
done < variants.txt
rm -rf _v
[ $fail -eq 0 ] && echo "[PASS] $i refusals" || echo "[FAIL]"
exit $fail
