# ---------------------------------------------------------------------------
#  numdiff.awk -- token-wise comparison of two text files with a numeric
#                 tolerance.  Non-numeric tokens (and integer indices) must
#                 match exactly; floating-point tokens may differ by up to
#                 `tol` in absolute OR relative terms.
#
#  Purpose: regression-check outputs (e.g. chimera volume fractions) that are
#  physically correct but not bit-identical across CPU architectures, where
#  FMA contraction perturbs the last one or two significant digits.
#
#  Usage:  awk -v tol=1e-6 -f numdiff.awk reference.txt produced.txt
#          exit status 0 == match within tolerance, 1 == mismatch.
# ---------------------------------------------------------------------------
function isnum(s){ return s ~ /^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([EeDd][+-]?[0-9]+)?$/ }
function num(s){ gsub(/[Dd]/,"E",s); return s+0 }
function abs(x){ return x<0 ? -x : x }

BEGIN { if (tol == "") tol = 1e-6; bad = 0 }

# first file: stash every line keyed by its line number
NR == FNR { line[FNR] = $0; nref = FNR; next }

# second file: compare token by token against the stashed reference line
{
  if (FNR > nref) { printf("extra line %d in produced file\n", FNR); bad++; next }
  m = split(line[FNR], R)
  if (NF != m) { printf("line %d: %d fields vs %d\n", FNR, m, NF); bad++; next }
  for (i = 1; i <= NF; i++) {
    x = R[i]; y = $i
    if (x == y) continue
    if (isnum(x) && isnum(y)) {
      dx = num(x); dy = num(y); d = abs(dx - dy)
      s = abs(dx); if (abs(dy) > s) s = abs(dy)
      if (d <= tol || d <= tol * s) continue
      printf("line %d field %d: %s vs %s (|diff|=%g)\n", FNR, i, x, y, d); bad++
    } else {
      printf("line %d field %d: '%s' vs '%s'\n", FNR, i, x, y); bad++
    }
  }
}

END {
  if (FNR < nref) { printf("produced file has %d lines, reference %d\n", FNR, nref); bad++ }
  if (bad > 0) { printf("%d mismatch(es) exceeding tol=%g\n", bad, tol); exit 1 }
}
