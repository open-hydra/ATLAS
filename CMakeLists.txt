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

# -------- Releases ATLAS is tested with --------
# lib/cea and lib/third_party/FiNeR are pinned by their gitlinks; these releases are checked against the CEA
# and FiNeR actually configured, CEA_PATH and FINER_PATH included (cmake/AddLibraries.cmake). Bump each
# together with its submodule.
set(ATLAS_CEA_VERSION "3.3.4")     # nasa/cea tag v3.3.4
set(ATLAS_FINER_VERSION "2.3.0")   # szaghi/FiNeR tag v2.3.0
# FiNeR's own dependencies (cmake/FiNeRDependencies.cmake). FREE fetches them as FiNeR's author does
# (`fobis fetch`: the default branch of each); BACKUP checks out the releases below, which ATLAS builds
# and passes its tests with. When an upstream change breaks ATLAS, set BACKUP here and commit it, or
# configure one build with -DATLAS_FINER_DEPS=BACKUP (kept in its cache until -UATLAS_FINER_DEPS).
if (NOT DEFINED ATLAS_FINER_DEPS)
  set(ATLAS_FINER_DEPS "FREE")
endif()
set(ATLAS_FINER_BACKUP_PINS   # the releases MOSE and FUSS share (hydra sync of October 2026)
  "PENF=v2.0.1"
  "StringiFor=v1.8.0"
  "FACE=v1.1.17"
  "FLAP=v2.5.3"
  "BeFoR64=v1.2.4")

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

# CEA, ORION and FiNeR (with FiNeR's dependencies), then the check of their pins and releases
INCLUDE(${CMAKE_MODULE_PATH}/AddLibraries.cmake)

############################################
# Define the actual files and building rules
############################################

include(GNUInstallDirs)

# Set directories
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")
set (CMAKE_Fortran_MODULE_DIRECTORY "${PROJECT_BINARY_DIR}/modules")

# Compiling
add_subdirectory(src)

# Testing
enable_testing()
add_subdirectory(test)
