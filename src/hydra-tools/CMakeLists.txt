# Shared sources
file(GLOB COMMON_SOURCES "common/*.f90")

# ICB executable: ICB/ + common
file(GLOB ICB_SOURCES "ICB/*.f90")
add_executable(ICB ${ICB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(ICB PRIVATE FiNeR::FiNeR NewCEA ORION)
target_include_directories(ICB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# BCB executable: BCB/ + common
file(GLOB BCB_SOURCES "BCB/*.f90")
add_executable(BCB ${BCB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(BCB PRIVATE FiNeR::FiNeR NewCEA ORION)
target_include_directories(BCB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# STB executable: STB/ + common
file(GLOB STB_SOURCES "STB/*.f90")
add_executable(STB ${STB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(STB PRIVATE FiNeR::FiNeR NewCEA ORION)
target_include_directories(STB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

if(USE_OPENMP)
  find_package(OpenMP REQUIRED COMPONENTS Fortran)
  target_link_libraries(ICB PRIVATE OpenMP::OpenMP_Fortran)
  target_link_libraries(BCB PRIVATE OpenMP::OpenMP_Fortran)
  target_link_libraries(STB PRIVATE OpenMP::OpenMP_Fortran)
endif()

if(USE_TECIO)
  target_link_libraries(ICB PRIVATE -pthread)
  target_link_libraries(BCB PRIVATE -pthread)
  target_link_libraries(STB PRIVATE -pthread)
endif()
