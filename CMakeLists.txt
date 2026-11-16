# CMake project file for ATLAS

cmake_minimum_required(VERSION 3.23)

project (ATLAS LANGUAGES Fortran CXX)

# -------- Libraries and the releases ATLAS is tested with --------
# - ORION. Required by a range of releases with semver_dependency of cmake/SemVerDeps.cmake. Standalone, the release
# is checked out in lib/ORION, out of the build folder, and kept in deps.lock (both git ignored); -DSEMVER_UPDATE=ALL
# selects the newest one again. ORION 2, as GPB reads its point files with tec_read_structured_multiblock
# (tec_read_points_multivars is gone since 2.0.0); 2.1.0 is the release the tests are run with.
set(ATLAS_ORION_VERSION 2.1)
set(ATLAS_ORION_URL https://github.com/MarcoGrossi92/ORION.git)
# - FiNeR. Directly pinned at one release, the submodule lib/FiNeR (bump the gitlink and the tag together).
set(ATLAS_FINER_TAG v2.3.0)
# FiNeR's own dependencies (cmake/FiNeRDependencies.cmake). FREE fetches them as FiNeR's author does
# (`fobis fetch`: the default branch of each); BACKUP checks out the releases below, which ATLAS builds and passes its
# tests with. When an upstream change breaks ATLAS, set BACKUP here and commit it, or configure one build with
# -DATLAS_FINER_DEPS=BACKUP (kept in its cache until -UATLAS_FINER_DEPS).
if (NOT DEFINED ATLAS_FINER_DEPS)
  set(ATLAS_FINER_DEPS "FREE")
endif()
set(ATLAS_FINER_BACKUP_PINS   # the releases MOSE, ICE and GROOT share
  "PENF=v2.0.1"
  "StringiFor=v1.8.0"
  "FACE=v1.1.17"
  "FLAP=v2.5.3"
  "BeFoR64=v1.2.4")
# - CEA and PiNeR. Directly pinned, the submodules lib/cea (or CEA_PATH) and lib/PiNeR; the release of CEA is checked
# against the CEA configured (bump the gitlink and the version together).
set(ATLAS_CEA_VERSION "3.3.4")

set(CMAKE_VERBOSE_MAKEFILE FALSE)

# Add our local modlues to the module path
SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

# Default to using OpenMP for parallelization
OPTION(USE_OPENMP "Use OpenMP for parallelization" OFF)

# This INCLUDE statement executes code that sets the compile flags for DEBUG, RELEASE, and TESTING.
INCLUDE(${CMAKE_MODULE_PATH}/SetFortranFlags.cmake)
# Locate and set parallelization libraries. There are some CMake peculiarities
# taken care of here, such as the fact that the FindOpenMP routine doesn't know
# about Fortran.
INCLUDE(${CMAKE_MODULE_PATH}/SetParallelizationLibrary.cmake)

#####################################################
# Add the needed libraries and special compiler flags
#####################################################

# An external clone given by a relative path is taken from the source folder
foreach(_name FETCHCONTENT_SOURCE_DIR_ORION FETCHCONTENT_SOURCE_DIR_FINER CEA_PATH)
  if (${_name})
    get_filename_component(${_name} "${${_name}}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
endforeach()
# ORION by its range. In a larger project (hydra) that selected ORION with SemVerDeps first, this checks that
# release against ATLAS's requirement instead
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/SemVerDeps.cmake)
semver_dependency(ORION GIT_REPOSITORY ${ATLAS_ORION_URL} VERSION ${ATLAS_ORION_VERSION} SOURCE_DIR lib/ORION)
# ORION, FiNeR (with FiNeR's dependencies) and CEA, the checks of their pins and releases, and
# FetchContent_MakeAvailable
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
