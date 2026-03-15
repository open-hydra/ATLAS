file(GLOB SOURCES "*.f90")

add_library(ATLAS ${SOURCES})
target_include_directories(ATLAS INTERFACE ${CMAKE_Fortran_MODULE_DIRECTORY})
target_link_libraries(ATLAS FiNeR::FiNeR NewCEA ORION)

if(USE_OPENMP)
  find_package(OpenMP REQUIRED COMPONENTS Fortran)
  target_link_libraries(ATLAS OpenMP::OpenMP_Fortran)
endif()
