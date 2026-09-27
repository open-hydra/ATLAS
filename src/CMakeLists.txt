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
if (TARGET fbasics::core)
  target_link_libraries(ICB PRIVATE fbasics::core)
endif()
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
if (TARGET fbasics::core)
  target_link_libraries(BCB PRIVATE fbasics::core)
endif()
target_include_directories(BCB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# MDB executable: MDB/ + common
file(GLOB MDB_SOURCES "MDB/*.f90")
list(REMOVE_ITEM MDB_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/MDB/config.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/MDB/decomposition.f90"
)
list(PREPEND MDB_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/MDB/config.f90"
  "${CMAKE_CURRENT_SOURCE_DIR}/MDB/decomposition.f90"
)
add_executable(MDB ${MDB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(MDB PRIVATE FiNeR::FiNeR ${ATLAS_CEA_TARGET} ORION)
if (TARGET fbasics::core)
  target_link_libraries(MDB PRIVATE fbasics::core)
endif()
target_include_directories(MDB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# STB executable: STB/ + common
file(GLOB STB_SOURCES "STB/*.f90")
add_executable(STB ${STB_SOURCES} ${COMMON_SOURCES})
target_link_libraries(STB PRIVATE FiNeR::FiNeR ${ATLAS_CEA_TARGET} ORION)
if (TARGET fbasics::core)
  target_link_libraries(STB PRIVATE fbasics::core)
endif()
target_include_directories(STB PRIVATE
    $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

# Each program compiles the common sources itself. With one module directory for all of them, two
# programs built in parallel (make -j) write the same .mod files at the same time and a compilation
# can fail on a module file another one is renaming ("Cannot rename module file"). Each program writes
# its modules to a directory of its own, searched before the shared one (which keeps ORION's modules).
foreach(_atlas_prog ICB BCB MDB STB)
  set_target_properties(${_atlas_prog} PROPERTIES
      Fortran_MODULE_DIRECTORY "${CMAKE_Fortran_MODULE_DIRECTORY}/${_atlas_prog}")
  target_include_directories(${_atlas_prog} BEFORE PRIVATE
      $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}/${_atlas_prog}>)
endforeach()

if (TARGET cea_abort_support)
  target_link_libraries(ICB PRIVATE cea_abort_support)
  target_link_libraries(BCB PRIVATE cea_abort_support)
  target_link_libraries(STB PRIVATE cea_abort_support)
  target_link_libraries(MDB PRIVATE cea_abort_support)
endif()

if(USE_OPENMP)
  find_package(OpenMP REQUIRED COMPONENTS Fortran)
  target_link_libraries(ICB PRIVATE OpenMP::OpenMP_Fortran)
  target_link_libraries(BCB PRIVATE OpenMP::OpenMP_Fortran)
  target_link_libraries(STB PRIVATE OpenMP::OpenMP_Fortran)
  target_link_libraries(MDB PRIVATE OpenMP::OpenMP_Fortran)
endif()

if(USE_TECIO)
  target_link_libraries(ICB PRIVATE -pthread)
  target_link_libraries(BCB PRIVATE -pthread)
  target_link_libraries(STB PRIVATE -pthread)
  target_link_libraries(MDB PRIVATE -pthread)
  # src/common/read_mesh.f90 refuses a .szplt mesh with a clear message and a
  # non-zero status when the build has no TecIO (ORION's own stop returns 0).
  target_compile_definitions(ICB PRIVATE TECIO)
  target_compile_definitions(BCB PRIVATE TECIO)
  target_compile_definitions(STB PRIVATE TECIO)
  target_compile_definitions(MDB PRIVATE TECIO)
endif()

# Link the Fortran programs with the Fortran driver. TecIO (C++, pulled in by
# ORION) would otherwise make CMake pick the CXX linker, which does not provide
# the entry point of an Intel Fortran main program (undefined reference to
# `main'). CMake adds the C++ runtime by itself. Same convention as ORION's own
# apps and as the Q2D/MOSE executables.
set_target_properties(ICB BCB MDB STB PROPERTIES LINKER_LANGUAGE Fortran)
