cmake_minimum_required(VERSION 3.15)
project(vg_tui CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(vg_tui main.cpp)
target_include_directories(vg_tui PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../../include")

if(UNIX AND NOT APPLE)
    target_link_libraries(vg_tui PRIVATE dl)
endif()
