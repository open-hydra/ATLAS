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
# _run-zones: the dispersed-phase keys of a zone apply to the cells of that zone: krho 0.20 and 0.40 in two zones
# (zones-krho.ini); an interpolated zone next to a vacuum zone in a block that builds only the dispersed phase
# (zones-interp.ini); check_zones.py compares the cells of each zone with the reference of IG+DP.
add_test(
    NAME    IG+DP
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/particles-ic.tec reference/particles-ic.tec && rm -rf _run-zones && mkdir _run-zones && cp *.ini *.tec *.txt *.dat _run-zones/ && cd _run-zones && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input zones-krho.ini && python3 ../check_zones.py fromATLAStoSolver/particles-ic.tec ../reference/particles-ic.tec krho && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input zones-interp.ini && python3 ../check_zones.py fromATLAStoSolver/particles-ic.tec ../reference/particles-ic.tec interp"
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

# ---- ICB : ICB-type-refused (a zone type that no writer knows, here one of an older ATLAS generation,
# ----       stops ICB naming the value; nothing is written) -------------
add_test(
    NAME    ICB-type-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F 'value 1D-centcomp not allowed' <<< \"$out\" && test ! -e fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/ICB-type-refused"
)
set_tests_properties(ICB-type-refused PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG+DP-phase-order (phase = particles gas builds as gas particles: the dispersed state derives from the gas state) -------------
add_test(
    NAME    IG+DP-phase-order
    COMMAND bash -c "rm -rf _run-order && mkdir _run-order && cp *.ini *.tec *.txt *.dat _run-order/ 2>/dev/null; cd _run-order && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input particles-gas.ini && diff fromATLAStoSolver/particles-ic.tec ../reference/particles-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG+DP"
)
set_tests_properties(IG+DP-phase-order PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : ICB-phase-key-refused (a phase name that no phase file declares, and a dispersed phase without the gas it derives from, stop ICB naming the cause) -------------
add_test(
    NAME    ICB-phase-key-refused
    COMMAND bash -c "rm -rf _run-keys && mkdir _run-keys && cp *.ini *.tec *.txt *.dat _run-keys/ 2>/dev/null; cd _run-keys && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input phase-undeclared.ini 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 2; test $rc -eq 1 && grep -q -F 'phase part is declared by no <name>-phase.txt (declared: gas, particles)' <<< \"$out\" && test ! -e fromATLAStoSolver/gas-ic.tec && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input particles-only.ini 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 2; test $rc -eq 1 && grep -q -F 'the block builds no ideal-gas phase' <<< \"$out\""
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG+DP"
)
set_tests_properties(ICB-phase-key-refused PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ===========================================================================
#  Fixtures for behaviours that no registered test reached (every reference
#  comes from an independent oracle: analytic values, the deck's own numbers
#  or a 30-digit replica, never from a snapshot of ATLAS output)
# ===========================================================================

# The p-file fixture IG-pfile-oneplane-2block (registered with the ICB cases above): a source
# array allocated too short (zero k extent for a one-plane file) is written AND read back through the same
# addresses, so the field stays right and the overrun is undefined behaviour that no
# output oracle can see. glibc's MALLOC_CHECK_=3 (inert on glibc >= 2.34) and ifx
# -check bounds turn it into a crash only for some heap layouts; the deterministic
# guard is the shape assertion of load_source (field array extents vs data extents:
# [ERROR] and a non-zero status). What such a source
# STORES (one plane, Nj planes) is compared against the reference and is output-killed.

# ===========================================================================
#  ICB: interpolation laws, zone writers and the initialised-cell rule
# ===========================================================================

# ---- ICB : IG-interp-2D (pure-2D source onto a pure-2D target, index law) -------------
add_test(
    NAME    IG-interp-2D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/gas-ic.tec reference/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-2D"
)
set_tests_properties(IG-interp-2D PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-2Dto3D (pure-2D source onto a revolved 3D target: the source mesh is classified
# ----       in its own configuration, the product keeps the 3D layout of the target) -------------
add_test(
    NAME    IG-interp-2Dto3D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/gas-ic.tec fromATLAStoSolver/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-2Dto3D"
)
set_tests_properties(IG-interp-2Dto3D PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-rans-src (source with a trailing turbulence band: the SA model of the source
# ----       is adopted and mi_t interpolated, the species count skips the surplus band) -------------
add_test(
    NAME    IG-interp-rans-src
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/gas-ic.tec reference/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-rans-src"
)
set_tests_properties(IG-interp-rans-src PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-3D (3D source onto a 3D target, index law) -------------
add_test(
    NAME    IG-interp-3D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/gas-ic.tec reference/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-3D"
)
set_tests_properties(IG-interp-3D PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-extrude (interpolation-law = extrude, theta = 60, nz = 4: the 2D source revolved
# ----       onto a target revolved with the same cells gives the field of the index law) -------------
add_test(
    NAME    IG-interp-extrude
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input index.ini && mkdir fromATLAStoSolver/index && mv fromATLAStoSolver/gas-ic.tec fromATLAStoSolver/index/ && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input extrude.ini && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk fromATLAStoSolver/index/gas-ic.tec fromATLAStoSolver/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-extrude"
)
set_tests_properties(IG-interp-extrude PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-zones-index-direction (zones ranged by cell index, direction = i, give the field of the
# ----       same zones ranged by coordinate) -------------
add_test(
    NAME    IG-zones-index-direction
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input coordinate.ini && mkdir fromATLAStoSolver/coordinate && mv fromATLAStoSolver/ic.tec fromATLAStoSolver/coordinate/ && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input index.ini && diff fromATLAStoSolver/coordinate/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-zones-index-direction"
)
set_tests_properties(IG-zones-index-direction PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-zone-interp-range (an interpolation zone writes the cells of its range only: after a
# ----       homogeneous zone it gives the field of the same zones in the other order) -------------
add_test(
    NAME    IG-zone-interp-range
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input interp-first.ini && mkdir fromATLAStoSolver/first && mv fromATLAStoSolver/ic.tec fromATLAStoSolver/first/ && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input interp-last.ini && diff fromATLAStoSolver/first/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-zone-interp-range"
)
set_tests_properties(IG-zone-interp-range PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : SP-interp (a solid field interpolated onto its own mesh is the source field) -------------
add_test(
    NAME    SP-interp
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/solid-ic.tec source.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/SP-interp"
)
set_tests_properties(SP-interp PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-pfile-oneplane-2block (one-plane K=1 p-file sources: ORION returns Nk = 0, the source
# ----       array still needs one plane) -------------
add_test(
    NAME    IG-pfile-oneplane-2block
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-pfile-oneplane-2block"
)
set_tests_properties(IG-pfile-oneplane-2block PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV};MALLOC_PERTURB_=165;MALLOC_CHECK_=3"
)

# ---- ICB : IG-pfile-oneplane-noK (the same two-block pure 2-D p-file written without K in its ZONE lines reads like K=1: the product equals the K=1 reference) -------------
add_test(
    NAME    IG-pfile-oneplane-noK
    COMMAND bash -c "rm -rf _run-noK && mkdir _run-noK && cp *.ini *.tec *.txt *.dat _run-noK/ 2>/dev/null; cd _run-noK && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input noK.ini && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk ../reference/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-pfile-oneplane-2block"
)
set_tests_properties(IG-pfile-oneplane-noK PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV};MALLOC_PERTURB_=165;MALLOC_CHECK_=3"
)

# ---- ICB : IG-zone-unwritten-refused (cells that no zone writes stop ICB naming the block, the phase and
# ----       the count; nothing is written) -------------
add_test(
    NAME    IG-zone-unwritten-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '8 of 32 cells are initialised by no zone' <<< \"$out\" && test ! -e fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-zone-unwritten-refused"
)
set_tests_properties(IG-zone-unwritten-refused PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-zone-interp-range-turb (a partial interpolation zone that adopts the source turbulence model writes mi_t in its range only; the cells of the other zone keep 0) -------------
add_test(
    NAME    IG-zone-interp-range-turb
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-zone-interp-range-turb"
)
set_tests_properties(IG-zone-interp-range-turb PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV};MALLOC_PERTURB_=165"
)

# ---- ICB : IG-range-separator-refused (a TAB between the two values of range<n> stops ICB naming the separator (the values are read on blanks)) -------------
add_test(
    NAME    IG-range-separator-refused
    COMMAND bash -c "rm -rf _run-tab && mkdir _run-tab && cp *.ini *.tec *.txt *.dat _run-tab/ 2>/dev/null; cd _run-tab && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input range-tab.ini 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 2; test $rc -eq 1 && grep -q -F 'separate the values with blanks (a TAB is not read as a separator)' <<< \"$out\" && test ! -e fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-multizone"
)
set_tests_properties(IG-range-separator-refused PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-turbulence-zero-refused (a k-omega zone (nrans = 2) with kappa and no omega stops ICB: omega = 0 would divide in the solver kernels; nothing is written) -------------
add_test(
    NAME    IG-turbulence-zero-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '[ERROR] build_IG_field: turbulence band omega (key omega) would be written as 0 under the k-omega (nrans = 2) model' <<< \"$out\" && test ! -e fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-turbulence-zero-refused"
)
set_tests_properties(IG-turbulence-zero-refused PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-state-not-physical (a zone with a negative pressure stops ICB naming the first cell and the state; nothing is written) -------------
add_test(
    NAME    IG-state-not-physical
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F '[ERROR] build_IG_field block 1: the initial field is not physical at cell (1,1,1)' <<< \"$out\" && test ! -e fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-state-not-physical"
)
set_tests_properties(IG-state-not-physical PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-band-refused (an interpolation source whose band after the velocities is T, not p, stops ICB naming the band: the bands would be shifted; nothing is written) -------------
add_test(
    NAME    IG-interp-band-refused
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F \"[ERROR] read_vtk_tec: band 5 of 'field.tec' is named 'T' but the declared layout expects 'p' there\" <<< \"$out\" && test ! -e fromATLAStoSolver/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-band-refused"
)
set_tests_properties(IG-interp-band-refused PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-species-profile-linear (yH2-file and yN2-file: two-row tables along x, in a zone ranged along y,
# ----       next to the constant yO2: every cell holds the mass fractions of the linear law at its centre, summing
# ----       to 1, and a density that follows its own composition; check-fractions.py computes them) -------------
add_test(
    NAME    IG-species-profile-linear
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && python3 check-fractions.py"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-species-profile-linear"
)
set_tests_properties(IG-species-profile-linear PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-2D-wband (the source of IG-interp-2D with a third velocity band w = 0 after v: a pure-2D
# ----       source that carries the w band is read, the product is that of IG-interp-2D) -------------
add_test(
    NAME    IG-interp-2D-wband
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff fromATLAStoSolver/gas-ic.tec reference/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-2D-wband"
)
set_tests_properties(IG-interp-2D-wband PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-block-no-section (a block that no [ICB-Block<n>] or [ICB-Block*] section describes stops ICB
# ----       naming the block; nothing is written) -------------
add_test(
    NAME    IG-block-no-section
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 1 && grep -q -F 'block 1 has no initial state: give a section [ICB-Block1]' <<< \"$out\" && test ! -e fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-block-no-section"
)
set_tests_properties(IG-block-no-section PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-phase-unbuilt (a phase that no block names is not written: one WARNING, the gas field
# ----       is written, no part-ic.tec) -------------
add_test(
    NAME    IG-phase-unbuilt
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input unbuilt.ini 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 0 && test $(grep -c -F -- '[WARNING] key phase of section [ICB-Block*]: the phase of part-phase.txt is built by no block' <<< \"$out\") -eq 1 && test -s fromATLAStoSolver/gas-ic.tec && test ! -e fromATLAStoSolver/part-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-phase-unbuilt"
)
set_tests_properties(IG-phase-unbuilt PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV};MALLOC_PERTURB_=165"
)

# ---- ICB : IG-interp-spherical-3D (interpolation-law = spherical_minimum_distance on a 3-D target: from a one-cell source it equals minimum_distance) -------------
add_test(
    NAME    IG-interp-spherical-3D
    COMMAND bash -c "rm -rf fromATLAStoSolver md && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input md.ini && mv fromATLAStoSolver md && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff md/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-spherical-3D"
)
set_tests_properties(IG-interp-spherical-3D PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-src-3coord-plane (an interpolation source written as a slice, x y z on one node plane
# ----       K = 1 with z nodal and the bands cell-centred, gives the product of the same source written
# ----       with x y only) -------------
add_test(
    NAME    IG-interp-src-3coord-plane
    COMMAND bash -c "rm -rf fromATLAStoSolver xy && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input xy.ini < /dev/null && mv fromATLAStoSolver xy && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB < /dev/null && diff xy/ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-src-3coord-plane"
)
set_tests_properties(IG-interp-src-3coord-plane PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-nozzle-plenum-order (the plenum rows of a nozzle zone cover the whole cross-section upstream of
# ----       nozzle-threshold, also outside the range of the zone: a homogeneous zone listed before the nozzle zone
# ----       loses 4 cells to the plenum, listed after it takes them back; a WARNING names each case and the
# ----       products of both orders are unchanged; unlike the other fixtures of this block, the two references are
# ----       ATLAS output, since the nozzle law has no simple independent oracle) -------------
add_test(
    NAME    IG-nozzle-plenum-order
    COMMAND bash -c "rm -rf fromATLAStoSolver first; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB 2>&1 < /dev/null) && mv fromATLAStoSolver first && out2=$(${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input reverse.ini 2>&1 < /dev/null) && grep -q -F 'block 1 (section [noz]): the plenum rows of this nozzle zone' <<< \"$out\" && grep -q -F 'overwrite 4 cells that an earlier zone wrote: the zone order decides' <<< \"$out\" && grep -q -F 'block 1 (section [hom]): this zone overwrites 4 cells that the plenum rows of an earlier nozzle zone' <<< \"$out2\" && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/ic.tec first/ic.tec && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/reverse-ic.tec fromATLAStoSolver/ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-nozzle-plenum-order"
)
set_tests_properties(IG-nozzle-plenum-order PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-multiple-x3-3D (a uniform 2x2x2 source refined by 3 in 3-D with interpolation-law =
# ----       multiple must stay uniform: the product equals the one of minimum_distance) -------------
add_test(
    NAME    IG-interp-multiple-x3-3D
    COMMAND bash -c "rm -rf fromATLAStoSolver md && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input md.ini && mv fromATLAStoSolver md && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && diff md/gas-ic.tec fromATLAStoSolver/gas-ic.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-multiple-x3-3D"
)
set_tests_properties(IG-interp-multiple-x3-3D PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-interp-multiple-x3-linear (a field linear in the cell indices, refined by 3 with interpolation-law =
# ----       multiple, is reproduced exactly inside the block in 2-D and in 3-D: the edge, corner and vertex sub-cells
# ----       use products of 2/3 and 1/3; the references hold the linear values there) -------------
add_test(
    NAME    IG-interp-multiple-x3-linear
    COMMAND bash -c "for d in 2D 3D; do (cd $d && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB < /dev/null && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/gas-ic.tec fromATLAStoSolver/gas-ic.tec) || exit 1; done"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-interp-multiple-x3-linear"
)
set_tests_properties(IG-interp-multiple-x3-linear PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG-ic-write-failure (TecIO builds: the binary initial condition cannot be written, because a folder
# ----       stands where the file goes; ORION returns an error and ICB stops with exit status 1 naming the file,
# ----       instead of ending as a success without an initial condition) -------------
if(USE_TECIO)
add_test(
    NAME    IG-ic-write-failure
    COMMAND bash -c "rm -rf fromATLAStoSolver && mkdir -p fromATLAStoSolver/ic.szplt && if ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB > icb.log 2>&1 < /dev/null; then cat icb.log; false; else cat icb.log; grep -q -F 'ic.szplt (ORION error' icb.log && grep -q -F 'no initial condition was written for this phase' icb.log; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG-ic-write-failure"
)
set_tests_properties(IG-ic-write-failure PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)
endif()

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
# Twall-extra.dat: a row with a third number (0.5 400.0 999) is read as its first two, as upstream reads it, with a
# WARNING naming it; a comment after the two numbers of a row gives no WARNING; bc.txt is the same.
add_test(
    NAME    IG-table-header-skipped
    COMMAND bash -c "rm -rf fromATLAStoSolver _run-extra; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F '[WARNING] table file Twall.dat: line 1 is not two numbers (coordinate value), skipped: x T' <<< \"$out\" && diff fromATLAStoSolver/bc.txt reference/bc.txt && mkdir _run-extra && cp input.ini mesh.tec phase.txt _run-extra/ && cp Twall-extra.dat _run-extra/Twall.dat && cd _run-extra && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F '[WARNING] table file Twall.dat: line 3 holds more than two numbers: the first two are read (coordinate value), the rest is ignored: 0.5 400.0 999' <<< \"$out\" && ! grep -q -F 'line 2 ' <<< \"$out\" && diff fromATLAStoSolver/bc.txt ../reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-table-header-skipped"
)
set_tests_properties(IG-table-header-skipped PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-table-not-monotone -------------
# A T-file whose coordinate column turns back (0, 1, 0.5) is refused: the table reader names the row and BCB says the
# file is refused for its content (it exists); no bc.txt.
add_test(
    NAME    IG-table-not-monotone
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > bcb.log 2>&1; then cat bcb.log; false; else grep -q -F '[ERROR] table file Twall.dat: the coordinate column is not monotone at row 3' bcb.log && grep -q -F '[ERROR] BC file Twall.dat refused: its coordinate column is not monotone' bcb.log && ! grep -q -F 'BC file Twall.dat not found' bcb.log && test ! -e fromATLAStoSolver/bc.txt; fi"
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

# ---- BCB : DP-population-forms (the per-population reader's value forms) --------------------------
# DP-population-list with drop-Tp = 450, 460, 470, drop-dp = 0.01/ 0.02, 0.03, and drop-gp = 3*345.0
# (one value for every pair): the per-population reader reads each token with list-directed input,
# so the BC file must be DP-population-list's.
add_test(
    NAME    DP-population-forms
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/drop-bc.txt ../DP-population-list/reference/drop-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-population-forms"
)
set_tests_properties(DP-population-forms PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- ICB : IG+DP-population-forms (the same forms in an ICB block section) ------------------------
# krho = 0.20, 0.30, and dp = 2*20e-6: the particle fields must be those of krho = 0.20 0.30 and
# dp = 20e-6.
add_test(
    NAME    IG+DP-population-forms
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB && mkdir fromATLAStoSolver/plain && mv fromATLAStoSolver/particles-ic.tec fromATLAStoSolver/plain/block.tec && ${CMAKE_SOURCE_DIR}/ATLAS.sh ICB --input forms.ini && cmp fromATLAStoSolver/particles-ic.tec fromATLAStoSolver/plain/block.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/ICB/IG+DP-population-forms"
)
set_tests_properties(IG+DP-population-forms PROPERTIES
    LABELS      "ICB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : DP-logical-forms (logical values as FiNeR's get reads them) ----------------------------
# DP-population-list with the logical keys of [ATLAS-Parameters] written .true # ..., T ! ..., F and
# a TAB, false, (their defaults): FiNeR reads the first item of the value, so the BC file must be
# DP-population-list's. chimera/ is IG-chimera's deck with BC-chimera = T#note, a comment attached to
# a value that is not the default: its BC file must be IG-chimera's (same tolerance as IG-chimera).
# _run-strict: strict-keys is read before any key table, with the rule of every logical key: Tomato stops the tool
# with the message of that rule and no BC file; true and .false. give DP-population-list's BC file.
add_test(
    NAME    DP-logical-forms
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/drop-bc.txt ../DP-population-list/reference/drop-bc.txt && cd chimera && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-6 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk ../../IG-chimera/reference/bc.txt fromATLAStoSolver/bc.txt && cd .. && rm -rf _run-strict && mkdir _run-strict && cp input.ini mesh.tec drop-phase.txt _run-strict/ && cd _run-strict && sed -i 's/^strict-keys = .*/strict-keys = Tomato/' input.ini && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 1; test $rc -eq 1 && grep -q -F '[ERROR] key strict-keys of section [ATLAS-Parameters]: value Tomato is not a logical (T or F)' <<< \"$out\" && test ! -e fromATLAStoSolver/drop-bc.txt && sed -i 's/^strict-keys = .*/strict-keys = true/' input.ini && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > /dev/null && diff fromATLAStoSolver/drop-bc.txt ../../DP-population-list/reference/drop-bc.txt && rm -rf fromATLAStoSolver && sed -i 's/^strict-keys = .*/strict-keys = .false./' input.ini && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > /dev/null && diff fromATLAStoSolver/drop-bc.txt ../../DP-population-list/reference/drop-bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/DP-logical-forms"
)
set_tests_properties(DP-logical-forms PROPERTIES
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
# h0-first-node: a single-species inlet on its own N2 table, which starts at 100 K: h0 equal to the enthalpy of the
# first row gives T0 = 100 K, the bc.txt of T0 = 100, and neither warns, since the solvers' lookup reads the first
# row; an h0 below the first row stops BCB with its message.
add_test(
    NAME    IG-inflow-405a
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -v tol=1e-12 -f ${CMAKE_SOURCE_DIR}/test/numdiff.awk reference/bc.txt fromATLAStoSolver/bc.txt && cd h0-first-node && { rm -rf fromATLAStoSolver t0 && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input t0.ini 2>&1 < /dev/null) && mv fromATLAStoSolver t0 && out2=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input h0.ini 2>&1 < /dev/null) && diff t0/bc.txt fromATLAStoSolver/bc.txt && rm -rf fromATLAStoSolver t0 || { echo \"$out\" | tail -n 2; echo \"$out2\" | tail -n 2; exit 1; }; ! grep -F 'lies outside the temperature range' <<< \"$out $out2\" || exit 1; out3=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input below.ini 2>&1 < /dev/null); rc3=$?; echo \"$out3\" | tail -n 2; test $rc3 -eq 1 && grep -q -F '[ERROR] h0 = -2.06000E+05 J/kg lies outside the enthalpy range of thermo.dat: no T0 for it' <<< \"$out3\" && test ! -e fromATLAStoSolver/bc.txt; }"
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

# ---- BCB : IG-ablation -------------
# BC 505 (ablation, surface reactions): the model id is written as an integer (MOSE reads it into an INTEGER);
# the exact diff is the only registered check of the 505 record.
add_test(
    NAME    IG-ablation
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-ablation"
)
set_tests_properties(IG-ablation PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-table-no-data -------------
# A T-file that exists but holds no row of two numbers (a header and a comment) is refused as a file without data
# rows, not reported as missing; no bc.txt.
add_test(
    NAME    IG-table-no-data
    COMMAND bash -c "rm -rf fromATLAStoSolver; if ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB > bcb.log 2>&1; then cat bcb.log; false; else grep -q -F '[ERROR] BC file Twall.dat has no data row' bcb.log && ! grep -q -F 'BC file Twall.dat not found' bcb.log && test ! -e fromATLAStoSolver/bc.txt; fi"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-table-no-data"
)
set_tests_properties(IG-table-no-data PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : IG-multigrid-2D -------------
# MG-levels = 3 on a pure-2D mesh (9 x 5 nodes, X and Y): every coarse level stays pure 2D; bc2.txt and bc3.txt equal
# the bc.txt of the level meshes (every second and every fourth node) given directly.
add_test(
    NAME    IG-multigrid-2D
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && diff fromATLAStoSolver/bc.txt reference/bc.txt && diff fromATLAStoSolver/bc2.txt reference/bc2.txt && diff fromATLAStoSolver/bc3.txt reference/bc3.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-multigrid-2D"
)
set_tests_properties(IG-multigrid-2D PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : BCB-direction-refused (a direction letter outside x, y, z, r, t, i, j, k (here X) stops BCB naming the key) -------------
add_test(
    NAME    BCB-direction-refused
    COMMAND bash -c "rm -rf _run-dir && mkdir _run-dir && cp *.ini *.tec *.txt *.dat _run-dir/ 2>/dev/null; cd _run-dir && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input direction-X.ini 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 2; test $rc -eq 1 && grep -q -F 'key direction of section [isoth]: value X is not a direction' <<< \"$out\""
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/IG-xtheta-variable-T"
)
set_tests_properties(BCB-direction-refused PROPERTIES
    LABELS      "BCB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- BCB : SP-wall-305 (a solid wall with hconv, eps and Tref is written as BC 305) ----
# One solid block (IG-ablation's mesh, solid-bulk phase): face 4 gives hconv, eps and Tref and must be written as
# 305 with hconv, eps, Tref, the order in which FUSS reads that record; face 2 gives eps and Tref only and stays
# 304. check-walls.awk takes the values from input.ini and the counts from the mesh, not from a saved bc.txt.
# _run-none: [adiabatic] (the last section of input.ini) given q and T selects no solid-wall record: a WARNING names the section and the keys, and its
# faces (1, 3, 5, 6: 2070 records) are written with BC id 0, as upstream writes them; faces 4 and 2 keep 305 and 304.
add_test(
    NAME    SP-wall-305
    COMMAND bash -c "rm -rf fromATLAStoSolver _run-none && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB && awk -f check-walls.awk fromATLAStoSolver/bc.txt && mkdir _run-none && cp input.ini mesh.tec phase.txt check-walls.awk _run-none/ && cd _run-none && echo 'T    = 300.0' >> input.ini && out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB 2>&1) && grep -q -F '[WARNING] section [adiabatic] (solid wall): the keys given (q, T) select none of the records' <<< \"$out\" && awk -f check-walls.awk fromATLAStoSolver/bc.txt && test $(awk 'NF == 6 && $6 == 0' fromATLAStoSolver/bc.txt | wc -l) -eq 2070"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/BCB/SP-wall-305"
)
set_tests_properties(SP-wall-305 PROPERTIES
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

# ---- STB : qvol-direction-combined -------------
# A qvol profile with direction = xy: the profile is 1D and is read along x (the first letter by priority
# x > y > z > r > t) with a WARNING naming it; st.tec equals the one of the same deck with direction = x (run again in
# fromATLAStoSolver/x).
add_test(
    NAME    qvol-direction-combined
    COMMAND bash -c "rm -rf fromATLAStoSolver; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh STB 2>&1 < /dev/null); rc=$?; echo \"$out\" | tail -n 3; test $rc -eq 0 && grep -q -F \"direction = 'xy' combines letters: the qvol profile is 1D and is read along x\" <<< \"$out\" && mkdir fromATLAStoSolver/x && cp mesh.tec qvol.txt fromATLAStoSolver/x/ && sed 's/direction = xy/direction = x/' input.ini > fromATLAStoSolver/x/input.ini && cd fromATLAStoSolver/x && ${CMAKE_SOURCE_DIR}/ATLAS.sh STB && diff ../st.tec fromATLAStoSolver/st.tec"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/STB/qvol-direction-combined"
)
set_tests_properties(qvol-direction-combined PROPERTIES
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

# ---- MDB : manifold-remap (a BC 501 payload survives the split) -------------
# A manifold names a whole block face, not a cell (MOSE's BC_Manifold averages
# the entire source face and scales the mass flux by the entire target face),
# and MOSE aborts when the two blocks of a pair sit on different ranks.
# check-manifold.py holds the split file against the original one and the map:
# the payload renumbered to the piece that inherited the source face entire,
# both faces whole, both pieces on one rank. Copying the payload raw, as MDB did
# until 2026-09, leaves it pointing at a block whose face is now a cut.
add_test(
    NAME    manifold-remap
    COMMAND bash -c "rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB && python3 ${CMAKE_SOURCE_DIR}/scripts/check-split.py mesh.tec fromATLAStoSolver/mesh-split.tec fromATLAStoSolver/decomposition.map && python3 ${CMAKE_SOURCE_DIR}/scripts/check-bc.py fromATLAStoSolver/INPUT-split/bc.txt && python3 ${CMAKE_SOURCE_DIR}/scripts/check-manifold.py fromATLAStoSolver/bc.txt fromATLAStoSolver/INPUT-split/bc.txt fromATLAStoSolver/decomposition.map && diff fromATLAStoSolver/decomposition.map reference/decomposition.map && diff fromATLAStoSolver/INPUT-split/bc.txt reference/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/manifold-remap"
)
set_tests_properties(manifold-remap PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : manifold-split-ranks (a BC 501 pair LPT puts on two ranks) --------
# The same mesh on 3 ranks: the solver's own LPT separates the two blocks of the
# manifold, which MOSE refuses at start-up (abort_if_split). MDB has to say so
# with the decomposition in front of the user instead of writing the files.
# `!` inverts the status and the grep pins the reason (WILL_FAIL would accept
# any crash).
add_test(
    NAME    manifold-split-ranks
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB 2>&1 | tee mdb.log && grep -q 'MOSE aborts at start-up when the two blocks of a manifold' mdb.log && test ! -e fromATLAStoSolver/INPUT-split/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/manifold-split-ranks"
)
set_tests_properties(manifold-split-ranks PROPERTIES
    LABELS      "MDB;regression"
    TIMEOUT     300
    ENVIRONMENT "${_TEST_ENV}"
)

# ---- MDB : manifold-face-cut (a BC 501 source face cut tangentially) ---------
# The same mesh with block 1 restricted to j cuts, so its face 2 -- the source
# of the manifold -- is shared by two new blocks. A 501 payload cannot name half
# a face: MDB refuses and names the direction that keeps it whole.
add_test(
    NAME    manifold-face-cut
    COMMAND bash -c "set -o pipefail && rm -rf fromATLAStoSolver && ! ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB MDB 2>&1 | tee mdb.log && grep -q 'draws from block 1 face 2, which is cut across new blocks' mdb.log && grep -q 'split-directions = i' mdb.log && test ! -e fromATLAStoSolver/INPUT-split/bc.txt"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/test/MDB/manifold-face-cut"
)
set_tests_properties(manifold-face-cut PROPERTIES
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

# ---- BCB : IG-massfraction-range (a y<species> value outside [0, 1] stops BCB with one message, the same
# ----       below 0 and above 1, naming the key and the value; nothing is written. A value outside [0, 1]
# ----       by rounding only (1.0000000000000002, -1.0e-20) is read as 1 and 0: bc.txt equals the one of
# ----       yO2 = 1, yCH4 = 0. A TAB is white space like a blank: around the number it is ignored (bc.txt
# ----       of yO2 = 1, yCH4 = 0), inside the value (yO2 = 1.0<TAB>0.5) it stops BCB as two numbers) -----
add_test(
    NAME    IG-massfraction-range
    COMMAND bash -c "rm -rf fromATLAStoSolver exact && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input exact.ini < /dev/null && mv fromATLAStoSolver exact && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input rounding.ini < /dev/null && diff exact/bc.txt fromATLAStoSolver/bc.txt && rm -rf fromATLAStoSolver && ${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input tab-around.ini < /dev/null && diff exact/bc.txt fromATLAStoSolver/bc.txt && rm -rf fromATLAStoSolver exact || exit 1; out=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input negative.ini 2>&1 < /dev/null); rc=$?; out2=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input above.ini 2>&1 < /dev/null); rc2=$?; out3=$(${CMAKE_SOURCE_DIR}/ATLAS.sh BCB --input tab-inside.ini 2>&1 < /dev/null); rc3=$?; echo \"$out\" | tail -n 2; echo \"$out2\" | tail -n 2; echo \"$out3\" | tail -n 2; test $rc -eq 1 && test $rc2 -eq 1 && test $rc3 -eq 1 && grep -q -F '[ERROR] key yCH4 = -0.1: the mass fraction must lie in [0, 1]' <<< \"$out\" && grep -q -F '[ERROR] key yO2 = 1.5: the mass fraction must lie in [0, 1]' <<< \"$out2\" && grep -q -F ': the mass fraction must be one number' <<< \"$out3\" && grep -q -F '[ERROR] key yO2 = 1.0' <<< \"$out3\" && test $(grep -c -F '[ERROR]' <<< \"$out\") -eq 1 && test ! -e fromATLAStoSolver/bc.txt"
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
