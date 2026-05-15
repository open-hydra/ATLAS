# Shared sources
file(GLOB COMMON_SOURCES "common/*.f90")
list(REMOVE_ITEM COMMON_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/common/global.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/common/registry.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/common/config_shared.f90"
)
list(PREPEND COMMON_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/common/global.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/common/registry.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/common/config_shared.f90"
)

# ICB executable: ICB/ + common
file(GLOB ICB_SOURCES "ICB/*.f90")
list(REMOVE_ITEM ICB_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/ICB/config.f90"
)
list(PREPEND ICB_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/ICB/config.f90"
)
add_executable(ICB ${ICB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(ICB PRIVATE FiNeR::FiNeR ${ATLAS_CEA_TARGET} ORION)
target_include_directories(ICB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# BCB executable: BCB/ + common
file(GLOB BCB_SOURCES "BCB/*.f90")
list(REMOVE_ITEM BCB_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/BCB/bc_names.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/BCB/config.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/BCB/types_bc.f90"
)
list(PREPEND BCB_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/BCB/bc_names.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/BCB/config.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/BCB/types_bc.f90"
)
add_executable(BCB ${BCB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(BCB PRIVATE FiNeR::FiNeR ${ATLAS_CEA_TARGET} ORION)
target_include_directories(BCB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# STB executable: STB/ + common
file(GLOB STB_SOURCES "STB/*.f90")
add_executable(STB ${STB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(STB PRIVATE FiNeR::FiNeR ${ATLAS_CEA_TARGET} ORION)
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
