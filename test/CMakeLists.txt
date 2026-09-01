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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh GPB && diff fromATLAStoSolver/phase.txt reference/phase.txt && diff fromATLAStoSolver/composition.txt reference/composition.txt && diff fromATLAStoSolver/chemistry-info.txt reference/chemistry-info.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/GPB/IG-ceafile-reactive-OG"
)
set_tests_properties(ceafile-reactive-OG PROPERTIES
    LABELS      "GPB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : SP-basic -------------
add_test(
    NAME    SP-basic
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/solid-ic.tec reference/solid-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/SP-basic"
)
set_tests_properties(SP-basic PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-nozzle3D -------------
add_test(
    NAME    IG-nozzle3D
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/gas-ic.vtm reference/gas-ic.vtm"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/ic.tec reference/ic.tec"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-chimera+connection"
)
set_tests_properties(IG-chimera+connection PROPERTIES
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-force-chimera"
)
set_tests_properties(IG-force-chimera PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : CD-basic (dispersed-phase inlets, distribution field) -------------
add_test(
    NAME    CD-basic
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/CD-basic"
)
set_tests_properties(CD-basic PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- STB : x-variable -------------
add_test(
    NAME    x-variable
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh STB && diff fromATLAStoSolver/st.tec reference/st.tec"
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
# The BC files are integer records copied verbatim, so an exact diff is right
# here -- no numeric tolerance is needed as it is for the chimera cases.

# ---- MDB : split-longest (cut axis) -------------
add_test(
    NAME    split-longest
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt fromATLAStoSolver/INPUT-split/bc2.txt fromATLAStoSolver/INPUT-split/bc3.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt && diff fromATLAStoSolver/INPUT-split/bc2.txt reference/bc2.txt && diff fromATLAStoSolver/INPUT-split/bc3.txt reference/bc3.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
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
    COMMAND bash -c "${CMAKE_SOURCE_DIR}/ATLAS.sh BCB ICB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py fromATLAStoSolver/gas-ic.tec fromATLAStoSolver/gas-ic-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/gas-bc.txt && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/gas-bc.txt reference/gas-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/split-solution"
)
set_tests_properties(split-solution PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)
