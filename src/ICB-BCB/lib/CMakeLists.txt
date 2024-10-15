file(GLOB SOURCES "*.f90")

add_library(ATLAS ${SOURCES})
target_include_directories(ATLAS INTERFACE ${CMAKE_Fortran_MODULE_DIRECTORY})
target_link_libraries(ATLAS FiNeR::FiNeR NewCEA ORION)

# set( EXES tommy )
# foreach(EXE ${EXES})
#   add_executable(${EXE} "${CMAKE_CURRENT_SOURCE_DIR}/${EXE}.f90")
#   target_link_libraries(${EXE} ATLAS)
#   target_include_directories(${EXE}
#   INTERFACE
#       $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
#   )
# endforeach()