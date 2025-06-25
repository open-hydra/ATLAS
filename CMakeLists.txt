# CMake project file for ATLAS

cmake_minimum_required(VERSION 3.13)

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

# NewCEA
add_subdirectory( ${CMAKE_CURRENT_SOURCE_DIR}/lib/NewCEA/ )

# # ORION
if(MASTER STREQUAL None)
  set ( orionD ${CMAKE_CURRENT_SOURCE_DIR}/lib/ORION/ )
elseif(MASTER STREQUAL hydra)
  set ( orionD $ENV{HYDRADIR}/lib/ORION/ "${CMAKE_CURRENT_SOURCE_DIR}/build/lib/ORION/")
endif()
add_subdirectory(${orionD})

# FiNeR
if(MASTER STREQUAL None)
  set ( finerD ${CMAKE_CURRENT_SOURCE_DIR}/lib/third_party/FiNeR/ )
elseif(MASTER STREQUAL hydra)
  set ( finerD $ENV{HYDRADIR}/lib/third_party/FiNeR/ "${CMAKE_CURRENT_SOURCE_DIR}/build/lib/third_party/FiNeR/")
endif()
add_subdirectory(${finerD})

############################################
# Define the actual files and building rules
############################################

include(GNUInstallDirs)

# Set directories
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")
set (CMAKE_Fortran_MODULE_DIRECTORY "${PROJECT_BINARY_DIR}/modules")
set (CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/")

add_subdirectory(src/ICB-BCB/lib)
add_subdirectory(src/ICB-BCB/app)

# Add a distclean target to the Makefile
ADD_CUSTOM_TARGET(distclean 
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/distclean.cmake
)
