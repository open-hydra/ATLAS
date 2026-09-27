# ---------------------------------------------------------------------------
#  CTest definitions for MOSE validation cases
# ---------------------------------------------------------------------------

# Common environment for all solver tests
set(_TEST_ENV
    "OMP_NUM_THREADS=1"
    "KMP_STACKSIZE=100M"
    "ATLASDIR=${CMAKE_SOURCE_DIR}"
    # test/numdiff.awk reads numbers with the awk's own conversion: a POSIX-mode awk (POSIXLY_CORRECT,
    # gawk --posix) takes the decimal point from the locale, and under it_IT "0.611E+000" reads as 0.
    "LC_ALL=C"
)

# ---- GPB : ceafile-reactive-OG -------------
add_test(
    NAME    ceafile-reactive-OG
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/phase.txt reference/phase.txt && diff fromATLAStoSolver/composition.txt reference/composition.txt && diff fromATLAStoSolver/chemistry-info.txt reference/chemistry-info.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-ceafile-reactive-OG"
)
set_tests_properties(ceafile-reactive-OG PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-fixmat-dispersed (phase-file header + modeling token) -------------
add_test(
    NAME    CP-fixmat-dispersed
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/part-phase.txt reference/part-phase.txt && diff fromATLAStoSolver/part-properties.dat reference/part-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-fixmat-dispersed"
)
set_tests_properties(CP-fixmat-dispersed PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : SP-fixmat (solid-bulk header) -------------
add_test(
    NAME    SP-fixmat
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/metals-phase.txt reference/metals-phase.txt && diff fromATLAStoSolver/metals-properties.dat reference/metals-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/SP-fixmat"
)
set_tests_properties(SP-fixmat PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : SP-basic -------------
add_test(
    NAME    SP-basic
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/solid-ic.tec reference/solid-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/SP-basic"
)
set_tests_properties(SP-basic PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG+DP (gas + dispersed phase; DP IC file carries the population fields) -------------
add_test(
    NAME    IG+DP
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/particles-ic.tec reference/particles-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG+DP"
)
set_tests_properties(IG+DP PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-nozzle3D -------------
add_test(
    NAME    IG-nozzle3D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/gas-ic.vtm reference/gas-ic.vtm"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-nozzle3D"
)
set_tests_properties(IG-nozzle3D PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-mindist -------------
# Minimum-distance interpolation of an ideal-gas solution onto an identical
# grid (identity map). The source field.tec carries solver-style extra 
# variables (T,g,R) beyond ATLAS's rho,u,v,w,p layout.
add_test(
    NAME    IG-interp-mindist
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/ic.tec reference/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-mindist"
)
set_tests_properties(IG-interp-mindist PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-inflow-nozzle -------------
add_test(
    NAME    IG-inflow-nozzle
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1); rc=$?; echo \"$out\" | grep -F '[WARNING]'; test $rc -eq 0 && grep -q -F -- \"$(cat expected.txt)\" <<< \"$out\" && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-inflow-nozzle"
)
set_tests_properties(IG-inflow-nozzle PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-multipatch-file -------------
add_test(
    NAME    IG-multipatch-file
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-multipatch-file"
)
set_tests_properties(IG-multipatch-file PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-multipatch-1D (face1 multipatch IDs) -------------
add_test(
    NAME    IG-multipatch-1D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-multipatch-1D"
)
set_tests_properties(IG-multipatch-1D PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-inflow-ceafile-inertmix -------------
# The records carry 17 digits (ES24.16): the CEA-equilibrium T0 of ifx and gfortran builds differs in the
# 16th digit (3399.5978434892600 vs ...659, 1.7e-15), so the record is compared numerically (tolerance 1e-12).
add_test(
    NAME    IG-inflow-ceafile-inertmix
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-inflow-ceafile-inertmix"
)
set_tests_properties(IG-inflow-ceafile-inertmix PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-comment-lines (comment lines starting with #, ; or ! that hold an equals sign are ignored: bc.txt equals the one of the deck without them) -------------
add_test(
    NAME    IG-comment-lines
    COMMAND bash -c "rm -rf _run-comments && mkdir _run-comments && cp *.ini *.tec *.txt *.dat _run-comments/ 2>/dev/null; cd _run-comments && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && mv fromATLAStoSolver plain && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input comments.ini && diff plain/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-basic"
)
set_tests_properties(IG-comment-lines PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : mesh-p3d-fallback -------------
# Without a path the mesh is searched as mesh.tec, mesh.p3d, mesh.szplt. A mesh.p3d that cannot be read (40
# bytes here) is followed by mesh.szplt, as upstream, with a WARNING naming both files; mesh.szplt is a
# placeholder, so every build then stops on it (TecIO message or unreadable file): the WARNING and the stop are pinned.
add_test(
    NAME    mesh-p3d-fallback
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 | tee bcb.log && grep -q -F '[WARNING] mesh.p3d found, but failed to read it (read error): mesh.szplt is read instead' bcb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/mesh-p3d-fallback"
)
set_tests_properties(mesh-p3d-fallback PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-table-header-skipped -------------
# A table row that is not two numbers (the header row "x T" without #) is skipped with a WARNING, as upstream
# skips it (in silence): the wall temperature profile and bc.txt are those of the same file without the row.
add_test(
    NAME    IG-table-header-skipped
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F '[WARNING] table file Twall.dat: line 1 is not two numbers (coordinate value), skipped: x T' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-table-header-skipped"
)
set_tests_properties(IG-table-header-skipped PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-table-not-monotone -------------
# A T-file whose coordinate column turns back (0, 1, 0.5) is refused: the table reader names the row where the column
# turns back and BCB stops; no bc.txt.
add_test(
    NAME    IG-table-not-monotone
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > bcb.log 2>&1; then cat bcb.log; false; else grep -q -F '[ERROR] table file Twall.dat: the coordinate column is not monotone at row 3' bcb.log && test ! -e fromATLAStoSolver/bc.txt; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-table-not-monotone"
)
set_tests_properties(IG-table-not-monotone PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-table-decreasing -------------
# A T-file whose coordinates decrease (1, 0.5, 0) is read in increasing order: bc.txt equals the one of the same rows
# written in increasing order (isothermal wall 302 with T = 310, 330, 350, 370 on face 3).
add_test(
    NAME    IG-table-decreasing
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-table-decreasing"
)
set_tests_properties(IG-table-decreasing PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-duplicate-section-lenient -------------
# strict-keys = false and the deck in a BCB-file that writes the section [noz] twice: one WARNING, the second copy is
# ignored and bc.txt is that of the deck without it (the key check reads every option of every section).
add_test(
    NAME    IG-duplicate-section-lenient
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F '[WARNING] section [noz] of deck.ini: declared twice (lines 11 and 16), the second is ignored: merge them' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-duplicate-section-lenient"
)
set_tests_properties(IG-duplicate-section-lenient PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-duplicate-section-identical -------------
# Default settings (strict-keys = true) and a BCB-file that writes the section [noz] twice with the same keys and
# values (another key order, a comment line and a blank line in the second copy): one WARNING that says so, and
# bc.txt is that of the deck with one [noz] (the reference of IG-duplicate-section-lenient).
add_test(
    NAME    IG-duplicate-section-identical
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F '[WARNING] section [noz] of deck.ini: declared twice (lines 11 and 16), the second is ignored: merge them (the two copies hold the same keys and values)' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-duplicate-section-identical"
)
set_tests_properties(IG-duplicate-section-identical PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-duplicate-section-conflict -------------
# The two copies of [noz] differ (p0): with the default settings BCB stops with the ERROR and writes no bc.txt; with
# strict-keys = false (lenient.ini) one WARNING, the second copy is ignored and bc.txt is that of the first copy.
add_test(
    NAME    IG-duplicate-section-conflict
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 2; test $rc -eq 1 && grep -q -F '[ERROR] section [noz] of deck.ini: declared twice (lines 11 and 16), the second is ignored: merge them' <<< \"$out\" && test ! -e fromATLAStoSolver/bc.txt && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input lenient.ini 2>&1) && grep -q -F '[WARNING] section [noz] of deck.ini: declared twice (lines 11 and 16), the second is ignored: merge them' <<< \"$out\" && ! grep -q -F 'same keys and values' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-duplicate-section-conflict"
)
set_tests_properties(IG-duplicate-section-conflict PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : mesh-p3d-single-plane -------------
# A PLOT3D mesh written with three coordinates and one node plane (5 4 1, z = 0) is the pure-2D mesh of its x-y plane.
# reference/bc.txt was written by BCB from this mesh; mesh-tec-single-plane reads the same grid as a Tecplot zone with
# K = 1 (on the plane z = 0 and on a tilted plane) and compares its bc.txt with this same file.
add_test(
    NAME    mesh-p3d-single-plane
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/mesh-p3d-single-plane"
)
set_tests_properties(mesh-p3d-single-plane PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : mesh-p3d-plane-perpendicular -------------
# A PLOT3D mesh with three coordinates on one node plane that lies in x-z (y = 0) has no area on x-y, where the 2D
# mesh is read: refused with the block named; no bc.txt.
add_test(
    NAME    mesh-p3d-plane-perpendicular
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > bcb.log 2>&1; then cat bcb.log; false; else grep -q -F '[ERROR] mesh block 1: three coordinates on a single node plane that is perpendicular to x-y' bcb.log && test ! -e fromATLAStoSolver/bc.txt; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/mesh-p3d-plane-perpendicular"
)
set_tests_properties(mesh-p3d-plane-perpendicular PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-chimera (overset overlap connections) -------------
# Volume fractions come from an ill-conditioned hull volume of sliver contacts;
# they are correct to ~1e-9 but not bit-identical across CPU architectures
# (FMA contraction perturbs the last digit), so compare with a numeric tolerance
# rather than an exact diff.
add_test(
    NAME    IG-chimera
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-chimera"
)
set_tests_properties(IG-chimera PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-chimera+connection (chimera and connection on the same run) ----
# Three blocks in series on a distorted grid: block1 (coarse) overlaps block2
# (fine) -> chimera; block2 meets block3 on a shared, curved, non-matching-in-i
# surface -> standard connection. Checks that a face declared 'connection' keeps
# the exact 1:1 matching while chimera is enabled. Same numeric tolerance as
# IG-chimera, for the same reason.
add_test(
    NAME    IG-chimera+connection
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-chimera+connection"
)
set_tests_properties(IG-chimera+connection PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG+SP-force-chimera (inter-phase chimera, id 104) ----------------
# IG-force-chimera's mesh and faces, with the large block in a gas phase and the
# small one in a solid phase. With BC-force-chimera the facelets that see the
# other block become chimera; receiver and donor belong to different phases, so
# both gas-bc.txt and solid-bc.txt write them as 104 instead of 102. Same
# numeric tolerance as IG-chimera.
add_test(
    NAME    IG+SP-force-chimera
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/gas-bc.txt fromATLAStoSolver/gas-bc.txt && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/solid-bc.txt fromATLAStoSolver/solid-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG+SP-force-chimera"
)
set_tests_properties(IG+SP-force-chimera PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-force-chimera (partial interface, BC-force-chimera) ------------
# A small fine block overlaps only a strip of a large coarse block. The large
# block's face and the small block's lateral faces are declared symmetry; with
# BC-force-chimera the facelets that actually see the other block become chimera
# and the remaining ones keep symmetry. Same numeric tolerance as IG-chimera.
add_test(
    NAME    IG-force-chimera
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-force-chimera"
)
set_tests_properties(IG-force-chimera PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : mesh-p3d-3D -------------
# Without a path the mesh is searched as mesh.tec, mesh.p3d, mesh.szplt: a PLOT3D mesh alone, with three coordinates and
# three node planes (4 3 3), is read as a 3D mesh: bc.txt equals the one BCB writes for the same grid given as a Tecplot
# zone (same-grid.tec, run again in fromATLAStoSolver/tecplot).
add_test(
    NAME    mesh-p3d-3D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && mkdir fromATLAStoSolver/tecplot && cp input.ini phase.txt fromATLAStoSolver/tecplot/ && cp same-grid.tec fromATLAStoSolver/tecplot/mesh.tec && cd fromATLAStoSolver/tecplot && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff ../bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/mesh-p3d-3D"
)
set_tests_properties(mesh-p3d-3D PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-basic (dispersed-phase inlets, distribution field) -------------
add_test(
    NAME    DP-basic
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/drop-bc.txt reference/drop-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-basic"
)
set_tests_properties(DP-basic PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-multigrid (one dispersed BC file per grid level) -------------
# write_dp_bc used to ignore the level it was called with and always open
# <prefix>bc.txt, so a run with MG-levels > 1 rewrote that one file once per
# level: the fine table ended up replaced by the coarse one and padded with NULs
# to the old length. One file per level now, each with its own table, and every
# level carries the three (material, population) copies this phase has.
add_test(
    NAME    DP-multigrid
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py --dispersed fromATLAStoSolver/drop-bc.txt fromATLAStoSolver/drop-bc2.txt fromATLAStoSolver/drop-bc3.txt && diff fromATLAStoSolver/drop-bc.txt reference/drop-bc.txt && diff fromATLAStoSolver/drop-bc2.txt reference/drop-bc2.txt && diff fromATLAStoSolver/drop-bc3.txt reference/drop-bc3.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-multigrid"
)
set_tests_properties(DP-multigrid PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-z-variable-krho (z-profile krho file, phase-prefixed keys) -------------
add_test(
    NAME    DP-z-variable-krho
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/drop-bc.txt reference/drop-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-z-variable-krho"
)
set_tests_properties(DP-z-variable-krho PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG+CD (gas + dispersed phase on one inlet) -------------
add_test(
    NAME    IG+CD
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/gas-bc.txt reference/gas-bc.txt && diff fromATLAStoSolver/particles-bc.txt reference/particles-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG+CD"
)
set_tests_properties(IG+CD PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-tokens-tolerated (P3: key=value tokens on the material line) ----
# DP-basic with `modeling=lagrangian` on line 1 and `evaporation=CEM alpha-e=0.5`
# after `dummy 1` in drop-phase.txt (mesh.tec is a symlink to DP-basic's). The
# tokens are for the solvers: BCB must ignore them and write DP-basic's BC file.
add_test(
    NAME    DP-tokens-tolerated
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/drop-bc.txt ../DP-basic/reference/drop-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-tokens-tolerated"
)
set_tests_properties(DP-tokens-tolerated PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-bad-name (P3: a phase file name with two dashes is refused) ----
# `part-E-phase.txt` used to overrun ORION's parse(). `!` inverts BCB's status
# (pipefail carries it through tee) and the grep pins the reason, so a crash or
# an unrelated abort still fails the test; WILL_FAIL would accept any failure.
add_test(
    NAME    DP-bad-name
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 | tee bcb.log && grep -q 'must contain at most one' bcb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-bad-name"
)
set_tests_properties(DP-bad-name PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-substring-names (P5: nested phase names are refused) ----------
# `part` and `partL`: with substring matching a block associated to `part` was
# also written into partL-bc.txt. read_phase must now stop before any BC file
# is built; same expect-failure form as DP-bad-name.
add_test(
    NAME    DP-substring-names
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 | tee bcb.log && grep -q 'is a substring of' bcb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-substring-names"
)
set_tests_properties(DP-substring-names PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-two-phases (two dispersed phases on the same faces, one slot each) ----
# partE and partL share every inlet; each <name>-bc.txt must carry ITS phase's ids
# and payloads. partE's 402 inlet has Tp = 2300 K: written as a number, not as the
# 'normal,' direction sentinel. At db4b213 both files were identical (last phase won).
add_test(
    NAME    DP-two-phases
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/partE-bc.txt reference/partE-bc.txt && diff fromATLAStoSolver/partL-bc.txt reference/partL-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-two-phases"
)
set_tests_properties(DP-two-phases PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-axis-override (dispersed phase let out through the axis) -------------
# 2Daxi nozzle (IG+CD's mesh). [ax] type = axisymmetric + partL-type = outlet:
# gas-bc.txt keeps 200 on the axis face 3, partL-bc.txt carries 400 there; the
# auto-tagged wedge faces 5/6 stay 200 in both. Without the override both files carry 200.
add_test(
    NAME    DP-axis-override
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/gas-bc.txt reference/gas-bc.txt && diff fromATLAStoSolver/partL-bc.txt reference/partL-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-axis-override"
)
set_tests_properties(DP-axis-override PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-axis-symmetry (dispersed phase mirrored at the axis) -------------
# Same mesh as DP-axis-override. [ax] type = axisymmetric + partL-type = symmetry:
# gas-bc.txt keeps 200 on the axis face 3, partL-bc.txt carries 300 there (no payload);
# the auto-tagged wedge faces 5/6 stay 200 in both.
add_test(
    NAME    DP-axis-symmetry
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/gas-bc.txt reference/gas-bc.txt && diff fromATLAStoSolver/partL-bc.txt reference/partL-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-axis-symmetry"
)
set_tests_properties(DP-axis-symmetry PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-axis-refused (any other axis override word is refused) ----------
# [ax] partL-type = wall must stop BCB with exit 1; the grep pins the message naming
# both accepted words. Same expect-failure form as DP-bad-name.
add_test(
    NAME    DP-axis-refused
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 | tee bcb.log && grep -q 'or .symmetry. is allowed' bcb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-axis-refused"
)
set_tests_properties(DP-axis-refused PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-plate-keys -------------
# IG-multipatch-file's injector plate with its two plate keys written out (full-plate = F, z-hydra = 1.0, the
# defaults): the plate mapping reads them, so the deck passes the key check and writes the same bc.txt.
add_test(
    NAME    IG-plate-keys
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt ../IG-multipatch-file/reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-plate-keys"
)
set_tests_properties(IG-plate-keys PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-renamed-keys-lenient -------------
# Keys of older decks (rt, renamed g; force-connect, now BC-force-connect in [ATLAS-Parameters]) are unknown
# keys like any other: with strict-keys = false one WARNING each, whose hint names the current key, and the
# deck is written as without them.
add_test(
    NAME    IG-renamed-keys-lenient
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F \"[WARNING] key rt of section [noz]: unknown key (key 'rt' was renamed 'g'\" <<< \"$out\" && grep -q -F '[WARNING] key force-connect of section [ATLAS-Parameters]: unknown key (the option is BC-force-connect' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-renamed-keys-lenient"
)
set_tests_properties(IG-renamed-keys-lenient PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-value-not-a-number (a value with a trailing comment (T0 = 3400.0 ! K) stops BCB naming the key: it is not a number; nothing is written) -------------
add_test(
    NAME    IG-value-not-a-number
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '[ERROR] key T0 of section [noz]: value 3400.0 ! K is not a number' <<< \"$out\" && test ! -e fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-value-not-a-number"
)
set_tests_properties(IG-value-not-a-number PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-phase-type-refused (<phase>-type outside an axisymmetric face) -------------
# DP-axis-override's deck with partL-type = outlet also on the wall [noz]. Only a dispersed
# phase on a face of type axisymmetric reads the key, so BCB stops (strict-keys) instead of
# ignoring it. `!` inverts BCB's status and the grep pins the reason, as in DP-bad-name.
add_test(
    NAME    DP-phase-type-refused
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 | tee bcb.log && grep -q -F '[ERROR] key partL-type of section [noz]: not honoured (type = wall)' bcb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-phase-type-refused"
)
set_tests_properties(DP-phase-type-refused PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-keys-documented -------------
# Documented keys that do not stop BCB under strict-keys: Ae_At = 0.0 and a1-a3 = 0.0 (their defaults, "not
# given") are silent; u on the inlet and p-time-file on the outlet are carried by no record: one WARNING each.
# bc.txt is the one of the same deck without these keys.
add_test(
    NAME    IG-keys-documented
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && test $(grep -c -e '[[]WARNING[]] key' -e '[[]ERROR[]] key' <<< \"$out\") -eq 2 && grep -q -F '[WARNING] key u of section [noz]: no BC record carries' <<< \"$out\" && grep -q -F '[WARNING] key p-time-file of section [outflow]: no BC record carries' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-keys-documented"
)
set_tests_properties(IG-keys-documented PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-nozzle-arearatio -------------
# BC 420 from Ae_At = 2.5 on a calorically perfect gas (thermo.dat with a constant cp): psub, psup and g of the
# record (reference checked against the closed-form isentrope) in the solvers' order T0, p0, psub, psup, g, rf, massf.
add_test(
    NAME    IG-nozzle-arearatio
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-nozzle-arearatio"
)
set_tests_properties(IG-nozzle-arearatio PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-borda-2D -------------
# BC 421, the Borda choked injector read by Q2D only (2-D mesh), selected by a1-a3 = A1/A3 in (0, 1]: record
# T0, p0, A1/A3, rf, massf, no angle fields; the 2-D product passes the consistency check of scripts/check-bc.py.
add_test(
    NAME    IG-borda-2D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/bc.txt | grep -q -F 'all 32 connection records reciprocal'"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-borda-2D"
)
set_tests_properties(IG-borda-2D PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-inflow-405a -------------
# An inlet given mach, p0 and T0 is the supersonic 405 (it was written as 401): static T and p of the isentropic
# expansion on thermo.dat (constant cp; M = 2, T0 = 300 K, p0 = 1.013e5 Pa give T = 166.667 K, p = 12946.6 Pa).
add_test(
    NAME    IG-inflow-405a
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-inflow-405a"
)
set_tests_properties(IG-inflow-405a PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-composition-sum-refused (mass fractions of an inlet that sum to 0.99 stop BCB naming the section and the sum; nothing is written) -------------
add_test(
    NAME    IG-composition-sum-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '[ERROR] composition of section [injOX] (keys yO2 yCH4): the mass fractions sum to  9.90000E-01, they must sum to 1 within 1e-3' <<< \"$out\" && test ! -e fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-composition-sum-refused"
)
set_tests_properties(IG-composition-sum-refused PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-nozzle-inlet-envelope-refused (a nozzle inlet (BC 420) with psup above psub stops BCB: the solvers need 0 < psup <= psub < p0; nothing is written) -------------
add_test(
    NAME    IG-nozzle-inlet-envelope-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '[ERROR] nozzle inlet (BC 420) requires 0 < psup <= psub < p0' <<< \"$out\" && test ! -e fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-nozzle-inlet-envelope-refused"
)
set_tests_properties(IG-nozzle-inlet-envelope-refused PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-2D-inlet-408-refused (a normal-velocity inlet (BC 408) on a pure 2-D mesh stops BCB: Q2D, which reads 2-D meshes, does not implement BC 408; nothing is written) -------------
add_test(
    NAME    IG-2D-inlet-408-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '[ERROR] inflow (normal-velocity inlet, BC 408): a 2D mesh (x,y file) is read by Q2D, which does not implement BC 408' <<< \"$out\" && test ! -e fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-2D-inlet-408-refused"
)
set_tests_properties(IG-2D-inlet-408-refused PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-force-connect-plate -------------
# Injection plate with holes, the designed use of BC-force-connect (default true): block 1 face 1 is declared
# inlet [plate]; the cells that coincide with the hole blocks 2 and 3 are written as connections (101, with the
# hole's cell and orientation, the facelet ids and connection lines upstream writes), the other cells keep the
# inlet. One LOG line for the face, no WARNING, no refusal.
add_test(
    NAME    IG-force-connect-plate
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -x -F -- ' [LOG] BC-force-connect: block 1 face 1: 5 cells connected to block(s) 2 3, 3 cells keep the declared BC [plate]' <<< \"$out\" && ! grep -q -F '[WARNING] BC-force-connect' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-force-connect-plate"
)
set_tests_properties(IG-force-connect-plate PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-time-file-long-name -------------
# A time-file name longer than 32 characters. With line-file BCB writes the series itself: file and record take
# the first 32 characters of the name (one LOG line), the mapping is unchanged. Without line-file (user-file.ini)
# the file is the user's and the solver would look for the truncated name: BCB stops, no bc.txt.
add_test(
    NAME    IG-time-file-long-name
    COMMAND bash -c "rm -rf fromATLAStoSolver mapped_with_a_very_long_name_ove; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F ' [LOG] time-file mapped_with_a_very_long_name_over_32_chars.tec (written from line-file strip.tec) is named mapped_with_a_very_long_name_ove' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt && diff mapped_with_a_very_long_name_ove reference/mapped_with_a_very_long_name_ove && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input user-file.ini > user-file.log 2>&1 && grep -q -F '[ERROR] key time-file: file name longer than 32 characters' user-file.log && test ! -e fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-time-file-long-name"
)
set_tests_properties(IG-time-file-long-name PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-linefile-sector-axis -------------
# A line-file strip that covers a quarter of the lap, n-repeat = 4, mapped about the key axis x onto face 6 of an
# annulus about x, whose inward normal is -x: each face cell holds the closed-form law of the strip at 4 theta,
# the axial velocity of the record enters the domain (check-mapping.py computes both from mesh.tec and the law),
# and one INFO line names the axis and the normal. With axis = y (axis-y.ini), parallel to the face, BCB stops.
add_test(
    NAME    IG-linefile-sector-axis
    COMMAND bash -c "rm -rf fromATLAStoSolver mapped.tec; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -x -F -- '[INFO] Block 1 face 6: line-file mapped about axis x, inward normal along -x: a positive axial velocity of the record enters the domain' <<< \"$out\" && python3 check-mapping.py && rm -rf fromATLAStoSolver mapped.tec && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input axis-y.ini > axis-y.log 2>&1 && grep -q -F 'the face is parallel to the y axis' axis-y.log && grep -q -F '[ERROR] face 6: not aligned with a Cartesian axis on any block' axis-y.log && test ! -e mapped.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-linefile-sector-axis"
)
set_tests_properties(IG-linefile-sector-axis PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-multipatch-410-linefile (a 410 inlet written from a line-file as the one patch of a multipatch face equals the same face declared directly; two patches run) -------------
add_test(
    NAME    IG-multipatch-410-linefile
    COMMAND bash -c "rm -rf fromATLAStoSolver single mapped.tec && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input single.ini && mkdir single && mv fromATLAStoSolver/bc.txt mapped.tec single/ && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff single/bc.txt fromATLAStoSolver/bc.txt && diff single/mapped.tec mapped.tec && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input two-patches.ini"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-multipatch-410-linefile"
)
set_tests_properties(IG-multipatch-410-linefile PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- STB : x-variable -------------
add_test(
    NAME    x-variable
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh STB && diff fromATLAStoSolver/st.tec reference/st.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/STB/x-variable"
)
set_tests_properties(x-variable PROPERTIES
    LABELS      "STB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- STB : area-any-order -------------
# An x-areavariation profile whose rows are not in coordinate order: STB sorts the rows, the area law is that of the
# sorted profile.
add_test(
    NAME    area-any-order
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh STB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/block1_area.dat fromATLAStoSolver/block1_area.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/STB/area-any-order"
)
set_tests_properties(area-any-order PROPERTIES
    LABELS      "STB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---------------------------------------------------------------------------
#  MDB : mesh decomposition
# ---------------------------------------------------------------------------
# Each case runs the pre-processing chain that produces MDB's own input (BCB,
# and ICB where a solution field is wanted), then splits it.  Three things are
# checked, in order of how well they explain a failure:
#
#   check-split.py  the split grid against the grid it came from: dimensions,
#                   cell conservation, and every value equal to the parent's
#   check-bc.py     the split BC file on its own terms: every boundary cell
#                   present exactly once, every connection reciprocal
#   diff            the decomposition map and the BC file against the reference,
#                   which pins the cut placement, the block numbering and the
#                   canonical record order MOSE's ghost exchange relies on
#
# The BC files are integer records copied verbatim -- the one real value, the
# roughness trailing a fluid-phase 103 record, is carried over as text -- so an
# exact diff is right here: no numeric tolerance is needed as it is for the
# chimera cases.

# ---- MDB : coupled-phases (two-phase interface remapping) -------------
# A fluid block over a solid block, split with different rank counts so the two
# phases are cut at different indices.  Type-103 donors are numbered in the
# other phase, so they have to be remapped against that phase's decomposition;
# resolving them against the phase being split corrupts the interface silently,
# which is what this pins.  check-coupling.py checks the pair of files against
# each other, which is the only place a 103 record can be validated.
add_test(
    NAME    coupled-phases
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/gas-bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/plate-bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-coupling.py fromATLAStoSolver/INPUT-split/gas-bc.txt fromATLAStoSolver/INPUT-split/plate-bc.txt && diff fromATLAStoSolver/gas-decomposition.map reference/gas-decomposition.map && diff fromATLAStoSolver/plate-decomposition.map reference/plate-decomposition.map && diff fromATLAStoSolver/INPUT-split/gas-bc.txt reference/gas-bc.txt && diff fromATLAStoSolver/INPUT-split/plate-bc.txt reference/plate-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/coupled-phases"
)
set_tests_properties(coupled-phases PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : dispersed-populations (dispersed-phase BC file, two MG levels) ----
# A dispersed phase with two materials, one of them in two populations, on two
# multigrid levels.  Such a file is shaped differently from a gas one in two
# ways, and both are pinned here: BCB repeats the whole boundary table once per
# (material, population) pair, block by block, and it writes no property line
# under a dispersed wall or symmetry where the gas and solid writers write one.
# Read with the gas convention every wall record swallows the next header, and
# the copies look like duplicate boundary cells -- MDB refused the file outright
# before.  Both levels carry the same three copies, so the coarse table is split
# as well, which also pins that BCB now writes one dispersed file per level.
add_test(
    NAME    dispersed-populations
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py --dispersed fromATLAStoSolver/INPUT-split/drop-bc.txt fromATLAStoSolver/INPUT-split/drop-bc2.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/drop-bc.txt reference/drop-bc.txt && diff fromATLAStoSolver/INPUT-split/drop-bc2.txt reference/drop-bc2.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/dispersed-populations"
)
set_tests_properties(dispersed-populations PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : coupled-phases-ks (uniform roughness on the interface) -------------
# coupled-phases with ks on the gas connection.  A fluid phase writes the
# roughness after the integers of each 103 record, and MDB has to carry it
# through the split.  The solid phase writes none, so its file and both
# decompositions are diffed against coupled-phases itself: adding the
# roughness must leave them untouched.
add_test(
    NAME    coupled-phases-ks
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/gas-bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/plate-bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-coupling.py fromATLAStoSolver/INPUT-split/gas-bc.txt fromATLAStoSolver/INPUT-split/plate-bc.txt && diff fromATLAStoSolver/gas-decomposition.map ../coupled-phases/reference/gas-decomposition.map && diff fromATLAStoSolver/plate-decomposition.map ../coupled-phases/reference/plate-decomposition.map && diff fromATLAStoSolver/INPUT-split/gas-bc.txt reference/gas-bc.txt && diff fromATLAStoSolver/INPUT-split/plate-bc.txt ../coupled-phases/reference/plate-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/coupled-phases-ks"
)
set_tests_properties(coupled-phases-ks PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : coupled-phases-ksfile (roughness varying along x, real fluid) -----
# Same interface, real-fluid gas, ks read from a file along x: the connection
# is then built facelet by facelet, each 103 record getting the value at its
# own centre.  Same checks as coupled-phases-ks.
add_test(
    NAME    coupled-phases-ksfile
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/gas-bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/plate-bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-coupling.py fromATLAStoSolver/INPUT-split/gas-bc.txt fromATLAStoSolver/INPUT-split/plate-bc.txt && diff fromATLAStoSolver/gas-decomposition.map ../coupled-phases/reference/gas-decomposition.map && diff fromATLAStoSolver/plate-decomposition.map ../coupled-phases/reference/plate-decomposition.map && diff fromATLAStoSolver/INPUT-split/gas-bc.txt reference/gas-bc.txt && diff fromATLAStoSolver/INPUT-split/plate-bc.txt ../coupled-phases/reference/plate-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/coupled-phases-ksfile"
)
set_tests_properties(coupled-phases-ksfile PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : split-longest (cut axis) -------------
add_test(
    NAME    split-longest
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/split-longest"
)
set_tests_properties(split-longest PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : grid-p3d-3D (a 3D grid given as PLOT3D) -------------
# MDB reads the grid of [MDB-Parameters] grid by its path: a PLOT3D file with five node planes (grid.p3d) must be split
# as the same grid given as mesh.tec, i.e. the products equal those of the same deck with grid = mesh.tec (run again in
# fromATLAStoSolver/tecplot): decomposition.map, INPUT-split/bc.txt and the nodes of mesh-split.tec (its ZONE lines
# carry the solution time of the grid file, which a PLOT3D file does not hold: its zones carry SOLUTIONTIME=0).
add_test(
    NAME    grid-p3d-3D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && mkdir fromATLAStoSolver/tecplot && cp phase.txt mesh.tec fromATLAStoSolver/tecplot/ && sed 's/grid = grid.p3d/grid = mesh.tec/' input.ini > fromATLAStoSolver/tecplot/input.ini && cd fromATLAStoSolver/tecplot && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && diff ../decomposition.map fromATLAStoSolver/decomposition.map && diff ../INPUT-split/bc.txt fromATLAStoSolver/INPUT-split/bc.txt && diff <(grep -v ZONE ../mesh-split.tec) <(grep -v ZONE fromATLAStoSolver/mesh-split.tec) && ! grep ZONE ../mesh-split.tec | grep -q -v -F 'SOLUTIONTIME=0.000000000000000E+000'"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/grid-p3d-3D"
)
set_tests_properties(grid-p3d-3D PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : block-directions (per-block split-directions) -------------
add_test(
    NAME    block-directions
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/block-directions"
)
set_tests_properties(block-directions PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : mg3-granularity (multigrid cut alignment, 3 BC levels) -------------
add_test(
    NAME    mg3-granularity
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt fromATLAStoSolver/INPUT-split/bc2.txt fromATLAStoSolver/INPUT-split/bc3.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt && diff fromATLAStoSolver/INPUT-split/bc2.txt reference/bc2.txt && diff fromATLAStoSolver/INPUT-split/bc3.txt reference/bc3.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/mg3-granularity"
)
set_tests_properties(mg3-granularity PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : halo-trade (balance/ghost-cell objective) -------------
add_test(
    NAME    halo-trade
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/halo-trade"
)
set_tests_properties(halo-trade PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : balance-only (halo-weight = 0, the historical objective) ----------
add_test(
    NAME    balance-only
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/balance-only"
)
set_tests_properties(balance-only PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : split-solution (grid + solution field, prefixed BC files) ---------
add_test(
    NAME    split-solution
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB ICB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py fromATLAStoSolver/gas-ic.tec fromATLAStoSolver/gas-ic-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/gas-bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/gas-bc.txt reference/gas-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/split-solution"
)
set_tests_properties(split-solution PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-Tvar-dispersed (Burcat/cantera table -> absolute enthalpy, header Enthalpy_abs) ----
# Numeric tolerance instead of a byte diff: rows are closed-form NASA-7 evaluations printed with
# 6 decimals; libm/FMA/cantera-minor drift is <= 1e-12 relative, a datum error is >= 1e-3 relative,
# a wrong column is O(1). tol = 1e-6 as in IG-chimera.
add_test(
    NAME    CP-Tvar-dispersed
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/phase.txt reference/phase.txt && grep -q Enthalpy_abs fromATLAStoSolver/properties.dat && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/properties.dat fromATLAStoSolver/properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-Tvar-dispersed"
)
set_tests_properties(CP-Tvar-dispersed PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-fixmat-h0 (fixed cp + h0 -> Enthalpy_abs with h(298.15 K) = h0) --------------------
add_test(
    NAME    CP-fixmat-h0
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/part-phase.txt reference/part-phase.txt && bash check_h0.sh fromATLAStoSolver/part-properties.dat && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/part-properties.dat fromATLAStoSolver/part-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-fixmat-h0"
)
set_tests_properties(CP-fixmat-h0 PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-fixmat-tokens (per-material key=value tokens on the material line) ------------------
# Same case as CP-fixmat-dispersed plus `evaporation = CEM` and `alpha-e = 0.5`: the material line must
# read `AL2O3(L) 1 evaporation=CEM alpha-e=0.5` (IGLOO reads the tokens there). The properties table is
# unaffected by the keys and stays byte-identical to CP-fixmat-dispersed's.
add_test(
    NAME    CP-fixmat-tokens
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/part-phase.txt reference/part-phase.txt && diff fromATLAStoSolver/part-properties.dat reference/part-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-fixmat-tokens"
)
set_tests_properties(CP-fixmat-tokens PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-massfraction-range (a y<species> value outside [0, 1] stops BCB with one message, the same
# ----       below 0 and above 1, naming the key and the value; nothing is written. A value outside [0, 1]
# ----       by rounding only (1.0000000000000002, -1.0e-20) is read as 1 and 0: bc.txt equals the one of
# ----       yO2 = 1, yCH4 = 0) -------------
add_test(
    NAME    IG-massfraction-range
    COMMAND bash -c "rm -rf fromATLAStoSolver exact && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input exact.ini < /dev/null && mv fromATLAStoSolver exact && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input rounding.ini < /dev/null && diff exact/bc.txt fromATLAStoSolver/bc.txt && rm -rf fromATLAStoSolver exact || exit 1; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input negative.ini 2>&1 < /dev/null); rc=$?; out2=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input above.ini 2>&1 < /dev/null); rc2=$?; echo \"$out\" | tail -n 2; echo \"$out2\" | tail -n 2; test $rc -eq 1 && test $rc2 -eq 1 && grep -q -F '[ERROR] key yCH4 = -0.1: the mass fraction must lie in [0, 1]' <<< \"$out\" && grep -q -F '[ERROR] key yO2 = 1.5: the mass fraction must lie in [0, 1]' <<< \"$out2\" && test $(grep -c -F '[ERROR]' <<< \"$out\") -eq 1 && test ! -e fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-massfraction-range"
)
set_tests_properties(IG-massfraction-range PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : mesh-tec-single-plane (a Tecplot mesh with x y z on one node plane, K = 1, follows the rule of a PLOT3D
# ----       mesh written Ni Nj 1: on the plane z = 0 and on a tilted plane it gives the bc.txt of mesh-p3d-single-plane,
# ----       with a WARNING for the tilted plane; on the plane x-z it is refused) -------------
add_test(
    NAME    mesh-tec-single-plane
    COMMAND bash -c "for d in xy tilted; do (cd $d && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > bcb.log 2>&1 && diff fromATLAStoSolver/bc.txt ../reference/bc.txt) || { cat $d/bcb.log; exit 1; }; done && ! grep -q -F '[WARNING] mesh block' xy/bcb.log && grep -q -F '[WARNING] mesh block 1: three coordinates on a single node plane are read as a 2D (x, y) mesh, but z is not constant' tilted/bcb.log && cd perpendicular && rm -rf fromATLAStoSolver && if ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > bcb.log 2>&1; then cat bcb.log; false; else grep -q -F '[ERROR] mesh block 1: three coordinates on a single node plane that is perpendicular to x-y' bcb.log && test ! -e fromATLAStoSolver/bc.txt; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/mesh-tec-single-plane"
)
set_tests_properties(mesh-tec-single-plane PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-mixture-cantera (frozen air mixture, Cantera transport: the mix zone must hold air) ----
add_test(
    NAME    IG-mixture-cantera
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && bash check_transport.sh fromATLAStoSolver/gas-transport.dat && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/gas-transport.dat fromATLAStoSolver/gas-transport.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-mixture-cantera"
)
set_tests_properties(IG-mixture-cantera PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)
