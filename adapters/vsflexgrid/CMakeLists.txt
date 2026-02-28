cmake_minimum_required(VERSION 3.16)
project(VolvoxGridActiveX LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---------------------------------------------------------------------------
# ATL / COM requirements (Windows-only)
# ---------------------------------------------------------------------------
if(NOT WIN32)
    message(FATAL_ERROR "ActiveX/COM controls are only supported on Windows.")
endif()

# Find ATL -- typically ships with Visual Studio
# If ATL_ROOT is not set, we try the VS install path
if(NOT DEFINED ATL_INCLUDE_DIR)
    # Try to find ATL via the VC tools path
    if(DEFINED ENV{VCToolsInstallDir})
        set(ATL_INCLUDE_DIR "$ENV{VCToolsInstallDir}/atlmfc/include")
        set(ATL_LIB_DIR "$ENV{VCToolsInstallDir}/atlmfc/lib/x64")
    elseif(DEFINED ENV{VCINSTALLDIR})
        set(ATL_INCLUDE_DIR "$ENV{VCINSTALLDIR}/atlmfc/include")
        set(ATL_LIB_DIR "$ENV{VCINSTALLDIR}/atlmfc/lib/x64")
    else()
        message(WARNING "ATL_INCLUDE_DIR not set. Attempting system default.")
    endif()
endif()

if(ATL_INCLUDE_DIR AND EXISTS "${ATL_INCLUDE_DIR}")
    include_directories(${ATL_INCLUDE_DIR})
    link_directories(${ATL_LIB_DIR})
    message(STATUS "ATL include: ${ATL_INCLUDE_DIR}")
endif()

# ---------------------------------------------------------------------------
# Volvox plugin host
# ---------------------------------------------------------------------------
set(SYNURANG_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../.."
    CACHE PATH "Root of the synurang repository")

include_directories(
    ${SYNURANG_ROOT}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../codegen
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Protobuf (needed for volvoxgrid.pb.h / volvoxgrid.pb.cc)
find_package(Protobuf REQUIRED)
include_directories(${Protobuf_INCLUDE_DIRS})

# ---------------------------------------------------------------------------
# MIDL compile the IDL
# ---------------------------------------------------------------------------
set(IDL_FILE ${CMAKE_CURRENT_SOURCE_DIR}/src/VolvoxGrid.idl)
set(IDL_H    ${CMAKE_CURRENT_BINARY_DIR}/VolvoxGrid_i.h)
set(IDL_C    ${CMAKE_CURRENT_BINARY_DIR}/VolvoxGrid_i.c)
set(IDL_TLB  ${CMAKE_CURRENT_BINARY_DIR}/VolvoxGrid.tlb)
set(IDL_P    ${CMAKE_CURRENT_BINARY_DIR}/VolvoxGrid_p.c)
set(IDL_D    ${CMAKE_CURRENT_BINARY_DIR}/dlldata.c)

add_custom_command(
    OUTPUT  ${IDL_H} ${IDL_C} ${IDL_TLB} ${IDL_P} ${IDL_D}
    COMMAND midl
        /h   ${IDL_H}
        /iid ${IDL_C}
        /tlb ${IDL_TLB}
        /proxy ${IDL_P}
        /dlldata ${IDL_D}
        /win32
        /env x64
        ${IDL_FILE}
    DEPENDS ${IDL_FILE}
    COMMENT "Compiling IDL -> VolvoxGrid type library"
)
add_custom_target(VolvoxGridIDL DEPENDS ${IDL_H} ${IDL_C} ${IDL_TLB})

# ---------------------------------------------------------------------------
# DLL target
# ---------------------------------------------------------------------------
set(FLEXGRID_PROTO_CC "${CMAKE_CURRENT_SOURCE_DIR}/../codegen/volvoxgrid.pb.cc")

add_library(VolvoxGrid SHARED
    src/dllmain.cpp
    src/VolvoxGridCtrl.cpp
    src/ADOAdapter.cpp
    ${IDL_C}
    ${FLEXGRID_PROTO_CC}
)
add_dependencies(VolvoxGrid VolvoxGridIDL)

target_include_directories(VolvoxGrid PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}   # VolvoxGrid_i.h, VolvoxGrid.tlb
)

target_compile_definitions(VolvoxGrid PRIVATE
    _WINDOWS
    _USRDLL
    _ATL_DLL
    _ATL_NO_COM_SUPPORT=0
    UNICODE
    _UNICODE
    _WINDLL
)

# Link the synurang host library and protobuf
target_link_libraries(VolvoxGrid PRIVATE
    synurang          # Synurang C++ plugin host
    ${Protobuf_LIBRARIES}
    ole32
    oleaut32
    uuid
    advapi32
    user32
    gdi32
)

# Module definition file for COM exports
set_target_properties(VolvoxGrid PROPERTIES
    LINK_FLAGS "/DEF:\"${CMAKE_CURRENT_SOURCE_DIR}/src/VolvoxGrid.def\""
    OUTPUT_NAME "VolvoxGrid"
    SUFFIX ".dll"
)

# ---------------------------------------------------------------------------
# Post-build: register the COM DLL (development convenience)
# ---------------------------------------------------------------------------
add_custom_command(TARGET VolvoxGrid POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Build complete: $<TARGET_FILE:VolvoxGrid>"
    COMMAND ${CMAKE_COMMAND} -E echo "Register with: regsvr32 $<TARGET_FILE:VolvoxGrid>"
)
