# CMake project file for ATLAS

cmake_minimum_required(VERSION 3.23)

# Force the compiler depending on the host name
# cmake_host_system_information(RESULT host QUERY HOSTNAME)
# message("-- Host name detected: " ${host})
# if(${host} STREQUAL frontend)
#   set(CMAKE_Fortran_COMPILER "ifort")
# else()
#   set(CMAKE_Fortran_COMPILER "gfortran")
# endif()

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

# NewCEA
add_subdirectory( ${CMAKE_CURRENT_SOURCE_DIR}/lib/NewCEA/ )

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
