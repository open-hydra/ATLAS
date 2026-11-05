# ---------------------------------------------------------------------------
#  sample_rows.awk -- a thin copy of a property table, for a regression
#                     reference of a table too large to keep whole (5000
#                     temperatures per species): every line that does not
#                     start with a number (TITLE, VARIABLES, ZONE, I=...) and
#                     one numeric line in `every` (default 250), counted
#                     through the file.  The kept header lines carry the sizes
#                     of the zones, so a table of another length differs.
#
#  Usage:  awk [-v every=250] -f sample_rows.awk table.dat > sampled.dat
#          compared as   awk -v tol=1e-5 -f numdiff.awk reference/sampled.dat \
#                            <(awk -f sample_rows.awk produced.dat)
# ---------------------------------------------------------------------------
BEGIN { if (every == "") every = 250 }
$1 !~ /^[+-]?([0-9]|\.[0-9])/ { print; next }
{ if (++k % every == 0) print }
