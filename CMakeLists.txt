# CMake project file for ATLAS

cmake_minimum_required(VERSION 3.23)

project (ATLAS LANGUAGES Fortran CXX)

set(CMAKE_VERBOSE_MAKEFILE FALSE)

# Add our local modlues to the module path
SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

# Default to using OpenMP for parallelization
OPTION(USE_OPENMP "Use OpenMP for parallelization" OFF)

# -------- Libraries and the releases ATLAS is tested with --------
# ATLAS depends on a few libraries, which are either submodules or external dependencies. The submodules are:

# - ORION. Required by a range of releases, with semver_dependency of cmake/SemVerDeps.cmake.
# It is checked out in lib/ORION, out of the build folder. The release of ORION selected is kept in deps.lock and git ignored.
# Add -DSEMVER_UPDATE=ALL selects the newest one.
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/SemVerDeps.cmake)
set(ATLAS_ORION_VERSION 2)
semver_dependency(ORION GIT_REPOSITORY https://github.com/MarcoGrossi92/ORION.git VERSION ${ATLAS_ORION_VERSION}
                  SOURCE_DIR lib/ORION)

# - FiNeR. Added as submodule in lib/FiNeR
set(ATLAS_FINER_TAG v2.3.0)
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

# - CEA. Added as submodule in lib/cea or CEA_PATH; its release is checked against the CEA configured
set(ATLAS_CEA_VERSION "3.3.4")

# This INCLUDE statement executes code that sets the compile flags for DEBUG, RELEASE, and TESTING.
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
