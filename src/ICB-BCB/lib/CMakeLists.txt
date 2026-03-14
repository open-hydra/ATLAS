file(GLOB SOURCES "*.f90" "IO/*.f90")

add_library(ATLAS ${SOURCES})
target_include_directories(ATLAS INTERFACE ${CMAKE_Fortran_MODULE_DIRECTORY})
target_link_libraries(ATLAS FiNeR::FiNeR NewCEA ORION)
