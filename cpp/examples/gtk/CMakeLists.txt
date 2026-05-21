cmake_minimum_required(VERSION 3.15)
project(vg_gtk CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK4 REQUIRED IMPORTED_TARGET gtk4)
pkg_check_modules(CAIRO REQUIRED IMPORTED_TARGET cairo)

add_executable(vg_gtk main.cpp)
target_include_directories(vg_gtk PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../include"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../include/generated"
)
target_link_libraries(vg_gtk PRIVATE PkgConfig::GTK4 PkgConfig::CAIRO)

if(UNIX AND NOT APPLE)
    target_link_libraries(vg_gtk PRIVATE dl)
endif()
