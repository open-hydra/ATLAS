# ORION and FiNeR (with FiNeR's dependencies) as CMakeLists.txt required them with semver_dependency, checked
# first, so that a clone of another release stops the configure at once; then CEA (the submodule lib/cea, or
# CEA_PATH). Each is checked against the commit or the release ATLAS requires.

include(${CMAKE_CURRENT_LIST_DIR}/SubmodulePins.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/FiNeRDependencies.cmake)

# ORION: a release selected by SemVerDeps satisfies the requirement; an external clone (local) only warns there,
# so ATLAS checks its version, the newest vX.Y.Z tag of its HEAD as SemVerDeps found it
get_property(_orion_source GLOBAL PROPERTY SEMVER_ORION_SOURCE)
if (_orion_source STREQUAL "local")
  get_property(_orion_version GLOBAL PROPERTY SEMVER_ORION_VERSION)
  set(_ok FALSE)
  if (_orion_version)
    _semver_satisfies("${_orion_version}" _ok ${ATLAS_ORION_VERSION})
  else()
    set(_orion_version "of no release (no vX.Y.Z tag in its history)")
  endif()
  if (NOT _ok)
    _semver_range("${ATLAS_ORION_VERSION}" _min _max)
    message(${ATLAS_PIN_CHECK} "ORION at ${FETCHCONTENT_SOURCE_DIR_ORION} is ${_orion_version}, but ATLAS requires "
                    "ORION ${ATLAS_ORION_VERSION} (${_min} up to ${_max} excluded). Give a clone of such a release, or "
                    "build the release ATLAS selects (without FETCHCONTENT_SOURCE_DIR_ORION), or configure with "
                    "-DATLAS_PIN_CHECK=WARNING to build this ORION on purpose.")
  endif()
endif()

# FiNeR: its dependencies before its CMakeLists adds them. Those of the checkout of ATLAS are fetched; an
# external clone is built as it is, its dependencies only checked. Its release is in its VERSION file (v2.3.0):
# its project() still declares 2.0.3
if (FETCHCONTENT_SOURCE_DIR_FINER)
  set(ATLAS_FINER_SOURCE_DIR "${FETCHCONTENT_SOURCE_DIR_FINER}")
  ensure_finer_dependencies("${ATLAS_FINER_SOURCE_DIR}" FALSE)
else()
  set(ATLAS_FINER_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib/third_party/FiNeR")   # SOURCE_DIR of its semver_dependency
  ensure_finer_dependencies("${ATLAS_FINER_SOURCE_DIR}" TRUE)
endif()
set(_finer_version "")
if (EXISTS "${ATLAS_FINER_SOURCE_DIR}/VERSION")
  file(STRINGS "${ATLAS_FINER_SOURCE_DIR}/VERSION" _finer_version LIMIT_COUNT 1)
  string(REGEX REPLACE "^[ \t]*v" "" _finer_version "${_finer_version}")
endif()
string(REGEX REPLACE "^v" "" _finer_pinned "${ATLAS_FINER_TAG}")
string(CONCAT _hint "Give FETCHCONTENT_SOURCE_DIR_FINER a clone of FiNeR ${ATLAS_FINER_TAG}, or build the release "
                    "ATLAS checks out (without it)")
atlas_check_version(FiNeR "${ATLAS_FINER_SOURCE_DIR}" "${_finer_version}" "${_finer_pinned}" "${_hint}")

# CEA
set(ATLAS_CEA_TARGET "")
set(ATLAS_CEA_SOURCE_DIR "")

macro(ensure_cea_data_link)
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/data")
    message(STATUS "CEA data directory not found in ATLAS source; attempting to link from CEA source")
    message(STATUS "CEA source directory: ${ATLAS_CEA_SOURCE_DIR}")
    message(STATUS "CEA data directory: ${CEA_PATH}/data")
    file(CREATE_LINK "${ATLAS_CEA_SOURCE_DIR}/data" "${CMAKE_CURRENT_SOURCE_DIR}/data" SYMBOLIC)
    message(STATUS "Linked ATLAS data -> CEA data for compatibility")
  endif()
endmacro()

if (NOT TARGET cea_core)
  # Newer CEA/fbasics requires C abort-support symbols at link time.
  set(CEA_ENABLE_BIND_C ON CACHE BOOL "Enable C language bindings" FORCE)
  if (NOT DEFINED CEA_ENABLE_BIND_CXX)
    set(CEA_ENABLE_BIND_CXX OFF CACHE BOOL "Enable C++ language bindings" FORCE)
  endif()
  if (NOT DEFINED CEA_ENABLE_BIND_PYTHON)
    set(CEA_ENABLE_BIND_PYTHON OFF CACHE BOOL "Enable Python language bindings" FORCE)
  endif()
  if (NOT DEFINED CEA_ENABLE_BIND_MATLAB)
    set(CEA_ENABLE_BIND_MATLAB OFF CACHE BOOL "Enable MatLab language bindings" FORCE)
  endif()
  if (NOT DEFINED CEA_ENABLE_BIND_EXCEL)
    set(CEA_ENABLE_BIND_EXCEL OFF CACHE BOOL "Enable Excel language bindings" FORCE)
  endif()

  if (DEFINED CEA_PATH AND NOT "${CEA_PATH}" STREQUAL "")
    set(ATLAS_CEA_SOURCE_DIR "${CEA_PATH}")
    ensure_cea_data_link()
    add_subdirectory("${CEA_PATH}" "${CMAKE_BINARY_DIR}/lib/cea")
  elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/lib/cea/CMakeLists.txt")
    ensure_submodule_initialized("${CMAKE_CURRENT_SOURCE_DIR}/lib/cea")
    set(ATLAS_CEA_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib/cea")
    ensure_cea_data_link()
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/lib/cea" "${CMAKE_BINARY_DIR}/lib/cea")
  else()
    message(FATAL_ERROR
      "Could not find a CEA provider. Set CEA_PATH or initialize lib/cea.")
  endif()
endif()

if (TARGET cea_core)
  set(ATLAS_CEA_TARGET cea_core)
else()
  message(FATAL_ERROR "No supported CEA target was configured.")
endif()

FetchContent_MakeAvailable(ORION FiNeR)

# Pins: the submodules lib/cea and lib/PiNeR at the commit this ATLAS commit records
foreach(_sm "${ATLAS_CEA_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/lib/PiNeR")
  atlas_check_submodule_pin("${_sm}")
endforeach()

# Releases: CEA declares its own in project(); a cea_core provided by a parent project is its own
if (NOT "${ATLAS_CEA_SOURCE_DIR}" STREQUAL "")
  get_directory_property(_cea_version DIRECTORY "${ATLAS_CEA_SOURCE_DIR}" DEFINITION CEA_VERSION)
  string(CONCAT _hint "Point CEA_PATH to CEA ${ATLAS_CEA_VERSION} (nasa/cea tag v${ATLAS_CEA_VERSION}); "
                      "if lib/cea was bumped on purpose, set ATLAS_CEA_VERSION in CMakeLists.txt to its version")
  atlas_check_version(CEA "${ATLAS_CEA_SOURCE_DIR}" "${_cea_version}" "${ATLAS_CEA_VERSION}" "${_hint}")
endif()
