set( EXES ICB BCB )
foreach(EXE ${EXES})
  add_executable(${EXE} "${CMAKE_CURRENT_SOURCE_DIR}/${EXE}.f90")
  target_link_libraries(${EXE} PRIVATE ATLAS)
  if (USE_TECIO)
    target_link_libraries(${EXE} PRIVATE -pthread)
  endif()
  target_include_directories(${EXE}
  INTERFACE
      $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
  )
endforeach()
