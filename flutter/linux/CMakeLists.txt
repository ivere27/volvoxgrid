# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "volvoxgrid")
project(${PROJECT_NAME} LANGUAGES C)

# Resolve package root even when this file is accessed through .plugin_symlinks.
get_filename_component(VOLVOXGRID_PACKAGE_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." REALPATH)
set(VOLVOXGRID_MAVEN_SO "${VOLVOXGRID_PACKAGE_ROOT}/linux/x64/libvolvoxgrid_plugin.so")
set(VOLVOXGRID_PACKAGED_SO "${VOLVOXGRID_PACKAGE_ROOT}/linux/x64/libvolvoxgrid_plugin.so")
set(VOLVOXGRID_RELEASE_SO "${VOLVOXGRID_PACKAGE_ROOT}/../target/release/libvolvoxgrid_plugin.so")
set(VOLVOXGRID_DEBUG_SO "${VOLVOXGRID_PACKAGE_ROOT}/../target/debug/libvolvoxgrid_plugin.so")

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

# Check if Maven source is requested.
if(VOLVOXGRID_SOURCE STREQUAL "maven")
  message(STATUS "VolvoxGrid: Resolving plugin from Maven (version=${VOLVOXGRID_VERSION})...")

  # Prefer gradlew in repo checkout; fall back to system gradle for pub.dev use.
  set(VOLVOXGRID_GRADLE_EXECUTABLE "${VOLVOXGRID_PACKAGE_ROOT}/../android/gradlew")
  if(NOT EXISTS "${VOLVOXGRID_GRADLE_EXECUTABLE}")
    find_program(VOLVOXGRID_GRADLE_EXECUTABLE gradle)
  endif()

  if(VOLVOXGRID_GRADLE_EXECUTABLE)
    set(VOLVOXGRID_GRADLE_ARGS copyNative)
    if(VOLVOXGRID_VERSION MATCHES "-SNAPSHOT$")
      list(INSERT VOLVOXGRID_GRADLE_ARGS 0 "--refresh-dependencies")
    endif()
    execute_process(
      COMMAND "${VOLVOXGRID_GRADLE_EXECUTABLE}" -p "${VOLVOXGRID_PACKAGE_ROOT}/linux"
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
if(EXISTS "${VOLVOXGRID_PACKAGED_SO}")
  set(volvoxgrid_bundled_libraries
    "${VOLVOXGRID_PACKAGED_SO}"
    PARENT_SCOPE
  )
elseif(EXISTS "${VOLVOXGRID_RELEASE_SO}")
  set(volvoxgrid_bundled_libraries
    "${VOLVOXGRID_RELEASE_SO}"
    PARENT_SCOPE
  )
elseif(EXISTS "${VOLVOXGRID_DEBUG_SO}")
  set(volvoxgrid_bundled_libraries
    "${VOLVOXGRID_DEBUG_SO}"
    PARENT_SCOPE
  )
else()
  set(volvoxgrid_bundled_libraries "" PARENT_SCOPE)
endif()
