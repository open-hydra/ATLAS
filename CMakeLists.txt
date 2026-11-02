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

# -------- Libraries and the releases ATLAS is tested with --------
# ORION and FiNeR are required with semver_dependency of cmake/SemVerDeps.cmake, FLINT's copy unmodified (see
# docs/development/versioning.md). They are checked out in lib/ORION and lib/third_party/FiNeR, out of the build
# folder. The release of ORION selected is kept in deps.lock, not committed (in hydra the top-level project
# chooses); -DSEMVER_UPDATE=ALL selects the newest one again. An external clone is built in place of the
# checkout with -DFETCHCONTENT_SOURCE_DIR_ORION=<path> or -DFETCHCONTENT_SOURCE_DIR_FINER=<path> (install.sh
# --include-orion, --include-finer), and must satisfy the same requirement (cmake/AddLibraries.cmake).
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/SemVerDeps.cmake)
# ORION 2: ATLAS reads the point files of GPB with tec_read_structured_multiblock (2.0.0 removed
# tec_read_points_multivars)
set(ATLAS_ORION_VERSION 2)
semver_dependency(ORION GIT_REPOSITORY https://github.com/MarcoGrossi92/ORION.git VERSION ${ATLAS_ORION_VERSION}
                  SOURCE_DIR lib/ORION)
# FiNeR, a third-party library: one release
set(ATLAS_FINER_TAG v2.3.0)
semver_dependency(FiNeR GIT_REPOSITORY https://github.com/szaghi/FiNeR.git GIT_TAG ${ATLAS_FINER_TAG}
                  SOURCE_DIR lib/third_party/FiNeR)
# CEA stays a submodule (lib/cea, or CEA_PATH); its release is checked against the CEA configured. Bump it
# together with the gitlink.
set(ATLAS_CEA_VERSION "3.3.4")     # nasa/cea tag v3.3.4
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
