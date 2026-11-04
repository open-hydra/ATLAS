# ---------------------------------------------------------------------------
#  check_power.awk -- the power of an st.tec (sum of qvol times the cell volume,
#                     every cell of the same volume vcell) equals total.
#
#  Usage:  awk -v total=40 -v vcell=0.125 -f check_power.awk fromATLAStoSolver/st.tec
#          exit status 0 == |sum - total| <= 1e-9 (absolute or relative), 1 otherwise.
# ---------------------------------------------------------------------------
function abs(x){ return x<0 ? -x : x }
/ZONE/ { match($0, /I= *[0-9]+/); ni = substr($0, RSTART+2, RLENGTH-2) + 0
         match($0, /J= *[0-9]+/); nj = substr($0, RSTART+2, RLENGTH-2) + 0
         match($0, /K= *[0-9]+/); nk = substr($0, RSTART+2, RLENGTH-2) + 0
         ncell = (ni-1)*(nj-1)*(nk-1); next }
/^[ \t]*[-+0-9.]/ { for (i = 1; i <= NF; i++) v[++n] = $i }
END {
  if (ncell == 0 || n < ncell) { print "check_power: no cell values found"; exit 1 }
  s = 0
  for (i = n-ncell+1; i <= n; i++) s += v[i] * vcell
  d = abs(s - total)
  if (d <= 1e-9 || d <= 1e-9 * abs(total)) exit 0
  printf("check_power: %.12g W mapped, %.12g W expected\n", s, total); exit 1
}
