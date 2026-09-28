# ---------------------------------------------------------------------------
#  CTest definitions for MOSE validation cases
# ---------------------------------------------------------------------------

# Common environment for all solver tests
set(_TEST_ENV
    "OMP_NUM_THREADS=1"
    "KMP_STACKSIZE=100M"
    "ATLASDIR=${CMAKE_SOURCE_DIR}"
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

# ---- ICB : IG+DP-populations (a scalar DP key reaches every population) --------------------------
# IG+DP with AL2O3(L) on two populations: the scalar krho and dp of the zone must give population 2
# the fields of population 1, and population 1 must equal IG+DP's reference.
add_test(
    NAME    IG+DP-populations
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && python3 check_populations.py fromATLAStoSolver/particles-ic.tec ../IG+DP/reference/particles-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG+DP-populations"
)
set_tests_properties(IG+DP-populations PROPERTIES
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
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
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
add_test(
    NAME    IG-inflow-ceafile-inertmix
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-inflow-ceafile-inertmix"
)
set_tests_properties(IG-inflow-ceafile-inertmix PROPERTIES
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

# ---- BCB : DP-population-list (a per-population key: one value per (material, population)) --------
# DP-multigrid's phase (alumina 2 populations, water 1) on one level: drop-Tp and drop-dp list the three
# pairs in phase-file order, the other keys are scalars and reach every copy of the table.
add_test(
    NAME    DP-population-list
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py --dispersed fromATLAStoSolver/drop-bc.txt && diff fromATLAStoSolver/drop-bc.txt reference/drop-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-population-list"
)
set_tests_properties(DP-population-list PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-population-count (any count other than 1 or one per pair is refused) ----------------
# drop-Tp gives two values for three (material, population) pairs: BCB must stop with exit 1.
add_test(
    NAME    DP-population-count
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 | tee bcb.log && grep -q 'drop-Tp: 2 value(s) for 3 (material, population) pairs' bcb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-population-count"
)
set_tests_properties(DP-population-count PROPERTIES
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

# ---- GPB : CP-Tvar-fallback (a material the database lacks takes its INI constants) --------------
# thermo = Burcat with FOO(L) AL2O3(L): FOO(L) is not in burcat.yaml and falls back to cp/rho/h0 of
# the INI (one value broadcast for cp and h0), AL2O3(L) keeps its Burcat table and its own rho.
# groups = 2 1 must reach the phase file in the same order.
add_test(
    NAME    CP-Tvar-fallback
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB 2>&1 | tee gpb.log && grep -q 'FOO(L) is not in burcat.yaml' gpb.log && diff fromATLAStoSolver/part-phase.txt reference/part-phase.txt && bash check_fallback.sh fromATLAStoSolver/part-properties.dat && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/part-properties.dat fromATLAStoSolver/part-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-Tvar-fallback"
)
set_tests_properties(CP-Tvar-fallback PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-Tvar-missing (a material the database lacks, with no constants, is refused) ---------
# The reported defect: FOO(L) H2O(L) with rho = 1000 997 and no cp used to write one zone, H2O(L)
# with FOO(L)'s density. Now GPB stops and names the material and the database.
add_test(
    NAME    CP-Tvar-missing
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB 2>&1 | tee gpb.log && grep -q 'FOO(L): not in nasa9.yaml, and no cp is given' gpb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-Tvar-missing"
)
set_tests_properties(CP-Tvar-missing PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-Tvar-fallback-h0 (a fallback next to a database material needs h0) -----------------
# CP-Tvar-fallback without h0: the phase would mix the absolute (Burcat) and the relative (cp*T)
# enthalpy datum, so GPB stops and asks for h0.
add_test(
    NAME    CP-Tvar-fallback-h0
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB 2>&1 | tee gpb.log && grep -q 'give h0' gpb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-Tvar-fallback-h0"
)
set_tests_properties(CP-Tvar-fallback-h0 PROPERTIES
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

# ---- GPB : CP-psat-water (psat-vapour -> Psat column from the database's liquid/vapour pair) -------
# CP-fixmat-h0's water on 280..380 K plus `psat-vapour = H2O`: the table gains "Psat" [Pa] after
# "Enthalpy_abs", p_sat = 1e5*exp(-(g_H2O - g_H2O(L))/(R T)) from nasa9.yaml. check_psat.sh holds it to
# IAPWS at 300 and 350 K; the phase file stays CP-fixmat-h0's (the keys are not material-line tokens).
add_test(
    NAME    CP-psat-water
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/part-phase.txt ../CP-fixmat-h0/reference/part-phase.txt && bash check_psat.sh fromATLAStoSolver/part-properties.dat && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/part-properties.dat fromATLAStoSolver/part-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-psat-water"
)
set_tests_properties(CP-psat-water PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-psat-water-eulerian (the Psat column does not depend on the solver treatment) --------
# CP-psat-water with `modeling = eulerian`: line 1 of the phase file carries modeling=eulerian and the
# table is CP-psat-water's (ICE reads the same column as IGLOO).
add_test(
    NAME    CP-psat-water-eulerian
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/part-phase.txt reference/part-phase.txt && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk ../CP-psat-water/reference/part-properties.dat fromATLAStoSolver/part-properties.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-psat-water-eulerian"
)
set_tests_properties(CP-psat-water-eulerian PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-psat-refuse (a pair of different compositions is refused) ----------------------------
# CP-psat-water with `psat-vapour = O2`: GPB must stop with exit 1 and the composition message
# (same expect-failure form as DP-bad-name).
add_test(
    NAME    CP-psat-refuse
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB 2>&1 | tee gpb.log && grep -q 'different elemental compositions' gpb.log"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-psat-refuse"
)
set_tests_properties(CP-psat-refuse PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : database-flint-contract (every database/chemistry yaml whose phase name selects a compiled FLINT routine matches the routine in the copy of FLINT's contract file, test/tools/flint_mechanism_contract.json; the hooks below are pinned) -------------
add_test(
    NAME    database-flint-contract
    COMMAND bash -c "if [ -z \"\${ATLAS_PYTHON:-}\" ] && command -v conda >/dev/null 2>&1; then eval \"\$(conda shell.bash hook)\" && conda activate \"\${ATLAS_CONDA_ENV:-ct-env}\" || exit 1; fi; \"\${ATLAS_PYTHON:-python3}\" -B ${CMAKE_SOURCE_DIR}/test/tools/flint_contract_check.py ${CMAKE_SOURCE_DIR}/database --expect UCSD.yaml=sandiego20161214 Frolov.yaml=Frolov Frolov_nopressure.yaml=Frolov_nopressure Nassini_Original.yaml=Nassini_4 Nassini_Montanari_Grossi.yaml=Nassini_4 FFCMy_12.yaml=FFCMy_12 ONERA-7.yaml=ONERA_7 ONERA-7_rev.yaml=general"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/tools"
)
set_tests_properties(database-flint-contract PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-reactions-without-thermo (reactions = without thermo: the thermo records of the file are used, said with an INFO line; thermo.dat, chemistry-info.txt and chemistry-Arrhenius.dat equal to those of phase = on the same file) -------------
add_test(
    NAME    IG-reactions-without-thermo
    COMMAND bash -c "rm -rf fromATLAStoSolver _run-reactions && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1 && grep -q -F '[INFO] GPB: reactions = tiny-h2 without thermo: the thermo records of the file are used' gpb.log && ! grep -q -F 'not present in the employed database' gpb.log && mv fromATLAStoSolver _run-reactions && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB --input phase.ini > gpb-phase.log 2>&1 && diff _run-reactions/thermo.dat fromATLAStoSolver/thermo.dat && diff _run-reactions/chemistry-info.txt fromATLAStoSolver/chemistry-info.txt && diff _run-reactions/chemistry-Arrhenius.dat fromATLAStoSolver/chemistry-Arrhenius.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-reactions-without-thermo"
)
set_tests_properties(IG-reactions-without-thermo PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-strict-thermo (strict-thermo = true refuses a database thermo record that differs from the file record by more than 1 kJ/mol at 298.15 K) -------------
add_test(
    NAME    IG-strict-thermo
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1; then cat gpb.log; false; else grep -q -F '[ERROR] GPB: strict-thermo = true: the database thermo differs by more than 1 kJ/mol at 298.15 K (or at the lower bound of a record that starts above it) for: H2O' gpb.log; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-strict-thermo"
)
set_tests_properties(IG-strict-thermo PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-fixgas-gas-constant (a species given by gamma and mw: cp = gamma/(gamma-1) R_u/mw with the exact R_u = 8314.46261815324 J/(kmol K)) -------------
add_test(
    NAME    IG-fixgas-gas-constant
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && awk 'BEGIN{cp=3.5*8314.46261815324/28.97; n=0; bad=0} /^ *[0-9]/{ n++; d=$2-cp; if(d<0) d=-d; if(d>2e-6) bad++ } END{ exit (n==5000 && bad==0) ? 0 : 1 }' fromATLAStoSolver/air-thermo.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-fixgas-gas-constant"
)
set_tests_properties(IG-fixgas-gas-constant PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-transport-CEA-species-without-data (transport = CEA with a mechanism species that has no transport data and exists in the thermo database: accepted, transport.dat equal to the one of the same mechanism with transport records) -------------
add_test(
    NAME    IG-transport-CEA-species-without-data
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/transport.dat reference/transport.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-transport-CEA-species-without-data"
)
set_tests_properties(IG-transport-CEA-species-without-data PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : CP-tmin-noninteger (a non-integer Tmin of a condensed phase is refused naming the key; the products of the ideal-gas phase before it, with an integer Tmin = 300, are not left behind) -------------
add_test(
    NAME    CP-tmin-noninteger
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1; then cat gpb.log; false; else grep -q -F '[ERROR] key Tmin of section [GPB-Phase2]: Tmin = 300.5 is not an integer number of kelvin' gpb.log && ! grep -q 'section \\[GPB-Phase1\\]' gpb.log && test ! -e fromATLAStoSolver && ! ls -d .gpb-tmp-* 2>/dev/null; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/CP-tmin-noninteger"
)
set_tests_properties(CP-tmin-noninteger PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : GPB-tmin-range (Tmin at or below 0 K, or above Tmax, stops GPB naming the key (ideal gas and condensed phase)) -------------
add_test(
    NAME    GPB-tmin-range
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh GPB --input tmin-zero.ini 2>&1); test $? -eq 1 && grep -q -F '[ERROR] key Tmin of section [GPB-Phase1]: Tmin = 0 is not a temperature above 0 K' <<< \"$out\" && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh GPB --input tmin-above-tmax.ini 2>&1); test $? -eq 1 && grep -q -F 'Tmin = 450 is above Tmax = 400' <<< \"$out\" && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh GPB --input cp-tmin-zero.ini 2>&1); test $? -eq 1 && grep -q -F 'Tmin = 0 is not a temperature above 0 K' <<< \"$out\""
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/GPB-tmin-range"
)
set_tests_properties(GPB-tmin-range PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-falloff-irreversible-orders (k_c = 0 on every row of an irreversible falloff reaction, > 0 on a reversible one, in the Lindemann and Troe tables; explicit orders of a phase FLINT runs with general end chemistry-info.txt as the orders block) -------------
add_test(
    NAME    IG-falloff-irreversible-orders
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1 && for f in Lindemann Troe; do awk 'BEGIN{z=0;bad=0} /^ZONE/{z++} /^ *[0-9]/{ if(z==1 && $4+0<=0) bad++; if(z==2 && $4+0!=0) bad++ } END{ if(z!=2) bad++; exit bad?1:0 }' fromATLAStoSolver/chemistry-$f.dat || exit 1; done && tail -n 4 fromATLAStoSolver/chemistry-info.txt | diff - expected-orders.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-falloff-irreversible-orders"
)
set_tests_properties(IG-falloff-irreversible-orders PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-orders-block-always (the orders block ends chemistry-info.txt whatever the phase name: a phase named like a compiled FLINT routine (WD) keeps its explicit orders) -------------
add_test(
    NAME    IG-orders-block-always
    COMMAND bash -c "rm -rf _run-hooked && mkdir _run-hooked && cp *.ini *.yaml *.txt _run-hooked/ 2>/dev/null; cd _run-hooked && ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB --input hooked.ini > gpb.log 2>&1 && tail -n 4 fromATLAStoSolver/chemistry-info.txt | diff - expected-orders.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-falloff-irreversible-orders"
)
set_tests_properties(IG-orders-block-always PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : GPB-falloff-form-refused (a falloff form other than Troe and Lindemann (here Tsang) stops GPB naming the reaction: the tables could not hold it) -------------
add_test(
    NAME    GPB-falloff-form-refused
    COMMAND bash -c "rm -rf _run-tsang && mkdir _run-tsang && cp *.ini *.yaml *.txt _run-tsang/ 2>/dev/null; cd _run-tsang && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh GPB --input tsang.ini 2>&1); test $? -eq 1 && grep -q -F '1 (H + O2 (+M) <=> HO2 (+M); falloff-Tsang)' <<< \"$out\" && test ! -e fromATLAStoSolver/chemistry-info.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-falloff-irreversible-orders"
)
set_tests_properties(GPB-falloff-form-refused PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-phase-file-name-hint (phase = takes the yaml file name: phase = WD-Andersen, the phase name inside WD-andersen.yaml, stops with an error that suggests WD-andersen) -------------
add_test(
    NAME    IG-phase-file-name-hint
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1; then cat gpb.log; false; else grep -q -F 'did you mean phase = WD-andersen?' gpb.log; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-phase-file-name-hint"
)
set_tests_properties(IG-phase-file-name-hint PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-ct-equilibrium -------------
# The Cantera equilibrium of the tutorial (eq-of, eq-pressure, eq-fuel, eq-oxidizer): the phase holds the species of
# the H2/O2 flame above the mole-fraction threshold; phase and composition files as in the reference, thermo table written.
add_test(
    NAME    IG-ct-equilibrium
    COMMAND bash -c "rm -rf fromATLAStoSolver && { ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1 || { cat gpb.log; false; }; } && diff fromATLAStoSolver/gasmix-phase.txt reference/gasmix-phase.txt && diff fromATLAStoSolver/gasmix-composition.txt reference/gasmix-composition.txt && test -s fromATLAStoSolver/gasmix-thermo.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-ct-equilibrium"
)
set_tests_properties(IG-ct-equilibrium PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : IG-ct-equilibrium-inerts -------------
# Cantera equilibrium at a rich mixture (eq-of = 2) with inerts-mixing = true and add-species = N2: the cte-mixture
# pseudo-species has the mean molecular weight of the kept equilibrium species (H, H2, H2O), each with its own mass
# fraction, and the added N2 stays a separate species of the phase.
add_test(
    NAME    IG-ct-equilibrium-inerts
    COMMAND bash -c "rm -rf fromATLAStoSolver && { ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1 || { cat gpb.log; false; }; } && awk -v tol=1e-5 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/gasmix-phase.txt fromATLAStoSolver/gasmix-phase.txt && diff fromATLAStoSolver/gasmix-composition.txt reference/gasmix-composition.txt && test -s fromATLAStoSolver/gasmix-thermo.dat"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-ct-equilibrium-inerts"
)
set_tests_properties(IG-ct-equilibrium-inerts PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- GPB : GPB-launcher-atlasdir (ATLAS.sh derives ATLASDIR from its own location and passes it to GPB when the environment does not set it) -------------
add_test(
    NAME    GPB-launcher-atlasdir
    COMMAND bash -c "rm -rf _run-env && mkdir _run-env && cp *.ini *.yaml *.txt _run-env/ 2>/dev/null; cd _run-env && env -u ATLASDIR ${CMAKE_SOURCE_DIR}/ATLAS.sh GPB > gpb.log 2>&1 && tail -n 4 fromATLAStoSolver/chemistry-info.txt | diff - expected-orders.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-falloff-irreversible-orders"
)
set_tests_properties(GPB-launcher-atlasdir PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)
