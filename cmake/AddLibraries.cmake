# CEA, ORION and FiNeR (with FiNeR's dependencies), each from its path variable or bundled submodule,
# then the check of their pins and releases against those set in CMakeLists.txt.

include(${CMAKE_CURRENT_LIST_DIR}/SubmodulePins.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/FiNeRDependencies.cmake)

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

# ORION
if (NOT TARGET ORION)
  if (DEFINED ORION_PATH AND NOT "${ORION_PATH}" STREQUAL "")
    ensure_submodule_initialized("${ORION_PATH}")
    set(orionD "${ORION_PATH}" "${CMAKE_BINARY_DIR}/lib/ORION")
    add_subdirectory(${orionD})
  else()
    message(WARNING "ORION_PATH not defined; skipping ORION submodule initialization")
  endif()
endif()

# FiNeR
set(ATLAS_FINER_SOURCE_DIR "")
if (NOT TARGET FiNeR)
  if (DEFINED FINER_PATH AND NOT "${FINER_PATH}" STREQUAL "")
    ensure_submodule_initialized("${FINER_PATH}")
    ensure_finer_dependencies("${FINER_PATH}")
    set(ATLAS_FINER_SOURCE_DIR "${FINER_PATH}")
    set(finerD "${FINER_PATH}" "${CMAKE_BINARY_DIR}/lib/third_party/FiNeR")
    add_subdirectory(${finerD})
  else()
    message(WARNING "FINER_PATH not defined; skipping FiNeR submodule initialization")
  endif()
endif()

# Pins: each bundled submodule at the commit this ATLAS commit records
foreach(_sm "${ORION_PATH}" "${FINER_PATH}" "${ATLAS_CEA_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/lib/PiNeR")
  atlas_check_submodule_pin("${_sm}")
endforeach()

# Releases: CEA declares its own in project(); a cea_core provided by a parent project is its own
if (NOT "${ATLAS_CEA_SOURCE_DIR}" STREQUAL "")
  get_directory_property(_cea_version DIRECTORY "${ATLAS_CEA_SOURCE_DIR}" DEFINITION CEA_VERSION)
  string(CONCAT _hint "Point CEA_PATH to CEA ${ATLAS_CEA_VERSION} (nasa/cea tag v${ATLAS_CEA_VERSION}); "
                      "if lib/cea was bumped on purpose, set ATLAS_CEA_VERSION in CMakeLists.txt to its version")
  atlas_check_version(CEA "${ATLAS_CEA_SOURCE_DIR}" "${_cea_version}" "${ATLAS_CEA_VERSION}" "${_hint}")
endif()

# FiNeR's is in the VERSION file of its release (v2.3.0): its project() still declares 2.0.3
if (NOT "${ATLAS_FINER_SOURCE_DIR}" STREQUAL "")
  set(_finer_version "")
  if (EXISTS "${ATLAS_FINER_SOURCE_DIR}/VERSION")
    file(STRINGS "${ATLAS_FINER_SOURCE_DIR}/VERSION" _finer_version LIMIT_COUNT 1)
    string(REGEX REPLACE "^[ \t]*v" "" _finer_version "${_finer_version}")
  endif()
  string(CONCAT _hint "Point FINER_PATH to FiNeR ${ATLAS_FINER_VERSION} (szaghi/FiNeR tag v${ATLAS_FINER_VERSION}); "
                      "if lib/third_party/FiNeR was bumped on purpose, set ATLAS_FINER_VERSION in CMakeLists.txt "
                      "to its version and check that ATLAS_FINER_BACKUP_PINS still build with it")
  atlas_check_version(FiNeR "${ATLAS_FINER_SOURCE_DIR}" "${_finer_version}" "${ATLAS_FINER_VERSION}" "${_hint}")
endif()
