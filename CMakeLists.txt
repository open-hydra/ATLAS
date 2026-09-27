# CMake project file for ATLAS

cmake_minimum_required(VERSION 3.23)

project (ATLAS LANGUAGES Fortran CXX)

set(CMAKE_VERBOSE_MAKEFILE FALSE)

# Add our local modlues to the module path
SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

# Set some options the user may choose
# Uncomment the below if you want the user to choose a parallelization library
#OPTION(USE_MPI "Use the MPI library for parallelization" OFF)
OPTION(USE_OPENMP "Use OpenMP for parallelization" OFF)

# Default submodule paths (override with -DORION_PATH=... -DFINER_PATH=...)
if (NOT DEFINED ORION_PATH)
  set(ORION_PATH "${CMAKE_SOURCE_DIR}/lib/ORION" CACHE PATH "Path to ORION submodule")
endif()
if (NOT DEFINED FINER_PATH)
  set(FINER_PATH "${CMAKE_SOURCE_DIR}/lib/third_party/FiNeR" CACHE PATH "Path to FiNeR submodule")
endif()

# This INCLUDE statement executes code that sets the compile flags for DEBUG,
# RELEASE, and TESTING. You should  review this file and make sure the flags 
# are to your liking.
INCLUDE(${CMAKE_MODULE_PATH}/SetFortranFlags.cmake) 
# Locate and set parallelization libraries. There are some CMake peculiarities
# taken care of here, such as the fact that the FindOpenMP routine doesn't know
# about Fortran.
INCLUDE(${CMAKE_MODULE_PATH}/SetParallelizationLibrary.cmake)

#####################################################
# Add the needed libraries and special compiler flags
#####################################################

# -------- Helper: initialize a git submodule from the correct git root --------
macro(ensure_submodule_initialized SUBMOD_PATH)
  if (NOT EXISTS "${SUBMOD_PATH}/CMakeLists.txt")
    message(STATUS "Submodule at ${SUBMOD_PATH} not initialized. Attempting git submodule update --init...")
    get_filename_component(_sm_parent "${SUBMOD_PATH}" DIRECTORY)
    execute_process(
      COMMAND git rev-parse --show-toplevel
      WORKING_DIRECTORY "${_sm_parent}"
      OUTPUT_VARIABLE _sm_git_root
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE _sm_git_result)
    if(_sm_git_result EQUAL 0)
      file(RELATIVE_PATH _sm_rel "${_sm_git_root}" "${SUBMOD_PATH}")
      execute_process(
        COMMAND git submodule update --init "${_sm_rel}"
        WORKING_DIRECTORY "${_sm_git_root}"
        RESULT_VARIABLE _sm_init_result)
      if(NOT _sm_init_result EQUAL 0)
        message(FATAL_ERROR "Failed to initialize submodule: ${SUBMOD_PATH}")
      endif()
    else()
      message(FATAL_ERROR "Could not find git root for submodule: ${SUBMOD_PATH}")
    endif()
  endif()
endmacro()

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
if (NOT TARGET FiNeR)
  if (DEFINED FINER_PATH AND NOT "${FINER_PATH}" STREQUAL "")
    ensure_submodule_initialized("${FINER_PATH}")
    set(finerD "${FINER_PATH}" "${CMAKE_BINARY_DIR}/lib/third_party/FiNeR")
    add_subdirectory(${finerD})
  else()
    message(WARNING "FINER_PATH not defined; skipping FiNeR submodule initialization")
  endif()
endif()

############################################
# Define the actual files and building rules
############################################

# Check that each bundled submodule is checked out at the commit this ATLAS
# commit records (a mismatch typically follows `git checkout <branch>` without
# `git submodule update`): ATLAS would compile against a library version it was
# not tested with. Example: with an ORION older than a770748 ICB reads no
# variable names from the unquoted headers ATLAS writes, so the turbulence of an
# ATLAS-written old solution is silently not adopted. Read-only git queries;
# nothing is checked for tarballs, plain copies or paths outside this tree.
find_package(Git QUIET)
# a mismatch is fatal; to build against a
# work-in-progress checkout of a submodule (an ORION PR under test) configure with -DATLAS_PIN_CHECK=WARNING.
set(ATLAS_PIN_CHECK "FATAL_ERROR" CACHE STRING "Severity of a submodule checkout that differs from the recorded pin: FATAL_ERROR (default) or WARNING")
if (NOT ATLAS_PIN_CHECK STREQUAL "FATAL_ERROR" AND NOT ATLAS_PIN_CHECK STREQUAL "WARNING")
  message(FATAL_ERROR "ATLAS_PIN_CHECK must be FATAL_ERROR or WARNING (got '${ATLAS_PIN_CHECK}')")
endif()
function(atlas_check_submodule_pin SUBMOD_PATH)
  if (NOT GIT_FOUND OR "${SUBMOD_PATH}" STREQUAL "" OR NOT EXISTS "${SUBMOD_PATH}/.git")
    return()
  endif()
  file(REAL_PATH "${SUBMOD_PATH}" _abs)
  file(REAL_PATH "${CMAKE_SOURCE_DIR}" _top)
  file(RELATIVE_PATH _rel "${_top}" "${_abs}")
  if ("${_rel}" STREQUAL "" OR "${_rel}" MATCHES "^\\.\\.")
    return()
  endif()
  set(_git ${CMAKE_COMMAND} -E env GIT_OPTIONAL_LOCKS=0 ${GIT_EXECUTABLE})
  execute_process(COMMAND ${_git} ls-files -s -- "${_rel}" WORKING_DIRECTORY "${_top}"
                  OUTPUT_VARIABLE _entry RESULT_VARIABLE _r1 ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
  execute_process(COMMAND ${_git} rev-parse --show-toplevel HEAD WORKING_DIRECTORY "${_abs}"
                  OUTPUT_VARIABLE _head RESULT_VARIABLE _r2 ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (NOT _r1 EQUAL 0 OR NOT _r2 EQUAL 0 OR NOT "${_entry}" MATCHES "^160000 ([0-9a-f]+) ")
    return()   # not a registered submodule (gitlink) of this checkout
  endif()
  set(_pin "${CMAKE_MATCH_1}")
  string(REPLACE "\n" ";" _head "${_head}")
  list(LENGTH _head _n)
  if (NOT _n EQUAL 2)
    return()
  endif()
  list(GET _head 0 _root)
  list(GET _head 1 _sha)
  file(REAL_PATH "${_root}" _root)
  if (NOT "${_root}" STREQUAL "${_abs}")
    return()   # the directory has no repository of its own
  endif()
  if (NOT "${_sha}" STREQUAL "${_pin}")
    string(SUBSTRING "${_pin}" 0 7 _pin7)
    string(SUBSTRING "${_sha}" 0 7 _sha7)
    message(${ATLAS_PIN_CHECK} "${_rel} is checked out at ${_sha7}, but this ATLAS commit records ${_pin7}. "
                    "ATLAS would be built against a library version it was not tested with. "
                    "Run `git submodule update --init --recursive` and configure again "
                    "(or configure with -DATLAS_PIN_CHECK=WARNING to build against this checkout on purpose).")
  endif()
endfunction()
foreach(_sm "${ORION_PATH}" "${FINER_PATH}" "${ATLAS_CEA_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/lib/PiNeR")
  atlas_check_submodule_pin("${_sm}")
endforeach()

include(GNUInstallDirs)

# Set directories
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")
set (CMAKE_Fortran_MODULE_DIRECTORY "${PROJECT_BINARY_DIR}/modules")
set (CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

# Compiling
add_subdirectory(src)

# Testing
enable_testing()
add_subdirectory(test)
