# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "volvoxgrid")
project(${PROJECT_NAME} LANGUAGES CXX)

# Resolve package root even when this file is accessed through .plugin_symlinks.
get_filename_component(VOLVOXGRID_PACKAGE_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." REALPATH)
set(VOLVOXGRID_PACKAGED_DLL "${VOLVOXGRID_PACKAGE_ROOT}/windows/x64/volvoxgrid_plugin.dll")
set(VOLVOXGRID_RELEASE_DLL "${VOLVOXGRID_PACKAGE_ROOT}/../target/release/volvoxgrid_plugin.dll")
set(VOLVOXGRID_DEBUG_DLL "${VOLVOXGRID_PACKAGE_ROOT}/../target/debug/volvoxgrid_plugin.dll")

# Resolve source/version from env.
# Default to Maven so pub.dev consumers work without monorepo-local binaries.
set(VOLVOXGRID_SOURCE "maven")
if(DEFINED ENV{VOLVOXGRID_SOURCE})
  set(VOLVOXGRID_SOURCE "$ENV{VOLVOXGRID_SOURCE}")
endif()
set(VOLVOXGRID_VERSION "0.3.0")
if(DEFINED ENV{VOLVOXGRID_VERSION})
  set(VOLVOXGRID_VERSION "$ENV{VOLVOXGRID_VERSION}")
endif()

if(NOT VOLVOXGRID_SOURCE STREQUAL "maven" AND NOT VOLVOXGRID_SOURCE STREQUAL "local")
  message(FATAL_ERROR "VolvoxGrid: Invalid VOLVOXGRID_SOURCE='${VOLVOXGRID_SOURCE}'. Expected 'maven' or 'local'.")
endif()

if(VOLVOXGRID_SOURCE STREQUAL "maven")
  message(STATUS "VolvoxGrid: Resolving plugin from Maven (version=${VOLVOXGRID_VERSION})...")

  if(WIN32)
    set(VOLVOXGRID_GRADLE_EXECUTABLE "${VOLVOXGRID_PACKAGE_ROOT}/../android/gradlew.bat")
  else()
    set(VOLVOXGRID_GRADLE_EXECUTABLE "${VOLVOXGRID_PACKAGE_ROOT}/../android/gradlew")
  endif()

  if(NOT EXISTS "${VOLVOXGRID_GRADLE_EXECUTABLE}")
    find_program(VOLVOXGRID_GRADLE_EXECUTABLE NAMES gradle gradle.bat gradle.cmd)
  endif()

  if(VOLVOXGRID_GRADLE_EXECUTABLE)
    set(VOLVOXGRID_GRADLE_ARGS copyNative)
    if(VOLVOXGRID_VERSION MATCHES "-SNAPSHOT$")
      list(INSERT VOLVOXGRID_GRADLE_ARGS 0 "--refresh-dependencies")
    endif()
    execute_process(
      COMMAND "${VOLVOXGRID_GRADLE_EXECUTABLE}" -p "${VOLVOXGRID_PACKAGE_ROOT}/windows"
              -PvolvoxgridVersion=${VOLVOXGRID_VERSION}
              ${VOLVOXGRID_GRADLE_ARGS}
      RESULT_VARIABLE gradlew_result
    )
    if(NOT gradlew_result EQUAL 0)
      message(WARNING "VolvoxGrid: Failed to download plugin from Maven via Gradle.")
    endif()
  else()
    message(WARNING "VolvoxGrid: gradle not found. Skipping Maven resolution.")
  endif()
endif()

# Prefer Maven/packaged pub artifact first, then local release/debug builds.
if(EXISTS "${VOLVOXGRID_PACKAGED_DLL}")
  set(volvoxgrid_bundled_libraries
    "${VOLVOXGRID_PACKAGED_DLL}"
    PARENT_SCOPE
  )
elseif(EXISTS "${VOLVOXGRID_RELEASE_DLL}")
  set(volvoxgrid_bundled_libraries
    "${VOLVOXGRID_RELEASE_DLL}"
    PARENT_SCOPE
  )
elseif(EXISTS "${VOLVOXGRID_DEBUG_DLL}")
  set(volvoxgrid_bundled_libraries
    "${VOLVOXGRID_DEBUG_DLL}"
    PARENT_SCOPE
  )
else()
  set(volvoxgrid_bundled_libraries "" PARENT_SCOPE)
endif()
