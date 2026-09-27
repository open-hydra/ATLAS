# Oracle of the test SP-wall-305: awk -f check-walls.awk fromATLAStoSolver/bc.txt
#
# The deck is one solid block of 50 x 20 x 1 cells (IG-ablation's mesh, 51 x 21 x 2 nodes) in a
# solid-bulk phase. The oracle takes its numbers from input.ini and from the mesh size, never from a
# saved bc.txt:
#  - face 4, section [hot] (hconv = 15, eps = 0.85, Tref = 290): 50 records, each of type 305 with the
#    payload hconv, eps, Tref in this order, the order in which FUSS reads a 305 record;
#  - face 2, section [rad] (eps = 0.6, Tref = 350, no hconv): 20 records, each of type 304 with the
#    payload eps, Tref.
# A record is a header of six integers (block, i, j, k, face, type) and, for these types, one line
# with the payload reals.
function near(a, b) { return (a - b) * (a - b) <= 1e-24 * b * b }
function payload(   line) {
    if ((getline line) <= 0) { short = 1; return 0 }
    gsub(",", " ", line)
    return split(line, v, " ")
}
NF == 6 && $0 ~ /^[ 0-9-]+$/ && $1 == 1 {
    if ($5 == 4) {
        n4++; np = payload()
        if ($6 != 305 || np != 3 || !near(v[1], 15) || !near(v[2], 0.85) || !near(v[3], 290)) bad4++
    } else if ($5 == 2) {
        n2++; np = payload()
        if ($6 != 304 || np != 2 || !near(v[1], 0.6) || !near(v[2], 350)) bad2++
    }
}
END {
    printf "face 4: %d records, %d not 305 with hconv, eps, Tref; face 2: %d records, %d not 304 with eps, Tref\n", \
        n4, bad4, n2, bad2
    exit !(n4 == 50 && bad4 == 0 && n2 == 20 && bad2 == 0 && !short)
}
