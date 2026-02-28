# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "volvoxgrid")
project(${PROJECT_NAME} LANGUAGES C)

# Resolve package root even when this file is accessed through .plugin_symlinks.
get_filename_component(VOLVOXGRID_PACKAGE_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." REALPATH)
set(VOLVOXGRID_PACKAGED_SO "${VOLVOXGRID_PACKAGE_ROOT}/linux/x64/libvolvoxgrid_plugin.so")
set(VOLVOXGRID_RELEASE_SO "${VOLVOXGRID_PACKAGE_ROOT}/../target/release/libvolvoxgrid_plugin.so")
set(VOLVOXGRID_DEBUG_SO "${VOLVOXGRID_PACKAGE_ROOT}/../target/debug/libvolvoxgrid_plugin.so")

# Prefer packaged pub artifact first, then local release/debug builds.
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
